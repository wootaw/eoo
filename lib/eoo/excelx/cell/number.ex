defmodule Eoo.Excelx.Cell.Number do
  @moduledoc """
  数值单元格类型。处理整数、浮点数、百分比格式。
  """

  defstruct [
    :value,
    :formula,
    :style,
    :coordinate,
    :hyperlink,
    :format,
    :cell_value,
    :cell_type,
    default_type: :float
  ]

  @type t :: %__MODULE__{
          value: number(),
          formula: String.t() | nil,
          style: non_neg_integer(),
          coordinate: {pos_integer(), pos_integer()},
          hyperlink: String.t() | nil,
          format: String.t(),
          cell_value: String.t(),
          cell_type: term(),
          default_type: :float
        }

  @error_values ~w(#N/A #REF! #NAME? #DIV/0! #NULL! #VALUE! #NUM!)

  def new(value, formula, excelx_type, style, link, coordinate) do
    format = if excelx_type, do: elem(excelx_type, 1) || "General", else: "General"

    %__MODULE__{
      value: maybe_link(value, link),
      formula: formula,
      style: style || 1,
      coordinate: coordinate,
      hyperlink: link,
      format: format,
      cell_value: value,
      cell_type: excelx_type
    }
    |> convert_value(value, format)
  end

  def type(%__MODULE__{formula: f}) when not is_nil(f), do: :formula
  def type(%__MODULE__{default_type: dt}), do: dt

  def formula?(%__MODULE__{formula: nil}), do: false
  def formula?(%__MODULE__{}), do: true

  def empty?(%__MODULE__{}), do: false

  def link?(%__MODULE__{hyperlink: nil}), do: false
  def link?(%__MODULE__{}), do: true

  def formatted_value(%__MODULE__{value: v, format: f}) do
    format_number(v, f)
  end

  defp convert_value(cell, value, _format) when value in @error_values, do: %{cell | value: value}

  defp convert_value(cell, value, _format) do
    numeric =
      if String.contains?(value, ".") or String.match?(value, ~r/^[-+]?\d+E[-+]?\d+$/i) do
        Float.parse(value) |> elem(0)
      else
        String.to_integer(value)
      end

    %{cell | value: numeric}
  end

  defp format_number(value, format) do
    cond do
      is_binary(value) -> value
      String.downcase(format) == "general" -> "#{value}"
      String.contains?(format, "%") -> "#{Float.round(value * 100, 2)}%"
      true -> "#{value}"
    end
  end

  defp maybe_link(value, nil), do: value
  defp maybe_link(value, link), do: %Eoo.Link{href: link, text: to_string(value)}
end
