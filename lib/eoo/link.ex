defmodule Eoo.Link do
  @moduledoc """
  表示一个超链接单元格。

  包含 href (URL) 和显示文本 text。
  """

  defstruct [:href, :text]

  @type t :: %__MODULE__{
          href: String.t(),
          text: String.t()
        }

  @doc """
  创建一个超链接。
  """
  @spec new(String.t(), String.t()) :: t()
  def new(href, text \\ "") do
    %__MODULE__{href: href, text: text}
  end

  @doc """
  解析 href 为 URI 结构。
  """
  def to_uri(%__MODULE__{href: href}) do
    URI.parse(href)
  end
end
