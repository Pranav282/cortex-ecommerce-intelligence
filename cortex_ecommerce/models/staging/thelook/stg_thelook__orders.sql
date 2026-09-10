with source as (

    select *
    from {{ source('thelook', 'orders') }}

),

renamed as (

    select
        order_id::number as order_id,
        user_id::number as user_id,
        upper(trim(status))::varchar as order_status,
        upper(trim(gender))::varchar as customer_gender,
        created_at::timestamp_ntz as order_created_at,
        shipped_at::timestamp_ntz as shipped_at,
        delivered_at::timestamp_ntz as delivered_at,
        returned_at::timestamp_ntz as returned_at,
        num_of_item::number as item_count

    from source

)

select *
from renamed