# Search Adapter
A REST app which runs on Python 3.4. It uses [falcon](https://github.com/falconry/falcon)
for creating and running a WSGI app using [gunicorn](https://github.com/benoitc/gunicorn)

However, only a small section of the app responsible for streaming data from the database
to elasticsearch is shown here.

## Short Description
I have a request which could request any of the following:
  - Reindex entire dataset
  - Reindex specific products/entities
  - Reindex for combination of products and entities

The request is validated, inputs parsed and a process is started to stream data accordingly

## Description
Depending upon the type of request, appropriate method(
[`index_all`](module_adapter.py#L200-L210), [`index_entities`](module_adapter.py#L212-L224),
[`index_doc`](module_adapter.py#L226-L236) or [`update_entities`](module_adapter.py#L238-L251))
is called in [`module_adapter.py`](module_adapter.py). These methods call
[`apply_perform_request`](module_adapter.py#L172-L198) which starts a process to
[perform indexing](module_adapter.pyL66-L170). This method uses a
[configuration file](#product_listing_def)
to discern important details like:
  - How to get the list of document id
  - What is the SQL for a given entity
  - What is the mapping between Database columns and elasticsearh fields

If it is a heavy request like indexing all, the module is locked
and subsequent requests are denied until index all is completed.
Depending upon the type of request, conditions are built which can be used to
partition the query to the database. If there were 20K products in the database,
I would create 20 conditions of 1K products each which can be used in SQL where condition.

These conditions are processed by [`read_from_db`](producer_consumer.py#L72-L140) running in a thread pool.
However, there is still the issue of loading data into elasticsearch from multiple tables.
If there were 10 entities, 20K products, we would end up with 200000 rows of results.
Although elasticsearch can handle upserts, having such a huge number of requests will take a long time to process.
So I [merge rows](producer_consumer.py#L28-L43) for a given product id down to a single dict.
I also take care of multiple rows from the same table.

Example query output from a table with columns `PRODUCT_ID`, `PRODUCT_PRICE_TYPE_ID` and `PRICE`:

|PRODUCT_ID|DEFAULT_PRICE|MAXIMUM_PRICE|MINIMUM_PRICE|SAP_MINIMUM_PRICE|
|----------|-------------|-------------|-------------|-----------------|
|BP10000580|485.000|NULL|NULL|NULL|
|BP10000580|NULL|485.000|NULL|NULL|
|BP10000580|NULL|NULL|236.750|NULL|
|BP10000580|NULL|NULL|NULL|301.780|

These merged rows are pushed on to a queue(producer) and consumed by
[`push_to_elasticsearch`](producer_consumer.py#L143-L174).

The application does not consume more than 250 MB even while loading the complete dataset
and takes only about 30 seconds for ~30K products.
```
curl -X GET -H "X-Auth-Token: my-super-awesome-secret-token" "https://secret.host:443/status/VHVfdMYNpbCnM6itcn7YG5"
```
```json
{
  "result": {
    "reqId": "VHVfdMYNpbCnM6itcn7YG5",
    "desc": "POST request to 'https://secret.host:443/module/product_listing/docType/products'",
    "started": "October 06, 2016 - 06:00:00 AM",
    "status": [
      "[October 06, 2016 - 06:00:00 AM] 'Started' - Request received",
      "[October 06, 2016 - 06:00:00 AM] 'In Progress' - Calling perform_indexing in background process",
      "[October 06, 2016 - 06:00:00 AM] 'In Progress' - Acquired lock on Module resource",
      "[October 06, 2016 - 06:00:00 AM] 'In Progress' - Indexing all entities for module 'product_listing' and docType 'products' started",
      "[October 06, 2016 - 06:00:00 AM] 'In Progress' - Building conditions for streaming data into elasticsearch",
      "[October 06, 2016 - 06:00:02 AM] 'In Progress' - Starting producer and consumer thread pools for streaming data into elasticsearch",
      "[October 06, 2016 - 06:00:24 AM] 'In Progress' - Finished streaming records to elasticsearch in 22.692 seconds",
      "[October 06, 2016 - 06:00:24 AM] 'In Progress' - Released Module resource lock",
      "[October 06, 2016 - 06:00:24 AM] 'Successful' - Indexing all entities for module 'product_listing' and docType 'products' completed successfully. Total time taken - 24.735 seconds"
    ],
    "requestCompleted": true,
    "completed": "October 06, 2016 - 06:00:24 AM",
    "successful": true
  },
  "msg": "Request details fetched successfully"
}
```


## Other helper code

#### action_generator.py
<details>
    <summary>Click to expand</summary>
```py
class ActionGenerator(object):
    def __init__(self, index: str, doc_type: str,
                 doc_field_id: str, rows: list):
        adapter_logger.debug('Instantiating Action Generator '
                             'for index %r, docType %r',
                             index, doc_type)

        self._action_template = {
            '_index': index, '_type': doc_type,
            '_retry_on_conflict': '3', '_op_type': 'update',
            'doc_as_upsert': True
        }

        self._doc_field_id = doc_field_id
        self._rows = rows
        self._len = len(self._rows)
        self._lock = ThreadLock()
        self._pos = 0

    def __iter__(self):
        """Returns itself as an iterator object"""
        self._pos = 0
        return self

    def __next__(self):
        """Returns the next value"""
        if self._pos >= self._len:
            raise StopIteration
        try:
            with self._lock:
                row = self._rows[self._pos]  # type: dict
                self._pos += 1
            action = dict(self._action_template)
            action['_id'] = row[self._doc_field_id]
            action['doc'] = row
            return action
        except Exception:
            adapter_logger.exception('Exception while generating actions for bulk insert')
            raise StopIteration
```
</details>

#### product_listing_def.json

<details>
    <summary>Click to expand</summary>
```json
{
  "products": {
    "docIdColumn": "PRODUCT_ID",
    "sqlIdSelect": "SELECT PROD.PRODUCT_ID AS PRODUCT_ID FROM PRODUCT PROD LEFT JOIN PRODUCT_ATTRIBUTE ATTR ON (PROD.PRODUCT_ID = ATTR.PRODUCT_ID AND ATTR_NAME = 'PRODUCT_NOT_TO_BE_LISTED') WHERE STATUS_ID = 'APPROVED' AND PRODUCT_TYPE_ID = 'FINISHED_GOOD' AND (SALES_DISCONTINUATION_DATE IS NULL OR SALES_DISCONTINUATION_DATE > NOW()) AND IS_VIRTUAL = 'N' AND ATTR.PRODUCT_ID IS NULL",
    "docIdField": "productId",
    "safeguardCondition": {
      "query": {
        "select": "SELECT PRODUCT_ID FROM PRODUCT",
        "where": " WHERE IS_VIRTUAL = 'N'"
      }
    },
    "entityDef": {
      "product": {
        "query": {
          "select": "SOME_COMPLICATED_QUERY"
        },
        "columnMapping": {
          "DESCRIPTION": "shortDesc",
          "IS_ACTIVE": "isActive",
          "INTRODUCTION_DATE": "introductionDate",
          "PRIMARY_PRODUCT_CATEGORY_ID": "primaryCategoryId",
          "PRODUCT_ID": "productId",
          "PRODUCT_NAME": "productName",
          "DISPLAY_PRODUCT_NAME": "displayProductName",
          "BRAND_NAME": "brandName",
          "QUALIFIED_PRODUCT_NAME": "qualifiedProductName",
          "BRAND_BOOST": "brandBoost"
        }
      },
      "productFacility": {
        "query": {
          "select": "SOME_COMPLICATED_QUERY",
          "groupBy": "GROUP BY PRODUCT_ID",
          "where": "WHERE FACILITY_ID NOT IN ('NO_LONGER_USED')"
        },
        "columnMapping": {"IN_STOCK": "inStock", "PRODUCT_ID": "productId"}
      },
      "productFeature": {
        "query": {
          "select": "SOME_COMPLICATED_QUERY",
          "where": "WHERE PRODUCT_FEATURE_CATEGORY_ID IN ('COLLECTIONS', 'COLOUR', 'GENDER', 'MATERIAL', 'PACK_QUANTITY', 'SIZE_AGE', 'SIZE_APPAREL', 'SIZE_DIAPERS', 'SIZE_MATERNITY', 'SIZE_RELATIVE', 'SIZE_SHOES', 'SIZE_WRIST')"
        },
        "columnMapping": {
          "PACK_QUANTITY_FEATURE": "packQuantityFeature",
          "PRODUCT_ID": "productId",
          "GENDER_FEATURE": "genderFeature",
          "COLLECTIONS_FEATURE": "collectionsFeature",
          "SIZE_SHOES_FEATURE": "sizeShoesFeature",
          "SIZE_AGE_ABBREV_FEATURE": "sizeAgeAbbrevFeature",
          "SIZE_DIAPERS_FEATURE": "sizeDiapersFeature",
          "MATERIAL_FEATURE": "materialFeature",
          "SIZE_APPAREL_FEATURE": "sizeApparelFeature",
          "SIZE_RELATIVE_FEATURE": "sizeRelativeFeature",
          "SIZE_AGE_FEATURE": "sizeAgeFeature",
          "SIZE_WRIST_FEATURE": "sizeWristFeature",
          "SIZE_MATERNITY_FEATURE": "sizeMaternityFeature",
          "COLOUR_FEATURE": "colourFeature"
        }
      },
      "productImageCount": {
        "query": {
          "select": "SELECT PRODUCT_ID, IMAGES_COUNT_NUM FROM SPL_PRODUCT_IMAGE_COUNT"
        },
        "columnMapping": {
          "PRODUCT_ID": "productId",
          "IMAGES_COUNT_NUM": "imageCount"
        }
      },
      "productContent": {
        "query": {
          "select": "SOME_COMPLICATED_QUERY",
          "where": "WHERE PC.PRODUCT_CONTENT_TYPE_ID IN ('LONG_DESCRIPTION', 'PRODUCT_SNIPPET')"
        },
        "columnMapping": {
          "PRODUCT_ID": "productId",
          "PRODUCT_SNIPPET": "productSnippet",
          "LONG_DESC": "longDesc"
        }
      },
      "productPrice": {
        "query": {
          "select": "SOME_COMPLICATED_QUERY",
          "where": "SOME_COMPLICATED_CONDITION"
        },
        "execFields": [
          "row['minimumPrice'] = row['minimumPrice'] if 'minimumPrice' in row and row['minimumPrice'] > 10 else row['sapMinimumPrice'] if 'sapMinimumPrice' in row and row['sapMinimumPrice'] > 10 else row['defaultPrice']",
          "row['defaultPrice'] = row['defaultPrice'] if 'minimumPrice' not in row or row['defaultPrice'] >= row['minimumPrice'] else row['minimumPrice']",
          "row['profit'] = row['defaultPrice'] - row['minimumPrice'] if row['defaultPrice'] - row['minimumPrice'] > 0 else 0",
          "row['discount'] = row['maximumPrice'] - row['defaultPrice'] if row['maximumPrice'] - row['defaultPrice'] > 0 else 0",
          "row['discountPercent'] = math.ceil(row['discount'] / row['maximumPrice'] * 100 if row['discount'] > 0 else 0)"
        ],
        "columnMapping": {
          "MINIMUM_PRICE": "minimumPrice",
          "MAXIMUM_PRICE": "maximumPrice",
          "SAP_MINIMUM_PRICE": "sapMinimumPrice",
          "PRODUCT_ID": "productId",
          "DEFAULT_PRICE": "defaultPrice"
        }
      },
      "productDcs": {
        "query": {
          "select": "SOME_COMPLICATED_QUERY"
        },
        "columnMapping": {"PRODUCT_ID": "productId", "DCS_JSON": "dcs"}
      }
    }
  }
}
```
</details>

#### db.py

<details>
    <summary>Click to expand</summary>
```py
class DataBaseClient(object):

    def __init__(self, db_config: dict, pool_size: int):
        self._engine = sqlalchemy.create_engine(url.URL(**db_config),
                                                execution_options={'stream_results': False},
                                                max_overflow=2, pool_size=pool_size,
                                                pool_recycle=120, pool_timeout=180,
                                                connect_args={'compress': True})

    def query_multi(self, sql_list: list, column_mapping_list: list) -> list:
        # Maybe I should pass a list of tuples here instead of 2 lists
        adapter_logger.debug('Executing multi-part query')

        if (column_mapping_list and
                len(column_mapping_list) != len(sql_list)):
            raise errors.DatabaseClientError('Invalid column mapping provided.')

        conn = None
        try:
            start = time.time()
            sql_multi = '; '.join(sql_list)
            conn = self._engine.raw_connection()
            with conn.cursor(SSDictCursor) as cursor:
                cursor.execute(sql_multi)
                ctr = 0
                while True:
                    if column_mapping_list and column_mapping_list[ctr]:
                        yield [{doc_field: parse_json(row[column])
                                for column, doc_field in column_mapping_list[ctr].items()
                                if row[column] is not None} for row in cursor.fetchall()]
                    else:
                        yield cursor.fetchall()
                    ctr += 1
                    if not cursor.nextset():
                        break
                adapter_logger.debug('Finished executing query in %.3f seconds ',
                                     time.time() - start)
        except (MySQLError, SQLAlchemyError) as e:
            adapter_logger.exception('Database Client error. Error sqls - %r', sql_list)

            raise errors.DatabaseClientError('Query Failed while trying '
                                             'to fetch result from database. '
                                             'Exception: %r', e) from e
        finally:
            if conn:
                conn.close()
```
</details>

#### cls_manager.py

<details>
    <summary>Click to expand</summary>
```py
class ClsManager(BaseManager):
    @classmethod
    def start_instance(cls):
        from substratum import adapter_logger, RequestMetadataTracker
        from substratum.bones import RequestLock
        from es.metadata_manager import MetadataManager

        adapter_logger.debug('Starting Class Manager instance')

        cls.register('RequestMetadataTracker', RequestMetadataTracker)
        cls.register('MetadataManager', MetadataManager)
        cls.register('RequestLock', RequestLock)

        mgr = cls()
        mgr.start()
        return mgr
```
</details>

#### request_lock.py

<details>
    <summary>Click to expand</summary>
```py
class RequestLock(object):
    def __init__(self, resource: str, req_tracker, lock_cls):
        self._lock = lock_cls()
        self._resource = resource
        self._is_locked = False
        self._req_id = None
        self._req_tracker = req_tracker

    def is_locked(self):
        return self._is_locked

    def req_id(self):
        return self._req_id

    def acquire(self, req_id: str):
        self._is_locked = True
        self._req_id = req_id
        self._lock.acquire()
        self._req_tracker.track_status(self._req_id,
                                       'Acquired lock on {0} resource'
                                       .format(self._resource))

    def release(self):
        if self._is_locked:
            self._lock.release()
            self._req_tracker.track_status(self._req_id,
                                           'Released {0} resource lock'
                                           .format(self._resource))
            self._is_locked = False
            self._req_id = None

```
</details>
## Misc

Some random snippets that were used in the app
<details>
    <summary>Click to expand</summary>
```py
# http://stackoverflow.com/questions/18478287/making-object-json-serializable-with-regular-encoder
class PythonObjectEncoder(json.JSONEncoder):
    def default(self, obj):
        return {'_python_object': pickle.dumps(obj).decode('latin1')}


def as_python_object(dct):
    if '_python_object' in dct:
        return pickle.loads(dct['_python_object'].encode('latin1'))
    return dct

class DataBaseClient(object):

    @staticmethod
    def build_where_condition(doc_column_id: str, doc_id_list: list):
        if not doc_column_id or not doc_id_list:
            return ''
        return '{0} IN ({1})'.format(doc_column_id,
                                     ', '.join("'{0}'".format(doc)
                                               for doc in doc_id_list))

    @staticmethod
    def build_query(query_def: dict, conditions: str = None):
        try:
            where = query_def.get('where', '')
            if conditions:
                if where:
                    where = '{0} AND {1}'.format(where, conditions)
                else:
                    where = 'WHERE ' + conditions

            query_parts = {
                'select': query_def['select'], 'where': where,
                'groupBy': query_def.get('groupBy', ''),
                'orderBy': query_def.get('orderBy', '')
            }

            sql = '{select} {where} {groupBy} {orderBy}'.format(**query_parts)

            return sql
        except KeyError as e:
            adapter_logger.exception('Query Build Error. Error sql dict - %s', query_def)
            raise errors.DatabaseClientError('Failed to build query from entity definition'
                                             'Exception: %r', e)
```
</details>