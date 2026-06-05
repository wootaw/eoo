defmodule Eoo.Excelx.Styles do
  @moduledoc """
  解析 styles.xml，提供样式/字体定义和格式代码查找。
  """

  defstruct [:path, :doc, :num_fmt_ids, :num_fmts, :fonts, :definitions]

  alias Eoo.XML

  def new(path) do
    doc = if File.exists?(path) do
      File.read!(path) |> XML.parse()
    end
    %__MODULE__{path: path, doc: doc}
  end

  def style_format(%__MODULE__{} = styles, style_id) when is_integer(style_id) do
    ids = num_fmt_ids(styles)
    num_fmt_id = Enum.at(ids, style_id)
    if num_fmt_id do
      fmts = num_fmts(styles)
      Map.get(fmts, num_fmt_id) || Eoo.Excelx.Format.standard_format(num_fmt_id)
    end
  end
  def style_format(%__MODULE__{} = styles, style_id) when is_binary(style_id) do
    style_format(styles, String.to_integer(style_id))
  end
  def style_format(_, _), do: nil

  def definitions(%__MODULE__{definitions: nil} = styles), do: extract_definitions(styles)
  def definitions(%__MODULE__{definitions: defs}), do: defs

  defp num_fmt_ids(%__MODULE__{num_fmt_ids: nil} = styles), do: extract_num_fmt_ids(styles)
  defp num_fmt_ids(%__MODULE__{num_fmt_ids: ids}), do: ids
  defp num_fmts(%__MODULE__{num_fmts: nil} = styles), do: extract_num_fmts(styles)
  defp num_fmts(%__MODULE__{num_fmts: fmts}), do: fmts

  defp extract_num_fmt_ids(%__MODULE__{doc: nil}), do: []
  defp extract_num_fmt_ids(%__MODULE__{doc: doc}) do
    doc |> XML.xpath("//cellXfs/xf") |> Enum.map(&(XML.attr(&1, "numFmtId"))) |> Enum.filter(& &1)
  end

  defp extract_num_fmts(%__MODULE__{doc: nil}), do: %{}
  defp extract_num_fmts(%__MODULE__{doc: doc}) do
    doc |> XML.xpath("//numFmt")
    |> Enum.reduce(%{}, fn nf, acc ->
      Map.put(acc, XML.attr(nf, "numFmtId"), XML.attr(nf, "formatCode"))
    end)
  end

  defp extract_fonts(%__MODULE__{doc: nil}), do: []
  defp extract_fonts(%__MODULE__{doc: doc}) do
    doc |> XML.xpath("//fonts/font")
    |> Enum.map(fn f ->
      %Eoo.Font{
        bold: XML.children_by_tag(f, "b") != [],
        italic: XML.children_by_tag(f, "i") != [],
        underline: XML.children_by_tag(f, "u") != []
      }
    end)
  end

  defp extract_definitions(%__MODULE__{doc: nil}), do: []
  defp extract_definitions(%__MODULE__{} = styles) do
    fonts = extract_fonts(styles)
    doc  = styles.doc
    doc |> XML.xpath("//cellXfs/xf")
    |> Enum.map(fn xf ->
      fid = XML.attr(xf, "fontId")
      if fid, do: Enum.at(fonts, String.to_integer(fid))
    end)
  end
end
