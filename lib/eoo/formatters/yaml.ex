defmodule Eoo.Formatters.YAML do
  @moduledoc """
  YAML 格式化输出。
  """

  @doc """
  将 sheet 转为 YAML 字符串。

  ## 选项
    - `:sheet` - 工作表名
    - `:from_row` / `:to_row` - 行范围
    - `:from_column` / `:to_column` - 列范围
    - `:prefix` - 额外前缀字段映射
  """
  def to_yaml(spreadsheet, opts \\ []) do
    m = spreadsheet.__struct__
    sheet = Keyword.get(opts, :sheet, apply(m, :default_sheet, [spreadsheet]))
    from_row = Keyword.get(opts, :from_row, apply(m, :first_row, [spreadsheet, sheet]))
    to_row = Keyword.get(opts, :to_row, apply(m, :last_row, [spreadsheet, sheet]))
    from_col = Keyword.get(opts, :from_column, apply(m, :first_column, [spreadsheet, sheet]))
    to_col = Keyword.get(opts, :to_column, apply(m, :last_column, [spreadsheet, sheet]))
    prefix = Keyword.get(opts, :prefix, %{})

    if is_nil(from_row) do
      ""
    else
      lines = ["--- \n"]

      lines = for row <- from_row..to_row, col <- from_col..to_col,
                  not apply(m, :empty?, [spreadsheet, row, col, sheet]),
                  reduce: lines do
        acc ->
          value = apply(m, :cell, [spreadsheet, row, col, sheet])
          celltype = apply(m, :celltype, [spreadsheet, row, col, sheet])
          display_val = if celltype == :time and is_integer(value),
            do: Eoo.Formatters.Base.integer_to_timestring(value),
            else: value

          acc ++ [
            "cell_#{row}_#{col}: \n",
            Enum.map(prefix, fn {k, v} -> "  #{k}: #{v} \n" end),
            "  row: #{row} \n",
            "  col: #{col} \n",
            "  celltype: #{celltype} \n",
            "  value: #{display_val} \n"
          ]
      end

      lines |> List.flatten() |> Enum.join("")
    end
  end
end
