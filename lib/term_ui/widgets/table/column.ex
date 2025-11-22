defmodule TermUI.Widgets.Table.Column do
  @moduledoc """
  Column specification for Table widget.

  Defines how a column is displayed and how data is extracted from rows.

  ## Usage

      Column.new(:name, "Name")
      Column.new(:age, "Age", width: Constraint.length(10))
      Column.new(:status, "Status", render: &format_status/1)

  ## Width Constraints

  Columns support the full constraint system:

  - `Constraint.length(20)` - Fixed 20 cells
  - `Constraint.ratio(2)` - Proportional share
  - `Constraint.percentage(50)` - 50% of available
  - `Constraint.fill()` - Take remaining space

  ## Custom Renderers

  The render function transforms the cell value to a string:

      Column.new(:date, "Date", render: fn date ->
        Calendar.strftime(date, "%Y-%m-%d")
      end)
  """

  alias TermUI.Layout.Constraint

  @type t :: %__MODULE__{
          key: atom(),
          header: String.t(),
          width: Constraint.t(),
          render: (term() -> String.t()) | nil,
          sortable: boolean(),
          align: :left | :center | :right
        }

  defstruct [
    :key,
    :header,
    :width,
    :render,
    sortable: true,
    align: :left
  ]

  @doc """
  Creates a new column specification.

  ## Parameters

  - `key` - The map key to extract from row data
  - `header` - The header text to display
  - `opts` - Additional options

  ## Options

  - `:width` - Width constraint (default: `Constraint.fill()`)
  - `:render` - Custom render function (default: `to_string/1`)
  - `:sortable` - Whether column can be sorted (default: true)
  - `:align` - Text alignment :left, :center, :right (default: :left)

  ## Examples

      Column.new(:name, "Name")
      Column.new(:age, "Age", width: Constraint.length(10), align: :right)
  """
  @spec new(atom(), String.t(), keyword()) :: t()
  def new(key, header, opts \\ []) when is_atom(key) and is_binary(header) do
    %__MODULE__{
      key: key,
      header: header,
      width: Keyword.get(opts, :width, Constraint.fill()),
      render: Keyword.get(opts, :render),
      sortable: Keyword.get(opts, :sortable, true),
      align: Keyword.get(opts, :align, :left)
    }
  end

  @doc """
  Extracts and renders the cell value from a row.

  ## Parameters

  - `column` - The column specification
  - `row` - The row data (map or struct)

  ## Returns

  The rendered string value for the cell.

  ## Examples

      column = Column.new(:name, "Name")
      Column.render_cell(column, %{name: "Alice"})
      # => "Alice"
  """
  @spec render_cell(t(), map()) :: String.t()
  def render_cell(%__MODULE__{key: key, render: nil}, row) do
    row
    |> Map.get(key, "")
    |> to_string()
  end

  def render_cell(%__MODULE__{key: key, render: render_fn}, row) when is_function(render_fn, 1) do
    row
    |> Map.get(key, "")
    |> render_fn.()
    |> to_string()
  end

  @doc """
  Aligns text within a given width.

  ## Parameters

  - `text` - The text to align
  - `width` - The available width
  - `align` - Alignment (:left, :center, :right)

  ## Returns

  The aligned text, padded to width.
  """
  @spec align_text(String.t(), non_neg_integer(), :left | :center | :right) :: String.t()
  def align_text(text, width, align) do
    text_len = String.length(text)

    cond do
      text_len >= width ->
        String.slice(text, 0, width)

      align == :left ->
        String.pad_trailing(text, width)

      align == :right ->
        String.pad_leading(text, width)

      align == :center ->
        left_pad = div(width - text_len, 2)
        right_pad = width - text_len - left_pad
        String.duplicate(" ", left_pad) <> text <> String.duplicate(" ", right_pad)
    end
  end
end
