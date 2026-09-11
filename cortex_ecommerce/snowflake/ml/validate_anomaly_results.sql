/*--------------------------------------------------------------
  Phase 8.5: Validate KPI anomaly-detection results
--------------------------------------------------------------*/

use role CORTEX_ECOMMERCE_ROLE;
use warehouse CORTEX_ECOMMERCE_WH;
use database CORTEX_ECOMMERCE;
use schema AI_GOVERNANCE;


/*--------------------------------------------------------------
  1. Overall scoring summary
--------------------------------------------------------------*/

select
    count(*) as scored_rows,
    count(distinct series::varchar) as scored_kpis,
    count_if(is_anomaly = true) as anomalies_detected,
    min(ts) as first_scoring_timestamp,
    max(ts) as last_scoring_timestamp
from KPI_ANOMALY_RESULTS;


/*--------------------------------------------------------------
  2. Results by KPI
--------------------------------------------------------------*/

select
    series::varchar as series_key,
    count(*) as scored_rows,
    count_if(is_anomaly = true) as anomalies_detected,
    min(ts) as first_scoring_timestamp,
    max(ts) as last_scoring_timestamp,
    avg(y) as average_actual_value,
    avg(forecast) as average_forecast_value
from KPI_ANOMALY_RESULTS
group by series::varchar
order by series_key;


/*--------------------------------------------------------------
  3. Inspect detected anomalies
--------------------------------------------------------------*/

select
    series::varchar as series_key,
    ts as metric_timestamp,
    y as actual_value,
    forecast as expected_value,
    lower_bound,
    upper_bound,
    percentile,
    distance
from KPI_ANOMALY_RESULTS
where is_anomaly = true
order by
    metric_timestamp desc,
    series_key;


/*--------------------------------------------------------------
  4. Validate that scoring follows training
--------------------------------------------------------------*/

with training_boundary as (

    select
        max(metric_timestamp) as last_training_timestamp
    from CORTEX_ECOMMERCE.ML.KPI_ANOMALY_TRAIN_V2

),

scoring_boundary as (

    select
        min(ts) as first_scoring_timestamp
    from KPI_ANOMALY_RESULTS

)

select
    training.last_training_timestamp,
    scoring.first_scoring_timestamp,

    scoring.first_scoring_timestamp >
        training.last_training_timestamp
        as valid_timestamp_boundary

from training_boundary training
cross join scoring_boundary scoring;


/*--------------------------------------------------------------
  5. Validate timestamp boundaries for each scored KPI
--------------------------------------------------------------*/

with training_boundaries as (

    select
        series_key::varchar as series_key,
        max(metric_timestamp) as last_training_timestamp
    from CORTEX_ECOMMERCE.ML.KPI_ANOMALY_TRAIN_V2
    group by series_key::varchar

),

scoring_boundaries as (

    select
        series::varchar as series_key,
        min(ts) as first_scoring_timestamp
    from KPI_ANOMALY_RESULTS
    group by series::varchar

)

select
    training.series_key,
    training.last_training_timestamp,
    scoring.first_scoring_timestamp,

    scoring.first_scoring_timestamp >
        training.last_training_timestamp
        as valid_timestamp_boundary

from training_boundaries training
join scoring_boundaries scoring
    on training.series_key = scoring.series_key
order by training.series_key;


/*--------------------------------------------------------------
  6. Find KPIs excluded from scoring
--------------------------------------------------------------*/

with expected_series as (

    select distinct
        series_key::varchar as series_key
    from CORTEX_ECOMMERCE.ML.KPI_ANOMALY_SCORE_V2

),

scored_series as (

    select distinct
        series::varchar as series_key
    from KPI_ANOMALY_RESULTS

)

select
    expected.series_key as excluded_series_key,
    'Series was skipped during Snowflake ML scoring'
        as exclusion_reason

from expected_series expected
left join scored_series scored
    on expected.series_key = scored.series_key
where scored.series_key is null
order by excluded_series_key;


/*--------------------------------------------------------------
  7. Check for duplicate KPI timestamps in the results
--------------------------------------------------------------*/

select
    series::varchar as series_key,
    ts as metric_timestamp,
    count(*) as duplicate_count
from KPI_ANOMALY_RESULTS
group by
    series::varchar,
    ts
having count(*) > 1
order by
    series_key,
    metric_timestamp;


/*--------------------------------------------------------------
  8. Check for invalid or incomplete output
--------------------------------------------------------------*/

select
    count_if(series is null) as null_series_keys,
    count_if(ts is null) as null_timestamps,
    count_if(y is null) as null_actual_values,
    count_if(forecast is null) as null_forecasts,
    count_if(lower_bound is null) as null_lower_bounds,
    count_if(upper_bound is null) as null_upper_bounds,
    count_if(lower_bound > upper_bound) as invalid_bound_ranges
from KPI_ANOMALY_RESULTS;