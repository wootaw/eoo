defmodule Eoo.Formatters.Matrix do
  @moduledoc """
  Matrix 格式化输出。返回二维列表（行列表）。
  """

  @doc """
  将 sheet 转为二维列表（矩阵）。

  ## 选项
    - `:sheet` - 工作表名
    - `:from_row` / `:to_row` - 行范围
    - `:from_column` / `:to_column` - 列范围
  """
  @spec to_matrix(term(), keyword()) :: [[any()]]
  def to_matrix(spreadsheet, opts \\ []) do
    m = spreadsheet.__struct__
    sheet = Keyword.get(opts, :sheet, apply(m, :default_sheet, [spreadsheet]))
    from_row = Keyword.get(opts, :from_row, apply(m, :first_row, [spreadsheet, sheet]))
    to_row = Keyword.get(opts, :to_row, apply(m, :last_row, [spreadsheet, sheet]))
    from_col = Keyword.get(opts, :from_column, apply(m, :first_column, [spreadsheet, sheet]))
    to_col = Keyword.get(opts, :to_column, apply(m, :last_column, [spreadsheet, sheet]))

    if is_nil(from_row) do
      []
    else
      for row <- from_row..to_row do
        for col <- from_col..to_col do
          apply(m, :cell, [spreadsheet, row, col, sheet])
        end
      end
    end
  end
end
