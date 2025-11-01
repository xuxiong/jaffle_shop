-- 客户信息的staging表
-- 业务逻辑：从原始客户表中提取基础信息，过滤掉无效邮箱记录
-- 数据质量：确保邮箱字段不为空
{{ config(materialized='view') }}

select
  id as customer_id,
  name as customer_name,
  email as customer_email
from {{ source('jaffle_shop', 'customers') }}
where email is not null
