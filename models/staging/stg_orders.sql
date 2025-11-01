-- 订单信息的staging表
-- 业务逻辑：从原始订单表中提取订单基础信息，进行数据类型转换
-- 数据质量：将订单日期转换为date类型，金额转换为numeric类型
{{ config(materialized='view') }}

select
  id as order_id,
  customer_id,
  cast(order_date as date) as order_date,
  status,
  cast(amount as numeric) as order_amount
from {{ source('jaffle_shop', 'orders') }}
