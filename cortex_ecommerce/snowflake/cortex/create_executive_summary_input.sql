/*--------------------------------------------------------------
  Phase 8.6: Prepare KPI context for Cortex
--------------------------------------------------------------*/

use role CORTEX_ECOMMERCE_ROLE;
use warehouse CORTEX_ECOMMERCE_WH;
use database CORTEX_ECOMMERCE;
use schema AI_GOVERNANCE;


create or replace view EXECUTIVE_SUMMARY_INPUT as

with anomaly_results as (

    select
        series::varchar as series_key,
        ts as metric_timestamp,
        y as actual_value,
        forecast as expected_value,
        lower_bound,
        upper_bound,
        is_anomaly,
        distance
    from KPI_ANOMALY_RESULTS

),

reporting_period as (

    select
        min(metric_timestamp)::date as period_start_date,
        max(metric_timestamp)::date as period_end_date,
        count(*) as scored_observations,
        count(distinct series_key) as scored_kpis,
        count_if(is_anomaly = true) as total_anomalies
    from anomaly_results

),

kpi_rollup as (

    select
        series_key,

        round(avg(actual_value), 2)
            as average_actual_value,

        round(avg(expected_value), 2)
            as average_expected_value,

        round(
            100 * (
                avg(actual_value) - avg(expected_value)
            ) / nullif(abs(avg(expected_value)), 0),
            2
        ) as variance_from_expected_pct,

        round(max_by(actual_value, metric_timestamp), 2)
            as latest_actual_value,

        round(max_by(expected_value, metric_timestamp), 2)
            as latest_expected_value,

        max(metric_timestamp)::date
            as latest_metric_date,

        count_if(is_anomaly = true)
            as anomaly_count

    from anomaly_results
    group by series_key

),

kpi_context as (

    select
        listagg(
            concat(
                series_key,
                ': average actual = ',
                coalesce(average_actual_value::varchar, 'Unavailable'),
                ', average expected = ',
                coalesce(average_expected_value::varchar, 'Unavailable'),
                ', variance from expected = ',
                coalesce(variance_from_expected_pct::varchar, 'Unavailable'),
                '%, latest actual = ',
                coalesce(latest_actual_value::varchar, 'Unavailable'),
                ', latest expected = ',
                coalesce(latest_expected_value::varchar, 'Unavailable'),
                ', anomaly count = ',
                anomaly_count::varchar
            ),
            ' | '
        ) within group (order by series_key)
            as kpi_summary_text

    from kpi_rollup

),

anomaly_context as (

    select
        listagg(
            concat(
                series_key,
                ' on ',
                metric_timestamp::date::varchar,
                ': actual = ',
                round(actual_value, 2)::varchar,
                ', expected = ',
                round(expected_value, 2)::varchar,
                ', expected range = ',
                round(lower_bound, 2)::varchar,
                ' to ',
                round(upper_bound, 2)::varchar
            ),
            ' | '
        ) within group (
            order by metric_timestamp, series_key
        ) as anomaly_detail_text

    from anomaly_results
    where is_anomaly = true

)

select
    reporting_period.period_start_date,
    reporting_period.period_end_date,
    reporting_period.scored_observations,
    reporting_period.scored_kpis,
    reporting_period.total_anomalies,

    kpi_context.kpi_summary_text,

    coalesce(
        anomaly_context.anomaly_detail_text,
        'No anomalies were detected during the reporting period.'
    ) as anomaly_detail_text,

    'v1.0' as input_version,
    current_timestamp() as input_generated_at

from reporting_period
cross join kpi_context
cross join anomaly_context;