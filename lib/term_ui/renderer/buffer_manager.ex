defmodule TermUI.Renderer.BufferManager do
  @moduledoc """
  GenServer managing double-buffered screen rendering.

  The BufferManager owns two ETS-based buffers:
  - **Current buffer**: Components write to this buffer
  - **Previous buffer**: Contains the last rendered frame for diffing

  After rendering, `swap_buffers/0` exchanges the buffer references atomically.
  This enables efficient differential updates without copying buffer contents.

  ## Usage

      # Start the manager
      {:ok, pid} = BufferManager.start_link(rows: 24, cols: 80)

      # Get buffer for writing
      buffer = BufferManager.get_current_buffer()
      Buffer.set_cell(buffer, 1, 1, Cell.new("X"))

      # Mark dirty after modifications
      BufferManager.mark_dirty()

      # Check if render needed
      if BufferManager.dirty?() do
        current = BufferManager.get_current_buffer()
        previous = BufferManager.get_previous_buffer()
        # ... perform diff and render ...
        BufferManager.swap_buffers()
        BufferManager.clear_dirty()
      end

  ## Concurrency

  Multiple processes can write to the current buffer concurrently via ETS.
  Cell writes are atomic but unordered—last writer wins for overlapping cells.
  Components should write to non-overlapping regions for deterministic results.

  ## Dirty Flag

  The dirty flag uses `:atomics` for lock-free concurrent access. Any process
  can mark the buffer dirty after modifications, and the renderer checks and
  clears the flag during the render cycle.
  """

  use GenServer

  alias TermUI.Renderer.Buffer

  @type t :: %__MODULE__{
          current: Buffer.t(),
          previous: Buffer.t(),
          dirty: :atomics.atomics_ref()
        }

  defstruct current: nil,
            previous: nil,
            dirty: nil

  # Client API

  @doc """
  Starts the BufferManager with the given dimensions.

  ## Options

    * `:rows` - Number of rows (required)
    * `:cols` - Number of columns (required)
    * `:name` - GenServer name (default: `__MODULE__`)

  ## Examples

      {:ok, pid} = BufferManager.start_link(rows: 24, cols: 80)
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Returns the current buffer for writing.

  Components use this buffer for all cell modifications.
  """
  @spec get_current_buffer(GenServer.server()) :: Buffer.t()
  def get_current_buffer(server \\ __MODULE__) do
    GenServer.call(server, :get_current_buffer)
  end

  @doc """
  Returns the previous buffer for diffing.

  The renderer compares current against previous to identify changes.
  """
  @spec get_previous_buffer(GenServer.server()) :: Buffer.t()
  def get_previous_buffer(server \\ __MODULE__) do
    GenServer.call(server, :get_previous_buffer)
  end

  @doc """
  Atomically swaps the current and previous buffers.

  After rendering, call this to make the current frame the new previous
  frame for the next render cycle. This is O(1)—only references swap.
  """
  @spec swap_buffers(GenServer.server()) :: :ok
  def swap_buffers(server \\ __MODULE__) do
    GenServer.call(server, :swap_buffers)
  end

  @doc """
  Returns the buffer dimensions as `{rows, cols}`.
  """
  @spec dimensions(GenServer.server()) :: {pos_integer(), pos_integer()}
  def dimensions(server \\ __MODULE__) do
    GenServer.call(server, :dimensions)
  end

  @doc """
  Resizes both buffers to new dimensions.

  Content is preserved where it fits within the new dimensions.
  """
  @spec resize(GenServer.server(), pos_integer(), pos_integer()) :: :ok
  def resize(server \\ __MODULE__, rows, cols) do
    GenServer.call(server, {:resize, rows, cols})
  end

  @doc """
  Clears the entire current buffer.
  """
  @spec clear_current(GenServer.server()) :: :ok
  def clear_current(server \\ __MODULE__) do
    GenServer.call(server, :clear_current)
  end

  @doc """
  Clears a single row in the current buffer.
  """
  @spec clear_row(GenServer.server(), pos_integer()) :: :ok
  def clear_row(server \\ __MODULE__, row) do
    GenServer.call(server, {:clear_row, row})
  end

  @doc """
  Clears a rectangular region in the current buffer.
  """
  @spec clear_region(GenServer.server(), pos_integer(), pos_integer(), pos_integer(), pos_integer()) ::
          :ok
  def clear_region(server \\ __MODULE__, start_row, start_col, width, height) do
    GenServer.call(server, {:clear_region, start_row, start_col, width, height})
  end

  @doc """
  Marks the buffer as dirty, indicating it needs rendering.

  This uses an atomic operation and can be called from any process.
  """
  @spec mark_dirty(GenServer.server()) :: :ok
  def mark_dirty(server \\ __MODULE__) do
    GenServer.call(server, :mark_dirty)
  end

  @doc """
  Clears the dirty flag after rendering.
  """
  @spec clear_dirty(GenServer.server()) :: :ok
  def clear_dirty(server \\ __MODULE__) do
    GenServer.call(server, :clear_dirty)
  end

  @doc """
  Returns whether the buffer is dirty and needs rendering.
  """
  @spec dirty?(GenServer.server()) :: boolean()
  def dirty?(server \\ __MODULE__) do
    GenServer.call(server, :dirty?)
  end

  @doc """
  Sets a cell in the current buffer.

  Convenience function that delegates to Buffer.set_cell/4.
  """
  @spec set_cell(GenServer.server(), pos_integer(), pos_integer(), TermUI.Renderer.Cell.t()) ::
          :ok | {:error, :out_of_bounds}
  def set_cell(server \\ __MODULE__, row, col, cell) do
    buffer = get_current_buffer(server)
    Buffer.set_cell(buffer, row, col, cell)
  end

  @doc """
  Sets multiple cells in the current buffer.

  Cells is a list of `{row, col, cell}` tuples.
  """
  @spec set_cells(GenServer.server(), [{pos_integer(), pos_integer(), TermUI.Renderer.Cell.t()}]) ::
          :ok
  def set_cells(server \\ __MODULE__, cells) do
    buffer = get_current_buffer(server)
    Buffer.set_cells(buffer, cells)
  end

  @doc """
  Gets a cell from the current buffer.

  Convenience function that delegates to Buffer.get_cell/3.
  """
  @spec get_cell(GenServer.server(), pos_integer(), pos_integer()) :: TermUI.Renderer.Cell.t()
  def get_cell(server \\ __MODULE__, row, col) do
    buffer = get_current_buffer(server)
    Buffer.get_cell(buffer, row, col)
  end

  @doc """
  Writes a string to the current buffer.

  Convenience function that delegates to Buffer.write_string/4.
  """
  @spec write_string(GenServer.server(), pos_integer(), pos_integer(), String.t(), keyword()) ::
          non_neg_integer()
  def write_string(server \\ __MODULE__, row, col, string, opts \\ []) do
    buffer = get_current_buffer(server)
    Buffer.write_string(buffer, row, col, string, opts)
  end

  # Server Callbacks

  @impl true
  def init(opts) do
    rows = Keyword.fetch!(opts, :rows)
    cols = Keyword.fetch!(opts, :cols)

    {:ok, current} = Buffer.new(rows, cols)
    {:ok, previous} = Buffer.new(rows, cols)

    # Create atomic for dirty flag (1 element, signed 64-bit)
    dirty = :atomics.new(1, signed: false)

    state = %__MODULE__{
      current: current,
      previous: previous,
      dirty: dirty
    }

    {:ok, state}
  end

  @impl true
  def handle_call(:get_current_buffer, _from, state) do
    {:reply, state.current, state}
  end

  @impl true
  def handle_call(:get_previous_buffer, _from, state) do
    {:reply, state.previous, state}
  end

  @impl true
  def handle_call(:swap_buffers, _from, state) do
    new_state = %{state | current: state.previous, previous: state.current}
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call(:dimensions, _from, state) do
    {:reply, Buffer.dimensions(state.current), state}
  end

  @impl true
  def handle_call({:resize, rows, cols}, _from, state) do
    {:ok, new_current} = Buffer.resize(state.current, rows, cols)
    {:ok, new_previous} = Buffer.resize(state.previous, rows, cols)

    new_state = %{state | current: new_current, previous: new_previous}
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call(:clear_current, _from, state) do
    Buffer.clear(state.current)
    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:clear_row, row}, _from, state) do
    Buffer.clear_row(state.current, row)
    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:clear_region, start_row, start_col, width, height}, _from, state) do
    Buffer.clear_region(state.current, start_row, start_col, width, height)
    {:reply, :ok, state}
  end

  @impl true
  def handle_call(:mark_dirty, _from, state) do
    :atomics.put(state.dirty, 1, 1)
    {:reply, :ok, state}
  end

  @impl true
  def handle_call(:clear_dirty, _from, state) do
    :atomics.put(state.dirty, 1, 0)
    {:reply, :ok, state}
  end

  @impl true
  def handle_call(:dirty?, _from, state) do
    value = :atomics.get(state.dirty, 1)
    {:reply, value == 1, state}
  end

  @impl true
  def terminate(_reason, state) do
    # Clean up ETS tables
    Buffer.destroy(state.current)
    Buffer.destroy(state.previous)
    :ok
  end
end
