defmodule Eoo.OpenOffice do
  @moduledoc """
  OpenDocument Spreadsheet (.ods) 解析器。

  支持 OpenOffice / LibreOffice 创建的 ODS 文件，包括加密文档。

  ## 示例

      {:ok, ods} = Eoo.OpenOffice.open("file.ods")
      ods.sheets()
      # => ["Sheet1", "Sheet2"]

      # 加密文档
      {:ok, ods} = Eoo.OpenOffice.open("encrypted.ods", password: "secret")
  """

  @behaviour Eoo.Base

  defstruct [
    :filename,
    :tmpdir,
    :options,
    :doc,
    sheet_names: [],
    default_sheet_name: nil,
    cells: %{},
    cell_types: %{},
    formulas: %{},
    styles: %{},
    style_defaults: %{},
    font_styles: %{},
    comments: %{},
    labels: %{},
    cells_read: %{},
    comments_read: %{},
    table_display: %{},
    first_rows: %{},
    last_rows: %{},
    first_cols: %{},
    last_cols: %{},

  ]

  @type t :: %__MODULE__{
          filename: String.t(),
          tmpdir: String.t(),
          options: Keyword.t(),
          doc: term() | nil,
          sheet_names: [String.t()],
          default_sheet_name: String.t() | nil,
          cells: map(),
          cell_types: map(),
          formulas: map(),
          styles: map(),
          style_defaults: map(),
          font_styles: map(),
          comments: map(),
          labels: map(),
          cells_read: map(),
          comments_read: map(),
          table_display: map(),
          first_rows: map(),
          last_rows: map(),
          first_cols: map(),
          last_cols: map(),

        }

  @doc """
  打开一个 ODS 文件。
  """
  def open(filename, options \\ []) do
    tmpdir = nil

    try do
      _file_warning = Keyword.get(options, :file_warning, :error)
      only_visible = Keyword.get(options, :only_visible_sheets, false)
      password = Keyword.get(options, :password)

      tmpdir = make_tempdir(filename, Keyword.get(options, :tmpdir_root))

      # 解压 ODS 文件
      :zip.unzip(String.to_charlist(filename), [{:cwd, String.to_charlist(tmpdir)}])

      # 读取 content.xml
      content_path = Path.join(tmpdir, "content.xml")

      # 检查是否需要解密
      if password do
        decrypt_content(tmpdir, password)
      end

      # 解析 XML
      raw_content = File.read!(content_path)
      # ODS 文件使用大量命名空间，需要完整剥离
      stripped = strip_ods_namespaces(raw_content)
      doc = Eoo.XML.parse(stripped)

      # 读取表样式信息
      table_display = read_table_styles(doc)

      # 读取 sheet 名称
      sheet_names =
        doc
        |> find_tables()
        |> Enum.map(fn table ->
          name = get_attr(table, "table:name") || get_attr(table, "name")
          visible = if only_visible do
            style_name = get_attr(table, "table:style-name")
            Map.get(table_display, style_name, true)
          else
            true
          end
          if visible, do: name, else: nil
        end)
        |> Enum.reject(&is_nil/1)

      # 获取自动样式
      font_styles = read_auto_styles(doc)

      {:ok, %__MODULE__{
        filename: filename,
        tmpdir: tmpdir,
        options: options,
        doc: doc,
        sheet_names: sheet_names,
        default_sheet_name: List.first(sheet_names),
        font_styles: font_styles,
        table_display: table_display
      }}
    rescue
      e ->
        if tmpdir, do: cleanup_tmpdir(tmpdir)
        {:error, e}
    end
  end

  # ── Eoo.Base 回调 ───────────────────────────────────────

  def sheets(ods), do: ods.sheet_names

  def default_sheet(ods), do: ods.default_sheet_name || hd(ods.sheet_names)

  def default_sheet(ods, sheet) when is_binary(sheet) do
    if sheet in ods.sheet_names do
      {:ok, %{ods | default_sheet_name: sheet}}
    else
      {:error, "sheet '#{sheet}' not found"}
    end
  end

  def default_sheet(ods, index) when is_integer(index) do
    s = Enum.at(ods.sheet_names, index)
    if s, do: {:ok, %{ods | default_sheet_name: s}}, else: {:error, "sheet index #{index} not found"}
  end

  def cell(ods, row, col, sheet \\ nil) do
    s = sheet_name(ods, sheet)
    ods_with_cells = ensure_cells_read(ods, s)
    {r, c} = Eoo.Utils.normalize(row, col)
    key = {r, c}

    case Map.get(ods_with_cells.cell_types, {s, key}) do
      :date ->
        val = Map.get(ods_with_cells.cells, {s, key})
        if val do
          [yyyy, mm, dd] = String.split(to_string(val), "-")
          {:ok, date} = Date.new(String.to_integer(yyyy), String.to_integer(mm), String.to_integer(dd))
          date
        end
      _ ->
        Map.get(ods_with_cells.cells, {s, key})
    end
  end

  def celltype(ods, row, col, sheet \\ nil) do
    s = sheet_name(ods, sheet)
    ods_with = ensure_cells_read(ods, s)
    {r, c} = Eoo.Utils.normalize(row, col)
    key = {s, {r, c}}

    if Map.get(ods_with.formulas, key) do
      :formula
    else
      Map.get(ods_with.cell_types, key)
    end
  end

  def row(ods, row_number, sheet \\ nil) do
    s = sheet_name(ods, sheet)
    ods_with = ensure_cells_read(ods, s)
    first = first_column(ods_with, s)
    last = last_column(ods_with, s)

    if first && last do
      first..last
      |> Enum.map(fn col -> cell(ods_with, row_number, col, s) end)
    else
      []
    end
  end

  def column(ods, col, sheet \\ nil)

  def column(ods, col_number, sheet) when is_integer(col_number) do
    s = sheet_name(ods, sheet)
    ods_with = ensure_cells_read(ods, s)
    first = first_row(ods_with, s)
    last = last_row(ods_with, s)

    if first && last do
      first..last
      |> Enum.map(fn row -> cell(ods_with, row, col_number, s) end)
    else
      []
    end
  end

  def column(ods, col_letter, sheet) when is_binary(col_letter) do
    column(ods, Eoo.Utils.letter_to_number(col_letter), sheet)
  end

  def first_row(ods, sheet \\ nil) do
    s = sheet_name(ods, sheet)
    ods_with = ensure_cells_read(ods, s)
    Map.get(ods_with.cells_read, s, false) && ods_with.first_rows[s]
  end

  def last_row(ods, sheet \\ nil) do
    s = sheet_name(ods, sheet)
    ods_with = ensure_cells_read(ods, s)
    Map.get(ods_with.cells_read, s, false) && ods_with.last_rows[s]
  end

  def first_column(ods, sheet \\ nil) do
    s = sheet_name(ods, sheet)
    ods_with = ensure_cells_read(ods, s)
    Map.get(ods_with.cells_read, s, false) && ods_with.first_cols[s]
  end

  def last_column(ods, sheet \\ nil) do
    s = sheet_name(ods, sheet)
    ods_with = ensure_cells_read(ods, s)
    Map.get(ods_with.cells_read, s, false) && ods_with.last_cols[s]
  end

  def empty?(ods, row, col, sheet \\ nil) do
    s = sheet_name(ods, sheet)
    val = cell(ods, row, col, s)
    is_nil(val) or (is_binary(val) and val == "") or
      row < (first_row(ods, s) || 0) or row > (last_row(ods, s) || 0) or
      col < (first_column(ods, s) || 0) or col > (last_column(ods, s) || 0)
  end

  def set(ods, row, col, value, sheet \\ nil) do
    s = sheet_name(ods, sheet)
    {r, c} = Eoo.Utils.normalize(row, col)
    key = {s, {r, c}}
    ct = if is_integer(value), do: :float, else: :string
    {:ok, %{ods | cells: Map.put(ods.cells, key, value), cell_types: Map.put(ods.cell_types, key, ct)}}
  end

  def reload(ods) do
    open(ods.filename, ods.options)
  end

  def close(ods) do
    if ods.tmpdir, do: cleanup_tmpdir(ods.tmpdir)
    :ok
  end

  # ODS 特有方法

  def formula(ods, row, col, sheet \\ nil) do
    s = sheet_name(ods, sheet)
    ods_with = ensure_cells_read(ods, s)
    {r, c} = Eoo.Utils.normalize(row, col)
    Map.get(ods_with.formulas, {s, {r, c}})
  end

  def formula?(ods, row, col, sheet \\ nil) do
    not is_nil(formula(ods, row, col, sheet))
  end

  def formulas(ods, sheet \\ nil) do
    s = sheet_name(ods, sheet)
    ods_with = ensure_cells_read(ods, s)

    ods_with.formulas
    |> Enum.filter(fn {{sn, _}, _} -> sn == s end)
    |> Enum.map(fn {{_sn, {r, c}}, f} -> [r, c, f] end)
  end

  def font(ods, row, col, sheet \\ nil) do
    s = sheet_name(ods, sheet)
    ods_with = ensure_cells_read(ods, s)
    {r, c} = Eoo.Utils.normalize(row, col)
    key = {s, {r, c}}

    style_name = Map.get(ods_with.styles, key) ||
      Map.get(ods_with.style_defaults, {s, c - 1}) || "Default"

    Map.get(ods_with.font_styles, style_name)
  end

  def comment(ods, row, col, sheet \\ nil) do
    s = sheet_name(ods, sheet)
    ods_with = ensure_cells_read(ods, s)
    {r, c} = Eoo.Utils.normalize(row, col)
    Map.get(ods_with.comments, {s, {r, c}})
  end

  def comments(ods, sheet \\ nil) do
    s = sheet_name(ods, sheet)
    ods_with = ensure_cells_read(ods, s)

    ods_with.comments
    |> Enum.filter(fn {{sn, _}, _} -> sn == s end)
    |> Enum.map(fn {{_sn, {r, c}}, text} -> [r, c, text] end)
  end

  def label(ods, name) do
    read_labels(ods)
    label_info = Map.get(ods.labels, name)
    if label_info do
      {label_info.row, label_info.col, label_info.sheet}
    end
  end

  def labels(ods) do
    ods_with = read_labels(ods)
    ods_with.labels
    |> Enum.map(fn {name, info} -> {name, {info.row, info.col, info.sheet}} end)
  end

  # ── 私有函数 ────────────────────────────────────────────

  defp sheet_name(ods, nil), do: ods.default_sheet_name || hd(ods.sheet_names)
  defp sheet_name(_ods, s), do: s

  defp ensure_cells_read(ods, sheet) do
    if Map.get(ods.cells_read, sheet, false) do
      ods
    else
      read_cells(ods, sheet)
    end
  end

  defp read_cells(ods, sheet) do
    doc = ods.doc
    _table_style_defaults = %{}
    _table_found = false

    {new_ods, _found} =
      doc
      |> find_tables()
      |> Enum.reduce({ods, false}, fn table, {acc, _found_so_far} ->
        table_name = get_attr(table, "table:name") || get_attr(table, "name")
        if table_name != sheet, do: {acc, false}, else:
          {read_table_cells(acc, table, sheet), true}
      end)

    new_ods
    |> read_auto_styles_from_doc()
    |> Map.put(:cells_read, Map.put(new_ods.cells_read, sheet, true))
  end

  defp read_table_cells(ods, table, sheet) do
    {cells, cell_types, formulas, styles, style_defaults, comments, _current_row, first_row, last_row, first_col, last_col} =
      table
      |> children_elements()
      |> Enum.reduce({ods.cells, ods.cell_types, ods.formulas, ods.styles, ods.style_defaults, ods.comments,
                      1, nil, nil, nil, nil}, fn elem, {c, ct, f, st, sdef, cm, cur_row, fr, lr, fc, lc} ->
        case name(elem) do
          "table-column" ->
            default_style = get_attr(elem, "table:default-cell-style-name")
            new_sdef = if default_style, do: Map.put(sdef, {sheet, fc || 0}, default_style), else: sdef
            {c, ct, f, st, new_sdef, cm, cur_row, fr, lr, fc, lc}

          "table-row" ->
            repeated = get_attr_int(elem, "table:number-rows-repeated", 1)

            {new_c, new_ct, new_f, new_st, new_cm, cell_cols} =
              elem
              |> children_elements()
              |> Enum.reduce({c, ct, f, st, cm, [1]}, fn cell, {cc, cct, cf, cst, ccm, cols} ->
                if name(cell) != "table-cell" do
                  {cc, cct, cf, cst, ccm, cols}
                else
                  {nc, nct, nf, nst, ncm, next_col} = process_ods_cell(cell, sheet, cur_row, cc, cct, cf, cst, ccm, hd(cols))
                  {nc, nct, nf, nst, ncm, [next_col | cols]}
                end
              end)
            all_cols = cell_cols
            fc2 = fc || Enum.min(all_cols)
            lc2 = max(lc || 0, Enum.max(all_cols) - 1)
            {new_c, new_ct, new_f, new_st, sdef, new_cm,
             cur_row + repeated,
             fr || cur_row,
             cur_row + repeated - 1,
             fc2, lc2}

          _ ->
            {c, ct, f, st, sdef, cm, cur_row, fr, lr, fc, lc}
        end
      end)

    %{ods |
      cells: cells,
      cell_types: cell_types,
      formulas: formulas,
      styles: styles,
      style_defaults: style_defaults,
      comments: comments
    }
    |> then(fn s -> %{s | first_rows: Map.put(s.first_rows, sheet, first_row)} end)
    |> then(fn s -> %{s | last_rows: Map.put(s.last_rows, sheet, last_row)} end)
    |> then(fn s -> %{s | first_cols: Map.put(s.first_cols, sheet, first_col)} end)
    |> then(fn s -> %{s | last_cols: Map.put(s.last_cols, sheet, last_col)} end)
  end

  defp process_ods_cell(cell, sheet, row_num, cells, cell_types, formulas, styles, comments, fc) do
    value_type = get_attr(cell, "office:value-type") || get_attr(cell, "value-type")
    value = get_attr(cell, "office:value") || get_attr(cell, "value")
    formula_str = get_attr(cell, "table:formula") || get_attr(cell, "formula")
    style_name = get_attr(cell, "table:style-name") || get_attr(cell, "style-name")
    repeated = get_attr_int(cell, "table:number-columns-repeated", 1)
    col = fc || 1
    col_advance = repeated

    # Process cell content (text, time, etc.)
    {str_v, new_comments} = extract_cell_content(cell, sheet, row_num, col, comments)

    # Determine the value
    final_value = cond do
      value_type == "string" -> str_v
      value_type == "float" -> parse_number(value, str_v)
      value_type == "percentage" -> parse_float(value)
      value_type == "date" -> value || get_attr(cell, "office:date-value")
      value_type == "time" -> str_v
      value_type == "boolean" -> get_attr(cell, "office:boolean-value")
      true -> str_v || value
    end

    # Cell type
    final_type = cond do
      formula_str -> :formula
      value_type == "float" -> :float
      value_type == "percentage" -> :percentage
      value_type == "date" -> :date
      value_type == "time" -> :time
      value_type == "boolean" -> :boolean
      true -> :string
    end

    # Set values for repeated columns
    {new_cells, new_types, new_formulas, new_styles} =
      Enum.reduce(0..(repeated - 1), {cells, cell_types, formulas, styles}, fn i,
                                                                               {cc, cct, cf, cst} ->
        key = {sheet, {row_num, col + i}}
        {Map.put(cc, key, final_value),
         Map.put(cct, key, final_type),
         if(formula_str, do: Map.put(cf, key, formula_str), else: cf),
         if(style_name, do: Map.put(cst, key, style_name), else: cst)}
      end)

    {new_cells, new_types, new_formulas, new_styles, new_comments, col + col_advance}
  end

  defp extract_cell_content(cell, sheet, row_num, col, comments) do
    str_v = ""
    new_comments = comments

    {str_v, new_comments} =
      cell
      |> children_elements()
      |> Enum.reduce({str_v, new_comments}, fn child, {sv, cm} ->
        case name(child) do
          "p" ->
            text = xml_text_content(child)
            {sv <> (if sv == "", do: "", else: "\n") <> text, cm}

          "annotation" ->
            annot_text = child
            |> children_elements()
            |> Enum.find(fn c -> name(c) == "p" end)
            |> (fn
              nil -> ""
              p -> xml_text_content(p)
            end).()
            {sv, Map.put(cm, {sheet, {row_num, col}}, annot_text)}

          _ ->
            {sv, cm}
        end
      end)

    {str_v, new_comments}
  end

  # ── XML 辅助 ────────────────────────────────────────────

  defp find_tables(doc) do
    # Find all table elements at any depth
    find_all_elements(doc, "table")
  end

  defp find_all_elements(elem, tag) when is_tuple(elem) do
    do_find_all(elem, tag, [])
  end
  defp find_all_elements(list, tag) when is_list(list) do
    Enum.flat_map(list, &find_all_elements(&1, tag))
  end
  defp find_all_elements(_, _), do: []

  defp do_find_all({:xmlElement, name, _, _, _, _, _, _, children, _, _, _} = elem, tag, acc) do
    acc = if to_string(name) == tag, do: acc ++ [elem], else: acc
    Enum.reduce(children, acc, fn c, a -> do_find_all(c, tag, a) end)
  end
  defp do_find_all(list, tag, acc) when is_list(list) do
    Enum.reduce(list, acc, fn c, a -> do_find_all(c, tag, a) end)
  end
  defp do_find_all(_, _, acc), do: acc

  defp children_elements({:xmlElement, _, _, _, _, _, _, _, children, _, _, _}) do
    Enum.filter(children, fn
      {:xmlElement, _, _, _, _, _, _, _, _, _, _, _} -> true
      _ -> false
    end)
  end
  defp children_elements(_), do: []

  defp name({:xmlElement, name, _, _, _, _, _, _, _, _, _, _}), do: to_string(name)
  defp name(_), do: ""

  defp get_attr({:xmlElement, _, _, _, _, _, _, attrs, _, _, _, _}, attr_name) do
    attr_list = if is_list(attrs), do: attrs, else: []
    Enum.find_value(attr_list, fn
      {:xmlAttribute, aname, _, _, _, _, _, _, value, _} ->
        if to_string(aname) == attr_name and is_list(value) and value != [] do
          List.to_string(value)
        end
      _ -> nil
    end)
  end
  defp get_attr(_, _), do: nil

  defp get_attr_int(elem, attr, default) do
    case get_attr(elem, attr) do
      nil -> default
      str ->
        case Integer.parse(str) do
          {n, _} -> n
          :error -> default
        end
    end
  end

  defp xml_text_content({:xmlElement, _, _, _, _, _, _, _, children, _, _, _}) do
    texts = Enum.filter(children, fn
      {:xmlText, _, _, _, _, _} -> true
      _ -> false
    end)
    Enum.map(texts, fn {:xmlText, _, _, _, t, _} -> List.to_string(t) end) |> Enum.join("")
  end

  defp parse_number(value, str_v) do
    if value do
      if String.contains?(value, ".") or String.contains?(str_v, ".") do
        parse_float(value)
      else
        String.to_integer(value)
      end
    else
      nil
    end
  end

  defp parse_float(nil), do: nil
  defp parse_float(str) do
    {f, _} = Float.parse(str)
    f
  end

  # ── 样式处理 ────────────────────────────────────────────

  defp read_table_styles(_doc) do
    %{}
  end

  defp read_auto_styles(doc) do
    doc
    |> find_all_elements("style")
    |> Enum.reduce(%{}, fn style_el, acc ->
      style_name = get_attr(style_el, "style:name") || get_attr(style_el, "name")
      if style_name do
        font = %Eoo.Font{}

        font = style_el
        |> children_elements()
        |> Enum.reduce(font, fn prop_el, f ->
          case name(prop_el) do
            "text-properties" ->
              f
              |> Map.put(:bold, get_attr(prop_el, "fo:font-weight") == "bold" ||
                                  get_attr(prop_el, "font-weight") == "bold")
              |> Map.put(:italic, get_attr(prop_el, "fo:font-style") == "italic" ||
                                   get_attr(prop_el, "font-style") == "italic")
              |> Map.put(:underline, get_attr(prop_el, "style:text-underline-style") == "solid" ||
                                      get_attr(prop_el, "text-underline-style") == "solid")
            _ -> f
          end
        end)

        Map.put(acc, style_name, font)
      else
        acc
      end
    end)
  end

  defp read_auto_styles_from_doc(ods) do
    # Already done during initialization
    ods
  end

  # ── 标签处理 ────────────────────────────────────────────

  defp read_labels(ods) do
    if ods.labels != %{} || !ods.doc do
      ods
    else
      labels =
        ods.doc
        |> find_all_elements("named-range")
        |> Enum.reduce(%{}, fn ne, acc ->
          name = get_attr(ne, "table:name") || get_attr(ne, "name")
          range = get_attr(ne, "table:cell-range-address") || get_attr(ne, "cell-range-address")
          if name && range do
            case String.split(range, ".$", parts: 2) do
              [sheet_part, coords] ->
                sheet_name = String.trim_leading(sheet_part, "$")
                case String.split(coords, "$") do
                  [col_str, row_str] ->
                    row = String.to_integer(row_str)
                    col = Eoo.Utils.letter_to_number(col_str)
                    info = %{name: name, sheet: sheet_name, row: row, col: col}
                    Map.put(acc, name, info)
                  _ -> acc
                end
              _ -> acc
            end
          else
            acc
          end
        end)

      %{ods | labels: labels}
    end
  end

  # ── 命名空间处理 ────────────────────────────────────────

  defp strip_ods_namespaces(xml) do
    # Remove all namespace declarations
    xml
    |> String.replace(~r/\s+xmlns[^=]*="[^"]*"/, "")
    # Remove namespace prefixes from opening tags: <office:xxx -> <xxx
    |> String.replace(~r{<(\w+):}, "<")
    # Remove namespace prefixes from closing tags: </office:xxx -> </xxx
    |> String.replace(~r{</(\w+):}, "</")
    # Also handle self-closing tags with namespaces
    |> String.replace(~r{<(\w+):([^ >]+)([^>]*)/>}, "<\\2\\3/>")
    # Handle attributes with namespace prefixes
    |> String.replace(~r{ (\w+):(\w+)=}, " \\2=")
  end

  # ── 临时文件 ────────────────────────────────────────────

  defp make_tempdir(filename, root) do
    basename = Path.basename(filename)
    prefix = "eoo_#{basename}_"
    root = root || System.get_env("ROO_TMP") || System.tmp_dir!()
    path = Path.join(root, prefix <> random_string())
    File.mkdir_p!(path)
    path
  end

  defp random_string do
    :crypto.strong_rand_bytes(8) |> Base.encode32() |> String.downcase()
  end

  defp cleanup_tmpdir(nil), do: :ok
  defp cleanup_tmpdir(tmpdir) do
    File.rm_rf(tmpdir)
  rescue
    _ -> :ok
  end

  # ── 解密 ────────────────────────────────────────────────

  defp decrypt_content(_tmpdir, _password) do
    # TODO: Implement ODS decryption
    :ok
  end
end
