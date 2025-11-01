### dbt 项目完整 Demo：Jaffle Shop 数据建模与最佳实践

一个完整的、基于 dbt 最佳实践的 demo 项目：**Jaffle Shop**（dbt 官方样例项目）。这是一个模拟咖啡店的数据仓库项目，包括客户（customers）、订单（orders）和支付（payments）的数据转换。项目遵循**分层架构**（sources → staging → marts）、**测试驱动开发**、**YAML 配置**和**文档自动化**等最佳实践。

#### 项目概述
- **目标**：从 CSV 种子数据（seeds）加载原始数据，通过 SQL + Jinja 模型转换为分析友好的事实/维度表。
- **数据仓库**：PostgreSQL，使用 Docker 容器运行（易于本地复现）。
- **dbt 版本**：dbt Core 1.10+，适配器 dbt-postgres。
- **环境**：本地开发，支持 Git 版本控制。
- **时长估算**：1-2 小时完成。
- **最佳实践融入**：
  - **分层建模**：清晰的 `staging` 层和 `marts` 层。
  - **增量模型**：高效更新指标数据，而非全量刷新。
  - **自定义测试**：创建自己的通用测试，减少外部依赖。
  - **单元测试**：保证复杂业务逻辑（如指标计算）的准确性。
  - **自动化**：CI/CD 提示（可选 GitHub Actions）。
  - **安全**：`profiles.yml` 避免硬编码凭证。

#### 先决条件
- **系统**：macOS/Linux/Windows（WSL），Docker Desktop 已安装。
- **Python**：3.10+。
- **包管理**：uv（推荐安装：`brew install uv`）。
- **工具**：VS Code + dbt Power User 插件（可选，但推荐）。

---

### 分步骤开发指南

流程分为 8 个步骤，每个步骤包括**命令**、**代码示例**和**验证**。逐步执行，确保每个步骤成功后再继续。

#### 步骤 1: 设置 Docker 中的 PostgreSQL
使用 Docker Compose 启动 Postgres 容器，作为数据仓库。

1. 创建 `docker-compose.yml`：
   ```yaml
   version: '3.9'
   services:
     postgres:
       container_name: jaffle_postgres
       image: postgres:16-alpine
       environment:
         POSTGRES_DB: jaffle_db
         POSTGRES_USER: jaffle_user
         POSTGRES_PASSWORD: jaffle_pass
       ports:
         - "5432:5432"
       volumes:
         - postgres_data:/var/lib/postgresql/data
       healthcheck:
         test: ["CMD-SHELL", "pg_isready -U jaffle_user -d jaffle_db"]
         interval: 5s
         timeout: 5s
         retries: 5
   volumes:
     postgres_data:
   ```

2. 启动容器：
   `docker compose up -d`

3. 验证：
   `docker exec -it -e PGPASSWORD=jaffle_pass jaffle_postgres psql -U jaffle_user -d jaffle_db -c "SELECT 1;"`

#### 步骤 2: 使用 uv 管理 Python 环境并安装 dbt
借助 uv 创建隔离的虚拟环境并安装 dbt-postgres 适配器。

1. 准备虚拟环境：
   `uv venv .venv --python 3.12`

2. 激活虚拟环境：
   `source .venv/bin/activate`

3. 安装 dbt：
   `uv pip install "dbt-core~=1.10.0" "dbt-postgres~=1.10.0"`

4. 验证安装：
   `dbt --version`

> **提示**：后续 `dbt` 命令均假定已激活 `.venv`。若未激活，可在命令前加 `uv run`。

#### 步骤 3: 初始化 dbt 项目
使用 `dbt init` 创建项目骨架。

1. 初始化：
   ```bash
   dbt init jaffle_shop --skip-profile-setup
   ```

2. 更新 `dbt_project.yml`（添加层级配置）：
   ```yaml
   name: 'jaffle_shop'
   version: '1.0.0'
   profile: 'jaffle_shop'

   model-paths: ["models"]
   analysis-paths: ["analyses"]
   test-paths: ["tests"]
   seed-paths: ["seeds"]
   macro-paths: ["macros"]
   snapshot-paths: ["snapshots"]

   target-path: "target"
   clean-targets: ["target", "dbt_modules"]

   models:
     jaffle_shop:
       staging:
         +materialized: view
       marts:
         +materialized: table
   ```

#### 步骤 4: 配置 profiles.yml
1. 编辑 `~/.dbt/profiles.yml`：
   ```yaml
   jaffle_shop:
     target: dev
     outputs:
       dev:
         type: postgres
         host: localhost
         user: jaffle_user
         password: jaffle_pass
         port: 5432
         dbname: jaffle_db
         schema: public
         threads: 4
   ```

2. 验证连接：
   `dbt debug`

