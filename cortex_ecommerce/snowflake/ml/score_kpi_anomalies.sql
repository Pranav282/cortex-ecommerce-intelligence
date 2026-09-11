use role CORTEX_ECOMMERCE_ROLE;
use warehouse CORTEX_ECOMMERCE_WH;
use database CORTEX_ECOMMERCE;
use schema ML;

create or replace table
    CORTEX_ECOMMERCE.AI_GOVERNANCE.KPI_ANOMALY_RESULTS as

select *
from table(
    KPI_ANOMALY_DETECTOR_V2!detect_anomalies(
        input_data => table(KPI_ANOMALY_SCORE_V2),
        series_colname => 'SERIES_KEY',
        timestamp_colname => 'METRIC_TIMESTAMP',
        target_colname => 'METRIC_VALUE',

        config_object => {
            'prediction_interval': 0.99,
            'on_error': 'skip'
        }
    )
);