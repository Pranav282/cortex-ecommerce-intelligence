use role CORTEX_ECOMMERCE_ROLE;
use warehouse CORTEX_ECOMMERCE_WH;
use database CORTEX_ECOMMERCE;
use schema ML;

create or replace table KPI_ANOMALY_TRAIN_V2 as
select
    to_variant(series_key)             as series_key,
    metric_timestamp::timestamp_ntz    as metric_timestamp,
    metric_value::float                as metric_value
from CORTEX_ECOMMERCE.ANALYTICS.INT_KPI_ANOMALY_INPUT
where dataset_split = 'TRAIN'
  and metric_timestamp < '2025-12-01'::timestamp_ntz;


create or replace table KPI_ANOMALY_SCORE_V2 as
select
    to_variant(series_key)             as series_key,
    metric_timestamp::timestamp_ntz    as metric_timestamp,
    metric_value::float                as metric_value
from CORTEX_ECOMMERCE.ANALYTICS.INT_KPI_ANOMALY_INPUT
where dataset_split = 'SCORE'
  and metric_timestamp >= '2025-12-01'::timestamp_ntz;