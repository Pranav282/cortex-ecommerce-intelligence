with source as (

    select *
    from {{ source('thelook', 'events') }}

),

renamed as (

    select
        id::number as event_id,
        user_id::number as user_id,
        sequence_number::number as event_sequence_number,
        trim(session_id)::varchar as session_id,
        created_at::timestamp_ntz as event_created_at,

        sha2(
            ip_address::varchar,
            256
        )::varchar as ip_address_hash,

        trim(city)::varchar as city,
        trim(state)::varchar as state,
        trim(postal_code)::varchar as postal_code,
        trim(browser)::varchar as browser,
        trim(traffic_source)::varchar as traffic_source,
        trim(uri)::varchar as page_uri,
        lower(trim(event_type))::varchar as event_type,

        case
            when user_id is not null then true
            else false
        end as is_authenticated_event

    from source

)

select *
from renamed