# noinspection PyUnresolvedReferences
import math
import os
import time
from concurrent.futures import ThreadPoolExecutor
from multiprocessing.dummy import Queue, Event
from queue import Empty

from es import es_client
from substratum import adapter_logger, db_client, file_utils
from substratum.bones import errors
from substratum.bones.action_generator import ActionGenerator
from substratum.const import EXEC_FIELDS

EXECUTOR = ThreadPoolExecutor(max_workers=8)


def merge_values(val1, val2):
    if val1 == val2:
        return val1
    if isinstance(val1, list):
        if isinstance(val2, list):
            return val1 + val2
        if val2 not in val1:
            val1.append(val2)
        return val1
    if isinstance(val2, list):
        if val1 not in val2:
            val2.append(val1)
        return val2
    if isinstance(val1, (int, float)) and isinstance(val2, (int, float)):
        return val1 + val2
    if isinstance(val1, str) or isinstance(val2, str):
        return [str(val1), str(val2)]
    return [val1, val2]


def merge_rows(row1: dict, row2: dict) -> dict:
    # noinspection PyUnresolvedReferences
    for key in row1.keys() & row2.keys():
        row1[key] = merge_values(row1[key], row2.pop(key))
    row1.update(row2)
    return row1


def process_row_list(doc_field_id: str, row_dict: dict,
                     sub_queue: Queue, sub_exit_event: Event):
    while True:
        try:
            row_list = sub_queue.get(block=True, timeout=0.1)
            for row in row_list:
                row_id = row[doc_field_id]
                if row_id not in row_dict:
                    row_dict[row_id] = row
                else:
                    merge_rows(row_dict[row_id], row)
        except Empty:
            if sub_exit_event.is_set():
                return


# noinspection PyUnusedLocal
def exec_compiled(compiled_script, row):
    # noinspection PyBroadException
    try:
        exec(compiled_script)
    except:
        # adapter_logger.exception('exec error. %s', row)
        pass


def read_from_db(doc_field_id: str, entities: list,
                 entity_def_dict: dict, condition: str,
                 queue: Queue, error_event: Event):
    adapter_logger.debug('Starting producer thread for reading from db')

    if error_event.is_set():
        adapter_logger.debug('Caught error event, returning')
        return

    producer_start = time.time()
    try:
        row_dict = {}
        sql_list = []
        column_mapping_list = []
        exec_fields = []

        for entity in entities:
            entity_def = entity_def_dict[entity]

            sql_list.append(
                    db_client.build_query(entity_def['query'], condition)
            )
            column_mapping_list.append(entity_def['columnMapping'])

            if EXEC_FIELDS in entity_def:
                exec_fields.extend(entity_def[EXEC_FIELDS])

        sub_queue = Queue(10)
        sub_exit_event = Event()

        future = EXECUTOR.submit(process_row_list, *(doc_field_id, row_dict,
                                                     sub_queue, sub_exit_event))

        for row_list in db_client.query_multi(sql_list, column_mapping_list):
            sub_queue.put(row_list)

        sub_exit_event.set()
        start = time.time()
        future.result()
        adapter_logger.debug('Waited for future.result() - %.3f seconds',
                             time.time() - start)

        if exec_fields:
            start = time.time()
            for py_script in exec_fields:
                # http://stackoverflow.com/questions/2220699/
                # whats-the-difference-between-eval-exec-and-compile-in-python
                compiled_script = compile(py_script, '<string>', 'exec')
                [exec_compiled(compiled_script, row) for row in row_dict.values()]
            adapter_logger.debug('Generated scripted fields in %.3f seconds',
                                 time.time() - start)

        # What happens if row_dict is empty?
        queue.put(list(row_dict.values()))
    except Exception as e:
        if error_event.is_set():
            return
        adapter_logger.debug('Setting error event in consumer thread')
        error_event.set()

        adapter_logger.exception('Failed to execute query on database. '
                                 'Cause %s', e)

        raise errors.ModuleAdapterStreamError(
                'Failed to read from database. Cause: %s', e) from e

    adapter_logger.debug('Completed producer thread'
                         '(read chunk from db) in %.3f seconds',
                         time.time() - producer_start)


def push_to_elasticsearch(index: str, doc_type: str, doc_field_id: str,
                          queue: Queue, exit_event: Event, error_event: Event):
    adapter_logger.debug('Starting consumer thread for pushing to elasticsearch')
    if error_event.is_set():
        adapter_logger.debug('Caught error event, returning')
        return
    wait_time = 0
    while not error_event.is_set():
        try:
            consumer_start = time.time()
            row_list = queue.get(block=True, timeout=0.1)
            adapter_logger.debug('Got rows from queue, processing')
            push_row_list(index, doc_type, doc_field_id, row_list)
            adapter_logger.debug('Completed consuming chunk in %.3f seconds',
                                 time.time() - consumer_start)
        except Empty:
            if exit_event.is_set():
                adapter_logger.debug('Caught exit event, returning. '
                                     'Spent %.1f seconds waiting', wait_time)
                return
            wait_time += 0.1
        except Exception as e:
            if error_event.is_set():
                return
            adapter_logger.debug('Setting error event in consumer thread')
            error_event.set()

            adapter_logger.exception('Failed to load into elasticsearch. '
                                     'Cause: %s', e)

            raise errors.ModuleAdapterStreamError('Failed to push to elasticsearch. '
                                                  'Cause: %s', e) from e


def push_row_list(index: str, doc_type: str, doc_field_id: str,
                  row_list: list):
    len_row_list = len(row_list)

    actions = ActionGenerator(index, doc_type, doc_field_id, row_list)
    success, failed = es_client.parallel_bulk(actions)

    if failed or success != len_row_list:
        raise errors.ModuleAdapterError('Parallel Bulk load failed')
