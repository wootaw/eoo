defmodule Eoo.Excelx.Cell.Base do
  @moduledoc """
  所有 XLSX 单元格类型的基结构体。
  """

  defstruct [
    :cell_value,
    :cell_type,
    :formula,
    :style,
    :coordinate,
    :value,
    :hyperlink,
    default_type: :base
  ]

  @type t :: %__MODULE__{
          cell_value: String.t(),
          cell_type: term(),
          formula: String.t() | nil,
          style: non_neg_integer(),
          coordinate: {pos_integer(), pos_integer()},
          value: term(),
          hyperlink: String.t() | nil,
          default_type: atom()
        }

  def type(%__MODULE__{formula: f}) when not is_nil(f), do: :formula
  def type(%__MODULE__{default_type: dt}), do: dt

  def formula?(%__MODULE__{formula: nil}), do: false
  def formula?(%__MODULE__{}), do: true

  def link?(%__MODULE__{hyperlink: nil}), do: false
  def link?(%__MODULE__{}), do: true

  def formatted_value(cell), do: cell.value

  def empty?(%__MODULE__{}), do: false

  def presence(%__MODULE__{value: v}) when not is_nil(v), do: v
  def presence(_), do: nil
end
