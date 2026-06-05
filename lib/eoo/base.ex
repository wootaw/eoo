defmodule Eoo.Base do
  @moduledoc """
  所有电子表格类型的通用行为定义和辅助函数。
  """

  # ── 回调定义 ─────────────────────────────────────────────

  @callback sheets(term()) :: [String.t()]
  @callback default_sheet(term()) :: String.t()
  @callback default_sheet(term(), String.t() | integer()) :: {:ok, term()} | {:error, String.t()}
  @callback cell(term(), pos_integer(), pos_integer(), String.t() | nil) :: any()
  @callback celltype(term(), pos_integer(), pos_integer(), String.t() | nil) :: atom()
  @callback row(term(), pos_integer(), String.t() | nil) :: [any()]
  @callback column(term(), pos_integer() | String.t(), String.t() | nil) :: [any()]
  @callback first_row(term(), String.t() | nil) :: pos_integer() | nil
  @callback last_row(term(), String.t() | nil) :: pos_integer() | nil
  @callback first_column(term(), String.t() | nil) :: pos_integer() | nil
  @callback last_column(term(), String.t() | nil) :: pos_integer() | nil
  @callback empty?(term(), pos_integer(), pos_integer(), String.t() | nil) :: boolean()
  @callback set(term(), pos_integer(), pos_integer(), any(), String.t() | nil) :: {:ok, term()}
  @callback reload(term()) :: {:ok, term()}
  @callback close(term()) :: :ok
  @callback formula(term(), pos_integer(), pos_integer(), String.t() | nil) :: String.t() | nil
  @callback formula?(term(), pos_integer(), pos_integer(), String.t() | nil) :: boolean()
  @callback formulas(term(), String.t() | nil) :: [{pos_integer(), pos_integer(), String.t()}]
  @callback font(term(), pos_integer(), pos_integer(), String.t() | nil) :: term() | nil
  @callback hyperlink(term(), pos_integer(), pos_integer(), String.t() | nil) :: String.t() | nil
  @callback hyperlink?(term(), pos_integer(), pos_integer(), String.t() | nil) :: boolean()
  @callback comment(term(), pos_integer(), pos_integer(), String.t() | nil) :: String.t() | nil
  @callback comments(term(), String.t() | nil) :: [{pos_integer(), pos_integer(), String.t()}]
  @callback label(term(), String.t()) :: {pos_integer(), pos_integer(), String.t()} | nil
  @callback labels(term()) :: [{String.t(), {pos_integer(), pos_integer(), String.t()}}]

  @optional_callbacks [
    formula: 4, formula?: 4, formulas: 2, font: 4,
    hyperlink: 4, hyperlink?: 4, comment: 4, comments: 2, label: 2, labels: 1
  ]

  # ── 动态分发 ────────────────────────────────────────────

  defp mod(spreadsheet), do: spreadsheet.__struct__

  # ── info ────────────────────────────────────────────────

  @doc """
  返回文档信息的字符串。
  """
  def info(spreadsheet) do
    m = mod(spreadsheet)
    sheet_list = apply(m, :sheets, [spreadsheet])
    info_text = "File: #{inspect(spreadsheet)}\n" <>
      "Number of sheets: #{length(sheet_list)}\n" <>
      "Sheets: #{Enum.join(sheet_list, ", ")}\n"

    {final_text, _} =
      Enum.reduce(sheet_list, {info_text, 1}, fn sheet, {acc, n} ->
        ss = apply(m, :default_sheet, [spreadsheet, sheet]) |> elem(1)
        fr = apply(m, :first_row, [ss])
        sheet_info =
          case fr do
            nil -> "  - empty -"
            _ ->
              lr = apply(m, :last_row, [ss])
              fc = apply(m, :first_column, [ss])
              lc = apply(m, :last_column, [ss])
              "  First row: #{fr}\n" <>
              "  Last row: #{lr}\n" <>
              "  First column: #{Eoo.Utils.number_to_letter(fc)}\n" <>
              "  Last column: #{Eoo.Utils.number_to_letter(lc)}"
          end
        sep = if sheet != List.last(sheet_list), do: "\n", else: ""
        {acc <> "Sheet #{n}:\n#{sheet_info}#{sep}", n + 1}
      end)
    final_text
  end

  # ── each_with_pagename ──────────────────────────────────

  @doc """
  迭代每个工作表，返回 {sheet_name, spreadsheet} 元组。
  """
  def each_with_pagename(spreadsheet, fun) when is_function(fun, 2) do
    m = mod(spreadsheet)
    for sheet_name <- apply(m, :sheets, [spreadsheet]) do
      ss = apply(m, :default_sheet, [spreadsheet, sheet_name]) |> elem(1)
      fun.(sheet_name, ss)
    end
  end

  # ── each ────────────────────────────────────────────────

  @doc """
  迭代所有行。

  支持选项：
  - `:headers` - 将行转为 key-value map
  - `:header_search` - 搜索表头行
  """
  def each(spreadsheet, options \\ [], fun) when is_function(fun, 1) do
    m = mod(spreadsheet)
    last = apply(m, :last_row, [spreadsheet])

    if options == [] or options[:headers] == true do
      for row_num <- 1..last do
        fun.(apply(m, :row, [spreadsheet, row_num]))
      end
    else
      headers = build_headers(m, spreadsheet, options)
      first = apply(m, :first_row, [spreadsheet])

      for row_num <- first..last do
        row_map =
          Enum.reduce(headers, %{}, fn {key, col}, acc ->
            Map.put(acc, key, apply(m, :cell, [spreadsheet, row_num, col]))
          end)
        fun.(row_map)
      end
    end
  end

  # ── parse ───────────────────────────────────────────────

  @doc """
  解析所有行为数组。
  """
  def parse(spreadsheet, options \\ []) do
    results = each(spreadsheet, options, fn row -> row end)

    if options[:headers] == true do
      results
    else
      Enum.drop(results, 1)
    end
  end

  # ── 私有辅助 ────────────────────────────────────────────

  defp build_headers(m, spreadsheet, options) do
    header_line = options[:header_line] || 1

    if options[:header_search] do
      header_row_num = find_header_row(m, spreadsheet, options[:header_search])
      ss = apply(m, :default_sheet, [spreadsheet, header_row_num]) |> elem(1)
      build_headers_from_row(m, ss, header_row_num, options)
    else
      options
      |> Enum.filter(fn {_k, v} -> is_binary(v) or is_struct(v, Regex) end)
      |> Enum.map(fn {key, query} ->
        col = find_column_for_header(m, spreadsheet, header_line, query)
        {key, col}
      end)
      |> Enum.filter(fn {_k, col} -> col != nil end)
    end
  end

  defp find_column_for_header(m, spreadsheet, row_num, query) do
    first = apply(m, :first_column, [spreadsheet])
    last = apply(m, :last_column, [spreadsheet])

    first..last
    |> Enum.find(fn col ->
      cell_val = apply(m, :cell, [spreadsheet, row_num, col])
      if is_struct(query, Regex) do
        cell_val && String.match?(to_string(cell_val), query)
      else
        cell_val == query
      end
    end)
  end

  defp find_header_row(m, spreadsheet, queries) do
    1..100
    |> Enum.find(fn row_num ->
      row = apply(m, :row, [spreadsheet, row_num])
      Enum.all?(queries, fn q ->
        Enum.any?(row, fn cell ->
          cell && String.match?(to_string(cell), q)
        end)
      end)
    end)
  end

  defp build_headers_from_row(m, spreadsheet, row_num, _options) do
    first = apply(m, :first_column, [spreadsheet])
    last = apply(m, :last_column, [spreadsheet])

    first..last
    |> Enum.reduce(%{}, fn col, acc ->
      header_name = apply(m, :cell, [spreadsheet, row_num, col])
      if header_name, do: Map.put(acc, header_name, col), else: acc
    end)
  end
end
