defmodule Eoo.Excelx.Cell.Empty do
  @moduledoc """
  空单元格类型。
  """

  defstruct [:coordinate, value: nil, formula: nil, style: nil,
             hyperlink: nil, cell_value: nil, cell_type: nil, default_type: nil]

  @type t :: %__MODULE__{
          coordinate: {pos_integer(), pos_integer()} | nil,
          value: nil,
          formula: nil,
          style: nil,
          hyperlink: nil,
          cell_value: nil,
          cell_type: nil,
          default_type: nil
        }

  def new(coordinate) do
    %__MODULE__{coordinate: coordinate}
  end

  def type(_), do: nil
  def formula?(_), do: false
  def link?(_), do: false
  def empty?(_), do: true
  def formatted_value(_), do: ""
end
