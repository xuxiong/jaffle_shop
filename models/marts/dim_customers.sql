-- 客户维度表
-- 业务逻辑：从客户staging表中提取去重后的客户基础信息
-- 数据质量：确保客户ID唯一，避免重复记录
-- 用途：作为客户分析的基础维度表，支持按客户维度聚合分析
{{ config(materialized='table') }}

select distinct
  customer_id,
  customer_name,
  customer_email
from {{ ref('stg_customers') }}
