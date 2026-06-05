defmodule Eoo.StreamXML do
  @moduledoc """
  XML 流式行读取器。逐块扫描 XML 文件，提取完整 <row> 元素。

  用于大文件 XLSX 的流式处理，避免整个文档加载到内存。
  """

  @doc """
  从 XML 文件中流式提取指定标签的完整 XML 片段。

  返回一个 stream，每个元素是一个完整标签的 XML 字符串。
  """
  def stream_tag(path, tag) do
    open_tag = "<#{tag}"
    close_tag = "</#{tag}>"

    Stream.resource(
      fn -> File.stream!(path, [], 65536) end,
      fn [] ->
        {:halt, :done}
      end,
      fn _ -> :ok end
    )
    |> Stream.transform(
      "",
      fn chunk, buffer ->
        data = buffer <> chunk
        {rows, remaining} = extract_complete_tags(data, open_tag, close_tag, [])
        {rows, remaining}
      end
    )
  end

  @doc """
  从 XML 字符串中提取所有完整的 <row> 元素。

  返回 {[row_xml_strings], remaining_data}。
  """
  def extract_complete_tags(data, open_tag, close_tag, acc) do
    case find_tag(data, open_tag, 0) do
      nil ->
        {Enum.reverse(acc), data}

      start_idx ->
        after_open = start_idx + byte_size(open_tag)

        case find_closing(data, after_open, close_tag, 0) do
          nil ->
            {Enum.reverse(acc), data}

          end_idx ->
            row_content = binary_part(data, start_idx, end_idx - start_idx)
            rest = binary_part(data, end_idx, byte_size(data) - end_idx)
            extract_complete_tags(rest, open_tag, close_tag, [row_content | acc])
        end
    end
  end

  # Find opening tag: "<tag" followed by space, >, or />
  defp find_tag(data, open_tag, offset) do
    case :binary.match(data, open_tag, scope: {offset, byte_size(data) - offset}) do
      {pos, _len} ->
        after_tag = pos + byte_size(open_tag)

        if after_tag < byte_size(data) do
          case :binary.at(data, after_tag) do
            c when c in [?\s, ?/, ?>, ?\n, ?\r, ?\t] -> pos
            _ -> find_tag(data, open_tag, after_tag)
          end
        else
          pos
        end

      :nomatch ->
        nil
    end
  end

  # Find matching closing tag, tracking nesting depth
  defp find_closing(data, start, close_tag, depth) do
    # Search for next < character
    case find_next_tag(data, start) do
      nil ->
        nil

      {:open, tag_end} ->
        find_closing(data, tag_end, close_tag, depth + 1)

      {:close, tag_end} when depth > 0 ->
        find_closing(data, tag_end, close_tag, depth - 1)

      {:close, tag_end} when depth == 0 ->
        tag_end
    end
  end

  defp find_next_tag(data, offset) when offset >= byte_size(data), do: nil

  defp find_next_tag(data, offset) do
    case :binary.match(data, "<", scope: {offset, byte_size(data) - offset}) do
      {pos, _} ->
        next = pos + 1

        if next < byte_size(data) do
          case :binary.at(data, next) do
            ?/ ->
              # Find end of closing tag
              case :binary.match(data, ">", scope: {next, byte_size(data) - next}) do
                {end_pos, _} -> {:close, end_pos + 1}
                :nomatch -> nil
              end

            _ ->
              # Find end of opening tag (may include attributes)
              case find_tag_end(data, next) do
                nil -> find_next_tag(data, next)
                end_pos -> {:open, end_pos}
              end
          end
        else
          find_next_tag(data, next)
        end

      :nomatch ->
        nil
    end
  end

  defp find_tag_end(data, offset) do
    # Find > that ends the opening tag (handles attributes with >)
    # For simplicity, find the first >
    case :binary.match(data, ">", scope: {offset, byte_size(data) - offset}) do
      {pos, _} -> pos + 1
      :nomatch -> nil
    end
  end

  @doc """
  解析一行 XML 为 Elixir xmerl 元素。
  """
  def parse_row_xml(row_xml) do
    stripped = Eoo.XML.parse(row_xml)
    stripped
  end

  @doc """
  从 xmerl 元素中提取单元格值列表。
  返回 [{coordinate, value, type, formula}]
  """
  def extract_cells(row_elem) do
    cells = extract_cell_elements(row_elem)

    Enum.map(cells, fn cell ->
      ref = attr_value(cell, "r")
      type = attr_value(cell, "t")
      style = attr_value(cell, "s")
      value = extract_value(cell)
      formula = extract_formula(cell)
      %{ref: ref, type: type, style: style, value: value, formula: formula}
    end)
  end

  defp extract_cell_elements({:xmlElement, _, _, _, _, _, _, _, children, _, _, _}) do
    Enum.filter(children, fn
      {:xmlElement, :c, _, _, _, _, _, _, _, _, _, _} -> true
      _ -> false
    end)
  end

  defp extract_value({:xmlElement, _, _, _, _, _, _, _, children, _, _, _}) do
    v_elem =
      Enum.find(children, fn
        {:xmlElement, :v, _, _, _, _, _, _, _, _, _, _} -> true
        _ -> false
      end)

    case v_elem do
      {:xmlElement, _, _, _, _, _, _, _, vchildren, _, _, _} ->
        text =
          Enum.find(vchildren, fn
            {:xmlText, _, _, _, _, _} -> true
            _ -> false
          end)

        case text do
          {:xmlText, _, _, _, t, _} -> List.to_string(t)
          _ -> nil
        end

      _ ->
        nil
    end
  end

  defp extract_formula({:xmlElement, _, _, _, _, _, _, _, children, _, _, _}) do
    f_elem =
      Enum.find(children, fn
        {:xmlElement, :f, _, _, _, _, _, _, _, _, _, _} -> true
        _ -> false
      end)

    case f_elem do
      {:xmlElement, _, _, _, _, _, _, _, fchildren, _, _, _} ->
        text =
          Enum.find(fchildren, fn
            {:xmlText, _, _, _, _, _} -> true
            _ -> false
          end)

        case text do
          {:xmlText, _, _, _, t, _} -> List.to_string(t)
          _ -> nil
        end

      _ ->
        nil
    end
  end

  defp attr_value({:xmlElement, _, _, _, _, _, _, attrs, _, _, _, _}, name) do
    Enum.find_value(attrs, fn
      {:xmlAttribute, aname, _, _, _, _, _, _, value, _} ->
        if to_string(aname) == name and is_list(value), do: List.to_string(value)

      _ ->
        nil
    end)
  end
end
