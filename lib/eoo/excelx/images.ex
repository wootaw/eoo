defmodule Eoo.Excelx.Images do
  @moduledoc """
  解析图片关系文件，提取嵌入图片列表。
  """

  defstruct [:path, :list]

  alias Eoo.XML

  def new(path), do: %__MODULE__{path: path}

  def list(%__MODULE__{list: nil} = img), do: extract_images_names(img)
  def list(%__MODULE__{list: lst}), do: lst

  defp extract_images_names(%__MODULE__{path: nil}), do: %{}
  defp extract_images_names(%__MODULE__{path: path}) do
    unless File.exists?(path) do
      %{}
    else
      path
      |> File.read!()
      |> XML.parse()
      |> find_rels()
      |> Enum.reduce(%{}, fn rel, acc ->
        id = XML.attr(rel, "Id")
        target = XML.attr(rel, "Target") || ""
        name = "roo" <> String.replace(target, ["../", "/"], "_")
        Map.put(acc, id, name)
      end)
    end
  end

  defp find_rels(doc), do: do_find(doc, "Relationship", [])

  defp do_find({:xmlElement, name, _, _, _, _, _, _, children, _, _, _} = elem, tag, acc) do
    acc = if to_string(name) == tag, do: acc ++ [elem], else: acc
    Enum.reduce(children, acc, fn c, a -> do_find(c, tag, a) end)
  end
  defp do_find(list, tag, acc) when is_list(list) do
    Enum.reduce(list, acc, fn c, a -> do_find(c, tag, a) end)
  end
  defp do_find(_, _, acc), do: acc
end
