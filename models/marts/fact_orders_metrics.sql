{{ config(materialized='incremental', unique_key='order_date') }}

with base_orders as (
    select
        order_date::date as order_date,
        customer_id,
        order_amount,
        order_status,
        case when order_status = 'completed' then 1 else 0 end as is_completed
    from {{ ref('fact_orders') }}
), ranked_orders as (
    select
        order_date,
        customer_id,
        order_amount,
        is_completed,
        row_number() over (partition by customer_id order by order_date) as order_number
    from base_orders
), daily_rollup as (
    select
        order_date,
        count(*) as orders_count,
        sum(order_amount) as gross_revenue,
        avg(order_amount) as avg_order_value,
        sum(is_completed)::numeric / nullif(count(*), 0) as completion_rate
    from base_orders
    group by 1
), customer_rollup as (
    select
        order_date,
        count(distinct customer_id) as active_customers,
        count(distinct case when order_number > 1 then customer_id end) as repeat_customers
    from ranked_orders
    group by 1
)
select
    d.order_date,
    d.orders_count,
    d.gross_revenue,
    round(d.avg_order_value, 1) as avg_order_value,
    cast(round(avg(d.gross_revenue) over (order by d.order_date rows between 6 preceding and current row), 2) as decimal(10,2)) as revenue_rolling_7d,
    round(d.completion_rate, 1) as completion_rate,
    c.active_customers,
    c.repeat_customers,
    cast(round(c.repeat_customers::numeric / nullif(c.active_customers, 0), 4) as decimal(10,4)) as repeat_purchase_rate
from daily_rollup d
left join customer_rollup c using (order_date)
order by d.order_date
