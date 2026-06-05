defmodule Eoo.Excelx do
  @moduledoc """
  XLSX / XLSM 文件解析器。

  实现了 `Eoo.Base` 行为。

  ## 示例

      {:ok, xlsx} = Eoo.Excelx.open("file.xlsx")
      xlsx.sheets()              # => ["Sheet1", "Sheet2"]
      xlsx.cell(1, 1)            # => 左上角单元格值
      xlsx.row(1)                # => 第一行

  ## 选项

    - `:expand_merged_ranges` - 展开合并单元格 (默认 false)
    - `:only_visible_sheets` - 只加载可见工作表 (默认 false)
    - `:cell_max` - 单元格数量上限检查
    - `:no_hyperlinks` - 跳过超链接解析 (默认 false)
    - `:empty_cell` - 返回空单元格对象 (默认 false)
    - `:packed` - :zip 表示压缩包
    - `:file_warning` - :error | :warning | :ignore
    - `:tmpdir_root` - 临时目录根路径
  """

  @behaviour Eoo.Base

  defstruct [
    :filename,
    :shared,
    :tmpdir,
    :options,
    sheet_names: [],
    sheets: [],
    sheets_by_name: %{},
    default_sheet_name: nil
  ]

  @type t :: %__MODULE__{
          filename: String.t(),
          shared: Eoo.Excelx.Shared.t(),
          tmpdir: String.t(),
          options: Keyword.t(),
          sheet_names: [String.t()],
          sheets: [Eoo.Excelx.Sheet.t()],
          sheets_by_name: %{String.t() => Eoo.Excelx.Sheet.t()},
          default_sheet_name: String.t() | nil
        }

  @doc """
  打开一个 XLSX / XLSM 文件。
  """
  @spec open(String.t(), keyword()) :: {:ok, t()} | {:error, term()}
  def open(filename_or_stream, options \\ []) do
    try do
      packed = Keyword.get(options, :packed)
      file_warning = Keyword.get(options, :file_warning, :error)
      cell_max = Keyword.get(options, :cell_max)

      # 文件类型检查
      unless is_stream?(filename_or_stream) do
        file_type_check(filename_or_stream, [".xlsx", ".xlsm"], "an Excel 2007", file_warning, packed)
      end

      basename = find_basename(filename_or_stream)
      tmpdir = make_tempdir(basename, Keyword.get(options, :tmpdir_root))

      shared = Eoo.Excelx.Shared.new(tmpdir, options)

      # 处理 zip 文件
      filename = local_filename(filename_or_stream, tmpdir, packed)
      process_zipfile(filename || filename_or_stream, shared, tmpdir)

      # 读取 workbook
      wb = Eoo.Excelx.Shared.workbook(shared)
      sheet_defs = Eoo.Excelx.Workbook.sheets(wb)

      sheet_options = [
        expand_merged_ranges: Keyword.get(options, :expand_merged_ranges, false),
        no_hyperlinks: Keyword.get(options, :no_hyperlinks, false),
        empty_cell: Keyword.get(options, :empty_cell, false)
      ]

      {sheet_names, sheets, sheets_by_name, _} =
        Enum.reduce(Enum.with_index(sheet_defs), {[], [], %{}, 0}, fn {sheet_def, index},
                                                                      {names, sheet_list, by_name, _} ->
          if Keyword.get(options, :only_visible_sheets, false) and
               Map.get(sheet_def, :state) == "hidden" do
            {names, sheet_list, by_name, index}
          else
            sheet_name = Map.get(sheet_def, :name, "Sheet#{index + 1}")
            sheet = Eoo.Excelx.Sheet.new(sheet_name, shared, index, sheet_options)
            {[sheet_name | names], [sheet | sheet_list], Map.put(by_name, sheet_name, sheet), index}
          end
        end)

      result = %__MODULE__{
        filename: filename,
        shared: shared,
        tmpdir: tmpdir,
        options: options,
        sheet_names: Enum.reverse(sheet_names),
        sheets: Enum.reverse(sheets),
        sheets_by_name: sheets_by_name,
        default_sheet_name: List.first(Enum.reverse(sheet_names))
      }

      # 检查 cell_max
      if cell_max do
        dims = Eoo.Excelx.Sheet.dimensions(hd(result.sheets))
        if dims do
          cell_count = Eoo.Utils.num_cells_in_range(dims)
          if cell_count > cell_max do
            cleanup_tmpdir(tmpdir)
            raise Eoo.ExceedsMaxError, message: "Excel file exceeds cell maximum: #{cell_count} > #{cell_max}"
          end
        end
      end

      {:ok, result}
    rescue
      e -> {:error, e}
    end
  end
  # ── Eoo.Base 回调 ───────────────────────────────────────

  @impl true
  def sheets(%__MODULE__{sheet_names: names}), do: names

  @impl true
  def default_sheet(%__MODULE__{default_sheet_name: nil} = xlsx), do: hd(xlsx.sheet_names)
  def default_sheet(%__MODULE__{default_sheet_name: name}), do: name

  @impl true
  def default_sheet(%__MODULE__{} = xlsx, sheet) when is_binary(sheet) do
    if sheet in xlsx.sheet_names do
      {:ok, %{xlsx | default_sheet_name: sheet}}
    else
      {:error, "sheet '#{sheet}' not found"}
    end
  end

  def default_sheet(%__MODULE__{} = xlsx, index) when is_integer(index) do
    sheet = Enum.at(xlsx.sheet_names, index)

    if sheet do
      {:ok, %{xlsx | default_sheet_name: sheet}}
    else
      {:error, "sheet index #{index} not found"}
    end
  end

  @impl true
  def cell(%__MODULE__{} = xlsx, row, col, sheet \\ nil) do
    s = sheet_name(xlsx, sheet)
    sheet_mod = sheet_for(xlsx, s)
    {r, c} = Eoo.Utils.normalize(row, col)
    cells = Eoo.Excelx.Sheet.cells(sheet_mod)
    cell = Map.get(cells.cells_cache, {r, c})
    cell && cell.value
  end

  @impl true
  def celltype(%__MODULE__{} = xlsx, row, col, sheet \\ nil) do
    s = sheet_name(xlsx, sheet)
    sheet_mod = sheet_for(xlsx, s)
    {r, c} = Eoo.Utils.normalize(row, col)
    cells = Eoo.Excelx.Sheet.cells(sheet_mod)
    cell = Map.get(cells.cells_cache, {r, c})
    cell && cell.__struct__.type(cell)
  end

  @impl true
  def row(%__MODULE__{} = xlsx, row_number, sheet \\ nil) do
    s = sheet_name(xlsx, sheet)
    Eoo.Excelx.Sheet.row(sheet_for(xlsx, s), row_number)
  end

  @impl true
  def column(xlsx, col, sheet \\ nil)

  def column(%__MODULE__{} = xlsx, col, sheet) do
    actual_col = if is_binary(col), do: Eoo.Utils.letter_to_number(col), else: col
    s = sheet_name(xlsx, sheet)
    Eoo.Excelx.Sheet.column(sheet_for(xlsx, s), actual_col)
  end

  @impl true
  def first_row(%__MODULE__{} = xlsx, sheet \\ nil) do
    s = sheet_name(xlsx, sheet)
    Eoo.Excelx.Sheet.first_row(sheet_for(xlsx, s))
  end

  @impl true
  def last_row(%__MODULE__{} = xlsx, sheet \\ nil) do
    s = sheet_name(xlsx, sheet)
    Eoo.Excelx.Sheet.last_row(sheet_for(xlsx, s))
  end

  @impl true
  def first_column(%__MODULE__{} = xlsx, sheet \\ nil) do
    s = sheet_name(xlsx, sheet)
    Eoo.Excelx.Sheet.first_column(sheet_for(xlsx, s))
  end

  @impl true
  def last_column(%__MODULE__{} = xlsx, sheet \\ nil) do
    s = sheet_name(xlsx, sheet)
    Eoo.Excelx.Sheet.last_column(sheet_for(xlsx, s))
  end

  @impl true
  def empty?(%__MODULE__{} = xlsx, row, col, sheet \\ nil) do
    s = sheet_name(xlsx, sheet)
    sheet_mod = sheet_for(xlsx, s)
    {r, c} = Eoo.Utils.normalize(row, col)
    cells = Eoo.Excelx.Sheet.cells(sheet_mod)
    cell = Map.get(cells.cells_cache, {r, c})

    is_nil(cell) or
      cell_empty?(cell) or
      r < Eoo.Excelx.Sheet.first_row(sheet_mod) or
      r > Eoo.Excelx.Sheet.last_row(sheet_mod) or
      c < Eoo.Excelx.Sheet.first_column(sheet_mod) or
      c > Eoo.Excelx.Sheet.last_column(sheet_mod)
  end

  @impl true
  def set(%__MODULE__{} = xlsx, row, col, value, sheet \\ nil) do
    s = sheet_name(xlsx, sheet)
    sheet_mod = sheet_for(xlsx, s)
    {r, c} = Eoo.Utils.normalize(row, col)

    # 创建新单元格对象
    coord_tuple = {r, c}
    new_cell = %Eoo.Excelx.Cell.String{
      value: value,
      formula: nil,
      style: 1,
      coordinate: coord_tuple,
      hyperlink: nil,
      cell_value: value
    }

    cells_mod = Eoo.Excelx.Sheet.cells(sheet_mod)
    new_cells = Map.put(cells_mod.cells_cache, {r, c}, new_cell)
    # 由于目前返回 :ok，我们只是更新内部状态
    {:ok, %{xlsx | sheets_by_name: Map.put(xlsx.sheets_by_name, s, %{sheet_mod | cells_cache: new_cells})}}
  end

  @impl true
  def reload(%__MODULE__{filename: fn_, options: opts}) do
    {:ok, _} = open(fn_, opts)
  end

  @impl true
  def close(%__MODULE__{tmpdir: tmpdir}) do
    cleanup_tmpdir(tmpdir)
    :ok
  end

  # XLSX 特有方法

  @impl true
  def formula(%__MODULE__{} = xlsx, row, col, sheet \\ nil) do
    s = sheet_name(xlsx, sheet)
    sheet_mod = sheet_for(xlsx, s)
    {r, c} = Eoo.Utils.normalize(row, col)
    cells = Eoo.Excelx.Sheet.cells(sheet_mod)
    cell = Map.get(cells.cells_cache, {r, c})
    cell && cell.formula
  end

  @impl true
  def formula?(%__MODULE__{} = xlsx, row, col, sheet \\ nil) do
    not is_nil(formula(xlsx, row, col, sheet))
  end

  @impl true
  def formulas(%__MODULE__{} = xlsx, sheet \\ nil) do
    s = sheet_name(xlsx, sheet)
    sheet_mod = sheet_for(xlsx, s)
    cells = Eoo.Excelx.Sheet.cells(sheet_mod)

    cells.cells_cache
    |> Enum.filter(fn {_k, cell} -> cell.formula end)
    |> Enum.map(fn {{r, c}, cell} -> [r, c, cell.formula] end)
  end

  @impl true
  def font(%__MODULE__{} = xlsx, row, col, sheet \\ nil) do
    s = sheet_name(xlsx, sheet)
    sheet_mod = sheet_for(xlsx, s)
    {r, c} = Eoo.Utils.normalize(row, col)
    cells = Eoo.Excelx.Sheet.cells(sheet_mod)
    cell = Map.get(cells.cells_cache, {r, c})

    if cell && cell.style do
      styles = Eoo.Excelx.Shared.styles(xlsx.shared)
      defs = Eoo.Excelx.Styles.definitions(styles)
      Enum.at(defs, cell.style)
    end
  end

  @impl true
  def hyperlink(%__MODULE__{} = xlsx, row, col, sheet \\ nil) do
    s = sheet_name(xlsx, sheet)
    sheet_mod = sheet_for(xlsx, s)
    {r, c} = Eoo.Utils.normalize(row, col)
    hls = Eoo.Excelx.Sheet.hyperlinks(sheet_mod)
    Map.get(hls, {r, c})
  end

  @impl true
  def hyperlink?(%__MODULE__{} = xlsx, row, col, sheet \\ nil) do
    not is_nil(hyperlink(xlsx, row, col, sheet))
  end

  @impl true
  def comment(%__MODULE__{} = xlsx, row, col, sheet \\ nil) do
    s = sheet_name(xlsx, sheet)
    sheet_mod = sheet_for(xlsx, s)
    {r, c} = Eoo.Utils.normalize(row, col)
    cmts = Eoo.Excelx.Sheet.comments(sheet_mod)
    Map.get(cmts, {r, c})
  end

  @impl true
  def comments(%__MODULE__{} = xlsx, sheet \\ nil) do
    s = sheet_name(xlsx, sheet)
    sheet_mod = sheet_for(xlsx, s)
    cmts = Eoo.Excelx.Sheet.comments(sheet_mod)

    cmts
    |> Enum.map(fn {{r, c}, text} -> [r, c, text] end)
  end

  @impl true
  def label(%__MODULE__{shared: shared}, name) do
    wb = Eoo.Excelx.Shared.workbook(shared)
    defined_names = Eoo.Excelx.Workbook.defined_names(wb)
    label_info = Map.get(defined_names, name)

    if label_info do
      {label_info.row, label_info.col, label_info.sheet}
    end
  end

  @impl true
  def labels(%__MODULE__{shared: shared}) do
    wb = Eoo.Excelx.Shared.workbook(shared)
    defined_names = Eoo.Excelx.Workbook.defined_names(wb)

    defined_names
    |> Enum.map(fn {name, info} ->
      {name, {info.row, info.col, info.sheet}}
    end)
  end

  @doc """
  获取内部 excelx 类型。
  """
  def excelx_type(%__MODULE__{} = xlsx, row, col, sheet \\ nil) do
    s = sheet_name(xlsx, sheet)
    sheet_mod = sheet_for(xlsx, s)
    {r, c} = Eoo.Utils.normalize(row, col)
    cells = Eoo.Excelx.Sheet.cells(sheet_mod)
    cell = Map.get(cells.cells_cache, {r, c})
    cell && cell.cell_type
  end

  @doc """
  获取内部 excelx 值。
  """
  def excelx_value(%__MODULE__{} = xlsx, row, col, sheet \\ nil) do
    s = sheet_name(xlsx, sheet)
    sheet_mod = sheet_for(xlsx, s)
    {r, c} = Eoo.Utils.normalize(row, col)
    cells = Eoo.Excelx.Sheet.cells(sheet_mod)
    cell = Map.get(cells.cells_cache, {r, c})
    cell && cell.cell_value
  end

  @doc """
  获取格式化后的显示值。
  """
  def formatted_value(%__MODULE__{} = xlsx, row, col, sheet \\ nil) do
    s = sheet_name(xlsx, sheet)
    sheet_mod = sheet_for(xlsx, s)
    {r, c} = Eoo.Utils.normalize(row, col)
    cells = Eoo.Excelx.Sheet.cells(sheet_mod)
    cell = Map.get(cells.cells_cache, {r, c})
    cell && cell.__struct__.formatted_value(cell)
  end

  @doc """
  获取内部格式代码。
  """
  def excelx_format(%__MODULE__{} = xlsx, row, col, sheet \\ nil) do
    s = sheet_name(xlsx, sheet)
    sheet_mod = sheet_for(xlsx, s)
    {r, c} = Eoo.Utils.normalize(row, col)
    Eoo.Excelx.Sheet.excelx_format(sheet_mod, {r, c})
  end

  @doc """
  获取嵌入图片列表。
  """
  def images(%__MODULE__{} = xlsx, sheet \\ nil) do
    s = sheet_name(xlsx, sheet)
    sheet_mod = sheet_for(xlsx, s)
    sheet_mod.images
  end

  @doc """
  流式读取行。避免将整个文档加载到内存。

  ## 选项
    - `:offset` - 跳过的行数（默认 0）
    - `:max_rows` - 最大读取行数
    - `:pad_cells` - 是否用 nil 填充空白单元格（默认 false）
    - `:sheet` - 工作表名
  """
  def each_row_streaming(%__MODULE__{} = xlsx, opts \\ []) do
    s = Keyword.get(opts, :sheet, default_sheet(xlsx))
    sheet_mod = sheet_for(xlsx, s)
    path = sheet_mod.sheet_doc.path
    offset = Keyword.get(opts, :offset, 0)
    max_rows = Keyword.get(opts, :max_rows)
    pad_cells = Keyword.get(opts, :pad_cells, false)

    if is_nil(path) or !File.exists?(path) do
      Stream.map([], & &1)
    else
      sheet_xml = File.read!(path)
      {rows, _rest} = Eoo.StreamXML.extract_complete_tags(sheet_xml, "<row", "</row>", [])

      rows
      |> Stream.with_index(1)
      |> Stream.filter(fn {_xml, idx} -> idx > offset end)
      |> Stream.transform(nil, fn {row_xml, idx}, _acc ->
        halt? = max_rows != nil and idx > offset + max_rows
        if halt? do
          {:halt, nil}
        else
          {[stream_row_values(row_xml, pad_cells, xlsx.shared)], nil}
        end
      end)
    end
  end

  defp stream_row_values(row_xml, pad_cells, shared) do
    doc = Eoo.StreamXML.parse_row_xml(row_xml)
    raw = Eoo.StreamXML.extract_cells(doc)

    cols = raw |> Enum.map(fn c -> extract_col(c.ref) end) |> Enum.reject(&is_nil/1)
    first = if cols == [], do: 1, else: Enum.min(cols)
    last  = if cols == [], do: 0, else: Enum.max(cols)

    cell_map =
      raw
      |> Enum.map(fn c -> {extract_col(c.ref), raw_cell_value(c, shared)} end)
      |> Enum.reject(fn {k, _} -> is_nil(k) end)
      |> Enum.into(%{})

    if pad_cells do
      Enum.map(first..last, fn col -> Map.get(cell_map, col) end)
    else
      raw |> Enum.map(fn c -> Map.get(cell_map, extract_col(c.ref)) end)
    end
  end

  defp extract_col(nil), do: nil
  defp extract_col(ref) do
    %{column: c} = Eoo.Utils.extract_coordinate(ref)
    c
  end

  defp raw_cell_value(%{type: "s", value: v}, shared) when is_binary(v) do
    idx = String.to_integer(v)
    ss = Eoo.Excelx.Shared.shared_strings(shared)
    Eoo.Excelx.SharedStrings.get(ss, idx)
  end

  defp raw_cell_value(%{value: v}, _shared) when is_binary(v) do
    cond do
      String.match?(v, ~r/^\d+$/) -> String.to_integer(v)
      String.match?(v, ~r/^[-+]?\d+\.?\d*$/) -> elem(Float.parse(v), 0)
      true -> v
    end
  end

  defp raw_cell_value(_, _), do: nil

  # ── 私有辅助函数 ────────────────────────────────────────

  defp sheet_name(%__MODULE__{default_sheet_name: nil} = xlsx, nil), do: hd(xlsx.sheet_names)
  defp sheet_name(%__MODULE__{default_sheet_name: dn}, nil), do: dn
  defp sheet_name(_xlsx, sheet), do: sheet

  defp sheet_for(%__MODULE__{sheets_by_name: by_name, sheets: sheets}, sheet_name) do
    case Map.get(by_name, sheet_name) do
      nil ->
        idx = Enum.find_index(sheets, fn s -> s.name == sheet_name end)
        if idx, do: Enum.at(sheets, idx), else: nil
      s -> s
    end
  end


  defp find_basename(path) when is_binary(path) do
    if Eoo.Utils.uri?(path) do
      uri = URI.parse(path)
      Path.basename(uri.path || "")
    else
      Path.basename(path)
    end
  end

  defp find_basename(_), do: "spreadsheet"

  defp make_tempdir(basename, root) do
    prefix = "eoo_#{basename || "xlsx"}_"
    root = root || System.get_env("ROO_TMP") || System.tmp_dir!()

    path = Path.join(root, prefix <> random_string())
    File.mkdir_p!(path)
    path
  end

  defp random_string do
    :crypto.strong_rand_bytes(8) |> Base.encode32() |> String.downcase()
  end

  defp local_filename(filename, _tmpdir, :zip) when is_binary(filename) do
    # 如果是 .zip 包，移除 .zip 扩展名
    Path.rootname(filename, Path.extname(filename))
  end

  defp local_filename(filename, _tmpdir, _packed) when is_binary(filename) do
    filename
  end

  defp local_filename(_filename, _tmpdir, _packed), do: nil

  defp file_type_check(filename, exts, name, warning_level, _packed) do
    ext = Path.extname(filename) |> String.downcase()

    cond do
      ext in exts ->
        :ok

      warning_level == :error ->
        raise ArgumentError, "#{filename} is not #{name} file"

      warning_level == :warning ->
        IO.warn("are you sure, this is #{name} spreadsheet file?", [])

      warning_level == :ignore ->
        :ok

      true ->
        raise "#{warning_level} illegal state of file_warning"
    end
  end


  defp process_zipfile(filename, _shared, tmpdir) when is_binary(filename) do
    case :zip.unzip(String.to_charlist(filename), [{:cwd, String.to_charlist(tmpdir)}]) do
      {:ok, _files} -> :ok
      {:error, _} -> :ok
    end
    rename_extracted_files(tmpdir)
  end

  defp process_zipfile(nil, _shared, _tmpdir), do: :ok

  defp rename_extracted_files(tmpdir) do
    xl_dir = Path.join(tmpdir, "xl")
    ws_dir = Path.join(xl_dir, "worksheets")

    rename_if_exists(Path.join(xl_dir, "workbook.xml"), Path.join(tmpdir, "roo_workbook.xml"))
    rename_if_exists(Path.join(tmpdir, "xl/_rels/workbook.xml.rels"), Path.join(tmpdir, "roo_workbook.xml.rels"))
    rename_if_exists(Path.join(xl_dir, "sharedStrings.xml"), Path.join(tmpdir, "roo_sharedStrings.xml"))
    rename_if_exists(Path.join(xl_dir, "styles.xml"), Path.join(tmpdir, "roo_styles.xml"))

    if File.exists?(ws_dir) do
      File.ls!(ws_dir)
      |> Enum.filter(&String.match?(&1, ~r/^sheet\d+\.xml$/))
      |> Enum.each(fn fname ->
        idx = extract_sheet_index(fname)
        rename_if_exists(Path.join(ws_dir, fname), Path.join(tmpdir, "roo_sheet#{idx}"))
      end)
    end

    rels_dir = Path.join(ws_dir, "_rels")
    if File.exists?(rels_dir) do
      File.ls!(rels_dir)
      |> Enum.filter(&String.match?(&1, ~r/^sheet\d+\.xml\.rels$/))
      |> Enum.each(fn fname ->
        idx = extract_sheet_index(fname)
        rename_if_exists(Path.join(rels_dir, fname), Path.join(tmpdir, "roo_rels#{idx}"))
      end)
    end


    # Handle comments files (xl/comments1.xml etc.)
    for i <- 1..20 do
      rename_if_exists(
        Path.join(xl_dir, "comments#{i}.xml"),
        Path.join(tmpdir, "roo_comments#{i}")
      )
    end

    # Handle drawing rels
    for i <- 1..20 do
      rename_if_exists(
        Path.join(xl_dir, "drawings/drawing#{i}.xml.rels"),
        Path.join(tmpdir, "roo_image_rels#{i}")
      )
    end

    :ok
  end

  defp rename_if_exists(src, dest) do
    if File.exists?(src), do: File.rename!(src, dest)
  end

  defp extract_sheet_index(name) do
    [_, num_str] = Regex.run(~r/(\d+)/, name)
    String.to_integer(num_str)
  end

  defp cleanup_tmpdir(nil), do: :ok

  defp cleanup_tmpdir(tmpdir) do
    File.rm_rf(tmpdir)
  rescue
    _ -> :ok
  end

  defp is_stream?(filename_or_stream) do
    function_exported?(filename_or_stream, :seek, 2)
  rescue
    _ -> false
  end


  defp cell_empty?(cell) do
    mod = Map.get(cell, :__struct__)
    if mod && function_exported?(mod, :empty?, 1) do
      mod.empty?(cell)
    else
      false
    end
  end

end
