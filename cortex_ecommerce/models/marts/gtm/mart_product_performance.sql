with order_items as (

    select *
    from {{ ref('stg_thelook__order_items') }}

),

products as (

    select *
    from {{ ref('stg_thelook__products') }}

),

product_metrics as (

    select
        order_items.product_id,

        count(*) as ordered_units,

        count(distinct order_items.order_id)
            as unique_orders,

        count(distinct order_items.user_id)
            as unique_customers,

        count_if(lower(order_items.order_item_status) = 'complete')
            as completed_units,

        count_if(lower(order_items.order_item_status) = 'returned')
            as returned_units,

        count_if(lower(order_items.order_item_status) = 'cancelled')
            as cancelled_units,

        sum(
            case
                when lower(order_items.order_item_status) = 'complete'
                    then order_items.sale_price
                else 0
            end
        ) as completed_revenue,

        sum(
            case
                when lower(order_items.order_item_status) = 'complete'
                    then products.product_cost
                else 0
            end
        ) as completed_product_cost,

        avg(
            case
                when lower(order_items.order_item_status) = 'complete'
                    then order_items.sale_price
            end
        ) as average_selling_price

    from order_items
    inner join products
        on order_items.product_id = products.product_id

    group by order_items.product_id

),

final as (

    select
        products.product_id,
        products.product_name,
        products.product_brand,
        products.product_category,
        products.product_department,
        products.retail_price,
        products.product_cost,

        product_metrics.ordered_units,
        product_metrics.unique_orders,
        product_metrics.unique_customers,
        product_metrics.completed_units,
        product_metrics.returned_units,
        product_metrics.cancelled_units,
        product_metrics.completed_revenue,
        product_metrics.completed_product_cost,
        product_metrics.average_selling_price,

        product_metrics.completed_revenue
            - product_metrics.completed_product_cost
                as estimated_gross_profit,

        (
            product_metrics.completed_revenue
            - product_metrics.completed_product_cost
        )
        / nullif(product_metrics.completed_revenue, 0)
            as estimated_gross_margin,

        product_metrics.returned_units::float
        / nullif(
            product_metrics.completed_units
            + product_metrics.returned_units,
            0
        ) as product_return_rate,

        product_metrics.cancelled_units::float
        / nullif(product_metrics.ordered_units, 0)
            as product_cancellation_rate,

        product_metrics.completed_revenue
        / nullif(product_metrics.completed_units, 0)
            as revenue_per_completed_unit,

        dense_rank() over (
            order by product_metrics.completed_revenue desc
        ) as revenue_rank,

        dense_rank() over (
            order by
                product_metrics.completed_revenue
                - product_metrics.completed_product_cost desc
        ) as gross_profit_rank

    from products
    inner join product_metrics
        on products.product_id = product_metrics.product_id

)

select *
from final