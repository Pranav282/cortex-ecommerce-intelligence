select
    to_variant(series_key)             as series_key,
    metric_timestamp::timestamp_ntz    as metric_timestamp,
    metric_value::float                as metric_value
from {{ ref('int_kpi_anomaly_input') }}
where dataset_split = 'TRAIN'
  and metric_timestamp < '2025-12-01'::timestamp_ntz
