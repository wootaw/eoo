defmodule Eoo.Excelx.Format do
  @moduledoc """
  Excel 格式代码到类型的转换。

  格式代码在 styles.xml 中定义，用于判断单元格的数据类型
  （日期、时间、数字、百分比等）。
  """

  @exceptional_formats %{
    "h:mm am/pm" => :date,
    "h:mm:ss am/pm" => :date
  }

  @standard_formats %{
    0 => "General",
    1 => "0",
    2 => "0.00",
    3 => "#,##0",
    4 => "#,##0.00",
    9 => "0%",
    10 => "0.00%",
    11 => "0.00E+00",
    12 => "# ?/?",
    13 => "# ??/??",
    14 => "mm-dd-yy",
    15 => "d-mmm-yy",
    16 => "d-mmm",
    17 => "mmm-yy",
    18 => "h:mm AM/PM",
    19 => "h:mm:ss AM/PM",
    20 => "h:mm",
    21 => "h:mm:ss",
    22 => "m/d/yy h:mm",
    37 => "#,##0 ;(#,##0)",
    38 => "#,##0 ;[Red](#,##0)",
    39 => "#,##0.00;(#,##0.00)",
    40 => "#,##0.00;[Red](#,##0.00)",
    45 => "mm:ss",
    46 => "[h]:mm:ss",
    47 => "mmss.0",
    48 => "##0.0E+0",
    49 => "@"
  }

  @doc """
  根据格式代码返回单元格类型。

  返回: :float, :date, :datetime, :time, :percentage
  """
  def to_type(format_str) do
    format = format_str |> to_string() |> String.downcase()

    cond do
      Map.has_key?(@exceptional_formats, format) ->
        Map.get(@exceptional_formats, format)

      String.contains?(format, "#") ->
        :float

      String.contains?(format, "y") or String.contains?(format, "d") ->
        if String.contains?(format, "h") or String.contains?(format, "s") do
          :datetime
        else
          :date
        end

      String.contains?(format, "h") or String.contains?(format, "s") ->
        :time

      String.contains?(format, "%") ->
        :percentage

      true ->
        :float
    end
  end

  @doc """
  获取标准格式代码对应的格式字符串。
  """
  def standard_format(id) when is_integer(id) do
    Map.get(@standard_formats, id)
  end

  def standard_format(id) when is_binary(id) do
    id |> String.to_integer() |> standard_format()
  end
end
