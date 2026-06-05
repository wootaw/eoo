defmodule Eoo.Excelx.Workbook do
  @moduledoc """
  解析 workbook.xml，提取 sheet 信息、defined names、base_date。
  """

  defstruct [:path, :doc]

  alias Eoo.XML

  def new(path) do
    unless File.exists?(path) do
      raise ArgumentError, "missing required workbook file: #{path}"
    end

    doc = File.read!(path) |> XML.parse()
    %__MODULE__{path: path, doc: doc}
  end

  def sheets(%__MODULE__{doc: doc}) do
    doc
    |> XML.children_by_tag("sheets")
    |> List.first()
    |> case do
      nil -> []
      elem -> XML.children_by_tag(elem, "sheet")
    end
    |> Enum.map(fn sheet ->
      %{
        name: XML.attr(sheet, "name"),
        sheetId: XML.attr(sheet, "sheetId"),
        state: XML.attr(sheet, "state") || "visible",
        id: XML.attr(sheet, "id")
      }
    end)
  end

  def defined_names(%__MODULE__{doc: doc}) do
    doc
    |> find_all("definedName")
    |> Enum.reduce(%{}, fn dn, acc ->
      name = XML.attr(dn, "name")
      text = XML.text(dn) || ""

      case String.split(text, "!$", parts: 2) do
        [sheet, coords] ->
          case String.split(coords, "$") do
            [col, row] ->
              Map.put(acc, name, %{
                name: name,
                sheet: sheet,
                row: String.to_integer(row),
                col: Eoo.Utils.letter_to_number(col)
              })

            _ ->
              acc
          end

        _ ->
          acc
      end
    end)
  end

  # Recursive find all elements with given tag name (preserves original element)
  defp find_all({:xmlElement, name, _, _, _, _, _, _, children, _, _, _} = elem, tag) do
    t = String.to_atom(tag)
    direct = if name == t, do: [elem], else: []
    direct ++ find_all(children, tag)
  end

  defp find_all(list, tag) when is_list(list) do
    Enum.flat_map(list, &find_all(&1, tag))
  end

  defp find_all(_, _), do: []

  def base_date(%__MODULE__{doc: doc}) do
    result = ~D[1899-12-30]

    case XML.children_by_tag(doc, "workbookPr") do
      [pr | _] ->
        date1904 = XML.attr(pr, "date1904") || ""
        if date1904 =~ ~r/true|1/i, do: ~D[1904-01-01], else: result

      _ ->
        result
    end
  end

  def base_timestamp(%__MODULE__{doc: doc} = _wb) do
    d = base_date(%__MODULE__{doc: doc})
    {y, m, day} = Date.to_erl(d)
    :calendar.date_to_gregorian_days(y, m, day) * 86400
  end
end
