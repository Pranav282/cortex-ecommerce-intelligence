with completed_orders as (

    select
        user_id,
        order_id,
        order_created_at,
        order_revenue
    from {{ ref('int_customer_orders') }}
    where lower(order_status) = 'complete'

),

first_purchases as (

    select
        user_id,
        date_trunc(
            'month',
            min(order_created_at)
        )::date as cohort_month
    from completed_orders
    group by user_id

),

cohort_sizes as (

    select
        cohort_month,
        count(distinct user_id) as cohort_size
    from first_purchases
    group by cohort_month

),

monthly_activity as (

    select
        first_purchases.cohort_month,

        date_trunc(
            'month',
            completed_orders.order_created_at
        )::date as activity_month,

        datediff(
            'month',
            first_purchases.cohort_month,
            date_trunc('month', completed_orders.order_created_at)
        ) as months_since_first_purchase,

        count(distinct completed_orders.user_id)
            as active_customers,

        count(distinct completed_orders.order_id)
            as completed_orders,

        sum(completed_orders.order_revenue)
            as monthly_revenue

    from completed_orders
    inner join first_purchases
        on completed_orders.user_id = first_purchases.user_id

    group by
        first_purchases.cohort_month,
        date_trunc(
            'month',
            completed_orders.order_created_at
        )::date,
        datediff(
            'month',
            first_purchases.cohort_month,
            date_trunc('month', completed_orders.order_created_at)
        )

),

final as (

    select
        monthly_activity.cohort_month,
        monthly_activity.activity_month,
        monthly_activity.months_since_first_purchase,

        cohort_sizes.cohort_size,
        monthly_activity.active_customers,
        monthly_activity.completed_orders,
        monthly_activity.monthly_revenue,

        monthly_activity.active_customers::float
        / nullif(cohort_sizes.cohort_size, 0)
            as retention_rate,

        monthly_activity.monthly_revenue
        / nullif(monthly_activity.active_customers, 0)
            as revenue_per_active_customer,

        sum(monthly_activity.monthly_revenue) over (
            partition by monthly_activity.cohort_month
            order by monthly_activity.months_since_first_purchase
            rows between unbounded preceding and current row
        ) as cumulative_cohort_revenue

    from monthly_activity
    inner join cohort_sizes
        on monthly_activity.cohort_month = cohort_sizes.cohort_month

)

select *
from final