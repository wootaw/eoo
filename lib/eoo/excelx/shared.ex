defmodule Eoo.Excelx.Shared do
  @moduledoc """
  共享数据容器。允许各个 Sheet 共享 styles、shared_strings、workbook 等数据，
  减少内存占用。
  """

  defstruct [
    :dir,
    :options,
    sheet_files: [],
    rels_files: [],
    comments_files: [],
    image_rels: [],
    image_files: []
  ]

  @type t :: %__MODULE__{
          dir: String.t(),
          options: Keyword.t(),
          sheet_files: [String.t()],
          rels_files: [String.t()],
          comments_files: [String.t()],
          image_rels: [String.t()],
          image_files: [String.t()]
        }

  def new(dir, options \\ []) do
    %__MODULE__{
      dir: dir,
      options: options,
      sheet_files: [],
      rels_files: [],
      comments_files: [],
      image_rels: [],
      image_files: []
    }
  end

  def styles(%__MODULE__{dir: dir}) do
    Eoo.Excelx.Styles.new(Path.join(dir, "roo_styles.xml"))
  end

  def shared_strings(%__MODULE__{dir: dir, options: options}) do
    Eoo.Excelx.SharedStrings.new(Path.join(dir, "roo_sharedStrings.xml"), options)
  end

  def workbook(%__MODULE__{dir: dir}) do
    Eoo.Excelx.Workbook.new(Path.join(dir, "roo_workbook.xml"))
  end

  def base_date(shared) do
    Eoo.Excelx.Workbook.base_date(workbook(shared))
  end

  def base_timestamp(shared) do
    Eoo.Excelx.Workbook.base_timestamp(workbook(shared))
  end
end
