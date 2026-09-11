create or replace table
    CORTEX_ECOMMERCE.AI_GOVERNANCE.KPI_ANOMALY_EXCLUSIONS as

select
    series_key::varchar as series_key,
    'Skipped during anomaly scoring due to a series-specific ML error'
        as exclusion_reason,
    current_timestamp() as recorded_at
from CORTEX_ECOMMERCE.ML.KPI_ANOMALY_SCORE_V2

where series_key::varchar not in (

    select distinct series::varchar
    from CORTEX_ECOMMERCE.AI_GOVERNANCE.KPI_ANOMALY_RESULTS
)

group by series_key::varchar;