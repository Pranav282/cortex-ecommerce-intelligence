with daily_kpis as (

    select *
    from {{ ref('mart_daily_business_kpis') }}

),

long_format as (

    select
        metric_date,
        acquisition_channel,
        'COMPLETED_REVENUE' as metric_name,
        completed_revenue::float as metric_value
    from daily_kpis

    union all

    select
        metric_date,
        acquisition_channel,
        'TOTAL_ORDERS' as metric_name,
        total_orders::float as metric_value
    from daily_kpis

    union all

    select
        metric_date,
        acquisition_channel,
        'SESSION_CONVERSION_RATE' as metric_name,
        session_conversion_rate::float as metric_value
    from daily_kpis
    where session_conversion_rate is not null

    union all

    select
        metric_date,
        acquisition_channel,
        'CART_ABANDONMENT_RATE' as metric_name,
        cart_abandonment_rate::float as metric_value
    from daily_kpis
    where cart_abandonment_rate is not null

    union all

    select
        metric_date,
        acquisition_channel,
        'AVERAGE_ORDER_VALUE' as metric_name,
        average_order_value::float as metric_value
    from daily_kpis
    where average_order_value is not null

),

dataset_boundary as (

    select
        max(metric_date) as maximum_metric_date
    from long_format

),

final as (

    select
        concat(
            acquisition_channel,
            '|',
            metric_name
        ) as series_key,

        acquisition_channel,
        metric_name,

        metric_date::timestamp_ntz as metric_timestamp,
        metric_value,

        case
            when metric_date < dateadd(
                'day',
                -30,
                maximum_metric_date
            )
                then 'TRAIN'
            else 'SCORE'
        end as dataset_split

    from long_format
    cross join dataset_boundary

)

select *
from final