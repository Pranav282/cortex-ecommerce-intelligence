with sessions as (

    select *
    from {{ ref('int_session_funnel') }}

),

daily_funnel as (

    select
        session_started_at::date as session_date,
        {{ canonicalize_traffic_source('traffic_source') }} as acquisition_channel,
        coalesce(browser, 'Unknown') as browser,

        count(*) as total_sessions,
        count(distinct user_id) as unique_users,

        count_if(reached_home = 1) as home_sessions,
        count_if(reached_department = 1) as department_sessions,
        count_if(reached_product = 1) as product_sessions,
        count_if(reached_cart = 1) as cart_sessions,
        count_if(reached_purchase = 1) as purchase_sessions,

        count_if(
            reached_product = 1
            and reached_cart = 1
        ) as product_to_cart_sessions,

        count_if(
            reached_cart = 1
            and reached_purchase = 1
        ) as cart_to_purchase_sessions,

        count_if(abandoned_cart_session = 1)
            as abandoned_cart_sessions,

        count_if(bounced_session = 1)
            as bounced_sessions,

        avg(session_duration_seconds)
            as average_session_duration_seconds,

        avg(event_count)
            as average_events_per_session

    from sessions
    group by
        session_started_at::date,
        {{ canonicalize_traffic_source('traffic_source') }},
        coalesce(browser, 'Unknown')

),

final as (

    select
        *,

        purchase_sessions::float
        / nullif(total_sessions, 0)
            as session_conversion_rate,

        product_sessions::float
        / nullif(total_sessions, 0)
            as product_view_rate,

        product_to_cart_sessions::float
        / nullif(product_sessions, 0)
            as product_to_cart_rate,

        cart_to_purchase_sessions::float
        / nullif(cart_sessions, 0)
            as cart_to_purchase_rate,

        abandoned_cart_sessions::float
        / nullif(cart_sessions, 0)
            as cart_abandonment_rate,

        bounced_sessions::float
        / nullif(total_sessions, 0)
            as bounce_rate

    from daily_funnel

)

select *
from final