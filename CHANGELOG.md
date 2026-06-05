# Changelog

## 0.1.0 (2026-06-04)

Eoo 初始发布 — Ruby Roo gem 的 Elixir 移植版。

### 支持的格式

- **CSV** — 完整解析，含自定义分隔符和引号处理
- **XLSX** — 完整解析，含公式、批注、标签、超链接、样式、合并单元格、流式读取
- **ODS** — 完整解析（不含加密解密）

### API

- `Eoo.Spreadsheet.open/2` — 工厂模式自动检测格式
- `Eoo.CSV.open/2` — CSV 解析器
- `Eoo.Excelx.open/2` — XLSX 解析器
- `Eoo.OpenOffice.open/2` — ODS 解析器
- `Eoo.Base` 行为 — 统一的 cell/row/column/first_row/last_row 等接口
- `Eoo.Excelx.each_row_streaming/2` — 流式行读取（offset/max_rows/pad_cells）
- `Eoo.Formatters.CSV.to_csv/3` — CSV 导出
- `Eoo.Formatters.YAML.to_yaml/2` — YAML 导出
- `Eoo.Formatters.Matrix.to_matrix/2` — Matrix 导出

### 技术特性

- 零外部依赖，纯 Erlang/OTP 内置实现
- OTP 28 兼容（xmerl 12 元组格式、zip API 变更）
- 33 测试用例，零编译警告
