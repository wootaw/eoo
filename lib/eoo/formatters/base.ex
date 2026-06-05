defmodule Eoo.Formatters.Base do
  @moduledoc """
  格式化辅助函数。
  """

  @doc """
  将整数秒值转为 "HH:MM:SS" 格式。
  """
  def integer_to_timestring(content) when is_integer(content) do
    h = div(content, 3600)
    content = content - h * 3600
    m = div(content, 60)
    s = content - m * 60
    String.pad_leading(Integer.to_string(h), 2, "0") <>
      ":" <> String.pad_leading(Integer.to_string(m), 2, "0") <>
      ":" <> String.pad_leading(Integer.to_string(s), 2, "0")
  end

  def integer_to_timestring(content), do: integer_to_timestring(trunc(content))
end