#### 步骤 5: 准备种子数据 (Seeds)
1. 在 `seeds/` 目录创建 `customers.csv`, `orders.csv`, `payments.csv`。
   这些文件包含完整的种子数据，用于初始化数据库表。
2. 运行 seeds:
   `dbt seed`

#### 步骤 6: 开发模型（Staging 和 Marts 层）
1. **Staging 层**：创建 `models/staging/stg_customers.sql` 等文件，进行基础清洗和重命名。
   ```sql
   -- models/staging/stg_customers.sql
   {{ config(materialized='view') }}

   select
     id as customer_id,
     name as customer_name,
     email as customer_email
   from {{ source('jaffle_shop', 'customers') }}
   where email is not null
   ```

2. **Marts 层**：创建 `models/marts/dim_customers.sql` 和 `fact_orders.sql`，构建分析模型。
   ```sql
   -- models/marts/fact_orders.sql
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
   ```

3. **定义 sources**：在 `models/schema.yml` 添加：
   ```yaml
   version: 2
   sources:
     - name: jaffle_shop
       schema: public
       tables:
         - name: customers
         - name: orders
         - name: payments
   ```



#### 步骤 7: 构建统计指标层 (Metrics Layer)
> **最佳实践**: 将指标模型设置为 **增量 (incremental)**，以便在生产环境中高效更新，避免全量刷新。

1. 在 `models/marts/` 创建 `fact_orders_metrics.sql`:
   ```sql
   {{ config(materialized='incremental', unique_key='order_date') }}

   with base_orders as (
       select
           order_date::date as order_date,
           id as order_id,
           customer_id,
           status as order_status,
           case when status = 'completed' then 1 else 0 end as is_completed,
           amount as order_amount
       from {{ ref('fact_orders') }}
   ),
   ranked_orders as (
       select
           order_date,
           customer_id,
           row_number() over (partition by customer_id order by order_date) as order_number
       from base_orders
   ),
   daily_rollup as (
       select
           order_date,
           count(*) as orders_count,
           sum(order_amount) as gross_revenue,
           avg(order_amount) as avg_order_value,
           sum(is_completed)::numeric / nullif(count(*), 0) as completion_rate
       from base_orders
       group by 1
   ),
   customer_rollup as (
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
       round(d.completion_rate, 1) as completion_rate,
       cast(round(avg(d.gross_revenue) over (order by d.order_date rows between 6 preceding and current row), 2) as decimal(10,2)) as revenue_rolling_7d,
       c.active_customers,
       c.repeat_customers,
       cast(round(c.repeat_customers::numeric / nullif(c.active_customers, 0), 4) as decimal(10,4)) as repeat_purchase_rate
   from daily_rollup d
   left join customer_rollup c using (order_date)
   order by d.order_date

   {% if is_incremental() %}
   -- this filter will only be applied on an incremental run
   where order_date > (select max(order_date) from {{ this }})
   {% endif %}
   ```

#### 步骤 8: 扩展测试覆盖（Schema + Unit）与文档
1. **创建自定义通用测试 (Generic Tests)**
   `accepted_range` 测试并非 dbt 内置。作为最佳实践，我们创建自己的通用测试。在 `tests/generic/` 目录下创建：
   - `tests/generic/test_positive_value.sql`:
     ```sql
     {% test positive_value(model, column_name) %}
     select * from {{ model }} where {{ column_name }} < 0
     {% endtest %}
     ```
   - `tests/generic/test_is_between_0_and_1.sql`:
     ```sql
     {% test is_between_0_and_1(model, column_name) %}
     select * from {{ model }} where not ({{ column_name }} >= 0 and {{ column_name }} <= 1)
     {% endtest %}
     ```

2. **更新 `models/marts/schema.yml`** (如果不存在则创建)，使用新的通用测试：
   ```yaml
   version: 2
   models:
     - name: fact_orders_metrics
       columns:
         - name: order_date
           tests: [unique, not_null]
         - name: gross_revenue
           tests: [not_null, {name: positive_value}]
         - name: repeat_purchase_rate
           tests: [{name: is_between_0_and_1}]
   ```

