defmodule Eoo.Excelx.SharedStrings do
  @moduledoc """
  解析 sharedStrings.xml，提供共享字符串查找功能。
  """

  defstruct [:path, :options, :array, :html]

  alias Eoo.XML

  def new(path, options \\ []) do
    %__MODULE__{path: path, options: options}
  end

  def get(%__MODULE__{array: nil} = ss, index) when is_integer(index) do
    get(%{ss | array: extract_shared_strings(ss)}, index)
  end

  def get(%__MODULE__{array: array}, index) when is_integer(index) do
    Enum.at(array, index)
  end

  def to_array(%__MODULE__{array: nil} = ss), do: extract_shared_strings(ss)
  def to_array(%__MODULE__{array: array}), do: array

  def to_html(%__MODULE__{html: nil} = ss), do: extract_html(ss)
  def to_html(%__MODULE__{html: html}), do: html

  def use_html?(%__MODULE__{options: opts} = ss, index) do
    not Keyword.get(opts, :disable_html_wrapper, false) and
      case to_html(ss) do
        items when is_list(items) ->
          item = Enum.at(items, index)
          item && String.contains?(item, "<")
        _ -> false
      end
  end

  defp extract_shared_strings(%__MODULE__{path: path}) do
    unless File.exists?(path), do: []
    doc = File.read!(path) |> XML.parse()
    find_all(doc, "si")
    |> Enum.map(&extract_si_text/1)
  end

  defp extract_si_text(si) do
    case XML.children_by_tag(si, "r") do
      [] -> get_child_text(si, "t") || ""
      rich -> Enum.map(rich, &(get_child_text(&1, "t") || "")) |> Enum.join("")
    end
  end

  defp get_child_text(elem, tag) do
    elem
    |> XML.children_by_tag(tag)
    |> List.first()
    |> XML.text()
  end

  defp extract_html(%__MODULE__{path: path}) do
    unless File.exists?(path), do: []
    doc = File.read!(path) |> XML.parse()
    find_all(doc, "si")
    |> Enum.map(fn si ->
      "<html>" <>
        (XML.children_by_tag(si, "r") |> Enum.map(&extract_r_html/1) |> Enum.join("")) <>
        "</html>"
    end)
  end

  defp extract_r_html(r_elem) do
    xml_elems = %{sub: false, sup: false, b: false, i: false, u: false}
    xml_elems = case XML.children_by_tag(r_elem, "rPr") do
      [rpr | _] ->
        val = XML.attr(rpr, "val") || ""
        xml_elems
        |> Map.put(:b, XML.children_by_tag(rpr, "b") != [])
        |> Map.put(:i, XML.children_by_tag(rpr, "i") != [])
        |> Map.put(:u, XML.children_by_tag(rpr, "u") != [])
        |> Map.put(:sub, val == "subscript")
        |> Map.put(:sup, val == "superscript")
      _ -> xml_elems
    end
    text = get_child_text(r_elem, "t") || ""
    open = xml_elems |> Enum.filter(fn {_, v} -> v end) |> Enum.map(fn {k, _} -> "<#{k}>" end) |> Enum.join("")
    close = xml_elems |> Enum.reverse() |> Enum.filter(fn {_, v} -> v end) |> Enum.map(fn {k, _} -> "</#{k}>" end) |> Enum.join("")
    open <> text <> close
  end

  # Recursive find
  defp find_all(elem, tag), do: do_find(elem, tag, [])

  defp do_find({:xmlElement, name, _, _, _, _, _, _, children, _, _, _} = elem, tag, acc) do
    acc = if to_string(name) == tag, do: acc ++ [elem], else: acc
    Enum.reduce(children, acc, fn c, a -> do_find(c, tag, a) end)
  end
  defp do_find(list, tag, acc) when is_list(list) do
    Enum.reduce(list, acc, fn c, a -> do_find(c, tag, a) end)
  end
  defp do_find(_, _, acc), do: acc
end
