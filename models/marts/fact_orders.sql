-- 订单事实表
-- 业务逻辑：整合订单和支付信息，计算每个订单的实际支付金额
-- 数据关联：左连接支付汇总数据，未支付订单显示为0
-- 用途：作为下游指标计算的基础事实表
{{ config(materialized='table') }}

with payments as (
  select
    order_id,
    sum(payment_amount) as total_payment_amount
  from {{ ref('stg_payments') }}
  group by order_id
)

select
  o.order_id,
  o.customer_id,
  o.order_date,
  o.status as order_status,
  o.order_amount,
  coalesce(p.total_payment_amount, 0) as payment_amount
from {{ ref('stg_orders') }} as o
left join payments as p on o.order_id = p.order_id
