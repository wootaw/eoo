defmodule Eoo.Formatters.CSV do
  @moduledoc """
  CSV 格式化输出。
  """

  alias Eoo.Formatters.Base

  @doc """
  将整个 sheet 转为 CSV 字符串。

  ## 选项
    - `:separator` - 分隔符，默认为 ","
    - `:sheet` - 工作表名

  如果提供文件名则写入文件，否则返回字符串。
  """
  def to_csv(spreadsheet, filename \\ nil, opts \\ []) do
    separator = Keyword.get(opts, :separator, ",")
    m = spreadsheet.__struct__
    sheet_name = Keyword.get(opts, :sheet, apply(m, :default_sheet, [spreadsheet]))

    content = build_csv_content(m, spreadsheet, sheet_name, separator)

    case filename do
      nil -> content
      path -> File.write!(path, content)
    end
  end

  defp build_csv_content(m, spreadsheet, sheet, separator) do
    first_row = apply(m, :first_row, [spreadsheet, sheet])
    last_row = apply(m, :last_row, [spreadsheet, sheet])
    first_col = apply(m, :first_column, [spreadsheet, sheet])
    last_col = apply(m, :last_column, [spreadsheet, sheet])

    if is_nil(first_row) do
      ""
    else
      first_row..last_row
      |> Enum.map(fn row ->
        first_col..last_col
        |> Enum.map(fn col -> cell_to_csv(m, spreadsheet, row, col, sheet, separator) end)
        |> Enum.join(separator)
      end)
      |> Enum.join("\n")
    end
  end

  defp cell_to_csv(m, spreadsheet, row, col, sheet, _separator) do
    cond do
      apply(m, :empty?, [spreadsheet, row, col, sheet]) -> ""
      true ->
        value = apply(m, :cell, [spreadsheet, row, col, sheet])
        celltype = apply(m, :celltype, [spreadsheet, row, col, sheet])
        format_cell(value, celltype)
    end
  end

  defp format_cell(value, :string) when is_binary(value) and value != "" do
    ~s("#{String.replace(value, "\"", "\"\"")}")
  end

  defp format_cell(value, :boolean) do
    ~s("#{String.downcase(to_string(value))}")
  end

  defp format_cell(value, :float) when is_float(value) do
    if value == trunc(value) do
      Integer.to_string(trunc(value))
    else
      Float.to_string(value)
    end
  end

  defp format_cell(value, :percentage) when is_float(value) do
    if value == trunc(value) do
      Integer.to_string(trunc(value))
    else
      Float.to_string(value)
    end
  end

  defp format_cell(value, :formula) do
    cond do
      is_binary(value) and value != "" ->
        ~s("#{String.replace(value, "\"", "\"\"")}")
      is_integer(value) ->
        Integer.to_string(value)
      is_float(value) ->
        if value == trunc(value) do
          Integer.to_string(trunc(value))
        else
          Float.to_string(value)
        end
      true ->
        to_string(value)
    end
  end

  defp format_cell(value, :time) when is_integer(value) do
    Base.integer_to_timestring(value)
  end

  defp format_cell(value, :link) do
    cond do
      is_struct(value, Eoo.Link) -> ~s("#{String.replace(value.href, "\"", "\"\"")}")
      true -> ~s("#{String.replace(to_string(value), "\"", "\"\"")}")
    end
  end

  defp format_cell(value, _type) do
    to_string(value)
  end
end
