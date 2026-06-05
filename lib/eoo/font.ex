defmodule Eoo.Font do
  @moduledoc """
  表示单元格的字体样式（粗体、斜体、下划线）。
  """

  defstruct [:bold, :italic, :underline]

  @type t :: %__MODULE__{
          bold: boolean() | nil,
          italic: boolean() | nil,
          underline: boolean() | nil
        }

  @doc """
  创建一个新的字体样式。
  """
  @spec new(keyword()) :: t()
  def new(attrs \\ []) do
    struct!(%__MODULE__{}, attrs)
  end

  @doc """
  是否粗体。
  """
  def bold?(%__MODULE__{bold: b}), do: b == true

  @doc """
  是否斜体。
  """
  def italic?(%__MODULE__{italic: i}), do: i == true

  @doc """
  是否有下划线。
  """
  def underline?(%__MODULE__{underline: u}), do: u == true
end
