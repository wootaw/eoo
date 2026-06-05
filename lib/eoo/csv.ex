defmodule Eoo.CSV do
  @moduledoc """
  CSV 文件解析器。

  实现了 `Eoo.Base` 行为，不依赖外部 CSV 库。
  """

  @behaviour Eoo.Base

  defstruct [
    :filename,
    :options,
    :default_sheet,
    cells: %{},
    cell_types: %{},
    cells_read: false,
    first_row: nil,
    last_row: nil,
    first_column: nil,
    last_column: nil,
    sheets: ["default"]
  ]

  @type t :: %__MODULE__{
          filename: String.t(),
          options: Keyword.t(),
          default_sheet: String.t() | nil,
          cells: map(),
          cell_types: map(),
          cells_read: boolean(),
          first_row: pos_integer() | nil,
          last_row: pos_integer() | nil,
          first_column: pos_integer() | nil,
          last_column: pos_integer() | nil,
          sheets: [String.t()]
        }

  def open(filename, options \\ []) do
    unless File.exists?(filename),
      do: raise(Eoo.FileNotFound, message: "file #{filename} does not exist")

    csv_opts = Keyword.get(options, :csv_options, [])
    separator = Keyword.get(csv_opts, :separator, ",")

    csv =
      %__MODULE__{filename: filename, options: options}
      |> read_all_cells(separator)

    {:ok, csv}
  end

  # Eoo.Base callbacks
  @spec sheets(t()) :: [String.t()]
  def sheets(csv), do: csv.sheets
  @spec default_sheet(t()) :: String.t()
  def default_sheet(csv), do: csv.default_sheet || "default"

  def default_sheet(csv, sheet) when is_binary(sheet) do
    if sheet in csv.sheets,
      do: {:ok, %{csv | default_sheet: sheet}},
      else: {:error, "sheet '#{sheet}' not found"}
  end

  def default_sheet(csv, index) when is_integer(index) do
    s = Enum.at(csv.sheets, index)
    if s, do: {:ok, %{csv | default_sheet: s}}, else: {:error, "sheet index #{index} not found"}
  end

  @spec cell(t(), pos_integer(), pos_integer(), String.t() | nil) :: any()
  def cell(csv, row, col, _sheet \\ nil), do: Map.get(csv.cells, {row, col})
  def celltype(csv, row, col, _sheet \\ nil), do: Map.get(csv.cell_types, {row, col}, :string)

  def row(csv, row_number, _sheet \\ nil) do
    f = csv.first_column || 1
    l = csv.last_column || 1
    Enum.map(f..l, fn c -> cell(csv, row_number, c) end)
  end

  def column(csv, col, sheet \\ nil)

  def column(csv, col_number, _sheet) when is_integer(col_number) do
    f = csv.first_row || 1
    l = csv.last_row || 1
    Enum.map(f..l, fn r -> cell(csv, r, col_number) end)
  end

  def column(csv, col_letter, _sheet) when is_binary(col_letter) do
    column(csv, Eoo.Utils.letter_to_number(col_letter))
  end

  def first_row(csv, _sheet \\ nil), do: csv.first_row
  def last_row(csv, _sheet \\ nil), do: csv.last_row
  def first_column(csv, _sheet \\ nil), do: csv.first_column
  def last_column(csv, _sheet \\ nil), do: csv.last_column

  def empty?(csv, row, col, _sheet \\ nil) do
    v = cell(csv, row, col)

    is_nil(v) or (is_binary(v) and v == "") or
      row < (csv.first_row || 1) or row > (csv.last_row || 1) or
      col < (csv.first_column || 1) or col > (csv.last_column || 1)
  end

  def set(csv, row, col, value, _sheet \\ nil) do
    ct = if is_integer(value), do: :float, else: :string

    {:ok,
     %{
       csv
       | cells: Map.put(csv.cells, {row, col}, value),
         cell_types: Map.put(csv.cell_types, {row, col}, ct)
     }}
  end

  @spec reload(t()) :: {:ok, t()}
  def reload(csv) do
    csv_opts = Keyword.get(csv.options, :csv_options, [])
    sep = Keyword.get(csv_opts, :separator, ",")
    {:ok, read_all_cells(%{csv | cells: %{}, cell_types: %{}, cells_read: false}, sep)}
  end

  @spec close(t()) :: :ok
  def close(_csv), do: :ok
  def formula(_, _, _, _ \\ nil), do: nil
  def formula?(_, _, _, _ \\ nil), do: false
  def formulas(_, _ \\ nil), do: []
  def font(_, _, _, _ \\ nil), do: nil
  def hyperlink(_, _, _, _ \\ nil), do: nil
  def hyperlink?(_, _, _, _ \\ nil), do: false
  def comment(_, _, _, _ \\ nil), do: nil
  def comments(_, _ \\ nil), do: []
  def label(_, _), do: nil
  def labels(_), do: []

  # Private: simple CSV parser
  defp read_all_cells(csv, separator) do
    {cells, types, max_col} =
      csv.filename
      |> File.stream!()
      |> Enum.map(&String.trim_trailing(&1, "\n"))
      |> Enum.with_index(1)
      |> Enum.reduce({%{}, %{}, 0}, fn {line, row_num}, {c_acc, t_acc, mc} ->
        fields = parse_csv_line(line, hd(String.to_charlist(separator)))

        Enum.reduce(Enum.with_index(fields, 1), {c_acc, t_acc, mc}, fn {val, cn}, {ca, ta, m} ->
          type = type_class(val)
          {Map.put(ca, {row_num, cn}, val), Map.put(ta, {row_num, cn}, type), max(m, cn)}
        end)
      end)

    row_count = if cells == %{}, do: 0, else: Enum.max(for {r, _} <- Map.keys(cells), do: r)

    %{
      csv
      | cells: cells,
        cell_types: types,
        cells_read: true,
        first_row: if(row_count > 0, do: 1),
        last_row: if(row_count > 0, do: row_count),
        first_column: if(max_col > 0, do: 1),
        last_column: if(max_col > 0, do: max_col)
    }
  end

  # Simple CSV line parser (handles quoted fields)
  # Simple CSV line parser (handles quoted fields with escaped quotes)
  defp parse_csv_line(line, separator) do
    parse_csv_fields(String.to_charlist(line), separator, [], [], false)
    |> Enum.map(&List.to_string/1)
  end

  defp parse_csv_fields([], _sep, acc, cur, _in_quote), do: acc ++ [Enum.reverse(cur)]

  defp parse_csv_fields([?\" | rest], sep, acc, cur, false),
    do: parse_csv_fields(rest, sep, acc, cur, true)

  defp parse_csv_fields([?\" | rest], sep, acc, cur, true) do
    case rest do
      [?\" | rest2] -> parse_csv_fields(rest2, sep, acc, [?\" | cur], true)
      _ -> parse_csv_fields(rest, sep, acc, cur, false)
    end
  end

  defp parse_csv_fields([c | rest], sep, acc, cur, in_quote) when c == sep and not in_quote do
    parse_csv_fields(rest, sep, acc ++ [Enum.reverse(cur)], [], false)
  end

  defp parse_csv_fields([c | rest], sep, acc, cur, in_quote) do
    parse_csv_fields(rest, sep, acc, [c | cur], in_quote)
  end

  defp type_class(v) when is_binary(v) do
    case Float.parse(v) do
      {_, ""} -> :float
      _ -> :string
    end
  end

  defp type_class(_), do: :string
end