3. **编写单元测试**
   > **核心学习点**: 测试增量模型时，需在 `given` 块中用 `this` 关键字引用模型自身来模拟历史数据。

   在 `tests/unit/` 下创建 `test_fact_orders.yml`:
   ```yaml
   version: 2
   unit_tests:
     - name: fact_orders_payment_amount_matches
       model: fact_orders
       given:
         - input: ref('stg_orders')
           format: sql
           rows: |
             select *
             from (values
               (1, 1, cast('2024-01-01' as date), 'completed', cast(30 as numeric)),
               (2, 2, cast('2024-01-02' as date), 'completed', cast(50 as numeric))
             ) as stg_orders_fixture(order_id, customer_id, order_date, status, order_amount)
         - input: ref('stg_payments')
           format: sql
           rows: |
             select *
             from (values
               (101, 1, 'credit_card', cast(30 as numeric)),
               (102, 2, 'bank_transfer', cast(50 as numeric))
             ) as stg_payments_fixture(payment_id, order_id, payment_method, payment_amount)
       expect:
         rows:
           - {order_id: 1, payment_amount: 30}
           - {order_id: 2, payment_amount: 50}

     - name: fact_orders_metrics_rollup
       model: fact_orders_metrics
       given:
         - input: ref('fact_orders')
           rows:
             - {order_id: 10, customer_id: 1, order_date: '2024-03-01', order_status: 'completed', order_amount: 40, payment_amount: 40}
             - {order_id: 11, customer_id: 1, order_date: '2024-03-10', order_status: 'completed', order_amount: 60, payment_amount: 60}
             - {order_id: 12, customer_id: 2, order_date: '2024-03-10', order_status: 'cancelled', order_amount: 20, payment_amount: 0}
         - input: this
           rows: []
       expect:
         rows:
           - {order_date: '2024-03-01', orders_count: 1, gross_revenue: 40, avg_order_value: 40.0, revenue_rolling_7d: 40.00, completion_rate: 1.0, active_customers: 1, repeat_customers: 0, repeat_purchase_rate: 0.0000}
           - {order_date: '2024-03-10', orders_count: 2, gross_revenue: 80, avg_order_value: 40.0, revenue_rolling_7d: 60.00, completion_rate: 0.5, active_customers: 2, repeat_customers: 1, repeat_purchase_rate: 0.5000}
   ```
   > **注意：数据类型问题**
   > 上述 `expect` 块很可能会因为数据类型不匹配失败（例如 `1.0` vs `1.000000`）。这是 dbt 单元测试的常见挑战，解决它需要精确匹配数据库返回的数字精度。为演示，我们在此保留该问题。

#### 步骤 9.5: 调试浮点精度问题（实际案例）
> **核心学习点**: dbt 单元测试进行精确字符串匹配，浮点数计算可能导致精度差异。解决方案是使用显式 `CAST` 到特定精度的十进制类型。

**问题现象**：
```
actual differs from expected:
@@,order_date,orders_count,...,avg_order_value,revenue_rolling_7d,completion_rate,...,repeat_customers,repeat_purchase_rate
→ ,2024-03-01,1           ,...,40.0           ,40.0→40.00        ,1.0            ,...,0               ,0.0→0.0000
→ ,2024-03-10,2           ,...,40.0           ,60.0→60.00        ,0.5            ,...,1               ,0.5→0.5000
```

**根本原因**：
- dbt 单元测试进行精确字符串比较
- PostgreSQL 的 `ROUND()` 返回 `numeric` 类型，但不保证输出精度格式
- 浮点计算（如除法、平均值）可能产生微小精度差异

**解决方案**：
在 `fact_orders_metrics.sql` 中对关键字段使用显式 `CAST`：
```sql
-- 修复前
round(avg(d.gross_revenue) over (order by d.order_date rows between 6 preceding and current row), 2) as revenue_rolling_7d,
round(c.repeat_customers::numeric / nullif(c.active_customers, 0), 4) as repeat_purchase_rate

-- 修复后
cast(round(avg(d.gross_revenue) over (order by d.order_date rows between 6 preceding and current row), 2) as decimal(10,2)) as revenue_rolling_7d,
cast(round(c.repeat_customers::numeric / nullif(c.active_customers, 0), 4) as decimal(10,4)) as repeat_purchase_rate
```

**验证修复**：
```bash
uv run dbt test --select fact_orders_metrics_rollup
# 期望输出: PASS
```

**关键洞察**：
1. **理解 dbt 测试机制**：单元测试进行字符串精确匹配，而非数值近似比较
2. **优先使用数据库原生类型**：`decimal(10,2)` 确保输出格式与期望完全一致
3. **增量调试**：每次只修改一个字段，立即测试，避免多重问题混淆

#### 步骤 9: 运行项目和模拟部署
> **核心学习点**: `dbt build` 是标准命令，但如果遇到涉及新模型的复杂依赖错误，`dbt run` -> `dbt test` 的两步法是更可靠的调试策略。

1. **运行与测试**：
   ```bash
   # 方法一：标准构建（可能会因我们已知的数据类型问题而失败）
   dbt build

   # 方法二：分步执行（更适合调试）
   dbt run  # 确保所有模型都已创建
   dbt test # 单独运行测试
   ```
   你将看到除了 `fact_orders_metrics_rollup` 之外的所有测试都通过了。

2. **生成和查看文档**：
   `dbt docs generate && dbt docs serve`

3. **清理**：
   `dbt clean && docker compose down -v`
