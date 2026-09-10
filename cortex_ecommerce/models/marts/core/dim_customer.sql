with customers as (

    select
        user_id,
        first_name,
        last_name,
        email,
        age,
        gender,
        city,
        state,
        country,
        acquisition_source,
        account_created_at as customer_created_at
    from {{ ref('stg_thelook__users') }}

),

customer_order_metrics as (

    select
        user_id,

        count(distinct order_id) as total_order_count,

        count_if(lower(order_status) = 'complete')
            as completed_order_count,

        count_if(lower(order_status) = 'cancelled')
            as cancelled_order_count,

        count_if(lower(order_status) = 'returned')
            as returned_order_count,

        sum(item_count) as total_items_ordered,

        sum(
            case
                when lower(order_status) = 'complete'
                    then order_revenue
                else 0
            end
        ) as lifetime_revenue,

        avg(
            case
                when lower(order_status) = 'complete'
                    then order_revenue
            end
        ) as average_completed_order_value,

        min(order_created_at) as first_order_at,
        max(order_created_at) as last_order_at

    from {{ ref('int_customer_orders') }}
    group by user_id

),

final as (

    select
        customers.user_id,
        customers.first_name,
        customers.last_name,
        customers.email,
        customers.age,
        customers.gender,
        customers.city,
        customers.state,
        customers.country,
        customers.acquisition_source,
        customers.customer_created_at,

        coalesce(metrics.total_order_count, 0)
            as total_order_count,

        coalesce(metrics.completed_order_count, 0)
            as completed_order_count,

        coalesce(metrics.cancelled_order_count, 0)
            as cancelled_order_count,

        coalesce(metrics.returned_order_count, 0)
            as returned_order_count,

        coalesce(metrics.total_items_ordered, 0)
            as total_items_ordered,

        coalesce(metrics.lifetime_revenue, 0)
            as lifetime_revenue,

        metrics.average_completed_order_value,
        metrics.first_order_at,
        metrics.last_order_at,

        datediff(
            'day',
            metrics.last_order_at,
            current_date()
        ) as days_since_last_order,

        datediff(
            'day',
            customers.customer_created_at,
            current_date()
        ) as customer_tenure_days,

        case
            when coalesce(metrics.total_order_count, 0) >= 2 then true
            else false
        end as is_repeat_customer,

        case
            when metrics.first_order_at is null then 'Never Purchased'
            when datediff('day', metrics.last_order_at, current_date()) <= 30
                then 'Active'
            when datediff('day', metrics.last_order_at, current_date()) <= 90
                then 'At Risk'
            else 'Inactive'
        end as lifecycle_status

    from customers
    left join customer_order_metrics as metrics
        on customers.user_id = metrics.user_id

)

select *
from final