defmodule Eoo.Excelx.Cell.String do
  @moduledoc """
  字符串单元格类型。
  """

  defstruct [:value, :formula, :style, :coordinate, :hyperlink,
             cell_value: nil, cell_type: nil, default_type: :string]

  @type t :: %__MODULE__{
          value: String.t(),
          formula: String.t() | nil,
          style: non_neg_integer(),
          coordinate: {pos_integer(), pos_integer()},
          hyperlink: String.t() | nil,
          cell_value: String.t() | nil,
          cell_type: term(),
          default_type: :string
        }

  def new(value, formula, style, link, coordinate) do
    %__MODULE__{
      value: maybe_link(value, link),
      formula: formula,
      style: style || 1,
      coordinate: coordinate,
      hyperlink: link,
      cell_value: value
    }
  end

  def type(%__MODULE__{formula: f}) when not is_nil(f), do: :formula
  def type(%__MODULE__{}), do: :string

  def formula?(%__MODULE__{formula: nil}), do: false
  def formula?(%__MODULE__{}), do: true

  def empty?(%__MODULE__{value: v}), do: is_nil(v) or v == ""

  def link?(%__MODULE__{hyperlink: nil}), do: false
  def link?(%__MODULE__{}), do: true

  def formatted_value(%__MODULE__{value: v}), do: v

  defp maybe_link(value, nil), do: value
  defp maybe_link(value, link), do: %Eoo.Link{href: link, text: value}
end
