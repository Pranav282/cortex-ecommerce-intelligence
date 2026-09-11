with orders as (

    select *
    from {{ ref('int_customer_orders') }}

),

customers as (

    select
        user_id,
        {{ canonicalize_traffic_source('acquisition_source') }}
            as acquisition_channel
    from {{ ref('stg_thelook__users') }}

),

daily_order_metrics as (

    select
        orders.order_created_at::date as metric_date,
        coalesce(customers.acquisition_channel, 'Unknown')
            as acquisition_channel,

        count(distinct orders.order_id) as total_orders,

        count(distinct case
            when lower(orders.order_status) = 'complete'
                then orders.order_id
        end) as completed_orders,

        count(distinct case
            when lower(orders.order_status) = 'cancelled'
                then orders.order_id
        end) as cancelled_orders,

        count(distinct case
            when lower(orders.order_status) = 'returned'
                then orders.order_id
        end) as returned_orders,

        sum(case
            when lower(orders.order_status) = 'complete'
                then orders.order_revenue
            else 0
        end) as completed_revenue

    from orders
    left join customers
        on orders.user_id = customers.user_id

    group by
        orders.order_created_at::date,
        coalesce(customers.acquisition_channel, 'Unknown')

),

daily_funnel_metrics as (

    select
        session_date as metric_date,
        acquisition_channel,

        sum(total_sessions) as total_sessions,
        sum(product_sessions) as product_sessions,
        sum(cart_sessions) as cart_sessions,
        sum(purchase_sessions) as purchase_sessions,
        sum(product_to_cart_sessions) as product_to_cart_sessions,
        sum(cart_to_purchase_sessions) as cart_to_purchase_sessions,
        sum(abandoned_cart_sessions) as abandoned_cart_sessions,
        sum(bounced_sessions) as bounced_sessions

    from {{ ref('mart_conversion_funnel') }}

    group by
        session_date,
        acquisition_channel

),

combined as (

    select
        coalesce(
            daily_order_metrics.metric_date,
            daily_funnel_metrics.metric_date
        ) as metric_date,

        coalesce(
            daily_order_metrics.acquisition_channel,
            daily_funnel_metrics.acquisition_channel
        ) as acquisition_channel,

        coalesce(daily_order_metrics.total_orders, 0)
            as total_orders,

        coalesce(daily_order_metrics.completed_orders, 0)
            as completed_orders,

        coalesce(daily_order_metrics.cancelled_orders, 0)
            as cancelled_orders,

        coalesce(daily_order_metrics.returned_orders, 0)
            as returned_orders,

        coalesce(daily_order_metrics.completed_revenue, 0)
            as completed_revenue,

        coalesce(daily_funnel_metrics.total_sessions, 0)
            as total_sessions,

        coalesce(daily_funnel_metrics.product_sessions, 0)
            as product_sessions,

        coalesce(daily_funnel_metrics.cart_sessions, 0)
            as cart_sessions,

        coalesce(daily_funnel_metrics.purchase_sessions, 0)
            as purchase_sessions,

        coalesce(daily_funnel_metrics.product_to_cart_sessions, 0)
            as product_to_cart_sessions,

        coalesce(daily_funnel_metrics.cart_to_purchase_sessions, 0)
            as cart_to_purchase_sessions,

        coalesce(daily_funnel_metrics.abandoned_cart_sessions, 0)
            as abandoned_cart_sessions,

        coalesce(daily_funnel_metrics.bounced_sessions, 0)
            as bounced_sessions

    from daily_order_metrics
    full outer join daily_funnel_metrics
        on daily_order_metrics.metric_date
            = daily_funnel_metrics.metric_date
        and daily_order_metrics.acquisition_channel
            = daily_funnel_metrics.acquisition_channel

),

final as (

    select
        *,

        purchase_sessions::float
        / nullif(total_sessions, 0)
            as session_conversion_rate,

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
            as bounce_rate,

        completed_revenue
        / nullif(completed_orders, 0)
            as average_order_value,

        cancelled_orders::float
        / nullif(total_orders, 0)
            as order_cancellation_rate,

        returned_orders::float
        / nullif(
            completed_orders + returned_orders,
            0
        ) as order_return_rate

    from combined

)

select *
from final