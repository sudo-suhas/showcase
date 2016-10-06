package com.secret.ecom.elasticsearch.searchadapter;

import java.text.DateFormat;
import java.text.ParseException;
import java.text.SimpleDateFormat;

import org.apache.http.client.methods.HttpGet;
import org.json.JSONException;
import org.json.JSONObject;
import org.ofbiz.base.util.Debug;
import org.ofbiz.base.util.UtilValidate;

// https://github.com/sudo-suhas/showcase/blob/master/java/README.md#processor.java
class AcceptedQueueProcessor extends Processor {
    private static final DateFormat FORMAT = new SimpleDateFormat("MMMM dd, yyyy - hh:mm:ss aa");

    @Override
    public void run() {
        // noinspection InfiniteLoopStatement
        while (true) {
            final SearchAdapterRequest request = SearchAdapterClient.acceptedQueue.poll();
            boolean goToSleep = request == null;
            if (request != null && UtilValidate.isNotEmpty(request.getReqId())) {
                HttpGet httpReq = null;
                try {
                    // https://github.com/sudo-suhas/showcase/blob/master/java/README.md#routebuilder.java
                    final String route = RouteBuilder.builder()
                            .setRoute(SearchAdapterClient.STATUS_ENDPOINT)
                            .setRouteParam("req_id", request.getReqId())
                            .build();

                    httpReq = new HttpGet(route);
                    final String errorMsg = "Error retrieving request status for reqId " + request.getReqId();
                    JSONObject jsonResponse = SearchAdapterClient.executeRequest(httpReq, errorMsg);

                    int responseStatus = jsonResponse.getInt("statusCode");
                    if (responseStatus == SearchAdapterClient.STATUS_OK) {
                        final JSONObject response = new JSONObject(jsonResponse.getString("responseString"));
                        final JSONObject result = response.getJSONObject("result");

                        if (result.getBoolean("requestCompleted")) {
                            request.setCompleted(true);
                            request.setCompletedDate(FORMAT.parse(result.getString("completed")));
                            boolean successful = result.getBoolean("successful");
                            request.setSuccessful(successful);
                            request.setStatusDesc(result.getJSONArray("status"));
                            // Save to database
                            SearchAdapterClient.requestQueueUtils.persistRequest(request);
                            // if unsuccessful, add to request queue
                            if (!successful) {
                                synchronized (SearchAdapterClient.requestQueue) {
                                    SearchAdapterClient.requestQueue.offer(request);
                                }
                            }
                        } else {
                            SearchAdapterClient.acceptedQueue.offer(request);
                            if (SearchAdapterClient.acceptedQueue.size() < 2)
                                goToSleep = true;
                        }
                    } else if (responseStatus == SearchAdapterClient.STATUS_BAD_REQUEST) {
                        Debug.logError("Bad Request encountered for reqId " + request.getReqId(), MODULE);
                        Debug.logError("Response - " + jsonResponse.getString("responseString"), MODULE);

                        request.setBadRequest(true);
                        SearchAdapterClient.requestQueueUtils.persistRequest(request);
                    } else {
                        SearchAdapterClient.acceptedQueue.offer(request);
                        goToSleep = true;
                    }
                } catch (final ParseException e) {
                    Debug.logError(e, "Error parsing completed date field for reqId " + request.getReqId(), MODULE);
                } catch (final JSONException e) {
                    Debug.logError(e, "Error reading json response for reqId " + request.getReqId(), MODULE);
                } catch (final Exception e) {
                    Debug.logError(e, "Error retrieving request status for reqId " + request.getReqId(), MODULE);
                    SearchAdapterClient.acceptedQueue.offer(request);
                    goToSleep = true;
                } finally {
                    if (httpReq != null) {
                        // Release connection back to pool
                        httpReq.reset();
                    }
                }
            }
            if (goToSleep)
                sleep();
        }
    }
}