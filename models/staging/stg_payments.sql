-- 支付信息的staging表
-- 业务逻辑：从原始支付表中提取支付基础信息，进行数据类型转换
-- 数据质量：将支付金额转换为numeric类型以确保数值计算精度
{{ config(materialized='view') }}

select
  id as payment_id,
  order_id,
  payment_method,
  cast(amount as numeric) as payment_amount
from {{ source('jaffle_shop', 'payments') }}
