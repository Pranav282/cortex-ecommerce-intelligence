with customers as (

    select *
    from {{ ref('dim_customer') }}

),

rfm as (

    select *
    from {{ ref('mart_customer_rfm') }}

),

final as (

    select
        sha2(to_varchar(customers.user_id), 256) as customer_key,

        customers.age,

        case
            when customers.age < 20 then 'Under 20'
            when customers.age between 20 and 29 then '20–29'
            when customers.age between 30 and 39 then '30–39'
            when customers.age between 40 and 49 then '40–49'
            when customers.age between 50 and 59 then '50–59'
            when customers.age >= 60 then '60+'
            else 'Unknown'
        end as age_group,

        customers.gender,
        customers.city,
        customers.state,
        customers.country,
        customers.acquisition_source,
        customers.customer_created_at,

        customers.total_order_count,
        customers.completed_order_count,
        customers.cancelled_order_count,
        customers.returned_order_count,
        customers.total_items_ordered,
        customers.lifetime_revenue,
        customers.average_completed_order_value,
        customers.first_order_at,
        customers.last_order_at,
        customers.is_repeat_customer,

        rfm.analysis_date,
        rfm.recency_days,
        rfm.frequency,
        rfm.monetary_value,
        rfm.recency_score,
        rfm.frequency_score,
        rfm.monetary_score,
        rfm.rfm_score,

        coalesce(
            rfm.customer_segment,
            'Never Purchased'
        ) as customer_segment,

        case
            when rfm.user_id is null then 'Never Purchased'
            when rfm.recency_days <= 30 then 'Active'
            when rfm.recency_days <= 90 then 'At Risk'
            else 'Inactive'
        end as engagement_status,

        case
            when (
                customers.completed_order_count
                + customers.returned_order_count
            ) > 0
            then
                customers.returned_order_count
                / nullif(
                    customers.completed_order_count
                    + customers.returned_order_count,
                    0
                )
            else 0
        end as customer_return_rate,

        case
            when customers.total_order_count > 0 then
                customers.cancelled_order_count
                / nullif(customers.total_order_count, 0)
            else 0
        end as customer_cancellation_rate

    from customers
    left join rfm
        on customers.user_id = rfm.user_id

)

select *
from final