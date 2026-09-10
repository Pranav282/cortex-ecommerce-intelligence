with order_items as (

    select *
    from {{ source('thelook', 'order_items') }}

),

valid_orders as (

    select order_id
    from {{ ref('stg_thelook__orders') }}

),

rejected as (

    select
        order_items.id::number as order_item_id,
        order_items.order_id::number as order_id,
        order_items.user_id::number as user_id,
        order_items.product_id::number as product_id,
        order_items.inventory_item_id::number as inventory_item_id,
        order_items.status::varchar as order_item_status,
        order_items.created_at::timestamp_ntz
            as order_item_created_at,
        order_items.sale_price::number(12, 2) as sale_price,
        'ORDER_ID_NOT_FOUND'::varchar as rejection_reason,
        current_timestamp()::timestamp_ntz as rejected_at

    from order_items

    left join valid_orders
        on order_items.order_id = valid_orders.order_id

    where valid_orders.order_id is null

)

select *
from rejected