use role ACCOUNTADMIN;

grant create snowflake.ml.anomaly_detection
    on schema CORTEX_ECOMMERCE.ML
    to role CORTEX_ECOMMERCE_ROLE;

use role CORTEX_ECOMMERCE_ROLE;
use warehouse CORTEX_ECOMMERCE_WH;
use database CORTEX_ECOMMERCE;
use schema ML;

create or replace snowflake.ml.anomaly_detection
    KPI_ANOMALY_DETECTOR_V2(
        input_data => table(KPI_ANOMALY_TRAIN_V2),
        series_colname => 'SERIES_KEY',
        timestamp_colname => 'METRIC_TIMESTAMP',
        target_colname => 'METRIC_VALUE',
        label_colname => ''
    );