defmodule Eoo.XML do
  @moduledoc """
  XML 解析辅助模块。封装 Erlang 的 :xmerl，提供类似 SweetXml 的接口。
  """

  @doc """
  解析 XML 二进制字符串，返回简化后的文档树。
  自动移除所有命名空间前缀。
  """
  def parse(xml_binary) when is_binary(xml_binary) do
    # 移除 xmlns 属性声明
    stripped = Regex.replace(~r/\s+xmlns[^=]*="[^"]*"/, xml_binary, "")
    # 移除命名空间前缀 (如 <s:sheet> → <sheet>)
    stripped = Regex.replace(~r{<\w+:}, stripped, "<")
    stripped = Regex.replace(~r{</\w+:}, stripped, "</")

    {elements, _} = :xmerl_scan.string(String.to_charlist(stripped))
    elements
  end

  def parse_xml(xml_binary), do: parse(xml_binary)

  @doc """
  XPath 查询。返回匹配的元素列表。
  """
  def xpath(_doc, nil), do: []
  def xpath(_doc, ""), do: []

  def xpath(doc, expression) when is_list(doc) do
    Enum.flat_map(doc, &xpath(&1, expression))
  end

  def xpath(doc, expression) do
    try do
      result = :xmerl_xpath.string(doc, String.to_charlist(expression))
      result
    rescue
      _ -> []
    end
  end

  @doc """
  获取元素的文本内容。
  """
  def text({:xmlText, _value, _, _, text, _}) do
    List.to_string(text)
  end

  def text({:xmlElement, _name, _, _, _, _, _, _, children, _, _, _}) do
    extract_text(children)
  end

  def text(list) when is_list(list) do
    extract_text(list)
  end

  def text(nil), do: nil
  def text(other), do: to_string(other)

  @doc """
  获取元素的属性值。
  """
  def attr(element, attr_name) do
    case element do
      {:xmlElement, _name, _, _, _, _, _, attributes, _, _, _, _} when is_list(attributes) ->
        find_attr_value(attributes, attr_name)

      {:xmlElement, _, _, _, _, _, _, _, _, _, _, _} ->
        nil

      list when is_list(list) ->
        case list do
          [el | _] -> attr(el, attr_name)
          _ -> nil
        end

      _ ->
        nil
    end
  end

  @doc """
  获取指定标签名的子元素列表。
  """
  def children_by_tag(element, tag) when is_list(element) do
    Enum.flat_map(element, &children_by_tag(&1, tag))
  end

  def children_by_tag({:xmlElement, _name, _, _, _, _, _, _, children, _, _, _}, tag) do
    tag_atom = String.to_atom(to_string(tag))
    Enum.filter(children, fn
      {:xmlElement, child_name, _, _, _, _, _, _, _, _, _, _} ->
        child_name == tag_atom
      _ ->
        false
    end)
  end

  def children_by_tag(_, _), do: []

  @doc """
  获取所有子元素。
  """
  def children({:xmlElement, _name, _, _, _, _, _, _, children, _, _, _}) do
    Enum.filter(children, fn
      {:xmlElement, _, _, _, _, _, _, _, _, _, _, _} -> true
      _ -> false
    end)
  end


  def children(_), do: []
  @doc """
  获取指定标签名的第一个子元素文本。
  """
  def child_text(element, tag) do
    element
    |> children_by_tag(tag)
    |> List.first()
    |> text()
  end


  @doc """
  获取元素名（原子转字符串）。
  """
  def name({:xmlElement, name, _, _, _, _, _, _, _, _, _, _}), do: to_string(name)
  def name({:xmlText, _, _, _, _, _}), do: "text"
  def name(_), do: nil

  # 私有

  defp extract_text([]), do: ""

  defp extract_text([{:xmlText, _pos, _, _, text, _} | rest]) do
    List.to_string(text) <> extract_text(rest)
  end

  defp extract_text([{:xmlElement, _, _, _, _, _, _, _, children, _, _, _} | rest]) do
    extract_text(children) <> extract_text(rest)
  end

  defp extract_text([_ | rest]) do
    extract_text(rest)
  end

  defp find_attr_value([], _name), do: nil

  defp find_attr_value([{:xmlAttribute, aname, _, _, _, _, _, _, value, _} | rest], attr_name) when is_list(value) do
    if to_string(aname) == attr_name do
      List.to_string(value)
    else
      find_attr_value(rest, attr_name)
    end
  end

  defp find_attr_value([_ | rest], name) do
    find_attr_value(rest, name)
  end
end
