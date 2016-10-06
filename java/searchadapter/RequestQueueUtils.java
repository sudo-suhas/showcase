package com.secret.ecom.elasticsearch.searchadapter;

import java.util.*;
import java.util.concurrent.LinkedBlockingQueue;

import org.ofbiz.base.util.Debug;
import org.ofbiz.base.util.UtilDateTime;
import org.ofbiz.base.util.UtilMisc;
import org.ofbiz.entity.Delegator;
import org.ofbiz.entity.GenericEntityException;
import org.ofbiz.entity.GenericValue;
import org.ofbiz.entity.condition.EntityCondition;
import org.ofbiz.entity.condition.EntityDateFilterCondition;
import org.ofbiz.entity.condition.EntityOperator;

// https://github.com/sudo-suhas/showcase/blob/master/java/README.md#requesttablecolumns.java
import static com.secret.ecom.elasticsearch.searchadapter.RequestTableColumns.*;
import static org.ofbiz.entity.condition.EntityCondition.makeCondition;
import static org.ofbiz.entity.condition.EntityOperator.AND;
import static org.ofbiz.entity.condition.EntityOperator.EQUALS;
import static org.ofbiz.entity.condition.EntityOperator.OR;

class RequestQueueUtils {
    public static final String MODULE = RequestQueueUtils.class.getName();
    static final String REQUEST_TABLE = "SplSearchAdapterRequestsV2";
    public static final String YES = "Y";
    public static final String NO = "N";
    private static final int ROW_COUNT_THRESHOLD = 20;

    final Set<SearchAdapterRequest> requestsToPersist;
    private final Delegator delegator;

    RequestQueueUtils(final Delegator delegator) {
        this.delegator = delegator;
        requestsToPersist = new HashSet<>();
    }

    EntityCondition acceptedQueueCondition() {
        return makeCondition(
                UtilMisc.toList(makeCondition(String.valueOf(ACCEPTED), EQUALS, YES),
                        makeCondition(String.valueOf(COMPLETED), EQUALS, NO),
                        makeCondition(String.valueOf(BAD_REQUEST), EQUALS, NO)),
                AND);
    }

    EntityCondition requestQueueCondition() {
        return makeCondition(UtilMisc.toList(
                makeCondition(String.valueOf(BAD_REQUEST), EQUALS, NO),
                makeCondition(UtilMisc.toList(makeCondition(String.valueOf(ACCEPTED), EQUALS, NO),
                        makeCondition(UtilMisc.toList(makeCondition(String.valueOf(ACCEPTED), EQUALS, YES),
                                makeCondition(String.valueOf(COMPLETED), EQUALS, YES),
                                makeCondition(String.valueOf(SUCCESSFUL), EQUALS, NO)), AND)), OR)), AND);
    }

    Queue<SearchAdapterRequest> fetchRequestQueue(final EntityCondition whereCondition) {
        try {

            final List<GenericValue> persistedRequestList = delegator.findByCondition(RequestQueueUtils.REQUEST_TABLE,
                    whereCondition, null, UtilMisc.toList(String.valueOf(REQ_SERIAL_NO)));

            final Queue<SearchAdapterRequest> queue = new LinkedBlockingQueue<>();
            for (final GenericValue persistedRequest : persistedRequestList)
                try {
                    queue.offer(new SearchAdapterRequest(persistedRequest));
                } catch (final Exception e) {
                    Debug.logError(e,
                            "Failed to load request for reqId - " + persistedRequest.get(String.valueOf(REQ_ID)),
                            MODULE);
                }
            return queue;
        } catch (final GenericEntityException e) {
            Debug.logError(e, "Error initialising request queue for Search Adapter", MODULE);
            return new LinkedBlockingQueue<>();
        }
    }

    void persistRequest(final SearchAdapterRequest request) {
        if (request.getReqSerialNo() == 0)
            request.setReqSerialNo(Long.parseLong(delegator.getNextSeqId(REQUEST_TABLE)));
        boolean persistFlag = false;
        if (SearchAdapterClient.PERSISTENCE_ENABLED) {
            synchronized (requestsToPersist) {
                requestsToPersist.add(request);
                if (requestsToPersist.size() > ROW_COUNT_THRESHOLD)
                    persistFlag = true;
            }
            if (persistFlag)
                persistBatchRequest();
        }
    }

    void persistBatchRequest() {
        Set<SearchAdapterRequest> batchRequests = null;
        synchronized (requestsToPersist) {
            if (!requestsToPersist.isEmpty()) {
                batchRequests = new HashSet<>(requestsToPersist);
                requestsToPersist.clear();
            }
        }
        if (batchRequests != null) {
            try {
                List<GenericValue> rows = new ArrayList<>();
                for (SearchAdapterRequest request : batchRequests) {
                    rows.add(request.asGenericValue(delegator));
                }
                delegator.storeAll(rows);
            } catch (final GenericEntityException e) {
                Debug.logError(e, "Error while saving batch of search adapter requests", MODULE);
            }
        }
    }
}
