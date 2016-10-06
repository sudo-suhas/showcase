package com.secret.ecom.elasticsearch.searchadapter;

import java.util.*;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.LinkedBlockingQueue;

import com.secret.ecom.misc.HTTPHelper;
import com.secret.ecom.misc.UtilConfig;
import org.apache.http.Header;
import org.apache.http.HttpEntityEnclosingRequest;
import org.apache.http.HttpHost;
import org.apache.http.HttpRequest;
import org.apache.http.client.config.CookieSpecs;
import org.apache.http.client.config.RequestConfig;
import org.apache.http.client.protocol.HttpClientContext;
import org.apache.http.config.ConnectionConfig;
import org.apache.http.impl.client.CloseableHttpClient;
import org.apache.http.impl.client.HttpClients;
import org.apache.http.impl.conn.PoolingHttpClientConnectionManager;
import org.apache.http.message.BasicHeader;
import org.ofbiz.base.util.Debug;
import org.ofbiz.base.util.UtilProperties;
import org.ofbiz.base.util.UtilValidate;
import org.ofbiz.entity.Delegator;
import org.ofbiz.entity.DelegatorFactory;

public class SearchAdapterClient {
    // Private and used only within class
    public static final String MODULE = SearchAdapterClient.class.getName();
    private static final String CONFIG_KEY_ENABLED = "enable.search_adapter";
    private static final String CONFIG_KEY_PERSISTENCE_ENABLED = "enable.search_adapter.persistence";
    private static final boolean ENABLED;

    private static HttpHost targetHost;
    private static HttpClientContext context;
    private static List<Header> getHeaders;
    private static List<Header> postHeaders;

    // Protected and used within package
    static boolean PERSISTENCE_ENABLED;
    static final String DOC_UPDATE_ENDPOINT = "/module/{module}/docType/{docType}";
    static final String STATUS_ENDPOINT = "/status/{req_id}";
    static final int STATUS_OK = 200;
    static final int STATUS_ACCEPTED = 202;
    static final int STATUS_BAD_REQUEST = 400;

    static PoolingHttpClientConnectionManager poolingConnManager;

    static ExecutorService EXECUTOR;
    static final Queue<SearchAdapterRequest> requestQueue;
    static final Queue<SearchAdapterRequest> acceptedQueue;
    static final RequestQueueUtils requestQueueUtils;

    static {
        Debug.logInfo("Entered static block of Search Adapter Client", MODULE);
        final Delegator delegator = DelegatorFactory.getDelegator("default");

        ENABLED = Boolean.parseBoolean(UtilConfig.getValueFromConfig(delegator, CONFIG_KEY_ENABLED, "false"));

        requestQueueUtils = new RequestQueueUtils(delegator);
        String hostName = UtilProperties.getPropertyValue("general.properties", "unique.instanceId", "ofbiz");
        Boolean enableRequestQueues = hostName.equals("ofbizot1") || hostName.equals("ofbiz");
        if (enableRequestQueues) {
            // Retrieve all pending requests from database
            // But only do so on selected machines
            requestQueue = requestQueueUtils.fetchRequestQueue(requestQueueUtils.requestQueueCondition());
            acceptedQueue = requestQueueUtils.fetchRequestQueue(requestQueueUtils.acceptedQueueCondition());
        } else {
            requestQueue = new LinkedBlockingQueue<>();
            acceptedQueue = new LinkedBlockingQueue<>();
        }
        if (ENABLED) {
            // Populate authToken, projectId and url using UtilProperties.getPropertyValue
            String hostUrl = UtilProperties.getPropertyValue("general.properties", "search_adapter.url",
                    "http://localhost:6789");
            hostUrl = hostUrl.endsWith("/") ? hostUrl.substring(0, hostUrl.length() - 1) : hostUrl;

            targetHost = HttpHost.create(hostUrl);

            poolingConnManager = new PoolingHttpClientConnectionManager();
            poolingConnManager.setDefaultConnectionConfig(ConnectionConfig.DEFAULT);
            poolingConnManager.setMaxTotal(10);
            poolingConnManager.setDefaultMaxPerRoute(3);
            poolingConnManager.setValidateAfterInactivity(3000);

            context = HttpClientContext.create();
            context.setRequestConfig(
                    RequestConfig.custom()
                            .setConnectionRequestTimeout(10000)
                            .setConnectTimeout(10000)
                            .setSocketTimeout(10000)
                            .setExpectContinueEnabled(true)
                            .setCookieSpec(CookieSpecs.IGNORE_COOKIES)
                            .build());

            final String authToken =
                    UtilProperties.getPropertyValue("general.properties", "search_adapter.token", "dummy");

            Header authHeader = new BasicHeader("X-Auth-Token", authToken),
                    acceptHeader = new BasicHeader("accept", "application/json");
            getHeaders = new ArrayList<>(2);
            getHeaders.add(authHeader);
            getHeaders.add(acceptHeader);

            postHeaders = new ArrayList<>(3);
            postHeaders.add(authHeader);
            postHeaders.add(acceptHeader);
            postHeaders.add(new BasicHeader("Content-type", "application/json"));

            // http://stackoverflow.com/questions/949355/java-newcachedthreadpool-versus-newfixedthreadpool
            // http://tutorials.jenkov.com/java-util-concurrent/executorservice.html
            // http://stackoverflow.com/questions/3195035/
            // how-expensive-is-creating-of-a-new-thread-in-java-when-should-we-consider-using
            EXECUTOR = Executors.newCachedThreadPool();

            // Start a request queue processor thread in the background
            EXECUTOR.execute(new RequestQueueProcessor());

            // Start a accepted request queue processor thread in the background
            EXECUTOR.execute(new AcceptedQueueProcessor());

            PERSISTENCE_ENABLED = Boolean.parseBoolean(
                    UtilConfig.getValueFromConfig(delegator, CONFIG_KEY_PERSISTENCE_ENABLED, "false"));

            if (PERSISTENCE_ENABLED) {
                EXECUTOR.execute(new PersistRequestProcessor(requestQueueUtils));
            }
        }
    }

    public static void init() {
        // Calling this method executes the static block
        Debug.logInfo("Force initialisation of Search Adapter Client", MODULE);
    }

    private static void newProductUpdateRequest(final String productId, final String entity, final String mode,
                                                final boolean async) {
        // Method for new request. Compact requests and persist to database
        // Although not shown here, this methos is called from multiple methods
        // which accept input either through 'services' or HTTP requests,
        // process it and call this method
        EXECUTOR.execute(new ProductUpdateRequest(productId, entity, mode, async));
    }

    static JSONObject executeRequest(HttpRequest request, String errorMsg) throws Exception {
        CloseableHttpClient client = request instanceof HttpEntityEnclosingRequest ?
                httpClient(postHeaders) : httpClient(getHeaders);
        //https://github.com/sudo-suhas/showcase/blob/master/java/README.md#httphelper.java
        return HTTPHelper.httpClientResponseJSON(client, targetHost, request, context, errorMsg, 3);
    }

    private static CloseableHttpClient httpClient(List<Header> headers) {
        return HttpClients.custom()
                .setConnectionManager(poolingConnManager)
                .setDefaultHeaders(headers)
                .build();
    }
}
