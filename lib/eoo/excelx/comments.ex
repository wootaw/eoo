defmodule Eoo.Excelx.Comments do
  @moduledoc """
  解析 comments 文件，提取单元格批注。
  """

  defstruct [:path, :comments_map]

  alias Eoo.XML

  def new(path), do: %__MODULE__{path: path}

  def comments(%__MODULE__{comments_map: nil} = c), do: extract_comments(c)
  def comments(%__MODULE__{comments_map: cmts}), do: cmts

  defp extract_comments(%__MODULE__{path: nil}), do: %{}
  defp extract_comments(%__MODULE__{path: path}) do
    unless File.exists?(path) do
      %{}
    else
      doc = File.read!(path) |> XML.parse()
      # Find all comment elements (preserving original structure)
      doc
      |> find_elements("comment")
      |> Enum.reduce(%{}, fn comment, acc ->
        ref = XML.attr(comment, "ref")
        coord = if ref, do: Eoo.Utils.extract_coordinate(ref), else: nil
        text = extract_comment_text(comment)
        if coord, do: Map.put(acc, {coord.row, coord.column}, String.trim(text)), else: acc
      end)
    end
  end

  defp find_elements(elem, tag), do: do_find_elements(elem, tag, [])

  defp do_find_elements({:xmlElement, name, _, _, _, _, _, _, children, _, _, _} = elem, tag, acc) do
    acc = if to_string(name) == tag, do: acc ++ [elem], else: acc
    Enum.reduce(children, acc, fn c, a -> do_find_elements(c, tag, a) end)
  end
  defp do_find_elements(list, tag, acc) when is_list(list) do
    Enum.reduce(list, acc, fn c, a -> do_find_elements(c, tag, a) end)
  end
  defp do_find_elements(_, _, acc), do: acc

  defp extract_comment_text(elem) do
    # Find all <t> elements and join their text
    elem
    |> find_elements("t")
    |> Enum.map(fn t_elem -> extract_text_content(t_elem) end)
    |> Enum.join("")
  end

  defp extract_text_content({:xmlElement, _, _, _, _, _, _, _, children, _, _, _}) do
    extract_texts(children)
  end
  defp extract_texts([]), do: ""
  defp extract_texts([{:xmlText, _, _, _, text, _} | rest]), do: List.to_string(text) <> extract_texts(rest)
  defp extract_texts([_ | rest]), do: extract_texts(rest)
end
