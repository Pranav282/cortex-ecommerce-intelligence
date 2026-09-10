with orders as (

    select *
    from {{ ref('stg_thelook__orders') }}

),

order_items as (

    select *
    from {{ ref('stg_thelook__order_items') }}

),

order_item_metrics as (

    select
        order_id,
        count(*) as item_count,
        count(distinct product_id) as distinct_product_count,
        sum(sale_price) as order_revenue,
        avg(sale_price) as average_item_price,
        min(order_item_created_at) as first_item_created_at,
        max(order_item_created_at) as last_item_created_at
    from order_items
    group by order_id

),

final as (

    select
        orders.order_id,
        orders.user_id,
        orders.order_status,
        orders.order_created_at as order_created_at,
        orders.shipped_at,
        orders.delivered_at,
        orders.returned_at,

        coalesce(order_item_metrics.item_count, 0) as item_count,
        coalesce(order_item_metrics.distinct_product_count, 0)
            as distinct_product_count,
        coalesce(order_item_metrics.order_revenue, 0) as order_revenue,
        order_item_metrics.average_item_price,

        datediff(
            'day',
            orders.order_created_at,
            orders.delivered_at
        ) as days_to_delivery,

        case
            when orders.returned_at is not null then true
            else false
        end as is_returned,

        case
            when orders.order_status = 'CANCELLED' then true
            else false
        end as is_cancelled

    from orders
    left join order_item_metrics
        on orders.order_id = order_item_metrics.order_id

)

select *
from final
