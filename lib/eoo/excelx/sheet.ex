defmodule Eoo.Excelx.Sheet do
  @moduledoc """
  表示 XLSX 中的一个工作表。

  提供了单元格访问、行列遍历、超链接、批注等功能。
  """

  defstruct [
    :name,
    :shared,
    :sheet_index,
    :sheet_doc,
    :rels,
    :comments,
    :images,
    :cells_cache,
    :first_row_cache,
    :last_row_cache,
    :first_column_cache,
    :last_column_cache,
    :hyperlinks_cache
  ]

  @type t :: %__MODULE__{
          name: String.t(),
          shared: Eoo.Excelx.Shared.t(),
          sheet_index: non_neg_integer(),
          sheet_doc: Eoo.Excelx.SheetDoc.t(),
          rels: Eoo.Excelx.Relationships.t(),
          comments: Eoo.Excelx.Comments.t(),
          images: map(),
          cells_cache: map() | nil,
          first_row_cache: pos_integer() | nil,
          last_row_cache: pos_integer() | nil,
          first_column_cache: pos_integer() | nil,
          last_column_cache: pos_integer() | nil,
          hyperlinks_cache: map() | nil
        }

  def new(name, shared, sheet_index, options \\ []) do
    tmpdir = shared.dir
    idx = sheet_index + 1

    sheet_file =
      Enum.at(shared.sheet_files, sheet_index) ||
        Path.join(tmpdir, "roo_sheet#{idx}")

    rels_file =
      Enum.at(shared.rels_files, sheet_index) ||
        Path.join(tmpdir, "roo_rels#{idx}")

    comments_file =
      Enum.at(shared.comments_files, sheet_index) ||
        Path.join(tmpdir, "roo_comments#{idx}")

    image_rel_file =
      Enum.at(shared.image_rels, sheet_index) ||
        Path.join(tmpdir, "roo_image_rels#{idx}")

    rels = Eoo.Excelx.Relationships.new(rels_file)
    comments = Eoo.Excelx.Comments.new(comments_file)
    images_mod = Eoo.Excelx.Images.new(image_rel_file)

    sheet_doc = Eoo.Excelx.SheetDoc.new(sheet_file, rels, shared, options)

    %__MODULE__{
      name: name,
      shared: shared,
      sheet_index: sheet_index,
      sheet_doc: sheet_doc,
      rels: rels,
      comments: comments,
      images: Eoo.Excelx.Images.list(images_mod)
    }
  end

  @doc """
  获取所有单元格映射。
  """
  def cells(%__MODULE__{cells_cache: nil} = sheet) do
    sheet_doc = sheet.sheet_doc
    cells = Eoo.Excelx.SheetDoc.cells(sheet_doc)
    %{sheet | cells_cache: cells}
  end

  def cells(%__MODULE__{} = sheet), do: sheet

  @doc """
  获取指定行的值列表。
  """
  def row(%__MODULE__{} = sheet, row_number) do
    first = first_column(sheet)
    last = last_column(sheet)
    sheet_with_cells = cells(sheet)

    first..last
    |> Enum.map(fn col ->
      case Map.get(sheet_with_cells.cells_cache, {row_number, col}) do
        nil -> nil
        cell -> cell.value
      end
    end)
  end

  @doc """
  获取指定列的值列表。
  """
  def column(%__MODULE__{} = sheet, col_number) do
    first = first_row(sheet)
    last = last_row(sheet)
    sheet_with_cells = cells(sheet)

    first..last
    |> Enum.map(fn row ->
      case Map.get(sheet_with_cells.cells_cache, {row, col_number}) do
        nil -> nil
        cell -> cell.value
      end
    end)
  end

  @doc """
  第一行。
  """
  def first_row(%__MODULE__{first_row_cache: nil} = sheet) do
    fl = first_last_row_col(sheet)
    fl.first_row
  end

  def first_row(%__MODULE__{first_row_cache: fr}), do: fr

  @doc """
  最后一行。
  """
  def last_row(%__MODULE__{last_row_cache: nil} = sheet) do
    fl = first_last_row_col(sheet)
    fl.last_row
  end

  def last_row(%__MODULE__{last_row_cache: lr}), do: lr

  @doc """
  第一列。
  """
  def first_column(%__MODULE__{first_column_cache: nil} = sheet) do
    fl = first_last_row_col(sheet)
    fl.first_column
  end

  def first_column(%__MODULE__{first_column_cache: fc}), do: fc

  @doc """
  最后一列。
  """
  def last_column(%__MODULE__{last_column_cache: nil} = sheet) do
    fl = first_last_row_col(sheet)
    fl.last_column
  end

  def last_column(%__MODULE__{last_column_cache: lc}), do: lc

  @doc """
  获取超链接映射。
  """
  def hyperlinks(%__MODULE__{hyperlinks_cache: nil} = sheet) do
    sheet_doc = sheet.sheet_doc
    rels = sheet.rels
    rels_map = Eoo.Excelx.Relationships.to_map(rels)
    Eoo.Excelx.SheetDoc.hyperlinks(sheet_doc, rels_map)
  end

  def hyperlinks(%__MODULE__{hyperlinks_cache: hls}), do: hls

  @doc """
  获取批注映射。
  """
  def comments(%__MODULE__{comments: comments_mod}) do
    Eoo.Excelx.Comments.comments(comments_mod)
  end

  @doc """
  获取格式代码。
  """
  def excelx_format(%__MODULE__{} = sheet, key) do
    sheet_with_cells = cells(sheet)
    cell = Map.get(sheet_with_cells.cells_cache, key)

    if cell do
      styles = Eoo.Excelx.Shared.styles(sheet.shared)
      Eoo.Excelx.Styles.style_format(styles, cell.style)
    end
  end

  @doc """
  获取维度字符串。
  """
  def dimensions(%__MODULE__{sheet_doc: sd}) do
    Eoo.Excelx.SheetDoc.dimensions(sd)
  end

  # ── 私有函数 ────────────────────────────────────────────

  defp first_last_row_col(%__MODULE__{} = sheet) do
    sheet_with_cells = cells(sheet)

    {first_row, last_row, first_col, last_col} =
      sheet_with_cells.cells_cache
      |> Enum.reduce({nil, nil, nil, nil}, fn {{r, c}, cell}, {fr, lr, fc, lc} ->
        if cell && presence?(cell) do
          nr = if fr == nil or r < fr, do: r, else: fr
          nr_lr = if lr == nil or r > lr, do: r, else: lr
          nc = if fc == nil or c < fc, do: c, else: fc
          nc_lc = if lc == nil or c > lc, do: c, else: lc
          {nr, nr_lr, nc, nc_lc}
        else
          {fr, lr, fc, lc}
        end
      end)

    %{first_row: first_row, last_row: last_row, first_column: first_col, last_column: last_col}
  end

  defp presence?(cell) do
    not is_nil(cell) and (not function_exported?(cell, :empty?, 1) or not cell.empty?())
  rescue
    _ -> true
  end
end
