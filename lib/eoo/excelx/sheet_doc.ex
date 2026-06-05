defmodule Eoo.Excelx.SheetDoc do
  @moduledoc """
  解析 sheet XML 文件，提取单元格、超链接、合并范围等信息。
  """

  defstruct [:path, :shared, :options, :relationships]

  alias Eoo.XML

  def new(path, relationships, shared, options \\ []) do
    %__MODULE__{path: path, shared: shared, options: options, relationships: relationships}
  end

  def cells(%__MODULE__{path: path} = sd) do
    doc = load_doc(path)
    empty_cell = Keyword.get(sd.options, :empty_cell, false)
    rels_map = Eoo.Excelx.Relationships.to_map(sd.relationships)
    hyperlinks_map = extract_hyperlinks_v2(doc, rels_map)

    extracted =
      doc
      |> XML.children_by_tag("sheetData")
      |> Enum.flat_map(fn sd_elem -> XML.children_by_tag(sd_elem, "row") end)
      |> Enum.reduce(%{}, fn row_xml, acc ->
        XML.children_by_tag(row_xml, "c")
        |> Enum.reduce(acc, fn cell_xml, inner ->
          r = XML.attr(cell_xml, "r")
          coord = if r, do: Eoo.Utils.extract_coordinate(r), else: nil
          if coord do
            key = {coord.row, coord.column}
            hl = Map.get(hyperlinks_map, key)
            cell = cell_from_xml(cell_xml, hl, empty_cell, sd)
            if cell, do: Map.put(inner, key, cell), else: inner
          else
            inner
          end
        end)
      end)

    if Keyword.get(sd.options, :expand_merged_ranges, false) do
      expand_merged_ranges(extracted, doc)
    else
      extracted
    end
  end

  def hyperlinks(%__MODULE__{path: path} = sd, relationships) do
    if Keyword.get(sd.options, :no_hyperlinks, false) do
      %{}
    else
      extract_hyperlinks_v2(load_doc(path), relationships)
    end
  end

  def dimensions(%__MODULE__{path: path}) do
    doc = load_doc(path)
    case find_all_by_tag(doc, "dimension") do
      [dim | _] -> XML.attr(dim, "ref")
      _ -> nil
    end
  end

  defp load_doc(path), do: File.read!(path) |> XML.parse()

  # Recursive tag search (replaces xpath)
  defp find_all_by_tag(elem, tag), do: do_find(elem, tag, [])

  defp do_find({:xmlElement, name, _, _, _, _, _, _, children, _, _, _} = elem, tag, acc) do
    acc = if to_string(name) == tag, do: acc ++ [elem], else: acc
    Enum.reduce(children, acc, fn c, a -> do_find(c, tag, a) end)
  end
  defp do_find(list, tag, acc) when is_list(list) do
    Enum.reduce(list, acc, fn c, a -> do_find(c, tag, a) end)
  end
  defp do_find(_, _, acc), do: acc

  defp cell_value_type(type, format) do
    case type do
      "s" -> :shared; "b" -> :boolean; "str" -> :string; "inlineStr" -> :inlinestr
      _ -> if format, do: Eoo.Excelx.Format.to_type(format), else: :number
    end
  end

  defp cell_from_xml(cell_xml, hyperlink, empty_cell, sd) do
    children = XML.children(cell_xml)
    if children == [] do
      if empty_cell, do: Eoo.Excelx.Cell.Empty.new(nil), else: nil
    else
      r = XML.attr(cell_xml, "r")
      coord = if r, do: Eoo.Utils.extract_coordinate(r), else: nil
      t = XML.attr(cell_xml, "t")
      s_attr = XML.attr(cell_xml, "s")
      style = if s_attr, do: String.to_integer(s_attr), else: 0
      coord_t = if coord, do: {coord.row, coord.column}, else: nil

      inline_cells = XML.children_by_tag(cell_xml, "is")
      if inline_cells != [] do
        is = hd(inline_cells)
        t_children = XML.children_by_tag(is, "t")
        content = t_children |> Enum.map(&XML.text/1) |> Enum.join("")
        if content != "" do
          Eoo.Excelx.Cell.String.new(content, nil, style, hyperlink, coord_t)
        else; nil end
      else
        formulas = XML.children_by_tag(cell_xml, "f")
        formula = if formulas != [], do: XML.text(hd(formulas)), else: nil
        values = XML.children_by_tag(cell_xml, "v")
        if values != [] do
          value = XML.text(hd(values))
          fmt = Eoo.Excelx.Styles.style_format(Eoo.Excelx.Shared.styles(sd.shared), style)
          vt = cell_value_type(t, fmt)
          create_cell_from_value(vt, value, formula, fmt, style, hyperlink, coord_t, sd)
        else; nil end
      end
    end
  end

  defp create_cell_from_value(:shared, value, formula, _fmt, style, hyperlink, coord, sd) do
    idx = String.to_integer(value)
    ss = Eoo.Excelx.Shared.shared_strings(sd.shared)
    str = Eoo.Excelx.SharedStrings.get(ss, idx) || ""
    Eoo.Excelx.Cell.String.new(str, formula, style, hyperlink, coord)
  end

  defp create_cell_from_value(:boolean, value, formula, _fmt, style, hyperlink, coord, _sd) do
    Eoo.Excelx.Cell.Boolean.new(value, formula, style, hyperlink, coord)
  end

  defp create_cell_from_value(:string, value, formula, _fmt, style, hyperlink, coord, _sd) do
    Eoo.Excelx.Cell.String.new(value, formula, style, hyperlink, coord)
  end

  defp create_cell_from_value(type, value, formula, fmt, style, hyperlink, coord, sd) when type in [:time, :datetime] do
    {float_val, _} = Float.parse(value)
    cell_type = cond do
      float_val < 1.0 -> :time
      abs(float_val - round(float_val)) > 0.000001 -> :datetime
      true -> :date
    end
    base = if cell_type == :date, do: Eoo.Excelx.Shared.base_date(sd.shared), else: Eoo.Excelx.Shared.base_timestamp(sd.shared)
    etype = {:numeric_or_formula, fmt || "General"}
    case cell_type do
      :date -> Eoo.Excelx.Cell.Date.new(value, formula, etype, style, hyperlink, base, coord)
      :time -> Eoo.Excelx.Cell.Time.new(value, formula, etype, style, hyperlink, base, coord)
      :datetime -> Eoo.Excelx.Cell.DateTime.new(value, formula, etype, style, hyperlink, base, coord)
    end
  end

  defp create_cell_from_value(:date, value, formula, fmt, style, hyperlink, coord, sd) do
    bd = Eoo.Excelx.Shared.base_date(sd.shared)
    Eoo.Excelx.Cell.Date.new(value, formula, {:numeric_or_formula, fmt || "General"}, style, hyperlink, bd, coord)
  end

  defp create_cell_from_value(_type, value, formula, fmt, style, hyperlink, coord, _sd) do
    Eoo.Excelx.Cell.Number.new(value, formula, {:numeric_or_formula, fmt || "General"}, style, hyperlink, coord)
  end

  defp extract_hyperlinks_v2(doc, relationships) do
    doc
    |> find_all_by_tag("hyperlink")
    |> Enum.reduce(%{}, fn hl, acc ->
      id = XML.attr(hl, "id") || XML.attr(hl, "Id") || XML.attr(hl, "r:id")
      ref = XML.attr(hl, "ref")
      loc = XML.attr(hl, "location")
      target = cond do
        id && relationships && Map.has_key?(relationships, id) ->
          t = relationships[id]["Target"] || ""
          if loc, do: t <> "#" <> loc, else: t
        true -> nil
      end
      if target && ref do
        Eoo.Utils.coordinates_in_range(ref)
        |> Enum.reduce(acc, fn c, inner -> Map.put(inner, {c.row, c.column}, target) end)
      else; acc end
    end)
  end

  defp expand_merged_ranges(cells, doc) do
    merges = doc |> find_all_by_tag("mergeCell")
    |> Enum.reduce(%{}, fn mc, acc ->
      ref = XML.attr(mc, "ref") || ""
      case String.split(ref, ":") do
        [src_ref, dst_ref] ->
          src = Eoo.Utils.extract_coordinate(src_ref)
          dst = Eoo.Utils.extract_coordinate(dst_ref)
          sk = {src.row, src.column}
          if Map.has_key?(cells, sk) do
            for r <- src.row..dst.row, c <- src.column..dst.column,
                r != src.row or c != src.column, into: acc do
              {{r, c}, sk}
            end
          else; acc end
        _ -> acc
      end
    end)
    Enum.reduce(merges, cells, fn {dst, src}, acc -> Map.put(acc, dst, Map.get(acc, src)) end)
  end
end
