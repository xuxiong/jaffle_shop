{{ config(materialized='view') }}

select
  id as order_id,
  customer_id,
  cast(order_date as date) as order_date,
  status,
  cast(amount as numeric) as order_amount
from {{ source('jaffle_shop', 'orders') }}
