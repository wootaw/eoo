defmodule Eoo.Utils do
  @moduledoc """
  工具函数：列字母/数字转换、坐标提取、XML 加载等。
  """

  @letters Enum.to_list(?A..?Z)

  @doc """
  将数字列号转为字母表示 (1 => "A", 27 => "AA", ...)。
  """
  @spec number_to_letter(pos_integer()) :: String.t()
  def number_to_letter(num) when num > 0 do
    do_number_to_letter(num, "")
  end

  defp do_number_to_letter(0, acc), do: acc

  defp do_number_to_letter(num, acc) do
    num_minus_1 = num - 1
    index = rem(num_minus_1, 26)
    new_num = div(num_minus_1, 26)
    do_number_to_letter(new_num, <<Enum.at(@letters, index)::utf8>> <> acc)
  end

  @doc """
  将字母列号转为数字 ("A" => 1, "AA" => 27, ...)。
  不区分大小写。
  """
  @spec letter_to_number(String.t()) :: pos_integer()
  def letter_to_number(letters) when is_binary(letters) do
    letters
    |> String.upcase()
    |> String.to_charlist()
    |> Enum.reduce(0, fn c, acc ->
      acc * 26 + (c - ?A + 1)
    end)
  end

  @doc """
  从类似 "AB42" 的字符串中提取坐标。
  返回 %Eoo.Coordinate{}。
  """
  @spec extract_coordinate(String.t()) :: Eoo.Coordinate.t()
  def extract_coordinate(str) when is_binary(str) do
    {letter_part, num_part} = split_ref(str)
    col = letter_to_number(letter_part)
    row = String.to_integer(num_part)
    %Eoo.Coordinate{row: row, column: col}
  end

  @doc """
  将 {row, col} 元组转为 key string，如 "12,45"。
  """
  @spec key_to_string({pos_integer(), pos_integer()}) :: String.t()
  def key_to_string({row, col}) do
    "#{row},#{col}"
  end

  @doc """
  将 "12,45" 格式的 key 转为 {row, col} 元组。
  """
  @spec key_to_num(String.t()) :: {pos_integer(), pos_integer()}
  def key_to_num(str) do
    [r, c] = String.split(str, ",")
    {String.to_integer(r), String.to_integer(c)}
  end

  @doc """
  标准化单元格引用。支持多种输入形式：
  - `(1, 1)` → `{1, 1}`
  - `("A", 1)` → `{1, 1}`
  - `(1, "A")` → `{1, 1}`
  """
  @spec normalize(row :: any(), col :: any()) :: {pos_integer(), pos_integer()}
  def normalize(row, col)

  def normalize(row, col) when is_binary(row) and is_integer(col) do
    if String.match?(row, ~r/^\d+$/) do
      {col, String.to_integer(row)}
    else
      {col, letter_to_number(row)}
    end
  end

  def normalize(row, col) when is_integer(row) and is_binary(col) do
    {row, letter_to_number(col)}
  end

  def normalize(row, col) when is_integer(row) and is_integer(col) do
    {row, col}
  end

  @doc """
  计算范围字符串中的单元格上限数量。
  范围格式: "A1:B2"
  """
  @spec num_cells_in_range(String.t()) :: pos_integer()
  def num_cells_in_range(str) do
    cells = String.split(str, ":")

    case cells do
      [_single] ->
        1

      [c1, c2] ->
        a = extract_coordinate(c1)
        b = extract_coordinate(c2)
        (b.row - a.row + 1) * (b.column - a.column + 1)

      _ ->
        raise ArgumentError, "invalid range: #{str}"
    end
  end

  @doc """
  返回范围中的每个坐标。
  范围格式: "A1:B2"
  """
  @spec coordinates_in_range(String.t()) :: [Eoo.Coordinate.t()]
  def coordinates_in_range(str) do
    case String.split(str, ":", parts: 2) do
      [single] ->
        [extract_coordinate(single)]

      [tl_str, br_str] ->
        tl = extract_coordinate(tl_str)
        br = extract_coordinate(br_str)

        for row <- tl.row..br.row,
            col <- tl.column..br.column,
            do: %Eoo.Coordinate{row: row, column: col}
    end
  end

  @doc """
  加载 XML 文件，返回解析后的文档。
  使用 Erlang 的 xmerl 进行解析。
  """
  def load_xml(path) do
    path
    |> File.read!()
    |> Eoo.XML.parse()
  end

  @doc """
  从二进制字符串解析 XML。
  """
  def parse_xml(xml_binary) do
    Eoo.XML.parse(xml_binary)
  end

  @doc """
  检查路径是否为 URI。
  """
  @spec uri?(String.t()) :: boolean()
  def uri?(path) do
    String.starts_with?(path, ["http://", "https://", "ftp://"])
  rescue
    _ -> false
  end

  @doc """
  检查是否为流式 IO。
  """
  def is_stream?(term) do
    function_exported?(term, :seek, 2)
  end

  @doc """
  从文件路径提取文件名。
  """
  def find_basename(path) when is_binary(path) do
    if uri?(path) do
      uri = URI.parse(path)
      Path.basename(uri.path || "")
    else
      Path.basename(path)
    end
  end

  @doc """
  将整数时间值转为时间字符串 "HH:MM:SS"。
  """
  @spec integer_to_timestring(integer()) :: String.t()
  def integer_to_timestring(content) when is_integer(content) do
    h = div(content, 3600)
    content = content - h * 3600
    m = div(content, 60)
    s = content - m * 60
    format_time(h, m, s)
  end

  def integer_to_timestring(content) when is_float(content) do
    integer_to_timestring(trunc(content))
  end

  defp format_time(h, m, s) do
    String.pad_leading(Integer.to_string(h), 2, "0") <>
      ":" <>
      String.pad_leading(Integer.to_string(m), 2, "0") <>
      ":" <> String.pad_leading(Integer.to_string(s), 2, "0")
  end

  # 私有辅助函数

  defp split_ref(str) do
    {letters, digits} =
      str
      |> String.trim()
      |> String.to_charlist()
      |> Enum.split_while(&(&1 in ?A..?Z or &1 in ?a..?z))

    {List.to_string(letters), List.to_string(digits)}
  end
end
