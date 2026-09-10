with source as (

    select *
    from {{ source('thelook', 'order_items') }}

),

valid_orders as (

    select order_id
    from {{ ref('stg_thelook__orders') }}

),

renamed as (

    select
        source.id::number as order_item_id,
        source.order_id::number as order_id,
        source.user_id::number as user_id,
        source.product_id::number as product_id,
        source.inventory_item_id::number as inventory_item_id,
        upper(trim(source.status))::varchar as order_item_status,
        source.created_at::timestamp_ntz as order_item_created_at,
        source.shipped_at::timestamp_ntz as shipped_at,
        source.delivered_at::timestamp_ntz as delivered_at,
        source.returned_at::timestamp_ntz as returned_at,
        source.sale_price::number(12, 2) as sale_price

    from source

    inner join valid_orders
        on source.order_id = valid_orders.order_id

)

select *
from renamed