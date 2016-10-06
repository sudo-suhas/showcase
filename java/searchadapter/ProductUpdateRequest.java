package com.secret.ecom.elasticsearch.searchadapter;

import java.util.Set;

import org.ofbiz.base.util.UtilValidate;

/**
 * Created by suhas on 1/9/16.
 */
class ProductUpdateRequest implements Runnable {
    private static final String ADAPTER_MODULE = "product_listing";
    private static final String DOC_TYPE = "products";
    private final String productId;
    private final String entity;
    private final String mode;
    private final boolean async;

    ProductUpdateRequest(final String productId, final String entity, final String mode,
                         final boolean async) {
        this.productId = productId;
        this.entity = entity;
        this.mode = mode;
        this.async = async;
    }

    @Override
    public void run() {
        SearchAdapterRequest persistedRequest = null;
        try {
            synchronized (SearchAdapterClient.requestQueue) {
                for (final SearchAdapterRequest request : SearchAdapterClient.requestQueue) {
                    if (!request.getMode().equals(mode) || request.isAsync() != async)
                        continue;
                    // We use copies to be able to track which properties of SearchAdapterRequest have changed
                    final Set<String> docIds = request.getDocIdsCopy();
                    final Set<String> entities = request.getEntitiesCopy();
                    if ((UtilValidate.isEmpty(docIds) && productId == null) ||
                            (UtilValidate.isNotEmpty(docIds) && docIds.contains(productId))) {
                        if (UtilValidate.isNotEmpty(entity) && !entities.contains(entity)) {
                            entities.add(entity);
                            request.setEntities(entities);
                            persistedRequest = request;
                        }
                        return;
                    } else if (UtilValidate.isEmpty(entities) && entity == null ||
                            UtilValidate.isNotEmpty(entities) && entities.contains(entity)) {
                        if (UtilValidate.isNotEmpty(productId)) {
                            docIds.add(productId);
                            request.setDocIds(docIds);
                            persistedRequest = request;
                        }
                        return;
                    }
                }
                // https://github.com/sudo-suhas/showcase/blob/master/java/README.md#searchadapterrequest.java
                persistedRequest =
                        new SearchAdapterRequest(ADAPTER_MODULE, DOC_TYPE, productId, entity, mode, async);
                SearchAdapterClient.requestQueue.offer(persistedRequest);
            }
        } finally {
            if (persistedRequest != null) {
                SearchAdapterClient.requestQueueUtils.persistRequest(persistedRequest);
            }
        }
    }
}
