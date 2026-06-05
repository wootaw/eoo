defmodule Eoo.Excelx.Cell.Time do
  @moduledoc """
  时间单元格类型。
  """

  defstruct [
    :value,
    :formula,
    :style,
    :coordinate,
    :hyperlink,
    :format,
    :datetime,
    :cell_value,
    :cell_type,
    default_type: :time
  ]

  @type t :: %__MODULE__{
          value: integer(),
          formula: String.t() | nil,
          style: non_neg_integer(),
          coordinate: {pos_integer(), pos_integer()},
          hyperlink: String.t() | nil,
          format: String.t(),
          datetime: DateTime.t(),
          cell_value: String.t(),
          cell_type: term(),
          default_type: :time
        }

  @seconds_in_day 86_400

  def new(value, formula, excelx_type, style, link, base_date, coordinate) do
    format = if excelx_type, do: elem(excelx_type, 1) || "General", else: "General"
    float_val = Float.parse(value) |> elem(0)

    %__MODULE__{
      value: round(float_val * @seconds_in_day),
      formula: formula,
      style: style || 1,
      coordinate: coordinate,
      hyperlink: link,
      format: format,
      cell_value: value,
      cell_type: excelx_type,
      datetime: base_date
    }
  end

  def type(%__MODULE__{formula: f}) when not is_nil(f), do: :formula
  def type(%__MODULE__{}), do: :time

  def formula?(%__MODULE__{formula: nil}), do: false
  def formula?(%__MODULE__{}), do: true

  def empty?(%__MODULE__{}), do: false

  def link?(%__MODULE__{hyperlink: nil}), do: false
  def link?(%__MODULE__{}), do: true

  def formatted_value(%__MODULE__{value: v}) when is_integer(v) do
    Eoo.Utils.integer_to_timestring(v)
  end

  def formatted_value(%__MODULE__{value: v}), do: to_string(v)
end
