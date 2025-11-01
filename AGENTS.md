# This file provides guidance to Code agents when working with code in this repository.

## Project Overview

This is a **Jaffle Shop** dbt project - a demo e-commerce data warehouse implementation. It follows dbt best practices with a layered architecture and demonstrates data transformation from CSV seeds to analytical models.

## Key Architecture

**Data Flow Architecture:**
- **Sources**: Raw CSV data loaded as seeds → PostgreSQL tables
- **Staging Layer** (`models/staging/`): Cleaned views that transform source data
- **Marts Layer** (`models/marts/`): Analytical tables for business intelligence

**Model Hierarchy:**
- `stg_customers`, `stg_orders`, `stg_payments` (staging views)
- `dim_customers`, `fact_orders` (marts tables)

## Development Commands

### Environment Setup
```bash
# Start PostgreSQL database
docker compose up -d

# Activate Python environment (if using uv)
source .venv/bin/activate
```

### Core dbt Operations
```bash
# Run all models
dbt run

# Run specific models
dbt run --select staging.*    # All staging models
dbt run --select marts.*     # All marts models
dbt run --select stg_customers  # Specific model

# Run tests
dbt test

# Run tests on specific models
dbt test --select stg_customers

# Generate documentation
dbt docs generate
dbt docs serve

# Compile SQL without executing
dbt compile

# Full build (run + test)
dbt build
```

### Seed Data Management
```bash
# Load CSV seed data into database
dbt seed

# Load specific seeds
dbt seed --select customers
```

### Project Health & Debugging
```bash
# Check project configuration and database connection
dbt debug

# List all available models
dbt ls

# Clean build artifacts
dbt clean
```

## Model Configuration

**Materialization Strategy:**
- **Staging models**: Configured as `view` in `dbt_project.yml:35-36`
- **Marts models**: Configured as `table` in `dbt_project.yml:37-38`

**Testing Strategy:**
- Tests defined in `models/schema.yml:12-20`
- Column-level tests (unique, not_null) applied to staging models

## Database Configuration

- **Database**: PostgreSQL (via Docker)
- **Connection**: Localhost:5432, database `jaffle_db`
- **Credentials**: Managed through `~/.dbt/profiles.yml`

## File Structure

```
models/
├── staging/          # Data cleaning layer (views)
│   ├── stg_customers.sql
│   ├── stg_orders.sql
│   └── stg_payments.sql
├── marts/            # Analytical layer (tables)
│   ├── dim_customers.sql
│   └── fact_orders.sql
└── schema.yml        # Sources, tests, and documentation
```

## Key Dependencies

- Models reference each other using `{{ ref('model_name') }}`
- Staging models reference sources using `{{ source('jaffle_shop', 'table_name') }}`
- Dependencies are automatically resolved by dbt

## Development Workflow

1. **Start Database**: `docker compose up -d`
2. **Load Seeds**: `dbt seed` (if source data changed)
3. **Develop Models**: Edit SQL files in appropriate layer
4. **Test Changes**: `dbt run --select <model>` followed by `dbt test`
5. **Generate Docs**: `dbt docs generate` to update documentation
6. **Full Deployment**: `dbt build` for complete pipeline