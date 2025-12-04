defmodule TermUI.Backend.Raw do
  @moduledoc """
  Raw terminal backend providing full terminal control.

  The Raw backend is the primary high-fidelity rendering path in TermUI. It provides
  direct terminal control with immediate keystroke detection, true color support,
  mouse tracking, and all advanced terminal features.

  ## Requirements

  - **OTP 28+**: Raw mode is activated via `:shell.start_interactive({:noshell, :raw})`
  - **Terminal access**: Requires a real terminal (not pipes or redirected I/O)

  ## How It Works

  The Raw backend assumes raw mode has already been activated by `TermUI.Backend.Selector`
  before `init/1` is called. The selector uses `:shell.start_interactive({:noshell, :raw})`
  to enter raw mode, and on success, routes to this backend.

  **Important**: The `init/1` callback does NOT activate raw mode itself. It only performs
  terminal setup (alternate screen, cursor hiding, etc.) assuming raw mode is already active.

  ## Features

  When raw mode is active, this backend provides:

  - **Alternate screen buffer**: Preserves original terminal content, restored on exit
  - **Cursor control**: Hide/show cursor, precise positioning
  - **True color rendering**: Full 24-bit RGB color support (`{r, g, b}` tuples)
  - **256-color palette**: Extended color support (0-255 indices)
  - **Mouse tracking**: Click, drag, and movement detection
  - **Immediate input**: Character-by-character keystroke detection
  - **Escape sequence handling**: Function keys, arrow keys, modifiers

  ## Initialization Flow

  ```
  1. Selector calls :shell.start_interactive({:noshell, :raw})
     └── Returns :ok (raw mode active)

  2. Runtime creates Raw backend state
     └── Calls Raw.init(opts)

  3. Raw.init/1 performs terminal setup:
     ├── Enter alternate screen buffer (optional)
     ├── Hide cursor
     ├── Enable mouse tracking (optional)
     └── Clear screen
  ```

  ## Configuration Options

  The `init/1` callback accepts these options:

  - `:alternate_screen` - Use alternate screen buffer (default: `true`)
  - `:hide_cursor` - Hide cursor during rendering (default: `true`)
  - `:mouse_tracking` - Mouse tracking mode (default: `:none`)
    - `:none` - No mouse tracking
    - `:click` - Track button clicks only
    - `:drag` - Track clicks and drag events
    - `:all` - Track all mouse movement
  - `:size` - Explicit terminal dimensions `{rows, cols}` (default: auto-detect)

  ## Shutdown Behavior

  The `shutdown/1` callback restores the terminal to its pre-init state:

  1. Disable mouse tracking (if enabled)
  2. Show cursor
  3. Reset all text attributes
  4. Leave alternate screen (if entered)
  5. Return to cooked mode via `:shell.start_interactive({:noshell, :cooked})`

  Shutdown is designed to be error-safe - individual failures don't prevent
  subsequent cleanup steps from running.

  ## Usage Example

  This backend is typically used via the runtime, not directly:

      # Automatic backend selection (recommended)
      {:ok, runtime} = TermUI.Runtime.start_link()

      # The runtime handles:
      # 1. Backend selection via Selector
      # 2. Backend initialization
      # 3. Rendering via draw_cells/2
      # 4. Input polling via poll_event/2
      # 5. Clean shutdown

  ## See Also

  - `TermUI.Backend` - Behaviour definition
  - `TermUI.Backend.Selector` - Backend selection logic
  - `TermUI.Backend.TTY` - Fallback backend for non-raw environments
  - `TermUI.ANSI` - Escape sequence generation
  """

  @behaviour TermUI.Backend

  alias TermUI.ANSI

  # Stub implementations for behaviour callbacks
  # These will be fully implemented in subsequent tasks (2.2.x - 2.8.x)

  @impl true
  @doc """
  Initializes the Raw backend with terminal setup.

  Assumes raw mode is already active (started by Selector). Performs terminal
  configuration including alternate screen, cursor hiding, and mouse tracking.

  ## Options

  - `:alternate_screen` - Use alternate screen buffer (default: `true`)
  - `:hide_cursor` - Hide cursor during rendering (default: `true`)
  - `:mouse_tracking` - Mouse tracking mode (default: `:none`)
  - `:size` - Explicit dimensions `{rows, cols}` (default: auto-detect)

  ## Returns

  - `{:ok, state}` on success
  - `{:error, reason}` on failure
  """
  @spec init(keyword()) :: {:ok, term()} | {:error, term()}
  def init(_opts \\ []) do
    # Stub - will be implemented in Task 2.2.1
    {:ok, %{}}
  end

  @impl true
  @doc """
  Shuts down the backend and restores terminal state.

  Performs cleanup in order: disable mouse, show cursor, reset attributes,
  leave alternate screen, return to cooked mode. Error-safe - continues
  cleanup even if individual steps fail.
  """
  @spec shutdown(term()) :: :ok
  def shutdown(_state) do
    # Stub - will be implemented in Task 2.2.3
    :ok
  end

  @impl true
  @doc """
  Returns the current terminal dimensions.

  Returns cached size from state. Use `refresh_size/1` to re-query.
  """
  @spec size(term()) :: {:ok, TermUI.Backend.size()} | {:error, :enotsup}
  def size(_state) do
    # Stub - will be implemented in Task 2.4.2
    {:error, :enotsup}
  end

  @impl true
  @doc """
  Moves the cursor to the specified position.

  Position is 1-indexed: `{1, 1}` is the top-left corner.
  """
  @spec move_cursor(term(), TermUI.Backend.position()) :: {:ok, term()}
  def move_cursor(state, _position) do
    # Stub - will be implemented in Task 2.3.1
    {:ok, state}
  end

  @impl true
  @doc """
  Hides the terminal cursor.

  Uses ANSI sequence `ESC[?25l`.
  """
  @spec hide_cursor(term()) :: {:ok, term()}
  def hide_cursor(state) do
    # Stub - will be implemented in Task 2.3.2
    {:ok, state}
  end

  @impl true
  @doc """
  Shows the terminal cursor.

  Uses ANSI sequence `ESC[?25h`.
  """
  @spec show_cursor(term()) :: {:ok, term()}
  def show_cursor(state) do
    # Stub - will be implemented in Task 2.3.2
    {:ok, state}
  end

  @impl true
  @doc """
  Clears the entire screen and moves cursor to home.

  Uses ANSI sequences `ESC[2J` (clear) and `ESC[1;1H` (home).
  """
  @spec clear(term()) :: {:ok, term()}
  def clear(state) do
    # Stub - will be implemented in Task 2.4.1
    {:ok, state}
  end

  @impl true
  @doc """
  Draws cells to the terminal at specified positions.

  Cells are rendered with optimized cursor movement and style delta tracking
  to minimize escape sequence output.
  """
  @spec draw_cells(term(), [{TermUI.Backend.position(), TermUI.Backend.cell()}]) :: {:ok, term()}
  def draw_cells(state, _cells) do
    # Stub - will be implemented in Task 2.5.1
    {:ok, state}
  end

  @impl true
  @doc """
  Flushes pending output to the terminal.

  For the Raw backend, `IO.write/1` is synchronous so this is largely a no-op.
  """
  @spec flush(term()) :: {:ok, term()}
  def flush(state) do
    # Stub - will be implemented in Task 2.6.1
    {:ok, state}
  end

  @impl true
  @doc """
  Polls for input events with the specified timeout.

  In raw mode, input arrives character-by-character enabling real-time
  keyboard and mouse event handling.

  ## Returns

  - `{:ok, event, state}` - Event received
  - `{:timeout, state}` - No input within timeout
  - `{:error, reason, state}` - Error occurred
  """
  @spec poll_event(term(), non_neg_integer()) ::
          {:ok, TermUI.Backend.event(), term()}
          | {:timeout, term()}
          | {:error, term(), term()}
  def poll_event(state, _timeout) do
    # Stub - will be implemented in Task 2.7.1
    {:timeout, state}
  end

  # Keep the ANSI alias visible for future use
  # This satisfies subtask 2.1.1.4
  @doc false
  def ansi_module, do: ANSI
end
