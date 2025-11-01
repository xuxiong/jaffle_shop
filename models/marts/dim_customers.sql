{{ config(materialized='table') }}

select distinct
  customer_id,
  customer_name,
  customer_email
from {{ ref('stg_customers') }}
