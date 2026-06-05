defmodule Eoo.Excelx.Cell.Date do
  @moduledoc """
  日期单元格类型。
  """

  defstruct [:value, :formula, :style, :coordinate, :hyperlink,
             :format, :cell_value, :cell_type, default_type: :date]

  @type t :: %__MODULE__{
          value: Date.t(),
          formula: String.t() | nil,
          style: non_neg_integer(),
          coordinate: {pos_integer(), pos_integer()},
          hyperlink: String.t() | nil,
          format: String.t(),
          cell_value: String.t(),
          cell_type: term(),
          default_type: :date
        }

  def new(value, formula, excelx_type, style, link, base_date, coordinate) do
    format = if excelx_type, do: elem(excelx_type, 1) || "General", else: "General"

    %__MODULE__{
      value: Date.add(base_date, String.to_integer(value)),
      formula: formula,
      style: style || 1,
      coordinate: coordinate,
      hyperlink: link,
      format: format,
      cell_value: value,
      cell_type: excelx_type
    }
  end

  def type(%__MODULE__{formula: f}) when not is_nil(f), do: :formula
  def type(%__MODULE__{}), do: :date

  def formula?(%__MODULE__{formula: nil}), do: false
  def formula?(%__MODULE__{}), do: true

  def empty?(%__MODULE__{}), do: false

  def link?(%__MODULE__{hyperlink: nil}), do: false
  def link?(%__MODULE__{}), do: true

  def formatted_value(%__MODULE__{value: d}) when is_struct(d, Date), do: Date.to_string(d)
  def formatted_value(%__MODULE__{value: d}), do: to_string(d)
end
