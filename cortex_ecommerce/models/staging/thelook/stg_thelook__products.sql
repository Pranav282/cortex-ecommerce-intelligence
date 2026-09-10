with source as (

    select *
    from {{ source('thelook', 'products') }}

),

renamed as (

    select
        id::number as product_id,
        coalesce(
            nullif(trim(name), ''),
            'Unknown Product'
        )::varchar as product_name,

        case
            when name is null or trim(name) = '' then true
            else false
        end as is_product_name_missing,
        trim(category)::varchar as product_category,
        trim(brand)::varchar as product_brand,
        upper(trim(department))::varchar as product_department,
        trim(sku)::varchar as product_sku,
        cost::number(12, 2) as product_cost,
        retail_price::number(12, 2) as retail_price,
        distribution_center_id::number as distribution_center_id

    from source

)

select *
from renamed