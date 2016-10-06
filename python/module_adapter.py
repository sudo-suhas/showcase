import reprlib
import threading
import time
from multiprocessing import Pool, Lock
from multiprocessing.dummy import Pool as ThreadPool, Queue, Event
from multiprocessing.pool import AsyncResult

import falcon

from es import es_client
from module import module_def_mgr
from module.producer_consumer import read_from_db, push_to_elasticsearch
from settings import (STREAM_CHUNK_SIZE, STREAM_QUEUE_SIZE,
                      PRODUCER_POOL_SIZE, CONSUMER_POOL_SIZE)
from substratum import adapter_logger, db_client
from substratum.bones import Singleton, errors
from substratum.cls_manager import req_tracker, cls_mgr
from substratum.const import (DOC_ID_COLUMN, DOC_ID_FIELD,
                              ATTR_DOC_TYPE, ATTR_ENTITIES,
                              ENTITY_DEF, SQL_ID_SELECT, SAFEGUARD_CONDITION)


def db_doc_id_set(doc_column_id, sql_id_select):
    doc_list = db_client.query(sql_id_select)
    return {doc[doc_column_id] for doc in doc_list}


def master_doc_id_list(index, doc_type, doc_column_id, sql_id_select):
    doc_id_set = db_doc_id_set(doc_column_id, sql_id_select)
    doc_id_set |= es_client.active_id_set(index, doc_type)
    return list(doc_id_set)


def build_conditions(doc_column_id, doc_id_list):
    n = STREAM_CHUNK_SIZE
    conditions = []
    for doc_id_chunk in [doc_id_list[i:i + n]
                         for i in range(0, len(doc_id_list), n)]:
        conditions.append(db_client.
                          build_where_condition(doc_column_id, doc_id_chunk))
    return conditions


def set_exit_event(async_res: AsyncResult, exit_event: Event):
    if async_res:
        async_res.get()
    exit_event.set()


