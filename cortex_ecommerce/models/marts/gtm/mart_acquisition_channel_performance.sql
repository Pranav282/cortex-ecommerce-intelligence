with customers as (

    select *
    from {{ ref('mart_customer_360') }}

),

channel_metrics as (

    select

        {{ canonicalize_traffic_source('acquisition_source') }} as acquisition_channel,
        
        count(*) as acquired_customer_count,

        count_if(completed_order_count > 0)
            as purchasing_customer_count,

        count_if(completed_order_count >= 2)
            as repeat_customer_count,

        count_if(engagement_status = 'Active')
            as active_customer_count,

        count_if(engagement_status = 'At Risk')
            as at_risk_customer_count,

        count_if(engagement_status = 'Inactive')
            as inactive_customer_count,

        sum(total_order_count) as total_orders,

        sum(completed_order_count) as completed_orders,

        sum(lifetime_revenue) as total_revenue,

        avg(lifetime_revenue) as average_revenue_per_acquired_customer,

        avg(
            case
                when completed_order_count > 0
                    then lifetime_revenue
            end
        ) as average_revenue_per_purchasing_customer,

        avg(average_completed_order_value)
            as average_order_value,

        avg(customer_return_rate)
            as average_customer_return_rate,

        avg(customer_cancellation_rate)
            as average_customer_cancellation_rate

    from customers
    group by
        {{ canonicalize_traffic_source('acquisition_source') }}

),

overall_metrics as (

    select
        sum(total_revenue) as overall_revenue
    from channel_metrics

),

final as (

    select
        channel_metrics.*,

        purchasing_customer_count::float
        / nullif(acquired_customer_count, 0)
            as customer_conversion_rate,

        repeat_customer_count::float
        / nullif(purchasing_customer_count, 0)
            as repeat_purchaser_rate,

        active_customer_count::float
        / nullif(purchasing_customer_count, 0)
            as active_purchaser_rate,

        total_revenue
        / nullif(overall_metrics.overall_revenue, 0)
            as revenue_share,

        rank() over (
            order by total_revenue desc
        ) as revenue_rank,

        rank() over (
            order by
                purchasing_customer_count::float
                / nullif(acquired_customer_count, 0) desc
        ) as conversion_rank

    from channel_metrics
    cross join overall_metrics

)

select *
from final