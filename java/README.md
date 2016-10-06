# Search Adapter Client

All of this code is runnign inside [ofbiz](http://ofbiz.apache.org/) framework.
But the version is pretty old. Doesn't matter.
The framework only comes in for making database calls using an ORM.

## Short description
The [class](searchadapter/SearchAdapterClient.java) takes in requests
for updates which need to be triggered against a REST application.
It uses a queue and database for saving the requests and processing one by one.

## Description
[Apache HTTP client](https://hc.apache.org/) is used for making the requests.
The REST app processes requests in async(optional) and returns a request id
which can be queried for checking the request status.
So we use 2 queues. [One](searchadapter/RequestQueueProcessor.java)
for requests that are yet to be sent to the REST app
and [another](searchadapter/AcceptedQueueProcessor.java)
for ones which have been accepted. Another queue
is used for pushing databse update requests.

The update request, broadly speaking, has a product id and an entity that needs
to be updated in elasticsearch. So we use some intelligence to
[merge requests]((searchadapter/ProductUpdateRequest.java#L37-L53).
For example, if an update request is already present in the queue for
the same product but a different entity, we update the entities *only* in the
same request.

## Other Helper code

#### Processor.java
<details>
    <summary>Click to expand</summary>
```java
abstract class Processor implements Runnable {
    protected final String MODULE;

    protected Processor() {
        MODULE = getClassName();
    }

    protected void sleep() {
        try {
            TimeUnit.SECONDS.sleep(60);
        } catch (final InterruptedException e) {
            Debug.logError(e, "Sleep interrupted!", MODULE);
            SearchAdapterClient.poolingConnManager.shutdown();
            SearchAdapterClient.EXECUTOR.shutdown();
        }
    }

    private String getClassName() {
        final Class<?> enclosingClass = getClass().getEnclosingClass();
        if (enclosingClass != null)
            return enclosingClass.getName();
        else
            return getClass().getName();
    }
}
```
</details>
#### HTTPHelper.java
<details>
    <summary>Click to expand</summary>
```java
    /**
     * Returns a JSON with keys 'statusCode', 'reasonPhrase' and 'responseString'
     * when the response is with status code 200 or 400.
     * Repeated 500(internal server error) will result in an exception being thrown eventually
     *
     * @param httpclient
     * @param targetHost
     * @param httpRequest
     * @param context
     * @param errorMsg
     * @param retryCount
     * @return JSON object with response string, status code.
     * @throws Exception
     */
    public static JSONObject httpClientResponseJSON(CloseableHttpClient httpclient, HttpHost targetHost,
                                                    HttpRequest httpRequest, HttpContext context, String errorMsg,
                                                    int retryCount) throws Exception {
        CloseableHttpResponse response = null;
        String lastFailureMessage = "Unknown";
        int ctr = 0, statusCode;
        do {
            if (ctr >= retryCount)
                throw new Exception(errorMsg + "; Reason - " + lastFailureMessage + "; Exceeded retry count!");

            try {
                if (context != null)
                    response = httpclient.execute(targetHost, httpRequest, context);
                if (response != null) {
                    statusCode = response.getStatusLine().getStatusCode();
                    if (statusCode == 200 || statusCode == 202) {
                        return responseJSON(response);
                    } else {
                        Debug.logError("Could not get successful response from Host - " + targetHost.toURI()
                                + ". Reason - " + response.getStatusLine().getReasonPhrase(), MODULE);
                        if (statusCode == 400) {
                            // Bad request
                            return responseJSON(response);
                        }
                        if (ctr >= retryCount - 1) {
                            lastFailureMessage = buildFailureMessage(response);
                        }
                    }
                }
                ctr++;
            } catch (Exception ex) {
                Debug.logError(ex.getMessage(), MODULE);
                ctr++;
                if (ctr >= retryCount) {
                    throw ex;
                }
            } finally {
                try {
                    if (response != null)
                        response.close();
                } catch (IOException ignored) {}
            }
        } while (response == null || response.getStatusLine().getStatusCode() != 200);
        return null;
    }

    private static JSONObject responseJSON(CloseableHttpResponse response) throws IOException {
        JSONObject responseJSON = new JSONObject();
        responseJSON.put("statusCode", response.getStatusLine().getStatusCode());
        responseJSON.put("reasonPhrase", response.getStatusLine().getReasonPhrase());
        responseJSON.put("responseString", EntityUtils.toString(response.getEntity(), "UTF-8"));
        return responseJSON;
    }

    private static String buildFailureMessage(CloseableHttpResponse response) {
        String failureMessage = response.getStatusLine().getReasonPhrase();
        try {
            String responseString = EntityUtils.toString(response.getEntity(), "UTF-8");
            try {
                JSONObject responseJSON = new JSONObject(responseString);
                String msgKey = responseJSON.has("message") ? "message" : responseJSON.has("msg") ? "msg" : "";
                if (!msgKey.isEmpty())
                    failureMessage += " - " + responseJSON.getString("message");
                else {
                    failureMessage += " - " + responseString;
                }
            } catch (Exception ex) {
                failureMessage += " - " + responseString;
            }
        } catch (Exception ignore) {
        }
        return failureMessage;
    }
```
</details>

#### RouteBuilder.java
<details>
    <summary>Click to expand</summary>
```java
class RouteBuilder {
    private String route = "";

    static RouteBuilder builder() {
        return new RouteBuilder();
    }

    RouteBuilder setRoute(final String route) {
        this.route = route;
        return this;
    }

    RouteBuilder setRouteParam(final String name, final String value) throws UnsupportedEncodingException {
        Matcher matcher = Pattern.compile("\\{" + name + "\\}").matcher(route);
        boolean matched = false;
        while (matcher.find()) {
            matched = true;
            break;
        }
        if (!matched) {
            throw new RuntimeException("Can't find route parameter name \"" + name + "\"");
        }
        route = route.replaceAll("\\{" + name + "\\}", URLEncoder.encode(value, "UTF-8"));
        return this;
    }

    String build() {
        return route;
    }
}
```
</details>

#### SearchAdapterRequest.java
<details>
    <summary>Click to expand</summary>
```java
class SearchAdapterRequest {

    private static final DateFormat FORMAT = new SimpleDateFormat("yyyy-mm-dd HH:mm:ss.SSS");
    private long reqSerialNo;
    private final String module;
    private final String docType;
    private final String mode;
    private Set<String> docIds;
    private Set<String> entities;
    private final boolean async;
    private String reqId;
    private boolean accepted;
    private Date acceptedDate;
    private boolean completed;
    private Date completedDate;
    private boolean successful;
    private JSONArray statusDesc;
    private boolean badRequest;
    private final String instanceId;

    private boolean freshRequest;
    private final Set<RequestTableColumns> updatedFields = new HashSet<>();

    SearchAdapterRequest(final GenericValue persistedRequest) throws JSONException {
        reqSerialNo = Long.parseLong(persistedRequest.getString(String.valueOf(REQ_SERIAL_NO)));
        module = persistedRequest.getString(String.valueOf(MODULE));
        docType = persistedRequest.getString(String.valueOf(DOC_TYPE));
        mode = persistedRequest.getString(String.valueOf(MODE));
        docIds = getSetFromCsv(persistedRequest.getString(String.valueOf(DOC_IDS)));
        entities = getSetFromCsv(persistedRequest.getString(String.valueOf(ENTITIES)));
        async = persistedRequest.getBoolean(String.valueOf(ASYNC));
        reqId = persistedRequest.getString(String.valueOf(REQ_ID));
        accepted = persistedRequest.getBoolean(String.valueOf(ACCEPTED));
        acceptedDate = getAsDate(persistedRequest.getString(String.valueOf(ACCEPTED_DATE)));
        // acceptedDate = persistedRequest.getDate(String.valueOf(ACCEPTED_DATE));
        completed = persistedRequest.getBoolean(String.valueOf(COMPLETED));
        completedDate = getAsDate(persistedRequest.getString(String.valueOf(COMPLETED_DATE)));
        // completedDate = persistedRequest.getDate(String.valueOf(COMPLETED_DATE));
        successful = persistedRequest.getBoolean(String.valueOf(SUCCESSFUL));
        final String statusDescStr = persistedRequest.getString(String.valueOf(STATUS_DESC));
        if (UtilValidate.isNotEmpty(statusDescStr))
            statusDesc = new JSONArray(persistedRequest.getString(String.valueOf(STATUS_DESC)));
        badRequest = persistedRequest.getBoolean(String.valueOf(BAD_REQUEST));
        instanceId = persistedRequest.getString(String.valueOf(INSTANCE_ID));
        freshRequest = false;
    }

    GenericValue asGenericValue(final Delegator delegator) {
        final GenericValue request = delegator.makeValue(RequestQueueUtils.REQUEST_TABLE);
        // Primary Key
        request.set(String.valueOf(REQ_SERIAL_NO), String.valueOf(reqSerialNo));

        // OfBiz cannot detect the fields which were modified
        // So to avoid heavy update queries, only include fields which need to be updated

        // Do not change once initialised
        if (freshRequest) {
            request.set(String.valueOf(MODULE), module);
            request.set(String.valueOf(DOC_TYPE), docType);
            request.set(String.valueOf(MODE), mode);
            request.set(String.valueOf(ASYNC), async);
            request.set(String.valueOf(INSTANCE_ID), instanceId);
        }

        if (freshRequest || updatedFields.contains(DOC_IDS))
            request.set(String.valueOf(DOC_IDS), getCsvFromSet(docIds));

        if (freshRequest || updatedFields.contains(ENTITIES))
            request.set(String.valueOf(ENTITIES), getCsvFromSet(entities));

        if (freshRequest || updatedFields.contains(REQ_ID))
            request.set(String.valueOf(REQ_ID), reqId);

        if (freshRequest || updatedFields.contains(ACCEPTED))
            request.set(String.valueOf(ACCEPTED), accepted);

        if (UtilValidate.isNotEmpty(acceptedDate))
            if (freshRequest || updatedFields.contains(ACCEPTED_DATE))
                request.set(String.valueOf(ACCEPTED_DATE), UtilDateTime.getTimestamp(acceptedDate.getTime()));

        if (freshRequest || updatedFields.contains(COMPLETED))
            request.set(String.valueOf(COMPLETED), completed);

        if (UtilValidate.isNotEmpty(completedDate))
            if (freshRequest || updatedFields.contains(COMPLETED_DATE))
                request.set(String.valueOf(COMPLETED_DATE), UtilDateTime.getTimestamp(completedDate.getTime()));

        if (freshRequest || updatedFields.contains(SUCCESSFUL))
            request.set(String.valueOf(SUCCESSFUL), successful);

        if (statusDesc != null)
            if (freshRequest || updatedFields.contains(STATUS_DESC))
                request.set(String.valueOf(STATUS_DESC), statusDesc.toString());

        if (freshRequest || updatedFields.contains(BAD_REQUEST))
            request.set(String.valueOf(BAD_REQUEST), badRequest);

        freshRequest = false;
        updatedFields.clear();
        return request;
    }

    SearchAdapterRequest(final String module, final String docType, final String docId, final String entity,
                         final String mode, final boolean async) {
        reqSerialNo = 0;
        this.module = module;
        this.docType = docType;
        this.mode = mode;
        this.async = async;
        docIds = getSetFromCsv(docId);
        entities = getSetFromCsv(entity);
        accepted = false;
        completed = false;
        successful = false;
        badRequest = false;
        instanceId = OfbizInstanceUtil.getOfbizInstanceId();
        freshRequest = true;
    }

    SearchAdapterRequest(final String module, final String docType, final Set<String> docIds,
                         final Set<String> entities, final String mode, final boolean async) {
        reqSerialNo = 0;
        this.module = module;
        this.docType = docType;
        this.mode = mode;
        this.async = async;
        this.docIds = docIds;
        this.entities = entities;
        accepted = false;
        completed = false;
        successful = false;
        badRequest = false;
        instanceId = OfbizInstanceUtil.getOfbizInstanceId();
        freshRequest = true;
    }

    // Creates list using comma separated value
    private static Set<String> getSetFromCsv(final String csv) {
        if (UtilValidate.isNotEmpty(csv)) {
            final HashSet<String> set = new HashSet<>(10);
            final StringTokenizer st = new StringTokenizer(csv, ",");
            while (st.hasMoreTokens())
                set.add(st.nextToken());
            return set;
        }
        return null;
    }

    private static String getCsvFromSet(final Set<String> set) {
        if (UtilValidate.isNotEmpty(set))
            return StringUtils.join(set, ",");
        return "";
    }

    private Date getAsDate(String dateStr) {
        if (UtilValidate.isEmpty(dateStr)) {
            return null;
        }
        try {
            return FORMAT.parse(dateStr);
        } catch (ParseException e) {
            Debug.log("Parsing date failed: " + dateStr);
            return new Date();
        }
    }

    long getReqSerialNo() {
        return reqSerialNo;
    }

    public String getModule() {
        return module;
    }

    public String getDocType() {
        return docType;
    }

    public String getMode() {
        return mode;
    }

    Set<String> getDocIdsCopy() {
        return docIds != null ? new HashSet<>(docIds) : null;
    }

    Set<String> getEntitiesCopy() {
        return entities != null ? new HashSet<>(entities) : null;
    }

    public boolean isAsync() {
        return async;
    }

    String getReqId() {
        return reqId;
    }

    void setReqSerialNo(final long reqSerialNo) {
        // Primary key field. Always included in update request
        this.reqSerialNo = reqSerialNo;
    }

    public void setEntities(Set<String> entities) {
        updatedFields.add(ENTITIES);
        this.entities = entities;
    }

    void setDocIds(Set<String> docIds) {
        updatedFields.add(DOC_IDS);
        this.docIds = docIds;
    }

    void setReqId(final String reqId) {
        updatedFields.add(REQ_ID);
        this.reqId = reqId;
    }

    public void setAccepted(final boolean accepted) {
        updatedFields.add(ACCEPTED);
        this.accepted = accepted;
    }

    void setAcceptedDate(final Date acceptedDate) {
        updatedFields.add(ACCEPTED_DATE);
        this.acceptedDate = acceptedDate;
    }

    public void setCompleted(final boolean completed) {
        updatedFields.add(COMPLETED);
        this.completed = completed;
    }

    void setCompletedDate(final Date completedDate) {
        updatedFields.add(COMPLETED_DATE);
        this.completedDate = completedDate;
    }

    public void setSuccessful(final boolean successful) {
        updatedFields.add(SUCCESSFUL);
        this.successful = successful;
    }

    void setStatusDesc(final JSONArray statusDesc) {
        updatedFields.add(STATUS_DESC);
        this.statusDesc = statusDesc;
    }

    void setBadRequest(final boolean badRequest) {
        updatedFields.add(BAD_REQUEST);
        this.badRequest = badRequest;
    }
```
</details>

#### RequestTableColumns.java
<details>
    <summary>Click to expand</summary>
```java
enum RequestTableColumns {
    REQ_SERIAL_NO("reqSerialNo"), MODULE("module"), MODE("mode"), DOC_TYPE("docType"), DOC_IDS("docIds"),
    ENTITIES("entities"), ASYNC("async"), REQ_ID("reqId"), ACCEPTED("accepted"),
    ACCEPTED_DATE("acceptedDate"), COMPLETED("completed"), COMPLETED_DATE("completedDate"),
    SUCCESSFUL("successful"), STATUS_DESC("statusDesc"), BAD_REQUEST("badRequest"), INSTANCE_ID("instanceId");

    private final String columnName;

    RequestTableColumns(final String columnName) {
        this.columnName = columnName;
    }

    @Override
    public String toString() {
        return columnName;
    }
}
```
</details>
#### Entity Definition
<details>
    <summary>Click to expand</summary>
```xml
<entity entity-name="SplSearchAdapterRequestsV2" package-name="com.secret.ecommerce"
        title="Entity for tracking Search Adapter requests">
    <field name="reqSerialNo" type="id" not-null="true">
        <description>Auto-generated Serial number</description>
    </field>
    <field name="module" type="name" not-null="true">
        <description>Name of the module(endpoint)</description>
    </field>
    <field name="docType" type="name" not-null="true">
        <description>Name of the doc type</description>
    </field>
    <field name="mode" type="id" not-null="true">
        <description>Mode, create(POST) or update(PUT)</description>
    </field>
    <field name="docIds" type="very-long">
        <description>List(CSV) of document id</description>
    </field>
    <field name="entities" type="long-value">
        <description>List(CSV) of entities</description>
    </field>
    <field name="async" type="indicator">
        <description>Type of request, asynchronous or synchronous, either Y or N</description>
    </field>
    <field name="reqId" type="id-long">
        <description>Search Adapter generated request id</description>
    </field>
    <field name="accepted" type="indicator">
        <description>Request accepted by Search Adapter, either Y or N</description>
    </field>
    <field name="acceptedDate" type="date-time">
        <description>Date time at which request is accepted by Search Adapter</description>
    </field>
    <field name="completed" type="indicator">
        <description>Request completed by Search Adapter, either Y or N</description>
    </field>
    <field name="completedDate" type="date-time">
        <description>Date time at which request is completed by Search Adapter</description>
    </field>
    <field name="successful" type="indicator">
        <description>Request completed successfully by Search Adapter, either Y or N</description>
    </field>
    <field name="statusDesc" type="very-long">
        <description>Request life cycle status description(JSONArray)</description>
    </field>
    <field name="badRequest" type="indicator">
        <description>Request registered as a bad request, either Y or N</description>
    </field>
    <field name="instanceId" type="long-varchar">
        <description>Instance Id sending request to Search Adapter</description>
    </field>
    <prim-key field="reqSerialNo" />
    <index name="REQUEST_ACCEPTED_IDX_V2">
        <index-field name="accepted" />
    </index>
    <index name="REQUEST_COMPLETED_IDX_V2">
        <index-field name="completed" />
    </index>
</entity>
```
</details>
