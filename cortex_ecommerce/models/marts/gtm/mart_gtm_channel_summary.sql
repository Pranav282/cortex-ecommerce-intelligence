with acquisition as (

    select *
    from {{ ref('mart_acquisition_channel_performance') }}

),

sessions as (

    select *
    from {{ ref('int_session_funnel') }}

),

channel_funnel as (

    select
        {{ canonicalize_traffic_source('traffic_source') }} as acquisition_channel,

        count(*) as total_sessions,

        count_if(reached_product = 1)
            as product_sessions,

        count_if(reached_cart = 1)
            as cart_sessions,

        count_if(reached_purchase = 1)
            as purchase_sessions,

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
    group by {{ canonicalize_traffic_source('traffic_source') }}

),

combined as (

    select
        acquisition.acquisition_channel,

        acquisition.acquired_customer_count,
        acquisition.purchasing_customer_count,
        acquisition.repeat_customer_count,
        acquisition.total_orders,
        acquisition.total_revenue,
        acquisition.average_revenue_per_acquired_customer,
        acquisition.average_revenue_per_purchasing_customer,
        acquisition.average_order_value,
        acquisition.customer_conversion_rate,
        acquisition.repeat_purchaser_rate,
        acquisition.revenue_share,

        channel_funnel.total_sessions,
        channel_funnel.product_sessions,
        channel_funnel.cart_sessions,
        channel_funnel.purchase_sessions,
        channel_funnel.product_to_cart_sessions,
        channel_funnel.cart_to_purchase_sessions,
        channel_funnel.abandoned_cart_sessions,
        channel_funnel.bounced_sessions,
        channel_funnel.average_session_duration_seconds,
        channel_funnel.average_events_per_session,

        channel_funnel.purchase_sessions::float
        / nullif(channel_funnel.total_sessions, 0)
            as session_conversion_rate,

        channel_funnel.product_to_cart_sessions::float
        / nullif(channel_funnel.product_sessions, 0)
            as product_to_cart_rate,

        channel_funnel.cart_to_purchase_sessions::float
        / nullif(channel_funnel.cart_sessions, 0)
            as cart_to_purchase_rate,

        channel_funnel.abandoned_cart_sessions::float
        / nullif(channel_funnel.cart_sessions, 0)
            as cart_abandonment_rate,

        channel_funnel.bounced_sessions::float
        / nullif(channel_funnel.total_sessions, 0)
            as bounce_rate

    from acquisition
    left join channel_funnel
        on acquisition.acquisition_channel
            = channel_funnel.acquisition_channel

),

benchmarks as (

    select
        sum(purchase_sessions)::float
        / nullif(sum(total_sessions), 0)
            as overall_session_conversion_rate,

        sum(abandoned_cart_sessions)::float
        / nullif(sum(cart_sessions), 0)
            as overall_cart_abandonment_rate,

        sum(purchasing_customer_count)::float
        / nullif(sum(acquired_customer_count), 0)
            as overall_customer_conversion_rate,

        sum(repeat_customer_count)::float
        / nullif(sum(purchasing_customer_count), 0)
            as overall_repeat_purchaser_rate

    from combined

),

final as (

    select
        combined.*,

        dense_rank() over (
            order by total_revenue desc
        ) as revenue_rank,

        dense_rank() over (
            order by session_conversion_rate desc
        ) as session_conversion_rank,

        case
            when session_conversion_rate
                    >= benchmarks.overall_session_conversion_rate
                and repeat_purchaser_rate
                    >= benchmarks.overall_repeat_purchaser_rate
                then 'Scale high-performing channel'

            when cart_abandonment_rate
                    > benchmarks.overall_cart_abandonment_rate
                then 'Investigate cart and checkout abandonment'

            when customer_conversion_rate
                    < benchmarks.overall_customer_conversion_rate
                then 'Improve acquisition targeting and landing experience'

            when repeat_purchaser_rate
                    < benchmarks.overall_repeat_purchaser_rate
                then 'Strengthen retention and repeat-purchase campaigns'

            else 'Monitor and test incremental improvements'
        end as recommended_action

    from combined
    cross join benchmarks

)

select *
from final