defmodule Eoo.Excelx.Relationships do
  @moduledoc """
  解析 .xml.rels 关系文件。
  """

  defstruct [:path, :relationships]

  alias Eoo.XML

  def new(path), do: %__MODULE__{path: path}

  def get(%__MODULE__{relationships: nil} = rels, id),
    do: get(%{rels | relationships: extract_relationships(rels)}, id)

  def get(%__MODULE__{relationships: rels}, id),
    do: Map.get(rels, id)

  def to_map(%__MODULE__{relationships: nil} = rels), do: extract_relationships(rels)
  def to_map(%__MODULE__{relationships: rels}), do: rels

  def include_type?(%__MODULE__{} = rels, type) do
    rels
    |> to_map()
    |> Enum.any?(fn {_, rel} ->
      type_str = rel["Type"] || ""
      String.contains?(type_str, type)
    end)
  end

  defp extract_relationships(%__MODULE__{path: nil}), do: %{}

  defp extract_relationships(%__MODULE__{path: path}) do
    unless File.exists?(path) do
      %{}
    else
      path
      |> File.read!()
      |> XML.parse()
      |> find_rels()
      |> Enum.reduce(%{}, fn rel, acc ->
        id = XML.attr(rel, "Id")
        type = XML.attr(rel, "Type")
        target = XML.attr(rel, "Target")
        Map.put(acc, id, %{"Id" => id, "Type" => type, "Target" => target})
      end)
    end
  end

  defp find_rels(doc) do
    # Recursive search for Relationship elements
    do_find(doc, "Relationship", [])
  end

  defp do_find({:xmlElement, name, _, _, _, _, _, _, children, _, _, _} = elem, tag, acc) do
    acc = if to_string(name) == tag, do: acc ++ [elem], else: acc
    Enum.reduce(children, acc, fn c, a -> do_find(c, tag, a) end)
  end

  defp do_find(list, tag, acc) when is_list(list) do
    Enum.reduce(list, acc, fn c, a -> do_find(c, tag, a) end)
  end

  defp do_find(_, _, acc), do: acc
end
