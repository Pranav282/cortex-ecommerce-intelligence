with completed_orders as (

    select
        user_id,
        order_id,
        order_created_at,
        order_revenue
    from {{ ref('int_customer_orders') }}
    where lower(order_status) = 'complete'

),

analysis_date as (

    select
        dateadd('day', 1, max(order_created_at)::date) as analysis_date
    from completed_orders

),

customer_metrics as (

    select
        completed_orders.user_id,
        analysis_date.analysis_date,

        datediff(
            'day',
            max(completed_orders.order_created_at)::date,
            analysis_date.analysis_date
        ) as recency_days,

        count(distinct completed_orders.order_id) as frequency,

        sum(completed_orders.order_revenue) as monetary_value,

        avg(completed_orders.order_revenue) as average_order_value,

        min(completed_orders.order_created_at) as first_completed_order_at,
        max(completed_orders.order_created_at) as last_completed_order_at

    from completed_orders
    cross join analysis_date
    group by
        completed_orders.user_id,
        analysis_date.analysis_date

),

rfm_scores as (

    select
        *,

        ntile(5) over (
            order by recency_days desc
        ) as recency_score,

        ntile(5) over (
            order by frequency asc
        ) as frequency_score,

        ntile(5) over (
            order by monetary_value asc
        ) as monetary_score

    from customer_metrics

),

final as (

    select
        user_id,
        analysis_date,
        recency_days,
        frequency,
        monetary_value,
        average_order_value,
        first_completed_order_at,
        last_completed_order_at,
        recency_score,
        frequency_score,
        monetary_score,

        concat(
            recency_score,
            frequency_score,
            monetary_score
        ) as rfm_score,

        case
            when recency_score >= 4
                and frequency_score >= 4
                and monetary_score >= 4
                then 'Champions'

            when recency_score >= 3
                and frequency_score >= 3
                then 'Loyal Customers'

            when recency_score >= 4
                and frequency_score <= 2
                then 'New or Promising'

            when recency_score <= 2
                and frequency_score >= 3
                then 'At Risk'

            when recency_score <= 2
                and frequency_score <= 2
                then 'Hibernating'

            else 'Needs Attention'
        end as customer_segment

    from rfm_scores

)

select *
from final