class ModuleAdapter(object):
    __metaclass__ = Singleton

    @staticmethod
    def complete_request(req_id: str, async_res: AsyncResult):
        try:
            successful, msg = async_res.get()
            req_tracker.finish_request(req_id, successful, msg)
        except errors.SearchAdapterError as e:
            req_tracker.log_request_failure(req_id, e)

    def __init__(self, module: str):
        self._module = module
        self._model_def = module_def_mgr.get_model_def(self._module)
        self._lock = cls_mgr.RequestLock('Module', req_tracker, Lock)  # type: RequestLock

    def perform_indexing(self, req_id: str, action: str, doc_type: str,
                         entities: list, doc_id_list: list = None,
                         index: str = None, lock: bool = False) -> (bool, str):
        try:
            if lock:
                self._lock.acquire(req_id)
            req_tracker.track_status(req_id, '{0} started'.format(action))
            doc_model_def = self._model_def[doc_type]  # type: dict
            doc_column_id = doc_model_def[DOC_ID_COLUMN]
            doc_field_id = doc_model_def[DOC_ID_FIELD]
            entity_def_dict = doc_model_def[ENTITY_DEF]

            index = index or es_client.write_alias(self._module)

            if doc_id_list:
                req_tracker.track_status(req_id, 'Building where '
                                                 'condition using filter')
                if SAFEGUARD_CONDITION in doc_model_def:
                    safeguard_condition = doc_model_def[SAFEGUARD_CONDITION]
                    condition = db_client.build_where_condition(doc_column_id, doc_id_list)
                    query_def = safeguard_condition['query']
                    sql = db_client.build_query(query_def, condition)
                    conditions = build_conditions(
                        doc_column_id, list(db_doc_id_set(doc_column_id, sql))
                    )
                    if not conditions:
                        raise errors.ModuleAdapterError('Invalid doc ids, safeguard check failed!')
                else:
                    conditions = [db_client.build_where_condition
                                  (doc_column_id, doc_id_list)]
            elif SQL_ID_SELECT in doc_model_def:
                req_tracker.track_status(req_id, 'Building conditions for streaming '
                                                 'data into elasticsearch')
                sql_id_select = doc_model_def[SQL_ID_SELECT]
                conditions = build_conditions(
                    doc_column_id, master_doc_id_list(
                        index, doc_type, doc_column_id, sql_id_select
                    )
                )

            else:
                req_tracker.track_status(req_id, (('{0} not configured in model '
                                                   'definition! Streaming data '
                                                   'not supported.')
                                                  .format(SQL_ID_SELECT)))
                conditions = ['']

            queue = Queue(STREAM_QUEUE_SIZE)
            exit_event = Event()
            error_event = Event()
            producer_pool_size = min(len(conditions), PRODUCER_POOL_SIZE)
            consumer_pool_size = min(len(conditions), CONSUMER_POOL_SIZE)
            producer_pool = ThreadPool(processes=producer_pool_size)
            consumer_pool = ThreadPool(processes=consumer_pool_size)
            try:
                start = time.time()
                req_tracker.track_status(req_id, 'Starting producer and consumer thread pools '
                                                 'for streaming data into elasticsearch')

                # Prepare list of arguments
                args_list = [(doc_field_id, entities, entity_def_dict,
                              condition, queue, error_event)
                             for condition in conditions]
                # Start the producer threads to read from database and push result into queue
                # Take the async result so that we can set the exit flag
                # noinspection PyShadowingNames
                async_prod_res = producer_pool.starmap_async(
                    read_from_db, args_list
                )

                threading.Thread(daemon=True, target=set_exit_event,
                                 args=(async_prod_res, exit_event)).start()

                args = (index, doc_type, doc_field_id, queue, exit_event, error_event)
                # Start consumer threads with same arguments
                # Is there a better way than range?
                # noinspection PyShadowingNames
                consumer_pool.starmap(
                    push_to_elasticsearch, [args for _ in range(0, consumer_pool_size)]
                )
            finally:
                producer_pool.close()
                consumer_pool.close()

                # Wait for all tasks to finish
                # producer_pool.join() # Blocks for some reason when consumer throws error
                consumer_pool.join()

            req_tracker.track_status(req_id, ('Finished streaming records to elasticsearch in '
                                              '{0:.3f} seconds').format(time.time() - start))

            if error_event.is_set():
                if async_prod_res:
                    async_prod_res.get(timeout=0.1)
                return False, '{0} failed'.format(action)

            return True, '{0} completed successfully'.format(action)

        except Exception as e:
            adapter_logger.exception(e)
            raise errors.SearchAdapterError('Failed to perform indexing. Cause: %s', e) from e
        finally:
            if lock:
                self._lock.release()

    def apply_perform_request(self, req_id: str, kwargs: dict, async=True) -> (str, str):
        pool = Pool(processes=1)
        try:
            if async:
                req_tracker.track_status(req_id,
                                         'Calling perform_indexing in background process')

                async_res = pool.apply_async(self.perform_indexing, kwds=kwargs)

                threading.Thread(target=ModuleAdapter.complete_request,
                                 args=(req_id, async_res)).start()

                status = falcon.HTTP_ACCEPTED
                msg = '{0} in progress'.format(kwargs['action'])
            else:
                successful, msg = pool.apply(self.perform_indexing, kwds=kwargs)

                req_tracker.track_status(req_id, msg)
                if not successful:
                    raise errors.ModuleAdapterError('Failed to performing indexing')

                status = falcon.HTTP_OK
                msg = '{0} completed successfully'.format(kwargs['action'])
        finally:
            pool.close()

        return status, msg

    def index_all(self, req_id: str, doc_type: str, index: str = None, async=True) -> (str, str):
        self.check_locked()

        action = ('Indexing all entities for module {0!r} and docType {1!r}'
                  .format(self._module, doc_type))

        kwargs = {'req_id': req_id, 'action': action, 'doc_type': doc_type,
                  'entities': self.entities(doc_type),
                  'index': index, 'lock': True}

        return self.apply_perform_request(req_id, kwargs=kwargs, async=async)

    def index_entities(self, req_id: str, doc_type: str, entities: list,
                       index: str = None, async=True) -> (str, str):
        self.check_locked()
        self.validate_entities(doc_type, entities)

        action = ('Indexing entities {2} for module {0!r} and docType {1!r}'
                  .format(self._module, doc_type, reprlib.repr(entities)))

        kwargs = {'req_id': req_id, 'action': action, 'doc_type': doc_type,
                  'entities': entities, 'index': index,
                  'lock': True if len(entities) > 2 else False}

        return self.apply_perform_request(req_id, kwargs=kwargs, async=async)

    def index_doc(self, req_id: str, doc_type: str, doc_id_list: list, async=True) -> (str, str):
        self.check_locked()

        action = ('Indexing documents with id {2} for module {0!r} and docType {1!r}'
                  .format(self._module, doc_type, reprlib.repr(doc_id_list)))

        kwargs = {'req_id': req_id, 'action': action, 'doc_type': doc_type,
                  'entities': self.entities(doc_type),
                  'doc_id_list': doc_id_list, 'lock': False}

        return self.apply_perform_request(req_id, kwargs=kwargs, async=async)

    def update_entities(self, req_id: str, doc_type: str, doc_id_list: list,
                        entities: list, async=True) -> (str, str):
        self.check_locked()
        self.validate_entities(doc_type, entities)

        action = (('Updating documents with id {2} for module '
                   '{0!r}, docType {1!r} and entities {3}')
                  .format(self._module, doc_type, reprlib.repr(doc_id_list),
                          reprlib.repr(entities)))

        kwargs = {'req_id': req_id, 'action': action, 'doc_type': doc_type,
                  'doc_id_list': doc_id_list, 'entities': entities, 'lock': False}

        return self.apply_perform_request(req_id, kwargs=kwargs, async=async)

    def entities(self, doc_type: str):
        return [entity for entity in self._model_def[doc_type][ENTITY_DEF]]

    def validate_doc_type(self, doc_type: str, check_exists=True):
        adapter_logger.debug('Validating docType %r for module %r',
                             doc_type, self._module)

        if check_exists:
            if doc_type not in self._model_def:
                raise errors.InvalidParamError(ATTR_DOC_TYPE, doc_type)
        else:
            if doc_type in self._model_def:
                raise errors.InvalidParamError(ATTR_DOC_TYPE, doc_type)

    def check_locked(self):
        adapter_logger.debug('Checking lock on module %r', self._module)

        if self._lock.is_locked():
            raise errors.ResourceBusyError(('The {0!r} module is currently '
                                            'locked by a request with id {1!r}')
                                           .format(self._module, self._lock.req_id()))

    def validate_entities(self, doc_type: str, entities: list):
        if not entities:
            raise errors.InvalidRequestError('{0} cannot be empty'.format(ATTR_ENTITIES))

        entity_def_def = self._model_def[doc_type][ENTITY_DEF]  # type: dict
        if not set(entities).issubset(entity_def_def.keys()):
            raise errors.InvalidParamError(ATTR_ENTITIES, str(entities))
