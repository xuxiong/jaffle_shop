### dbt 项目完整 Demo：Jaffle Shop 咖啡店数据建模

一个完整的、基于 dbt 最佳实践的 demo 项目：**Jaffle Shop**（dbt 官方样例项目）。这是一个模拟咖啡店的数据仓库项目，包括客户（customers）、订单（orders）和支付（payments）的数据转换。项目遵循**分层架构**（sources → staging → marts）、**测试驱动开发**、**YAML 配置**和**文档自动化**等最佳实践。

#### 项目概述
- **目标**：从 CSV 种子数据（seeds）加载原始数据，通过 SQL + Jinja 模型转换为分析友好的事实/维度表。
- **数据仓库**：PostgreSQL，使用 Docker 容器运行（易于本地复现）。
- **dbt 版本**：假设 dbt Core 1.10+（2025 年标准），适配器 dbt-postgres。
- **环境**：本地开发，支持 Git 版本控制。
- **时长估算**：1-2 小时完成。
- **最佳实践融入**：
  - 模块化：使用 macros 和 packages。
  - 质量：内置测试（unique, not_null）和 freshness。
  - 自动化：CI/CD 提示（可选 GitHub Actions）。
  - 安全：profiles.yml 避免硬编码凭证。

#### 先决条件
- **系统**：macOS/Linux/Windows（WSL），Docker Desktop 已安装（测试：`docker --version`）。
- **Python**：3.10+（uv 可自动下载兼容版本，无需全局安装额外依赖）。
- **包管理**：uv（建议通过 Homebrew 安装：`brew install uv`，验证：`uv --version`）。
- **工具**：VS Code + dbt Power User 插件（可选，但推荐）。
- **文件夹**：创建项目根目录 `~/jaffle_shop_dbt`。

---

### 分步骤开发指南

流程分为 8 个步骤，每个步骤包括**命令**、**代码示例**和**验证**。逐步执行，确保每个步骤成功后再继续。

#### 步骤 1: 设置 Docker 中的 PostgreSQL
使用 Docker Compose 启动 Postgres 容器，作为数据仓库。最佳实践：使用健康检查和卷挂载。

1. 在项目根目录 `~/jaffle_shop_dbt` 创建 `docker-compose.yml`：
   ```yaml
   version: '3.9'
   services:
     postgres:
       container_name: jaffle_postgres
       image: postgres:16-alpine  # 2025 推荐轻量版（本地已验证）
       environment:
         POSTGRES_DB: jaffle_db
         POSTGRES_USER: jaffle_user
         POSTGRES_PASSWORD: jaffle_pass
       ports:
         - "5432:5432"
       volumes:
         - postgres_data:/var/lib/postgresql/data  # 持久化数据
       healthcheck:
         test: ["CMD-SHELL", "pg_isready -U jaffle_user -d jaffle_db"]
         interval: 5s
         timeout: 5s
         retries: 5
   volumes:
     postgres_data:
   ```

2. 启动容器：
   ```bash
   docker compose up -d
   ```

3. 验证：
   - `docker images postgres`
   - `docker ps`
   - `docker exec -e PGPASSWORD=jaffle_pass jaffle_postgres psql -U jaffle_user -d jaffle_db -c "SELECT 1;"`

#### 步骤 2: 使用 uv 管理 Python 环境并安装 dbt
借助 uv 创建隔离的虚拟环境并安装 dbt-postgres 适配器，避免污染全局 Python。

1. 在项目根目录准备虚拟环境（首次执行会自动下载所需 Python 版本）：
   ```bash
   cd ~/jaffle_shop_dbt
   uv python pin 3.13.7  # 与本地环境一致并经验证可用于 dbt-core 1.10
   uv venv .venv
   ```

2. 激活虚拟环境（macOS/Linux）：
   ```bash
   source .venv/bin/activate
   ```
   Windows PowerShell：`.\.venv\Scripts\Activate.ps1`

