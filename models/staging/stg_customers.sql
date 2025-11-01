{{ config(materialized='view') }}

select
  id as customer_id,
  name as customer_name,
  email as customer_email
from {{ source('jaffle_shop', 'customers') }}
where email is not null
