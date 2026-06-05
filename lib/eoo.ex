defmodule Eoo do
  @moduledoc """
  Eoo — Elixir 电子表格解析库。

  Ruby 生态中 Roo gem 的 Elixir 移植版。
  零外部依赖，仅使用 Erlang/OTP 内置模块。

  ## 支持的格式

  | 格式 | 模块 | 说明 |
  |------|------|------|
  | .xlsx / .xlsm | `Eoo.Excelx` | Excel 2007+ |
  | .ods | `Eoo.OpenOffice` | LibreOffice / OpenOffice |
  | .csv | `Eoo.CSV` | 逗号分隔值 |

  ## 快速开始

      # 工厂模式 — 自动检测格式
      {:ok, ss} = Eoo.Spreadsheet.open("data.xlsx")
      ss.sheets()
      # => ["Sheet1", "Sheet2"]

      # 直接使用特定解析器
      {:ok, xlsx} = Eoo.Excelx.open("data.xlsx")
      Eoo.Excelx.cell(xlsx, 1, 1)
      # => "Name"

      # 流式读取大文件
      xlsx
      |> Eoo.Excelx.each_row_streaming(max_rows: 100)
      |> Enum.each(fn row -> IO.inspect(row) end)

      # 导出为 CSV
      Eoo.Formatters.CSV.to_csv(xlsx)

  ## 设计原则

  - **零外部依赖** — 纯 Erlang/OTP 内置实现（:xmerl, :zip, :crypto）
  - **API 兼容** — 保持与 Ruby Roo 一致的命名和语义
  - **惰性求值** — 流式读取支持大文件
  - **不可变数据** — 所有操作返回新结构体
  """

  @doc false
  def temp_prefix, do: "eoo_"

  @doc """
  根据文件扩展名返回对应的处理模块。
  """
  def class_for_extension(ext) do
    case ext do
      :xlsx -> Eoo.Excelx
      :xlsm -> Eoo.Excelx
      :ods -> Eoo.OpenOffice
      :csv -> Eoo.CSV
      _ -> {:error, :unsupported_format}
    end
  end
end

defmodule Eoo.LibreOffice do
  @moduledoc false
  def open(path, opts \\ []), do: Eoo.OpenOffice.open(path, opts)
end
