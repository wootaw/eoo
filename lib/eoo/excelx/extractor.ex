defmodule Eoo.Excelx.Extractor do
  @moduledoc """
  XML 提取器基类。提供 XML 文档的惰性加载和缓存。
  """

  defstruct [:path, :options, :doc_cache]

  def new(path, options \\ []), do: %__MODULE__{path: path, options: options}

  def doc(%__MODULE__{path: path, doc_cache: nil} = ext) do
    doc = File.read!(path) |> Eoo.XML.parse()
    %{ext | doc_cache: doc}
  end

  def doc(%__MODULE__{doc_cache: doc}), do: doc

  def doc_exists?(%__MODULE__{path: nil}), do: false
  def doc_exists?(%__MODULE__{path: path}), do: path != nil and File.exists?(path)
end
