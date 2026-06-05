defmodule Eoo.Coordinate do
  @moduledoc """
  表示单元格坐标 `{row, column}`。

  - row: 正整数行号 (1-based, 与 Excel 一致)
  - column: 正整数列号 (1-based)
  """

  defstruct [:row, :column]

  @type t :: %__MODULE__{row: pos_integer(), column: pos_integer()}

  @doc """
  创建一个坐标。
  """
  @spec new(pos_integer(), pos_integer()) :: t()
  def new(row, column) when is_integer(row) and row > 0 and is_integer(column) and column > 0 do
    %__MODULE__{row: row, column: column}
  end

  @doc """
  将坐标转为 `{row, column}` 元组。
  """
  @spec to_tuple(t()) :: {pos_integer(), pos_integer()}
  def to_tuple(%__MODULE__{row: r, column: c}), do: {r, c}
end
