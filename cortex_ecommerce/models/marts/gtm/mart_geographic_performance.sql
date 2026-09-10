with customers as (

    select *
    from {{ ref('mart_customer_360') }}

),

geographic_metrics as (

    select
        coalesce(country, 'Unknown') as country,
        coalesce(state, 'Unknown') as state,

        count(*) as acquired_customer_count,

        count_if(completed_order_count > 0)
            as purchasing_customer_count,

        count_if(completed_order_count >= 2)
            as repeat_purchaser_count,

        sum(total_order_count) as total_orders,

        sum(completed_order_count) as completed_orders,

        sum(lifetime_revenue) as total_revenue,

        avg(lifetime_revenue)
            as average_revenue_per_acquired_customer,

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
        coalesce(country, 'Unknown'),
        coalesce(state, 'Unknown')

),

benchmarks as (

    select
        sum(purchasing_customer_count)::float
        / nullif(sum(acquired_customer_count), 0)
            as overall_customer_conversion_rate,

        sum(repeat_purchaser_count)::float
        / nullif(sum(purchasing_customer_count), 0)
            as overall_repeat_purchaser_rate,

        avg(average_customer_return_rate)
            as overall_return_rate,

        sum(total_revenue) as overall_revenue

    from geographic_metrics

),

final as (

    select
        geographic_metrics.*,

        purchasing_customer_count::float
        / nullif(acquired_customer_count, 0)
            as customer_conversion_rate,

        repeat_purchaser_count::float
        / nullif(purchasing_customer_count, 0)
            as repeat_purchaser_rate,

        total_revenue
        / nullif(benchmarks.overall_revenue, 0)
            as revenue_share,

        dense_rank() over (
            order by total_revenue desc
        ) as global_revenue_rank,

        dense_rank() over (
            partition by country
            order by total_revenue desc
        ) as state_revenue_rank_within_country,

        case
            when average_customer_return_rate
                    > benchmarks.overall_return_rate
                then 'Investigate product fit or fulfillment quality'

            when purchasing_customer_count::float
                    / nullif(acquired_customer_count, 0)
                    < benchmarks.overall_customer_conversion_rate
                then 'Improve regional acquisition conversion'

            when repeat_purchaser_count::float
                    / nullif(purchasing_customer_count, 0)
                    < benchmarks.overall_repeat_purchaser_rate
                then 'Develop regional retention campaigns'

            when dense_rank() over (
                order by total_revenue desc
            ) <= 10
                then 'Protect and expand high-value market'

            else 'Monitor market performance'
        end as recommended_action

    from geographic_metrics
    cross join benchmarks

)

select *
from final