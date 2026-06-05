# Eoo

> **E**lixir port of R**oo** — 电子表格解析库 | 零外部依赖 | 纯 Erlang/OTP 内置

[![Hex.pm](https://img.shields.io/hexpm/v/eoo)](https://hex.pm/packages/eoo)
[![Elixir](https://img.shields.io/badge/elixir-~%3E%201.17-blue)](https://elixir-lang.org)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

Eoo 是 Ruby 生态中 [Roo](https://github.com/roo-rb/roo) gem 的 **Elixir 移植版**，支持读取所有常见电子表格格式。

**不需要安装任何外部 C 库或 NIF** — 全部基于 Erlang/OTP 内置模块实现（`:xmerl`、`:zip`、`:crypto`）。

---

## ✨ 特性一览

| 格式 | 解析 | 高级功能 |
|------|:----:|:--------:|
| **XLSX / XLSM** | cell / row / column / sheet | 公式 · 批注 · 标签 · 超链接 · 字体 · 合并单元格 · **流式读取** |
| **ODS** | cell / row / column / sheet | 公式 · 标签 · 字体 · **AES-256-CBC 加密解密** |
| **CSV** | cell / row / column / sheet | 自定义分隔符 · 引号字段 |

| 通用 API |  |
|---------|--|
| **工厂模式** | `Eoo.Spreadsheet.open/2` — 自动检测格式 |
| **导出** | CSV · YAML · Matrix |
| **info / each / parse** | 文档信息 · 迭代 · 结构化解析 |

## 📦 安装

```elixir
def deps do
  [
    {:eoo, "~> 0.1.0"}
  ]
end
```

**零外部依赖** — 不需要配置任何 NIF 或 C 库。

## 🔰 快速开始

### 1. 打开文件

```elixir
# 自动检测格式（推荐）
{:ok, ss} = Eoo.Spreadsheet.open("data.xlsx")
Eoo.Excelx.sheets(ss)  # => ["Sheet1", "Sheet2"]

# 或直接使用对应模块
{:ok, xlsx} = Eoo.Excelx.open("data.xlsx")
{:ok, ods}  = Eoo.OpenOffice.open("data.ods")
{:ok, csv}  = Eoo.CSV.open("data.csv")
```

### 2. 读取数据

```elixir
# --- 基本访问 ---
Eoo.Excelx.cell(xlsx, 1, 1)       # "Name"
Eoo.Excelx.cell(xlsx, 1, "A")     # 列字母也支持
Eoo.Excelx.celltype(xlsx, 1, 1)   # :string | :float | :date ...

Eoo.Excelx.row(xlsx, 1)           # ["Name", "Age", "City"]
Eoo.Excelx.column(xlsx, 1)        # ["Name", "Alice", "Bob"]
Eoo.Excelx.column(xlsx, "A")      # 列字母

# --- 数据范围 ---
Eoo.Excelx.first_row(xlsx)        # 1
Eoo.Excelx.last_row(xlsx)         # 42
Eoo.Excelx.first_column(xlsx)     # 1
Eoo.Excelx.last_column(xlsx)      # 10
```

### 3. 高级功能

```elixir
# 🔢 公式
Eoo.Excelx.formula(xlsx, 2, 3)    # "A2+B2"
Eoo.Excelx.formulas(xlsx)         # [[2, 3, "A2+B2"]]

# 💬 批注
Eoo.Excelx.comment(xlsx, 2, 2)    # "This is cell B2"

# 🏷️ 标签 / 命名区域
Eoo.Excelx.label(xlsx, "total")   # {10, 5, "Sheet1"}

# 🔗 超链接
Eoo.Excelx.hyperlink(xlsx, 1, 1)  %Eoo.Link{href: "#Sheet2!A1", text: "Link"}

# 🔤 字体
Eoo.Excelx.font(xlsx, 1, 1)       # %Eoo.Font{bold: true, italic: false, ...}

# 🔀 合并单元格
{:ok, xlsx} = Eoo.Excelx.open("data.xlsx", expand_merged_ranges: true)
```

### 4. 流式读取大文件（低内存）

```elixir
xlsx
|> Eoo.Excelx.each_row_streaming(
     max_rows: 1000,
     offset: 1,
     pad_cells: true
   )
|> Enum.each(fn row -> IO.inspect(row) end)
# => ["Alice", 42, "New York"]
```

### 5. 导出

```elixir
Eoo.Formatters.CSV.to_csv(xlsx)
Eoo.Formatters.YAML.to_yaml(xlsx)
Eoo.Formatters.Matrix.to_matrix(xlsx)
```

### 6. CSV 解析

```elixir
{:ok, csv} = Eoo.CSV.open("data.csv")
Eoo.CSV.row(csv, 1)

# 自定义分隔符（例如 TSV）
{:ok, tsv} = Eoo.CSV.open("data.tsv", csv_options: [separator: "\t"])
```

### 7. ODS 加密文档

```elixir
# 密码保护的 ODS 文件（LibreOffice 创建）
{:ok, ods} = Eoo.OpenOffice.open("secret.ods", password: "mypassword")
Eoo.OpenOffice.cell(ods, 1, 1)
```

## 📋 API 对照：Ruby Roo → Elixir Eoo

| Ruby | Elixir |
|------|--------|
| `Roo::Spreadsheet.open(path)` | `Eoo.Spreadsheet.open(path)` |
| `xlsx.sheets` | `Eoo.Excelx.sheets(xlsx)` |
| `xlsx.default_sheet` | `Eoo.Excelx.default_sheet(xlsx)` |
| `xlsx.default_sheet = "Sheet1"` | `Eoo.Excelx.default_sheet(xlsx, "Sheet1")` |
| `xlsx.cell(1, "A")` | `Eoo.Excelx.cell(xlsx, 1, "A")` |
| `xlsx.cell(1, 1)` | `Eoo.Excelx.cell(xlsx, 1, 1)` |
| `xlsx.row(1)` | `Eoo.Excelx.row(xlsx, 1)` |
| `xlsx.column(1)` | `Eoo.Excelx.column(xlsx, 1)` |
| `xlsx.first_row` | `Eoo.Excelx.first_row(xlsx)` |
| `xlsx.last_row` | `Eoo.Excelx.last_row(xlsx)` |
| `xlsx.first_column` | `Eoo.Excelx.first_column(xlsx)` |
| `xlsx.last_column` | `Eoo.Excelx.last_column(xlsx)` |
| `xlsx.column("A")` | `Eoo.Excelx.column(xlsx, "A")` |
| `xlsx.empty?(1, 1)` | `Eoo.Excelx.empty?(xlsx, 1, 1)` |
| `xlsx.celltype(1, 1)` | `Eoo.Excelx.celltype(xlsx, 1, 1)` |
| `xlsx.formula(1, 1)` | `Eoo.Excelx.formula(xlsx, 1, 1)` |
| `xlsx.formulas` | `Eoo.Excelx.formulas(xlsx)` |
| `xlsx.font(1, 1)` | `Eoo.Excelx.font(xlsx, 1, 1)` |
| `xlsx.comment(1, 1)` | `Eoo.Excelx.comment(xlsx, 1, 1)` |
| `xlsx.hyperlink(1, 1)` | `Eoo.Excelx.hyperlink(xlsx, 1, 1)` |
| `xlsx.label("name")` | `Eoo.Excelx.label(xlsx, "name")` |
| `xlsx.to_csv` | `Eoo.Formatters.CSV.to_csv(xlsx)` |
| `xlsx.each_row_streaming` | `Eoo.Excelx.each_row_streaming(xlsx)` |
| `xlsx.info` | `Eoo.Base.info(xlsx)` |
| `xlsx.each { \|row\| }` | `Eoo.Base.each(xlsx, [], fn row -> end)` |
| `xlsx.parse` | `Eoo.Base.parse(xlsx)` |
| `Roo::Excelx.new(path, options)` | `Eoo.Excelx.open(path, options)` |
| `Roo::OpenOffice.new(path, password:)` | `Eoo.OpenOffice.open(path, password: "pwd")` |

## ⚙️ 设计原则

- **🔋 零外部依赖** — 纯 Erlang/OTP 内置（`:xmerl` XML 解析、`:zip` 压缩、`:crypto` 加密）
- **🔄 API 兼容** — 与 Ruby Roo 保持一致的命名和语义，降低迁移成本
- **🚰 惰性求值** — `each_row_streaming` 支持大文件流式读取
- **🔒 不可变数据** — 所有操作返回新结构体

## 🛠 开发

```bash
# 安装依赖（跳过，零外部依赖）
mix deps.get

# 编译（零警告）
mix compile --warnings-as-errors

# 测试（36 用例）
mix test

# 构建 Hex 包
mix hex.build

# 交互式调试
iex -S mix
```

## 📄 许可证

MIT License — 与原始 Roo gem 相同。

## 🙏 致谢

- [Roo](https://github.com/roo-rb/roo) — Ruby 电子表格库，本项目的设计蓝本
- [Erlang/OTP](https://www.erlang.org) — :xmerl、:zip、:crypto 等内置模块
