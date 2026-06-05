defmodule Eoo.Excelx.Cell.Boolean do
  @moduledoc """
  布尔单元格类型。
  """

  defstruct [:value, :formula, :style, :coordinate, :hyperlink,
             :cell_value, :cell_type, default_type: :boolean]

  @type t :: %__MODULE__{
          value: boolean(),
          formula: String.t() | nil,
          style: non_neg_integer(),
          coordinate: {pos_integer(), pos_integer()},
          hyperlink: String.t() | nil,
          cell_value: String.t(),
          cell_type: term(),
          default_type: :boolean
        }

  def new(value, formula, style, link, coordinate) do
    bool_val = String.to_integer(value) == 1

    %__MODULE__{
      value: bool_val,
      formula: formula,
      style: style || 1,
      coordinate: coordinate,
      hyperlink: link,
      cell_value: value,
      cell_type: :boolean
    }
  end

  def type(%__MODULE__{formula: f}) when not is_nil(f), do: :formula
  def type(%__MODULE__{}), do: :boolean

  def formula?(%__MODULE__{formula: nil}), do: false
  def formula?(%__MODULE__{}), do: true

  def empty?(%__MODULE__{}), do: false

  def link?(%__MODULE__{hyperlink: nil}), do: false
  def link?(%__MODULE__{}), do: true

  def formatted_value(%__MODULE__{value: true}), do: "TRUE"
  def formatted_value(%__MODULE__{value: false}), do: "FALSE"
end
