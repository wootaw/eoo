# Eoo

> **E**lixir port of R**oo** — 电子表格解析库

[![Hex.pm](https://img.shields.io/hexpm/v/eoo)](https://hex.pm/packages/eoo)
[![Build Status](https://github.com/roo-rb/eoo/workflows/CI/badge.svg)](https://github.com/roo-rb/eoo)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

Eoo 是 Ruby 生态中 [Roo](https://github.com/roo-rb/roo) gem 的 **Elixir 移植版**，支持读取所有常见电子表格格式。

**零外部依赖** — 纯 Erlang/OTP 内置实现（`:xmerl`、`:zip`、`:crypto`）。

## 支持的格式

| 格式 | 扩展名 | 模块 | 状态 |
|------|--------|------|:----:|
| Excel 2007+ | .xlsx, .xlsm | `Eoo.Excelx` | ✅ 完整 |
| LibreOffice / OpenOffice | .ods | `Eoo.OpenOffice` | ✅ 完整 |
| CSV | .csv | `Eoo.CSV` | ✅ 完整 |

## 安装

```elixir
def deps do
  [
    {:eoo, "~> 0.1.0"}
  ]
end
```

## 快速开始

### 打开电子表格

```elixir
# 工厂模式 — 自动检测文件格式
{:ok, spreadsheet} = Eoo.Spreadsheet.open("data.xlsx")
spreadsheet.sheets()
# => ["Sheet1", "Sheet2"]

# 或直接使用特定解析器
{:ok, xlsx} = Eoo.Excelx.open("data.xlsx")
```

### 读取数据

```elixir
# 工作表信息
Eoo.Excelx.sheets(xlsx)
Eoo.Excelx.default_sheet(xlsx)

# 单元格访问
Eoo.Excelx.cell(xlsx, 1, 1)          # 第一行第一列
Eoo.Excelx.cell(xlsx, 1, "A")        # 也支持列字母
Eoo.Excelx.celltype(xlsx, 1, 1)      # :string | :float | :date ...

# 行/列访问
Eoo.Excelx.row(xlsx, 1)              # 第一行
Eoo.Excelx.column(xlsx, 1)           # 第一列
Eoo.Excelx.column(xlsx, "A")         # 也支持列字母

# 数据范围
Eoo.Excelx.first_row(xlsx)           # 第一个非空行
Eoo.Excelx.last_row(xlsx)            # 最后一个非空行
Eoo.Excelx.first_column(xlsx)        # 第一个非空列
Eoo.Excelx.last_column(xlsx)         # 最后一个非空列
```

### 高级功能

```elixir
# 公式读取
Eoo.Excelx.formula(xlsx, 2, 3)       # "A2+B2"
Eoo.Excelx.formulas(xlsx)            # [[2, 3, "A2+B2"]]

# 批注
Eoo.Excelx.comment(xlsx, 2, 2)       # "This is cell B2"

# 标签/命名区域
Eoo.Excelx.label(xlsx, "first_cell") # {1, 1, "Sheet1"}

# 超链接
Eoo.Excelx.hyperlink(xlsx, 1, 1)     # "#Sheet2!A1"

# 合并单元格
{:ok, xlsx} = Eoo.Excelx.open("data.xlsx", expand_merged_ranges: true)
```

### 流式读取大文件

```elixir
xlsx
|> Eoo.Excelx.each_row_streaming(max_rows: 1000, offset: 1, pad_cells: true)
|> Enum.each(fn row -> IO.inspect(row) end)
```

### 导出

```elixir
# CSV 导出
Eoo.Formatters.CSV.to_csv(xlsx)

# YAML 导出
Eoo.Formatters.YAML.to_yaml(xlsx)

# Matrix 导出（二维列表）
Eoo.Formatters.Matrix.to_matrix(xlsx)
```

### CSV 解析

```elixir
# 基本用法
{:ok, csv} = Eoo.CSV.open("data.csv")
Eoo.CSV.row(csv, 1)

# 自定义分隔符
{:ok, csv} = Eoo.CSV.open("data.tsv", csv_options: [separator: "\t"])
```

### ODS 支持

```elixir
{:ok, ods} = Eoo.OpenOffice.open("data.ods")
Eoo.OpenOffice.cell(ods, 1, 1)
```

## API 对照（Ruby Roo → Elixir Eoo）

| Ruby | Elixir |
|------|--------|
| `Roo::Spreadsheet.open(path)` | `Eoo.Spreadsheet.open(path)` |
| `xlsx.sheets` | `Eoo.Excelx.sheets(xlsx)` |
| `xlsx.default_sheet = "Sheet1"` | `Eoo.Excelx.default_sheet(xlsx, "Sheet1")` |
| `xlsx.cell(1, "A")` | `Eoo.Excelx.cell(xlsx, 1, "A")` |
| `xlsx.row(1)` | `Eoo.Excelx.row(xlsx, 1)` |
| `xlsx.column(1)` | `Eoo.Excelx.column(xlsx, 1)` |
| `xlsx.first_row` | `Eoo.Excelx.first_row(xlsx)` |
| `xlsx.to_csv` | `Eoo.Formatters.CSV.to_csv(xlsx)` |
| `xlsx.each_row_streaming` | `Eoo.Excelx.each_row_streaming(xlsx)` |

## 设计原则

- **零外部依赖** — 纯 Erlang/OTP 内置（`:xmerl`、`:zip`、`:crypto`）
- **API 兼容** — 与 Ruby Roo 保持一致的命名和语义
- **惰性求值** — 流式读取支持大文件
- **不可变数据** — 所有操作返回新结构体

## 开发

```bash
# 获取依赖
mix deps.get

# 编译（零警告）
mix compile --warnings-as-errors

# 运行测试
mix test

# 交互式调试
iex -S mix
```

## 许可证

MIT License — 与原始 Roo gem 相同。

## 致谢

- [Roo](https://github.com/roo-rb/roo) — Ruby 电子表格库，本项目的设计蓝本
