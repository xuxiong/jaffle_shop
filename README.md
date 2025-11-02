欢迎使用新的 dbt 项目！

📖 **详细教程**：如需完整的开发指南、最佳实践和分步骤教程，请查看 [`dbt_demo.md`](dbt_demo.md) 文件。

## 前置要求

在开始之前，请确保已安装以下工具：
- [uv](https://github.com/astral-sh/uv) - Python 包管理器
- [Docker](https://www.docker.com/) 和 Docker Compose - 用于运行 PostgreSQL 数据库

## 设置

1. **安装依赖：**
   ```bash
   uv sync
   ```

2. **启动 PostgreSQL 数据库：**
   ```bash
   docker compose up -d
   ```

3. **验证设置：**
   ```bash
   uv run dbt debug
   ```

## 使用方法

设置完成后，您可以使用以下命令：

- **运行模型：**
  ```bash
  uv run dbt run
  ```

- **运行测试：**
  ```bash
  uv run dbt test
  ```

- **生成文档：**
  ```bash
  uv run dbt docs generate
  uv run dbt docs serve
  ```

## 项目结构

- `models/` - dbt 模型
- `seeds/` - CSV 种子文件
- `tests/` - 自定义测试
- `macros/` - dbt 宏
- `analyses/` - SQL 分析

## 资源

- 在[文档](https://docs.getdbt.com/docs/introduction)中了解更多关于 dbt 的信息
- 在 [Discourse](https://discourse.getdbt.com/) 查看常见问题和解答
- 在 Slack [聊天室](https://community.getdbt.com/) 参与实时讨论和支持
- 查找您附近的 [dbt 活动](https://events.getdbt.com)
- 查看[博客](https://blog.getdbt.com/)了解 dbt 开发和最佳实践的最新资讯
