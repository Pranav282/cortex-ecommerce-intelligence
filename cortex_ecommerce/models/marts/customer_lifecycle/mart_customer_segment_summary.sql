with customers as (

    select *
    from {{ ref('mart_customer_360') }}

),

segment_metrics as (

    select
        customer_segment,

        count(*) as customer_count,

        count_if(is_repeat_customer) as repeat_customer_count,

        count_if(engagement_status = 'Active') as active_customer_count,

        count_if(engagement_status = 'At Risk') as at_risk_customer_count,

        count_if(engagement_status = 'Inactive') as inactive_customer_count,

        count_if(engagement_status = 'Never Purchased')
            as never_purchased_customer_count,

        sum(total_order_count) as total_orders,

        sum(completed_order_count) as completed_orders,

        sum(lifetime_revenue) as total_revenue,

        avg(lifetime_revenue) as average_customer_value,

        avg(average_completed_order_value) as average_order_value,

        avg(recency_days) as average_recency_days,

        avg(customer_return_rate) as average_return_rate,

        avg(customer_cancellation_rate) as average_cancellation_rate

    from customers
    group by customer_segment

),

overall_totals as (

    select
        sum(customer_count) as all_customers,
        sum(total_revenue) as all_revenue
    from segment_metrics

),

final as (

    select
        segment_metrics.*,

        segment_metrics.customer_count
        / nullif(overall_totals.all_customers, 0)
            as customer_share,

        segment_metrics.total_revenue
        / nullif(overall_totals.all_revenue, 0)
            as revenue_share,

        segment_metrics.repeat_customer_count
        / nullif(segment_metrics.customer_count, 0)
            as repeat_customer_rate,

        case
            when customer_segment = 'Champions'
                then 'Protect and reward'

            when customer_segment = 'Loyal Customers'
                then 'Cross-sell and increase order value'

            when customer_segment = 'New or Promising'
                then 'Drive the second purchase'

            when customer_segment = 'At Risk'
                then 'Launch a targeted retention campaign'

            when customer_segment = 'Hibernating'
                then 'Test a reactivation offer'

            when customer_segment = 'Needs Attention'
                then 'Increase personalized engagement'

            when customer_segment = 'Never Purchased'
                then 'Improve first-purchase conversion'
        end as recommended_action

    from segment_metrics
    cross join overall_totals

)

select *
from final