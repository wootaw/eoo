defmodule Eoo.Spreadsheet do
  @moduledoc """
  电子表格工厂。根据文件扩展名自动选择解析器。

  ## 示例

      iex> {:ok, ss} = Eoo.Spreadsheet.open("file.xlsx")
      iex> ss.sheets()
      ["Sheet1", "Sheet2"]

  支持选项见各解析器模块。
  """

  @doc """
  打开电子表格文件，自动检测格式。

  返回 `{:ok, spreadsheet}` 或 `{:error, reason}`。
  """
  @spec open(String.t(), keyword()) :: {:ok, module()} | {:error, term()}
  def open(path, options \\ []) do
    ext = extension_for(path, options)

    case Eoo.class_for_extension(ext) do
      {:error, _} = err ->
        err

      module ->
        module.open(path, options)
    end
  end

  @doc """
  打开电子表格文件，失败时抛出异常。
  """
  @spec open!(String.t(), keyword()) :: module()
  def open!(path, options \\ []) do
    case open(path, options) do
      {:ok, ss} -> ss
      {:error, reason} -> raise reason
    end
  end

  @doc """
  从文件路径提取扩展名。
  """
  @spec extension_for(String.t(), keyword()) :: atom()
  def extension_for(path, options) do
    case Keyword.get(options, :extension) do
      ext when is_atom(ext) and not is_nil(ext) ->
        ext

      ext when is_binary(ext) ->
        ext |> String.trim_leading(".") |> String.downcase() |> String.to_atom()

      _ ->
        path
        |> Path.extname()
        |> String.trim_leading(".")
        |> String.downcase()
        |> String.to_atom()
    end
  end
end
