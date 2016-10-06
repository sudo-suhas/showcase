package com.secret.ecom.elasticsearch.searchadapter;

import java.util.Date;
import java.util.Set;

import org.apache.http.HttpEntityEnclosingRequest;
import org.apache.http.client.methods.HttpPost;
import org.apache.http.client.methods.HttpPut;
import org.apache.http.client.methods.HttpRequestBase;
import org.apache.http.entity.ContentType;
import org.apache.http.entity.StringEntity;
import org.json.JSONException;
import org.json.JSONObject;
import org.ofbiz.base.util.Debug;
import org.ofbiz.base.util.UtilValidate;

class RequestQueueProcessor extends Processor {

    @Override
    public void run() {
        // noinspection InfiniteLoopStatement
        while (true) {
            final SearchAdapterRequest request = SearchAdapterClient.requestQueue.peek();
            if (request != null)
                synchronized (SearchAdapterClient.requestQueue) {
                    JSONObject payload = null;
                    HttpEntityEnclosingRequest httpReq = null;
                    try {
                        // Construct payload using docIds, entities, async
                        payload = new JSONObject();
                        final Set<String> docIds = request.getDocIdsCopy();
                        final Set<String> entities = request.getEntitiesCopy();
                        final String mode = request.getMode();

                        if (UtilValidate.isNotEmpty(docIds))
                            payload.put("docIds", docIds);
                        if (UtilValidate.isNotEmpty(entities))
                            payload.put("entities", entities);
                        if (!request.isAsync())
                            payload.put("async", false);


                        String requestMode, route = RouteBuilder.builder()
                                .setRoute(SearchAdapterClient.DOC_UPDATE_ENDPOINT)
                                .setRouteParam("module", request.getModule())
                                .setRouteParam("docType", request.getDocType())
                                .build();

                        switch (mode) {
                            case "create":
                                requestMode = "POST";
                                httpReq = new HttpPost(route);
                                break;
                            case "update":
                                requestMode = "PUT";
                                httpReq = new HttpPut(route);
                                break;
                            default:
                                throw new Exception("Unknown request mode - " + mode + " for request serial no. "
                                        + request.getReqSerialNo());
                        }

                        httpReq.setEntity(new StringEntity(payload.toString(), ContentType.APPLICATION_JSON));
                        final String errorMsg = String.format("Error while sending %s update request to %s", requestMode, route);
                        final JSONObject jsonResponse = SearchAdapterClient.executeRequest(httpReq, errorMsg);

                        // Check response for status
                        final int status = jsonResponse.getInt("statusCode");

                        request.setCompleted(false);
                        request.setCompletedDate(null);
                        request.setSuccessful(false);

                        if ((status == SearchAdapterClient.STATUS_OK)
                                || (status == SearchAdapterClient.STATUS_ACCEPTED)) {
                            // Update accepted, completed appropriately and push to accepted queue if required
                            final Date now = new Date();
                            request.setAccepted(true);
                            request.setAcceptedDate(now);

                            if (status == SearchAdapterClient.STATUS_OK) {
                                request.setCompleted(true);
                                request.setCompletedDate(now);
                                request.setSuccessful(true);
                            } else
                                SearchAdapterClient.acceptedQueue.offer(request);

                            // Call remove(poll) on queue
                            SearchAdapterClient.requestQueue.poll();

                            final JSONObject response = new JSONObject(jsonResponse.getString("responseString"));
                            request.setReqId(response.getString(String.valueOf(RequestTableColumns.REQ_ID)));

                            // Save to database
                            SearchAdapterClient.requestQueueUtils.persistRequest(request);
                            continue;
                        } else if (status == SearchAdapterClient.STATUS_BAD_REQUEST) {
                            Debug.logError("Bad Request encountered in serial no " + request.getReqSerialNo(), MODULE);
                            Debug.logError("Bad Request payload - " + payload.toString(), MODULE);
                            Debug.logError("Response - " + jsonResponse.getString("responseString"), MODULE);

                            request.setBadRequest(true);
                            SearchAdapterClient.requestQueue.poll();
                            SearchAdapterClient.requestQueueUtils.persistRequest(request);
                        }
                    } catch (final JSONException e) {
                        Debug.logError(e, "Error constructing request for serial no " + request.getReqSerialNo(),
                                MODULE);
                        if (payload != null) {
                            Debug.logError("Error Payload - " + payload.toString(), MODULE);
                        }

                        SearchAdapterClient.requestQueue.poll();
                    } catch (final Exception e) {
                        Debug.logError(e, MODULE);

                        // SearchAdapterClient.requestQueue.poll();
                    } finally {
                        if (httpReq != null) {
                            ((HttpRequestBase) httpReq).reset();
                        }
                    }
                }
            // No request in queue or call to Search Adapter failed.
            // Repeat the call after getting some beauty sleep.
            /* For the status code 500(SERVER ERROR) - Keep retrying until elasticsearch is up and running
               For the status code 412(Precondition Failed i.e. Resource Busy) - Keep retrying
               until resource is free.
             */
            sleep();
        }
    }
}