3. 安装 dbt：
   ```bash
   UV_HTTP_TIMEOUT=180 uv pip install "dbt-core==1.10.*" "dbt-postgres==1.10.*"
   ```

4. 验证安装：
   ```bash
   uv run --python 3.13.7 dbt --version
   uv run --python 3.13.7 python --version
   ```

   同步确认 Python 版本：`uv python list --installed` 应显示 `cpython-3.13.7`。

   若之前已固定到其他版本，可重新执行 `uv python pin 3.13.7`；此后 `uv run python` 默认输出应为 3.13.7。

> 提示：后续涉及 `dbt` 的命令均假定已激活 `.venv`，若未激活可在命令前加 `uv run`。

#### 步骤 3: 初始化 dbt 项目
使用 dbt init 创建项目骨架。最佳实践：选择 Postgres 适配器，配置层级结构。

1. 初始化：
   ```bash
   cd ~/jaffle_shop_dbt
   uv run --python 3.13.7 dbt init jaffle_shop --skip-profile-setup
   cd jaffle_shop
   ```
   - 项目名：jaffle_shop
   - 选择：postgres
   - 连接详情：host=localhost, port=5432, user=jaffle_user, pass=jaffle_pass, dbname=jaffle_db, schema=public

2. 更新 `dbt_project.yml`（添加层级配置并设置 `target-path`）：
   ```yaml
   name: 'jaffle_shop'
   version: '1.0.0'
   config-version: 2
   profile: 'jaffle_shop'

   model-paths: ["models"]
   analysis-paths: ["analyses"]
   test-paths: ["tests"]
   seed-paths: ["seeds"]
   macro-paths: ["macros"]
   snapshot-paths: ["snapshots"]

   target-path: "target"
   clean-targets:
     - "target"
     - "dbt_modules"

   models:
     jaffle_shop:
       staging:
         +materialized: view  # staging 层用 view 节省存储
       marts:
         +materialized: table  # marts 层用 table 支持 BI 查询
   ```

3. 验证：
   ```bash
   uv run --python 3.13.7 dbt ls
   ```

#### 步骤 4: 配置 profiles.yml
确保连接配置正确。最佳实践：使用环境变量或 secrets 管理密码（demo 用明文）。

