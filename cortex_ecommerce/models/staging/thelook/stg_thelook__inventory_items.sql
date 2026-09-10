with source as (

    select *
    from {{ source('thelook', 'inventory_items') }}

),

renamed as (

    select
        id::number as inventory_item_id,
        product_id::number as product_id,
        created_at::timestamp_ntz as inventory_created_at,
        sold_at::timestamp_ntz as sold_at,
        cost::number(12, 2) as inventory_cost,
        trim(product_category)::varchar as product_category,
        trim(product_name)::varchar as product_name,
        trim(product_brand)::varchar as product_brand,
        product_retail_price::number(12, 2) as retail_price,
        upper(trim(product_department))::varchar as product_department,
        trim(product_sku)::varchar as product_sku,
        product_distribution_center_id::number
            as distribution_center_id

    from source

)

select *
from renamed