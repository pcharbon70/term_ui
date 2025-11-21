defmodule TermUI.Renderer.Buffer do
  @moduledoc """
  ETS-based screen buffer for storing cells.

  The buffer uses an ETS `:ordered_set` table keyed by `{row, col}` tuples
  for O(log n) access and efficient row-major iteration. This enables fast
  cell lookup and sequential rendering.

  ## Usage

      {:ok, buffer} = Buffer.new(24, 80)
      Buffer.set_cell(buffer, 1, 1, Cell.new("A", fg: :red))
      cell = Buffer.get_cell(buffer, 1, 1)
      Buffer.destroy(buffer)

  ## Coordinates

  Rows and columns are 1-indexed to match terminal conventions.
  """

  alias TermUI.Renderer.Cell
  alias TermUI.Renderer.Style

  # Maximum buffer dimensions to prevent resource exhaustion
  # 500 rows x 1000 cols = 500,000 cells max (reasonable for any terminal)
  @max_rows 500
  @max_cols 1000

  @type t :: %__MODULE__{
          table: :ets.tid(),
          rows: pos_integer(),
          cols: pos_integer()
        }

  defstruct table: nil,
            rows: 0,
            cols: 0

  @doc """
  Creates a new buffer with the given dimensions.

  Initializes all cells to empty (space with default colors).

  Maximum dimensions are #{@max_rows} rows x #{@max_cols} cols to prevent
  resource exhaustion.

  ## Examples

      iex> {:ok, buffer} = Buffer.new(24, 80)
      iex> buffer.rows
      24
      iex> buffer.cols
      80
  """
  @spec new(pos_integer(), pos_integer()) :: {:ok, t()} | {:error, term()}
  def new(rows, cols) when is_integer(rows) and rows > 0 and is_integer(cols) and cols > 0 do
    cond do
      rows > @max_rows ->
        {:error, {:dimensions_too_large, "rows #{rows} exceeds maximum #{@max_rows}"}}

      cols > @max_cols ->
        {:error, {:dimensions_too_large, "cols #{cols} exceeds maximum #{@max_cols}"}}

      true ->
        table = :ets.new(:buffer, [:ordered_set, :public])

        buffer = %__MODULE__{
          table: table,
          rows: rows,
          cols: cols
        }

        # Initialize all cells to empty
        initialize_cells(buffer)

        {:ok, buffer}
    end
  end

  @doc """
  Returns the maximum allowed rows.
  """
  @spec max_rows() :: pos_integer()
  def max_rows, do: @max_rows

  @doc """
  Returns the maximum allowed columns.
  """
  @spec max_cols() :: pos_integer()
  def max_cols, do: @max_cols

  @doc """
  Destroys the buffer and frees ETS table.

  ## Examples

      iex> {:ok, buffer} = Buffer.new(10, 10)
      iex> Buffer.destroy(buffer)
      :ok
  """
  @spec destroy(t()) :: :ok
  def destroy(%__MODULE__{table: table}) do
    :ets.delete(table)
    :ok
  end

  @doc """
  Gets the cell at the given position.

  Returns empty cell if position is out of bounds.

  ## Examples

      iex> {:ok, buffer} = Buffer.new(10, 10)
      iex> cell = Buffer.get_cell(buffer, 1, 1)
      iex> cell.char
      " "
  """
  @spec get_cell(t(), pos_integer(), pos_integer()) :: Cell.t()
  def get_cell(%__MODULE__{} = buffer, row, col) do
    if in_bounds?(buffer, row, col) do
      case :ets.lookup(buffer.table, {row, col}) do
        [{{^row, ^col}, cell}] -> cell
        [] -> Cell.empty()
      end
    else
      Cell.empty()
    end
  end

  @doc """
  Sets the cell at the given position.

  Returns `:ok` if successful, `{:error, :out_of_bounds}` if position is invalid.

  ## Examples

      iex> {:ok, buffer} = Buffer.new(10, 10)
      iex> Buffer.set_cell(buffer, 1, 1, Cell.new("X"))
      :ok
      iex> Buffer.get_cell(buffer, 1, 1).char
      "X"
  """
  @spec set_cell(t(), pos_integer(), pos_integer(), Cell.t()) :: :ok | {:error, :out_of_bounds}
  def set_cell(%__MODULE__{} = buffer, row, col, %Cell{} = cell) do
    if in_bounds?(buffer, row, col) do
      :ets.insert(buffer.table, {{row, col}, cell})
      :ok
    else
      {:error, :out_of_bounds}
    end
  end

  @doc """
  Sets multiple cells at once for efficiency.

  Cells is a list of `{row, col, cell}` tuples.

  ## Examples

      iex> {:ok, buffer} = Buffer.new(10, 10)
      iex> cells = [{1, 1, Cell.new("A")}, {1, 2, Cell.new("B")}]
      iex> Buffer.set_cells(buffer, cells)
      :ok
  """
  @spec set_cells(t(), [{pos_integer(), pos_integer(), Cell.t()}]) :: :ok
  def set_cells(%__MODULE__{} = buffer, cells) when is_list(cells) do
    entries =
      cells
      |> Enum.filter(fn {row, col, _cell} -> in_bounds?(buffer, row, col) end)
      |> Enum.map(fn {row, col, cell} -> {{row, col}, cell} end)

    :ets.insert(buffer.table, entries)
    :ok
  end

  @doc """
  Clears a rectangular region, filling it with empty cells.

  ## Examples

      iex> {:ok, buffer} = Buffer.new(10, 10)
      iex> Buffer.clear_region(buffer, 1, 1, 5, 5)
      :ok
  """
  @spec clear_region(t(), pos_integer(), pos_integer(), pos_integer(), pos_integer()) :: :ok
  def clear_region(%__MODULE__{} = buffer, start_row, start_col, width, height)
      when is_integer(width) and width > 0 and is_integer(height) and height > 0 do
    empty = Cell.empty()

    entries =
      for row <- start_row..(start_row + height - 1),
          col <- start_col..(start_col + width - 1),
          in_bounds?(buffer, row, col) do
        {{row, col}, empty}
      end

    :ets.insert(buffer.table, entries)
    :ok
  end

  def clear_region(%__MODULE__{}, _start_row, _start_col, _width, _height) do
    # Invalid dimensions (width or height <= 0), do nothing
    :ok
  end

  @doc """
  Clears the entire buffer.

  ## Examples

      iex> {:ok, buffer} = Buffer.new(10, 10)
      iex> Buffer.clear(buffer)
      :ok
  """
  @spec clear(t()) :: :ok
  def clear(%__MODULE__{} = buffer) do
    clear_region(buffer, 1, 1, buffer.cols, buffer.rows)
  end

  @doc """
  Clears a single row.

  ## Examples

      iex> {:ok, buffer} = Buffer.new(10, 10)
      iex> Buffer.clear_row(buffer, 1)
      :ok
  """
  @spec clear_row(t(), pos_integer()) :: :ok
  def clear_row(%__MODULE__{} = buffer, row) do
    clear_region(buffer, row, 1, buffer.cols, 1)
  end

  @doc """
  Clears a single column.

  ## Examples

      iex> {:ok, buffer} = Buffer.new(10, 10)
      iex> Buffer.clear_col(buffer, 1)
      :ok
  """
  @spec clear_col(t(), pos_integer()) :: :ok
  def clear_col(%__MODULE__{} = buffer, col) do
    clear_region(buffer, 1, col, 1, buffer.rows)
  end

  @doc """
  Resizes the buffer, preserving content where possible.

  Content that fits in the new dimensions is preserved.
  New areas are filled with empty cells.

  ## Examples

      iex> {:ok, buffer} = Buffer.new(10, 10)
      iex> {:ok, new_buffer} = Buffer.resize(buffer, 20, 20)
      iex> new_buffer.rows
      20
  """
  @spec resize(t(), pos_integer(), pos_integer()) :: {:ok, t()} | {:error, term()}
  def resize(%__MODULE__{} = buffer, new_rows, new_cols)
      when is_integer(new_rows) and new_rows > 0 and is_integer(new_cols) and new_cols > 0 do
    cond do
      new_rows > @max_rows ->
        {:error, {:dimensions_too_large, "rows #{new_rows} exceeds maximum #{@max_rows}"}}

      new_cols > @max_cols ->
        {:error, {:dimensions_too_large, "cols #{new_cols} exceeds maximum #{@max_cols}"}}

      true ->
        # Create new buffer
        new_table = :ets.new(:buffer, [:ordered_set, :public])

        new_buffer = %__MODULE__{
          table: new_table,
          rows: new_rows,
          cols: new_cols
        }

        # Initialize new buffer with empty cells
        initialize_cells(new_buffer)

        # Copy existing content that fits
        copy_rows = min(buffer.rows, new_rows)
        copy_cols = min(buffer.cols, new_cols)

        for row <- 1..copy_rows, col <- 1..copy_cols do
          cell = get_cell(buffer, row, col)
          :ets.insert(new_table, {{row, col}, cell})
        end

        # Destroy old buffer
        destroy(buffer)

        {:ok, new_buffer}
    end
  end

  @doc """
  Returns buffer dimensions as `{rows, cols}`.
  """
  @spec dimensions(t()) :: {pos_integer(), pos_integer()}
  def dimensions(%__MODULE__{rows: rows, cols: cols}) do
    {rows, cols}
  end

  @doc """
  Checks if a position is within buffer bounds.
  """
  @spec in_bounds?(t(), pos_integer(), pos_integer()) :: boolean()
  def in_bounds?(%__MODULE__{rows: rows, cols: cols}, row, col) do
    row >= 1 and row <= rows and col >= 1 and col <= cols
  end

  @doc """
  Iterates over all cells in row-major order.

  Calls the function with `{row, col, cell}` for each cell.

  ## Examples

      iex> {:ok, buffer} = Buffer.new(2, 2)
      iex> Buffer.each(buffer, fn {row, col, cell} -> IO.inspect({row, col}) end)
      :ok
  """
  @spec each(t(), ({pos_integer(), pos_integer(), Cell.t()} -> any())) :: :ok
  def each(%__MODULE__{} = buffer, fun) when is_function(fun, 1) do
    :ets.foldl(
      fn {{row, col}, cell}, _acc ->
        fun.({row, col, cell})
        :ok
      end,
      :ok,
      buffer.table
    )
  end

  @doc """
  Gets all cells as a list of `{row, col, cell}` tuples in row-major order.
  """
  @spec to_list(t()) :: [{pos_integer(), pos_integer(), Cell.t()}]
  def to_list(%__MODULE__{} = buffer) do
    buffer.table
    |> :ets.tab2list()
    |> Enum.map(fn {{row, col}, cell} -> {row, col, cell} end)
    |> Enum.sort()
  end

  @doc """
  Gets a row as a list of cells.

  Uses a single ETS match operation for efficiency instead of
  individual cell lookups.
  """
  @spec get_row(t(), pos_integer()) :: [Cell.t()]
  def get_row(%__MODULE__{} = buffer, row) do
    if row >= 1 and row <= buffer.rows do
      # Single ETS operation to get all cells in row
      buffer.table
      |> :ets.match_object({{row, :_}, :_})
      |> Enum.sort_by(fn {{_row, col}, _cell} -> col end)
      |> Enum.map(fn {{_row, _col}, cell} -> cell end)
    else
      # Return empty cells for out-of-bounds row
      List.duplicate(Cell.empty(), buffer.cols)
    end
  end

  @doc """
  Writes a string starting at the given position.

  Returns the number of columns written.

  ## Examples

      iex> {:ok, buffer} = Buffer.new(10, 80)
      iex> Buffer.write_string(buffer, 1, 1, "Hello")
      5
  """
  @spec write_string(t(), pos_integer(), pos_integer(), String.t(), keyword()) :: non_neg_integer()
  def write_string(%__MODULE__{} = buffer, row, col, string, opts \\ []) do
    style = Keyword.get(opts, :style)

    string
    |> String.graphemes()
    |> Enum.reduce(col, fn grapheme, current_col ->
      if in_bounds?(buffer, row, current_col) do
        cell = build_cell(grapheme, style)
        set_cell(buffer, row, current_col, cell)

        # For wide characters, set placeholder in next column
        if Cell.wide?(cell) and in_bounds?(buffer, row, current_col + 1) do
          placeholder = Cell.wide_placeholder(cell)
          :ets.insert(buffer.table, {{row, current_col + 1}, placeholder})
        end

        # Advance by display width
        current_col + Cell.width(cell)
      else
        current_col
      end
    end)
    |> then(&(&1 - col))
  end

  defp build_cell(grapheme, nil), do: Cell.new(grapheme)
  defp build_cell(grapheme, style), do: Style.to_cell(style, grapheme)

  # Private helpers

  defp initialize_cells(%__MODULE__{} = buffer) do
    empty = Cell.empty()

    entries =
      for row <- 1..buffer.rows, col <- 1..buffer.cols do
        {{row, col}, empty}
      end

    :ets.insert(buffer.table, entries)
  end
end