1. 编辑 `~/.dbt/profiles.yml`（如果 init 未创建）：
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
         threads: 4  # 并行线程，根据 CPU 调整
         keepalives_idle: 0  # 默认，防连接超时
         connect_timeout: 10
         retries: 1
   ```

2. 验证连接：
   ```bash
   uv run --python 3.13.7 dbt debug
   ```

#### 步骤 5: 准备种子数据（Seeds）
加载 CSV 原始数据到 Postgres。最佳实践：seeds 用于静态参考数据。

1. 下载官方 Jaffle Shop seeds（或手动创建）：
   - 在 `seeds/` 目录创建：
     - `customers.csv`：id,name,email
     - `orders.csv`：id,customer_id,order_date,status,amount
     - `payments.csv`：id,order_id,payment_method,amount

   示例 `seeds/customers.csv`：
   ```csv
   id,name,email
   1,Alice,alice@email.com
   2,Bob,bob@email.com
   ```

2. 运行 seeds：
   ```bash
   uv run --python 3.13.7 dbt seed
   ```

3. 验证：
   ```bash
   docker exec -e PGPASSWORD=jaffle_pass \
     jaffle_postgres psql -U jaffle_user -d jaffle_db -c "SELECT * FROM customers LIMIT 2;"
   ```

#### 步骤 6: 开发模型（Staging 和 Marts 层）
构建分层模型。最佳实践：使用 ref() 依赖，Jinja 模板。

1. **Staging 层**：创建 `models/staging/stg_customers.sql`（清洗数据）：
   ```sql
   {{ config(materialized='view') }}

   SELECT
     id AS customer_id,
     name AS customer_name,
     email AS customer_email
   FROM {{ source('jaffle_shop', 'customers') }}
   WHERE email IS NOT NULL
   ```

   类似创建 `stg_orders.sql` 和 `stg_payments.sql`。

2. **Marts 层**：创建 `models/marts/dim_customers.sql`（维度表）：
   ```sql
   {{ config(materialized='table') }}

   SELECT
     customer_id,
     customer_name,
     customer_email
   FROM {{ ref('stg_customers') }}
   ```

   创建 `fact_orders.sql`（事实表，聚合订单）：
   ```sql
   {{ config(materialized='table') }}

   SELECT
     o.order_id,
     o.customer_id,
     o.order_date,
     o.status AS order_status,
     o.order_amount,
     COALESCE(p.total_payment_amount, 0) AS payment_amount
   FROM {{ ref('stg_orders') }} o
   LEFT JOIN (
     SELECT order_id, SUM(payment_amount) AS total_payment_amount
     FROM {{ ref('stg_payments') }}
     GROUP BY order_id
   ) p ON o.order_id = p.order_id
   ```

3. 定义 sources：在 `models/schema.yml` 添加：
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

4. 删除默认示例：`rm -rf models/example`

5. 验证：
   ```bash
   uv run --python 3.13.7 dbt compile
   ```

#### 步骤 7: 添加测试和文档
质量保障。最佳实践：列级测试覆盖 80%+，自动生成 docs。

1. 更新 `models/schema.yml`（添加测试）：
   ```yaml
   models:
     - name: stg_customers
       columns:
         - name: customer_id
           tests:
             - unique
             - not_null
         - name: customer_email
           tests:
             - not_null
   ```

2. 运行模型以确保被测视图存在，再执行测试：
   ```bash
   uv run --python 3.13.7 dbt run --select stg_customers stg_orders stg_payments
   uv run --python 3.13.7 dbt test
   ```

3. 生成文档：
   ```bash
   uv run --python 3.13.7 dbt docs generate
   uv run --python 3.13.7 python -c "import subprocess, time; p = subprocess.Popen(['dbt', 'docs', 'serve', '--no-browser', '--port', '8080']); time.sleep(5); p.terminate(); p.wait()"
   ```

#### 步骤 8: 运行项目和模拟部署
执行完整管道。最佳实践：使用 incremental 模型优化（高级，可选）。

1. 运行与构建：
   ```bash
   uv run --python 3.13.7 dbt run
   uv run --python 3.13.7 dbt build
   ```

2. 验证输出：
   ```bash
   docker exec -e PGPASSWORD=jaffle_pass \
     jaffle_postgres psql -U jaffle_user -d jaffle_db -c "SELECT * FROM dim_customers ORDER BY customer_id;"
   ```

3. 模拟部署：
   - 添加 Git：`git init; git add .; git commit -m "Initial commit"`
   - CI/CD 示例（GitHub Actions）：创建 `.github/workflows/dbt.yml`：
     ```yaml
     name: dbt CI
     on: [push]
     jobs:
       test:
         runs-on: ubuntu-latest
         steps:
           - uses: actions/checkout@v4
           - name: Run dbt
             run: |
               pip install dbt-postgres
               dbt debug
               dbt test
     ```

4. 清理：
   ```bash
   uv run --python 3.13.7 dbt clean
   docker compose down -v
   ```

---

#### 常见问题与扩展
- **错误排查**：连接失败？检查 `dbt debug` 和 Docker 日志（`docker logs jaffle_postgres`）。
- **扩展**：添加 macros（如日期 spine）、snapshots（变更捕获）、packages.yml（dbt-utils）。
- **生产化**：用 dbt Cloud 调度；集成 Airflow 加载数据（见 web:1）。
- **资源**：官方 Jaffle Shop GitHub（搜索 "dbt jaffle shop"）；2025 更新：dbt 1.10 支持更好 Postgres SSL。

