with source as (

    select *
    from {{ source('thelook', 'users') }}

),

renamed as (

    select
        id::number as user_id,
        trim(first_name)::varchar as first_name,
        trim(last_name)::varchar as last_name,
        lower(trim(email))::varchar as email,
        age::number as age,
        upper(trim(gender))::varchar as gender,
        trim(state)::varchar as state,
        trim(street_address)::varchar as street_address,
        trim(postal_code)::varchar as postal_code,
        trim(city)::varchar as city,
        trim(country)::varchar as country,
        latitude::float as latitude,
        longitude::float as longitude,
        trim(traffic_source)::varchar as acquisition_source,
        created_at::timestamp_ntz as account_created_at

    from source

)

select *
from renamed