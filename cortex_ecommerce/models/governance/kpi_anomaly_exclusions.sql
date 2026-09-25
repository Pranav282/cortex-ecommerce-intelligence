select
    series_key::varchar as series_key,
    'Skipped during anomaly scoring due to a series-specific ML error'
        as exclusion_reason,
    current_timestamp() as recorded_at
from {{ ref('kpi_anomaly_score_v2') }}

where series_key::varchar not in (

    select distinct series::varchar
    from {{ ref('kpi_anomaly_results') }}
)

group by series_key::varchar
