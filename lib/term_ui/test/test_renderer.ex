defmodule TermUI.Test.TestRenderer do
  @moduledoc """
  Test renderer that captures output to a buffer for inspection.

  The test renderer implements a screen buffer interface without actual
  terminal output. Tests can inspect rendered content, styles, and positions.

  ## Usage

      {:ok, renderer} = TestRenderer.new(24, 80)
      TestRenderer.set_cell(renderer, 1, 1, Cell.new("X", fg: :red))

      # Inspect rendered content
      text = TestRenderer.get_text_at(renderer, 1, 1, 5)
      style = TestRenderer.get_style_at(renderer, 1, 1)

      # Snapshot comparison
      snapshot = TestRenderer.snapshot(renderer)
      assert TestRenderer.matches_snapshot?(renderer, snapshot)

  ## Buffer Coordinates

  Rows and columns are 1-indexed to match terminal conventions.
  """

  alias TermUI.Renderer.Buffer
  alias TermUI.Renderer.Cell

  @type t :: %__MODULE__{
          buffer: Buffer.t(),
          rows: pos_integer(),
          cols: pos_integer()
        }

  defstruct buffer: nil,
            rows: 0,
            cols: 0

  @doc """
  Creates a new test renderer with given dimensions.

  ## Examples

      {:ok, renderer} = TestRenderer.new(24, 80)
  """
  @spec new(pos_integer(), pos_integer()) :: {:ok, t()} | {:error, term()}
  def new(rows, cols) when is_integer(rows) and rows > 0 and is_integer(cols) and cols > 0 do
    case Buffer.new(rows, cols) do
      {:ok, buffer} ->
        {:ok, %__MODULE__{buffer: buffer, rows: rows, cols: cols}}

      error ->
        error
    end
  end

  @doc """
  Destroys the test renderer and frees resources.
  """
  @spec destroy(t()) :: :ok
  def destroy(%__MODULE__{buffer: buffer}) do
    Buffer.destroy(buffer)
  end

  @doc """
  Gets the cell at the given position.
  """
  @spec get_cell(t(), pos_integer(), pos_integer()) :: Cell.t()
  def get_cell(%__MODULE__{buffer: buffer}, row, col) do
    Buffer.get_cell(buffer, row, col)
  end

  @doc """
  Sets the cell at the given position.
  """
  @spec set_cell(t(), pos_integer(), pos_integer(), Cell.t()) :: :ok | {:error, :out_of_bounds}
  def set_cell(%__MODULE__{buffer: buffer}, row, col, cell) do
    Buffer.set_cell(buffer, row, col, cell)
  end

  @doc """
  Sets multiple cells at once.
  """
  @spec set_cells(t(), [{pos_integer(), pos_integer(), Cell.t()}]) :: :ok
  def set_cells(%__MODULE__{buffer: buffer}, cells) do
    Buffer.set_cells(buffer, cells)
  end

  @doc """
  Writes a string starting at the given position.

  Returns the number of columns written.
  """
  @spec write_string(t(), pos_integer(), pos_integer(), String.t(), keyword()) ::
          non_neg_integer()
  def write_string(%__MODULE__{buffer: buffer}, row, col, string, opts \\ []) do
    Buffer.write_string(buffer, row, col, string, opts)
  end

  @doc """
  Clears the entire buffer.
  """
  @spec clear(t()) :: :ok
  def clear(%__MODULE__{buffer: buffer}) do
    Buffer.clear(buffer)
  end

  @doc """
  Gets text at a position with specified width.

  Returns the characters in cells from (row, col) to (row, col + width - 1).

  ## Examples

      text = TestRenderer.get_text_at(renderer, 1, 1, 5)
      # => "Hello"
  """
  @spec get_text_at(t(), pos_integer(), pos_integer(), pos_integer()) :: String.t()
  def get_text_at(%__MODULE__{buffer: buffer}, row, col, width)
      when is_integer(width) and width > 0 do
    Enum.map_join(col..(col + width - 1), "", fn c ->
      cell = Buffer.get_cell(buffer, row, c)
      # Skip wide character placeholders
      if cell.wide_placeholder, do: "", else: cell.char
    end)
  end

  @doc """
  Gets the style at a position.

  Returns a map with fg, bg, and attrs.

  ## Examples

      style = TestRenderer.get_style_at(renderer, 1, 1)
      # => %{fg: :red, bg: :default, attrs: MapSet.new([:bold])}
  """
  @spec get_style_at(t(), pos_integer(), pos_integer()) :: map()
  def get_style_at(%__MODULE__{buffer: buffer}, row, col) do
    cell = Buffer.get_cell(buffer, row, col)

    %{
      fg: cell.fg,
      bg: cell.bg,
      attrs: cell.attrs
    }
  end

  @doc """
  Gets an entire row as text.

  ## Examples

      row_text = TestRenderer.get_row_text(renderer, 1)
      # => "Hello, World!                                              "
  """
  @spec get_row_text(t(), pos_integer()) :: String.t()
  def get_row_text(%__MODULE__{} = renderer, row) do
    get_text_at(renderer, row, 1, renderer.cols)
  end

  @doc """
  Checks if text appears at a position.

  ## Examples

      TestRenderer.text_at?(renderer, 1, 1, "Hello")
      # => true
  """
  @spec text_at?(t(), pos_integer(), pos_integer(), String.t()) :: boolean()
  def text_at?(%__MODULE__{} = renderer, row, col, expected) do
    actual = get_text_at(renderer, row, col, String.length(expected))
    actual == expected
  end

  @doc """
  Checks if text contains expected substring at a position.
  """
  @spec text_contains?(t(), pos_integer(), pos_integer(), pos_integer(), String.t()) :: boolean()
  def text_contains?(%__MODULE__{} = renderer, row, col, width, expected) do
    actual = get_text_at(renderer, row, col, width)
    String.contains?(actual, expected)
  end

  @doc """
  Searches for text in the entire buffer.

  Returns list of {row, col} positions where text was found.

  ## Examples

      positions = TestRenderer.find_text(renderer, "Error")
      # => [{5, 10}, {12, 3}]
  """
  @spec find_text(t(), String.t()) :: [{pos_integer(), pos_integer()}]
  def find_text(%__MODULE__{} = renderer, text) do
    text_len = String.length(text)

    for row <- 1..renderer.rows,
        col <- 1..(renderer.cols - text_len + 1),
        text_at?(renderer, row, col, text) do
      {row, col}
    end
  end

  @doc """
  Creates a snapshot of the current buffer state.

  Snapshots can be compared for equality or saved for regression testing.

  ## Examples

      snapshot = TestRenderer.snapshot(renderer)
  """
  @spec snapshot(t()) :: map()
  def snapshot(%__MODULE__{buffer: buffer, rows: rows, cols: cols}) do
    cells =
      for row <- 1..rows, col <- 1..cols, into: %{} do
        cell = Buffer.get_cell(buffer, row, col)
        {{row, col}, cell_to_map(cell)}
      end

    %{
      rows: rows,
      cols: cols,
      cells: cells
    }
  end

  defp cell_to_map(%Cell{} = cell) do
    %{
      char: cell.char,
      fg: cell.fg,
      bg: cell.bg,
      attrs: MapSet.to_list(cell.attrs) |> Enum.sort()
    }
  end

  @doc """
  Checks if current buffer matches a snapshot.

  ## Examples

      snapshot = TestRenderer.snapshot(renderer)
      # ... modify renderer ...
      TestRenderer.matches_snapshot?(renderer, snapshot)
      # => false
  """
  @spec matches_snapshot?(t(), map()) :: boolean()
  def matches_snapshot?(%__MODULE__{} = renderer, snapshot) do
    current = snapshot(renderer)
    current == snapshot
  end

  @doc """
  Compares current buffer with snapshot and returns differences.

  Returns list of {row, col, expected, actual} tuples for differing cells.
  """
  @spec diff_snapshot(t(), map()) :: [{pos_integer(), pos_integer(), map(), map()}]
  def diff_snapshot(%__MODULE__{} = renderer, snapshot) do
    current = snapshot(renderer)

    for row <- 1..renderer.rows,
        col <- 1..renderer.cols,
        current.cells[{row, col}] != snapshot.cells[{row, col}] do
      {row, col, snapshot.cells[{row, col}], current.cells[{row, col}]}
    end
  end

  @doc """
  Converts snapshot to a printable string representation.

  Useful for test failure output.
  """
  @spec snapshot_to_string(map()) :: String.t()
  def snapshot_to_string(snapshot) do
    for row <- 1..snapshot.rows do
      for col <- 1..snapshot.cols, into: "" do
        cell = snapshot.cells[{row, col}]
        cell.char
      end
    end
    |> Enum.join("\n")
  end

  @doc """
  Converts current buffer to a printable string.
  """
  @spec to_string(t()) :: String.t()
  def to_string(%__MODULE__{} = renderer) do
    for row <- 1..renderer.rows do
      get_row_text(renderer, row) |> String.trim_trailing()
    end
    |> Enum.join("\n")
    |> String.trim_trailing("\n")
  end

  @doc """
  Gets buffer dimensions.
  """
  @spec dimensions(t()) :: {pos_integer(), pos_integer()}
  def dimensions(%__MODULE__{rows: rows, cols: cols}) do
    {rows, cols}
  end

  @doc """
  Checks if position is within buffer bounds.
  """
  @spec in_bounds?(t(), pos_integer(), pos_integer()) :: boolean()
  def in_bounds?(%__MODULE__{rows: rows, cols: cols}, row, col) do
    row >= 1 and row <= rows and col >= 1 and col <= cols
  end
end
