defmodule EooTest do
  use ExUnit.Case

  # ── CSV Tests ───────────────────────────────────────────

  test "CSV basic reading" do
    {:ok, csv} = Eoo.CSV.open("test/test.csv")
    assert csv.sheets == ["default"]
    assert csv.first_row == 1
    assert csv.last_row == 4
    assert csv.first_column == 1
    assert csv.last_column == 3
    assert Eoo.CSV.cell(csv, 1, 1) == "Name"
    assert Eoo.CSV.cell(csv, 2, 2) == "30"
  end

  test "CSV row/column access" do
    {:ok, csv} = Eoo.CSV.open("test/test.csv")
    assert Eoo.CSV.row(csv, 2) == ["Alice", "30", "New York"]
    assert Eoo.CSV.column(csv, 1) == ["Name", "Alice", "Bob", "Charlie"]
    assert Eoo.CSV.column(csv, "A") == ["Name", "Alice", "Bob", "Charlie"]
  end

  test "CSV empty cell" do
    {:ok, csv} = Eoo.CSV.open("test/test.csv")
    refute Eoo.CSV.empty?(csv, 1, 1)
    assert Eoo.CSV.empty?(csv, 99, 99)
  end

  test "CSV set preserves original" do
    {:ok, csv} = Eoo.CSV.open("test/test.csv")
    {:ok, csv2} = Eoo.CSV.set(csv, 1, 1, "Header")
    assert Eoo.CSV.cell(csv2, 1, 1) == "Header"
    assert Eoo.CSV.cell(csv, 1, 1) == "Name"
  end

  test "Eoo.Spreadsheet factory" do
    {:ok, ss} = Eoo.Spreadsheet.open("test/test.csv")
    assert ss.sheets == ["default"]
    assert Eoo.CSV.cell(ss, 1, 1) == "Name"
  end

  # ── XLSX Tests (basic) ──────────────────────────────────

  test "XLSX open and sheets" do
    {:ok, xlsx} = Eoo.Excelx.open("test/test_mini.xlsx")
    assert Eoo.Excelx.sheets(xlsx) == ["Sheet1", "Sheet2"]
    assert Eoo.Excelx.default_sheet(xlsx) == "Sheet1"
    Eoo.Excelx.close(xlsx)
  end

  test "XLSX cell access" do
    {:ok, xlsx} = Eoo.Excelx.open("test/test_mini.xlsx")
    assert Eoo.Excelx.cell(xlsx, 1, 1) == "Name"
    assert Eoo.Excelx.cell(xlsx, 2, 1) == "Alice"
    assert Eoo.Excelx.cell(xlsx, 2, 2) == 42
    Eoo.Excelx.close(xlsx)
  end

  test "XLSX row and column" do
    {:ok, xlsx} = Eoo.Excelx.open("test/test_mini.xlsx")
    assert Eoo.Excelx.row(xlsx, 1) == ["Name", "Age", "City"]
    assert Eoo.Excelx.row(xlsx, 2) == ["Alice", 42, "New York"]
    assert Eoo.Excelx.column(xlsx, 1) == ["Name", "Alice"]
    Eoo.Excelx.close(xlsx)
  end

  test "XLSX boundaries and empty?" do
    {:ok, xlsx} = Eoo.Excelx.open("test/test_mini.xlsx")
    assert Eoo.Excelx.first_row(xlsx) == 1
    assert Eoo.Excelx.last_row(xlsx) == 2
    assert Eoo.Excelx.first_column(xlsx) == 1
    assert Eoo.Excelx.last_column(xlsx) == 3
    refute Eoo.Excelx.empty?(xlsx, 1, 1)
    assert Eoo.Excelx.empty?(xlsx, 99, 99)
    Eoo.Excelx.close(xlsx)
  end

  test "XLSX celltype" do
    {:ok, xlsx} = Eoo.Excelx.open("test/test_mini.xlsx")
    assert Eoo.Excelx.celltype(xlsx, 1, 1) == :string
    assert Eoo.Excelx.celltype(xlsx, 2, 2) == :float
    Eoo.Excelx.close(xlsx)
  end

  # ── XLSX Enhanced API Tests ──────────────────────────────

  test "XLSX formula" do
    {:ok, xlsx} = Eoo.Excelx.open("test/test_full.xlsx")
    assert Eoo.Excelx.formula(xlsx, 2, 3) == "A2+B2"
    assert Eoo.Excelx.formula?(xlsx, 2, 3)
    refute Eoo.Excelx.formula?(xlsx, 2, 1)
    assert Eoo.Excelx.formulas(xlsx) == [[2, 3, "A2+B2"]]
    Eoo.Excelx.close(xlsx)
  end

  test "XLSX labels" do
    {:ok, xlsx} = Eoo.Excelx.open("test/test_full.xlsx")
    assert Eoo.Excelx.label(xlsx, "first_cell") == {1, 1, "Sheet1"}
    assert Eoo.Excelx.labels(xlsx) == [{"first_cell", {1, 1, "Sheet1"}}]
    Eoo.Excelx.close(xlsx)
  end

  test "XLSX comment" do
    {:ok, xlsx} = Eoo.Excelx.open("test/test_full.xlsx")
    assert Eoo.Excelx.comment(xlsx, 2, 2) == "This is cell B2"
    assert Eoo.Excelx.comments(xlsx) == [[2, 2, "This is cell B2"]]
    Eoo.Excelx.close(xlsx)
  end

  test "XLSX switch sheets" do
    {:ok, xlsx} = Eoo.Excelx.open("test/test_full.xlsx")
    assert Eoo.Excelx.cell(xlsx, 1, 1) == "Name"
    {:ok, x2} = Eoo.Excelx.default_sheet(xlsx, "Sheet2")
    assert %Eoo.Link{href: "#Sheet1!A1", text: "Link to Sheet1"} = Eoo.Excelx.cell(x2, 1, 1)
    Eoo.Excelx.close(x2)
  end

  test "XLSX hyperlink" do
    {:ok, xlsx} = Eoo.Excelx.open("test/test_full.xlsx")
    {:ok, x2} = Eoo.Excelx.default_sheet(xlsx, "Sheet2")
    assert Eoo.Excelx.hyperlink(x2, 1, 1) == "#Sheet1!A1"
    assert Eoo.Excelx.hyperlink?(x2, 1, 1)
    refute Eoo.Excelx.hyperlink?(x2, 2, 1)
    Eoo.Excelx.close(x2)
  end

  test "XLSX excelx_type and excelx_value" do
    {:ok, xlsx} = Eoo.Excelx.open("test/test_full.xlsx")
    assert Eoo.Excelx.excelx_type(xlsx, 2, 2) == {:numeric_or_formula, "General"}
    assert Eoo.Excelx.excelx_value(xlsx, 2, 2) == "100"
    Eoo.Excelx.close(xlsx)
  end

  # ── Base Helper Tests ────────────────────────────────────

  test "Base.info returns document info" do
    {:ok, csv} = Eoo.CSV.open("test/test.csv")
    info = Eoo.Base.info(csv)
    assert info =~ "Number of sheets: 1"
    assert info =~ "Sheets: default"
  end

  test "Base.parse returns all rows" do
    {:ok, csv} = Eoo.CSV.open("test/test.csv")
    result = Eoo.Base.parse(csv, [])
    assert length(result) == 3
    assert hd(result) == ["Alice", "30", "New York"]
  end

  test "Formatters.CSV.to_csv works for CSV source" do
    {:ok, csv} = Eoo.CSV.open("test/test.csv")
    result = Eoo.Formatters.CSV.to_csv(csv)
    assert result =~ ~r/Name.*Age.*City/
    assert result =~ ~r/Alice.*30.*New York/
  end

  test "Formatters.CSV.to_csv works for XLSX source" do
    {:ok, xlsx} = Eoo.Excelx.open("test/test_mini.xlsx")
    result = Eoo.Formatters.CSV.to_csv(xlsx)
    assert result =~ ~r/Name.*Age.*City/
    assert result =~ ~r/Alice.*42.*New York/
    Eoo.Excelx.close(xlsx)
  end

  # ── ODS Tests ────────────────────────────────────────────

  test "ODS open and sheets" do
    {:ok, ods} = Eoo.OpenOffice.open("test/test.ods")
    assert Eoo.OpenOffice.sheets(ods) == ["Sheet1", "Sheet2"]
    Eoo.OpenOffice.close(ods)
  end

  test "ODS cell access" do
    {:ok, ods} = Eoo.OpenOffice.open("test/test.ods")
    assert Eoo.OpenOffice.cell(ods, 1, 1) == "Name"
    assert Eoo.OpenOffice.cell(ods, 2, 1) == "Alice"
    assert Eoo.OpenOffice.cell(ods, 2, 2) == 42
    assert Eoo.OpenOffice.cell(ods, 3, 2) == 25.5
    Eoo.OpenOffice.close(ods)
  end

  test "ODS row access" do
    {:ok, ods} = Eoo.OpenOffice.open("test/test.ods")
    assert Eoo.OpenOffice.row(ods, 1) == ["Name", "Value"]
    assert Eoo.OpenOffice.row(ods, 2) == ["Alice", 42]
    assert Eoo.OpenOffice.row(ods, 3) == ["Bob", 25.5]
    Eoo.OpenOffice.close(ods)
  end

  test "ODS boundaries" do
    {:ok, ods} = Eoo.OpenOffice.open("test/test.ods")
    assert Eoo.OpenOffice.first_row(ods) == 1
    assert Eoo.OpenOffice.last_row(ods) == 3
    assert Eoo.OpenOffice.first_column(ods) == 1
    assert Eoo.OpenOffice.last_column(ods) == 2
    Eoo.OpenOffice.close(ods)
  end

  test "ODS switch sheets" do
    {:ok, ods} = Eoo.OpenOffice.open("test/test.ods")
    {:ok, ods2} = Eoo.OpenOffice.default_sheet(ods, "Sheet2")
    assert Eoo.OpenOffice.cell(ods2, 1, 1) == "ODS Data"
    Eoo.OpenOffice.close(ods2)
  end

  test "ODS Spreadsheet factory" do
    {:ok, ss} = Eoo.Spreadsheet.open("test/test.ods")
    assert Eoo.OpenOffice.sheets(ss) == ["Sheet1", "Sheet2"]
  end

  # ── Streaming Tests ──────────────────────────────────────

  test "XLSX each_row_streaming basic" do
    {:ok, xlsx} = Eoo.Excelx.open("test/test_mini.xlsx")
    rows = Eoo.Excelx.each_row_streaming(xlsx, []) |> Enum.to_list()
    assert rows == [["Name", "Age", "City"], ["Alice", 42, "New York"]]
    Eoo.Excelx.close(xlsx)
  end

  test "XLSX each_row_streaming offset" do
    {:ok, xlsx} = Eoo.Excelx.open("test/test_mini.xlsx")
    rows = Eoo.Excelx.each_row_streaming(xlsx, offset: 1) |> Enum.to_list()
    assert rows == [["Alice", 42, "New York"]]
    Eoo.Excelx.close(xlsx)
  end

  test "XLSX each_row_streaming max_rows" do
    {:ok, xlsx} = Eoo.Excelx.open("test/test_mini.xlsx")
    rows = Eoo.Excelx.each_row_streaming(xlsx, max_rows: 1) |> Enum.to_list()
    assert rows == [["Name", "Age", "City"]]
    Eoo.Excelx.close(xlsx)
  end

  test "XLSX each_row_streaming pad_cells" do
    {:ok, xlsx} = Eoo.Excelx.open("test/test_mini.xlsx")
    rows = Eoo.Excelx.each_row_streaming(xlsx, pad_cells: true) |> Enum.to_list()
    assert rows == [["Name", "Age", "City"], ["Alice", 42, "New York"]]
    Eoo.Excelx.close(xlsx)
  end

  # ── Formatter Tests ──────────────────────────────────────

  test "Formatters.YAML output" do
    {:ok, csv} = Eoo.CSV.open("test/test.csv")
    yaml = Eoo.Formatters.YAML.to_yaml(csv)
    assert yaml =~ "cell_1_1"
    assert yaml =~ "value: Alice"
    assert yaml =~ "celltype: string"
  end

  test "Formatters.Matrix output" do
    {:ok, csv} = Eoo.CSV.open("test/test.csv")
    matrix = Eoo.Formatters.Matrix.to_matrix(csv)
    assert length(matrix) == 4
    assert hd(matrix) == ["Name", "Age", "City"]
  end

  test "Formatters.YAML with prefix" do
    {:ok, csv} = Eoo.CSV.open("test/test.csv")
    yaml = Eoo.Formatters.YAML.to_yaml(csv, prefix: %{file: "test.csv", sheet: "default"})
    assert yaml =~ "file: test.csv"
    assert yaml =~ "sheet: default"
  end

  # ── Encryption Tests ────────────────────────────────────

  test "ODS encrypted file decryption" do
    {:ok, ods} = Eoo.OpenOffice.open("test/test_encrypted.ods", password: "testpass123")
    assert Eoo.OpenOffice.sheets(ods) == ["Sheet1"]
    assert Eoo.OpenOffice.cell(ods, 1, 1) == "Secret Data"
    assert Eoo.OpenOffice.cell(ods, 1, 2) == 42
    Eoo.OpenOffice.close(ods)
  end

  test "ODS encrypted wrong password" do
    {:error, _} = Eoo.OpenOffice.open("test/test_encrypted.ods", password: "wrongpassword")
  end

  test "ODS encrypted no password" do
    {:error, _} = Eoo.OpenOffice.open("test/test_encrypted.ods")
  end
end
