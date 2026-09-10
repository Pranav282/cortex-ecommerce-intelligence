with events as (

    select *
    from {{ ref('stg_thelook__events') }}
    where session_id is not null

),

session_events as (

    select
        session_id,
        max(user_id) as user_id,
        max(traffic_source) as traffic_source,
        max(browser) as browser,

        min(event_created_at) as session_started_at,
        max(event_created_at) as session_ended_at,

        count(*) as event_count,
        count(distinct event_type) as distinct_event_type_count,

        max(
            case when lower(event_type) = 'home'
                then 1 else 0 end
        ) as reached_home,

        max(
            case when lower(event_type) = 'department'
                then 1 else 0 end
        ) as reached_department,

        max(
            case when lower(event_type) = 'product'
                then 1 else 0 end
        ) as reached_product,

        max(
            case when lower(event_type) = 'cart'
                then 1 else 0 end
        ) as reached_cart,

        max(
            case when lower(event_type) = 'purchase'
                then 1 else 0 end
        ) as reached_purchase,

        max(
            case when lower(event_type) = 'cancel'
                then 1 else 0 end
        ) as reached_cancel

    from events
    group by session_id

),

final as (

    select
        *,

        datediff(
            'second',
            session_started_at,
            session_ended_at
        ) as session_duration_seconds,

        case
            when reached_purchase = 1 then 'Purchase'
            when reached_cart = 1 then 'Cart'
            when reached_product = 1 then 'Product'
            when reached_department = 1 then 'Department'
            when reached_home = 1 then 'Home'
            else 'Other'
        end as deepest_funnel_stage,

        case
            when reached_purchase = 1 then 1
            else 0
        end as converted_session,

        case
            when reached_cart = 1
                and reached_purchase = 0
                then 1
            else 0
        end as abandoned_cart_session,

        case
            when event_count = 1 then 1
            else 0
        end as bounced_session

    from session_events

)

select *
from final