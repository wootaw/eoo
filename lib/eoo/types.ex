defmodule Eoo.Types do
  @moduledoc """
  定义 Eoo 中使用的共享类型和结构体。
  """

  # ── 单元格类型 ──────────────────────────────────────────

  @type cell_type ::
          :float
          | :string
          | :date
          | :datetime
          | :time
          | :percentage
          | :formula
          | :boolean
          | :link
          | :empty

  @type sheet_name :: String.t()
  @type row_index :: pos_integer()
  @type col_index :: pos_integer()
  @type cell_ref :: {row_index, col_index}

  # ── 坐标 ────────────────────────────────────────────────

  @type t_coordinate :: %Eoo.Coordinate{row: row_index, column: col_index}

  # ── 文件选项 ────────────────────────────────────────────

  @type file_warning :: :error | :warning | :ignore

  @type spreadsheet_option ::
          {:packed, :zip}
          | {:file_warning, file_warning}
          | {:cell_max, pos_integer()}
          | {:expand_merged_ranges, boolean()}
          | {:only_visible_sheets, boolean()}
          | {:csv_options, keyword()}
          | {:password, String.t()}
          | {:tmpdir_root, String.t()}
          | {:no_hyperlinks, boolean()}
          | {:empty_cell, boolean()}
          | {:disable_html_wrapper, boolean()}

  @type spreadsheet_options :: keyword(spreadsheet_option)
end
