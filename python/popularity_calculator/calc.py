import datetime
import multiprocessing
import sys
import time
from bisect import bisect

from scipy.stats import rankdata

from substratum import calc_logger, db_client, es_client
from substratum.const import (PRODUCT_ID, DATE, VIEW_COUNT, ORDER_COUNT,
                              POPULARITY, POPULARITY_PERCENTILE, NUM_DAYS)
from substratum.bones.action_generator import ActionGenerator

WEIGHTAGE_BREAKPOINTS = [2, 5, 14, 21, 28, 35, 42, 49, 56, 63, 70]
WEIGHTAGES = [1, 0.9, 0.85, 0.70, 0.4, 0.3, 0.2, 0.1, 0.05, 0.01, 0.005, 0.001]

PERCENTILE_BREAKPOINTS = [25, 35, 45, 55, 65, 75, 85, 95, 100]
NORMALIZERS = [135, 126, 122, 118, 114, 110, 106, 104, 102]

today = datetime.date.today()


# noinspection PyShadowingNames
def date_weightage(days: int) -> float:
    # https://docs.python.org/2/library/bisect.html#examples
    idx = bisect(WEIGHTAGE_BREAKPOINTS, days)
    return WEIGHTAGES[idx]


# noinspection PyShadowingNames
def calc_normalization_factor(percentile: float) -> float:
    normalization_factor = 1.0
    if percentile is not None and percentile > 25:
        normalizer = NORMALIZERS[bisect(PERCENTILE_BREAKPOINTS, percentile)]
        normalization_factor = (normalizer - percentile) / 100.0
    return normalization_factor


# noinspection PyShadowingNames
def calc_stats_by_product(pop_stats: dict, stats_by_product: dict):
    # http://stackoverflow.com/questions/151199/
    # how-do-i-calculate-number-of-days-betwen-two-dates-using-python
    days_diff = (today - pop_stats[DATE]).days
    weightage = date_weightage(days_diff)

    product_id = pop_stats[PRODUCT_ID]
    if product_id in stats_by_product:
        product_stats = stats_by_product[product_id]
    else:
        product_stats = {
            PRODUCT_ID: product_id, VIEW_COUNT: 0, ORDER_COUNT: 0,
            NUM_DAYS: 0, POPULARITY_PERCENTILE: 0
        }
        stats_by_product[product_id] = product_stats

    product_stats[VIEW_COUNT] += pop_stats[VIEW_COUNT] * weightage
    product_stats[ORDER_COUNT] += pop_stats[ORDER_COUNT] * weightage
    product_stats[POPULARITY_PERCENTILE] += pop_stats[POPULARITY_PERCENTILE]
    if days_diff > product_stats[NUM_DAYS]:
        product_stats[NUM_DAYS] = days_diff


def calc_percentiles(a: list) -> list:
    # http://stackoverflow.com/questions/12414043/map-each-list-value-to-its-corresponding-percentile
    return rankdata(a, method='dense') / len(a) * 100


# Python min version check
assert sys.version_info >= (3, 4), \
    'Python 3.4 is required for running this application'

calc_logger.info('Starting Popularity Calculator')

# Select popularity stats rows for 60 days in past
# http://stackoverflow.com/questions/2041575/mysql-query-records-between-today-and-last-30-days
sql = ('SELECT PRODUCT_ID, DATE, VIEW_COUNT, ORDER_COUNT, '
       'POPULARITY_PERCENTILE FROM SPL_PRODUCT_POPULARITY '
       'WHERE DATE BETWEEN CURDATE() - INTERVAL 60 DAY '
       'AND CURDATE() - INTERVAL 1 DAY '
       'AND (VIEW_COUNT > 0 OR ORDER_COUNT > 0)')
popularity_stats_rows = db_client.query(sql)

# Calculate weighted Popularity stats for each product
# Includes normalization using popularity percentile
calc_logger.debug('Calculating normalization and weightage for popularity factors')

start = time.time()
stats_by_product = {}

for pop_stats in popularity_stats_rows:
    calc_stats_by_product(pop_stats, stats_by_product)

del popularity_stats_rows

calc_logger.debug('Finished calc_stats_by_product in %.3f seconds ',
                  time.time() - start)

calc_logger.debug('Preparing lists for calculating percentiles')
start = time.time()

product_stats_list = list(stats_by_product.values())
del stats_by_product

view_counts = []
order_counts = []
for product_stats in product_stats_list:
    num_days = product_stats[NUM_DAYS]
    avg_percentile = product_stats[POPULARITY_PERCENTILE] / num_days
    normalization_factor = calc_normalization_factor(avg_percentile)
    view_counts.append(product_stats[VIEW_COUNT] * normalization_factor / num_days)
    order_counts.append(product_stats[ORDER_COUNT] * normalization_factor / num_days)

pool = multiprocessing.Pool(processes=multiprocessing.cpu_count())
try:
    view_count_async_res = pool.apply_async(
            calc_percentiles, args=(view_counts,),
            error_callback=lambda e: calc_logger.exception(e)
    )
    order_count_async_res = pool.apply_async(
            calc_percentiles, args=(order_counts,),
            error_callback=lambda e: calc_logger.exception(e)
    )
finally:
    pool.close()
    pool.join()

view_count_percentiles = view_count_async_res.get()
order_count_percentiles = order_count_async_res.get()

del view_counts, order_counts

calc_logger.debug(('Finished calculating percentiles for view counts '
                   'and order counts in %.3f seconds '),
                  time.time() - start)

calc_logger.debug('Calculating product popularity')

# Calculate popularity for each product by putting together weighted factors
start = time.time()
popularity_list = []
for idx, product_stats in enumerate(product_stats_list):
    product_stats[POPULARITY] = popularity = (
        0.1 * view_count_percentiles[idx] +
        3 * order_count_percentiles[idx]
    )
    popularity_list.append(popularity)

del view_count_percentiles, order_count_percentiles

calc_logger.debug('Finished calculating product popularity in %.3f seconds ',
                  time.time() - start)

popularity_percentiles = calc_percentiles(popularity_list)

# Push popularity information back to database
calc_logger.debug('Updating popularity in database')
# http://stackoverflow.com/questions/15465478/update-or-insert-mysql-python
today_str = today.strftime('%Y-%m-%d')
db_client.batch_insert(
        ('INSERT INTO SPL_PRODUCT_POPULARITY (PRODUCT_ID, DATE, '
         'VIEW_COUNT, ORDER_COUNT, POPULARITY, POPULARITY_PERCENTILE) '
         'VALUES (%s, %s, %s, %s, %s, %s, %s) '
         'ON DUPLICATE KEY UPDATE '
         'POPULARITY = VALUES(POPULARITY), '
         'POPULARITY_PERCENTILE = VALUES(POPULARITY_PERCENTILE)'),
        [(product_stats[PRODUCT_ID], today_str,
          0, 0, 0, product_stats[POPULARITY], popularity_percentiles[idx])
         for idx, product_stats in enumerate(product_stats_list)]
)

# Push information to elasticsearch
calc_logger.debug('Updating popularity in elasticsearch')
actions = ActionGenerator('product_listing_w', 'products', product_stats_list)
success, failed = es_client.parallel_bulk(actions)

if failed:
    calc_logger.error('Failed to update documents. Cause: {}'.format(failed))

calc_logger.info('Finished Popularity Calculator')
