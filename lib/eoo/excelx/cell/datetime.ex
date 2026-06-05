defmodule Eoo.Excelx.Cell.DateTime do
  @moduledoc """
  日期时间单元格类型。
  """

  defstruct [:value, :formula, :style, :coordinate, :hyperlink,
             :format, :cell_value, :cell_type, default_type: :datetime]

  @type t :: %__MODULE__{
          value: DateTime.t(),
          formula: String.t() | nil,
          style: non_neg_integer(),
          coordinate: {pos_integer(), pos_integer()},
          hyperlink: String.t() | nil,
          format: String.t(),
          cell_value: String.t(),
          cell_type: term(),
          default_type: :datetime
        }

  @seconds_in_day 86_400

  def new(value, formula, excelx_type, style, link, base_timestamp, coordinate) do
    format = if excelx_type, do: elem(excelx_type, 1) || "General", else: "General"
    float_val = Float.parse(value) |> elem(0)

    %__MODULE__{
      value: create_datetime(base_timestamp, float_val),
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
  def type(%__MODULE__{}), do: :datetime

  def formula?(%__MODULE__{formula: nil}), do: false
  def formula?(%__MODULE__{}), do: true

  def empty?(%__MODULE__{}), do: false

  def link?(%__MODULE__{hyperlink: nil}), do: false
  def link?(%__MODULE__{}), do: true

  def formatted_value(%__MODULE__{value: dt}) do
    dt |> NaiveDateTime.from_iso8601!() |> NaiveDateTime.to_string()
  rescue
    _ -> to_string(dt)
  end

  defp create_datetime(base_ts, value) when is_integer(base_ts) do
    timestamp = base_ts + round(value * @seconds_in_day)
    DateTime.from_unix!(timestamp)
  end

  defp create_datetime(_base_ts, _value) do
    DateTime.utc_now()
  end
end
