{{ config(materialized='view') }}

select
  id as payment_id,
  order_id,
  payment_method,
  cast(amount as numeric) as payment_amount
from {{ source('jaffle_shop', 'payments') }}
