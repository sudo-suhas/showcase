# Popularity Calculator
Script for calculating the popularity for products based on stats.
It takes into account the weightage for the stats based on how old the data is
and also factors in the popularity percentile for the same.
If a product had more popularity, it's data will be normalized to account for popularity driven sales/views

It uses [`scipy`](https://www.scipy.org/)'s rankdata for calculating percentiles.

## Description
It queries the database to fetch ~1100000 rows of data for products from the last 60 days.
This includes information about view count, order count and popularity of that product on that day.
This data is weighted for how old it is and product stats are [aggregated](calc.py#L40-L60) for each product id.
Stats are normalised for average popularity. Percentiles for the view and order counts are calculated and
used in the calculation of popularity. This data is pushed back into the database and into elasticsearch for
use in calculating score.
The whole script executes in under 1 minute.