-- Requires the separately trained ML.KPI_ANOMALY_DETECTOR_V2 object.
select *
from table(
    {{ target.database }}.ML.KPI_ANOMALY_DETECTOR_V2!detect_anomalies(
        input_data => table({{ ref('kpi_anomaly_score_v2') }}),
        series_colname => 'SERIES_KEY',
        timestamp_colname => 'METRIC_TIMESTAMP',
        target_colname => 'METRIC_VALUE',

        config_object => {
            'prediction_interval': 0.99,
            'on_error': 'skip'
        }
    )
)
