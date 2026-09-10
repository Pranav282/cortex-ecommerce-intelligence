with source as (

    select *
    from {{ source('thelook', 'distribution_centers') }}

),

renamed as (

    select
        id::number as distribution_center_id,
        trim(name)::varchar as distribution_center_name,
        latitude::float as latitude,
        longitude::float as longitude

    from source

)

select *
from renamed