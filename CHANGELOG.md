# Changelog

## Unreleased

### 修复

- **XML 解析** — 修复 `:xmerl_scan` 无法处理中文等非 Latin-1 字符的问题，在解析前自动将非 ASCII 字符转义为 XML 数值实体

### 测试

- 新增 `store.xlsx` 读取测试，验证中文工作表名称的正确解析

## 0.1.0 (2026-06-04)

Eoo 初始发布 — Ruby Roo gem 的 Elixir 移植版。

### 支持的格式

- **CSV** — 完整解析，含自定义分隔符和引号字段处理
- **XLSX / XLSM** — 完整解析，含公式、批注、标签、超链接、样式、合并单元格、流式行读取
- **ODS** — 完整解析，含公式、标签、字体、**AES-256-CBC + PBKDF2 加密解密**

### 通用 API

- `Eoo.Spreadsheet.open/2` — 工厂模式自动检测格式（.xlsx / .xlsm / .ods / .csv）
- `Eoo.Base.info/1` — 文档信息
- `Eoo.Base.each/3` — 行迭代（支持表头映射）
- `Eoo.Base.parse/2` — 结构化解析（支持 header_search）
- `Eoo.Formatters.CSV.to_csv/3` — CSV 格式导出
- `Eoo.Formatters.YAML.to_yaml/2` — YAML 格式导出（支持 prefix）
- `Eoo.Formatters.Matrix.to_matrix/2` — Matrix（二维列表）导出

### 流式读取

- `Eoo.Excelx.each_row_streaming/2` — 流式行读取
  - 支持 `:offset` 跳过行数
  - 支持 `:max_rows` 限制行数
  - 支持 `:pad_cells` 填充空白单元格

### ODS 加密

- AES-256-CBC 算法
- PBKDF2 密钥派生（HMAC-SHA1）
- SHA256 密码哈希
- 兼容 LibreOffice 创建的加密 ODS 文件

### 技术特性

- **零外部依赖** — 纯 Erlang/OTP 内置实现（`:xmerl`、`:zip`、`:crypto`）
- OTP 28 兼容（xmerl 12 元组格式、zip API 变更）
- 36 测试用例，零编译警告
