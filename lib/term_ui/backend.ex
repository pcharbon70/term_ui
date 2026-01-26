defmodule TermUI.Backend do
  @moduledoc """
  Behaviour defining the contract for terminal backends.

  The `TermUI.Backend` behaviour establishes a common interface for all terminal
  rendering backends in TermUI. This abstraction enables the framework to support
  multiple terminal environments:

  - **Raw mode** (`TermUI.Backend.Raw`): Direct terminal control with immediate
    keystroke detection, used when `:shell.start_interactive({:noshell, :raw})`
    succeeds (OTP 28+)

  - **TTY mode** (`TermUI.Backend.TTY`): Fallback rendering for constrained
    environments where raw mode is unavailable (Nerves devices, SSH sessions,
    remote IEx consoles)

  ## Implementing a Backend

  To implement a backend, define a module that uses this behaviour:

      defmodule MyBackend do
        @behaviour TermUI.Backend

        @impl true
        def init(opts) do
          # Initialize backend state
          {:ok, %{}}
        end

        @impl true
        def shutdown(state) do
          # Clean up resources
          :ok
        end

        # ... implement remaining callbacks
      end

  ## Backend Selection

  Backend selection is handled by `TermUI.Backend.Selector`, which uses the
  "try raw mode first" strategy. Applications typically don't interact with
  backends directly - the runtime handles backend lifecycle.

  ## Type Conventions

  - **Positions** are 1-indexed `{row, col}` tuples matching terminal standards
  - **Colors** can be `:default`, named atoms, 256-color indices, or RGB tuples
  - **Cells** are simplified tuples for the backend interface; the full
    `TermUI.Renderer.Cell` struct is used internally

  ## Callback Categories

  The callbacks are organized into categories:

  - **Lifecycle**: `init/1`, `shutdown/1` - backend setup and teardown
  - **Queries**: `size/1` - terminal state queries
  - **Cursor**: `move_cursor/2`, `hide_cursor/1`, `show_cursor/1` - cursor control
  - **Rendering**: `clear/1`, `draw_cells/2`, `flush/1` - screen output
  - **Input**: `poll_event/2` - keyboard/mouse input
  """

  # Type Definitions

  @typedoc """
  Cursor position as a 1-indexed `{row, col}` tuple.

  Row 1 is the top of the screen, column 1 is the left edge.
  This matches standard terminal addressing (ANSI escape sequences use 1-indexed positions).

  Note: Positions use `pos_integer()` (minimum 1) since terminal coordinates are 1-indexed.
  Position `{0, 0}` is invalid in terminal addressing.
  """
  @type position :: {row :: pos_integer(), col :: pos_integer()}

  @typedoc """
  Terminal dimensions as `{rows, cols}`.

  Represents the current terminal size in character cells.
  Terminals always have at least 1 row and 1 column.
  """
  @type size :: {rows :: pos_integer(), cols :: pos_integer()}

  @typedoc """
  Color specification for foreground or background.

  Supports multiple color formats:
  - `:default` - Terminal default color
  - Named atoms - Basic colors (`:red`, `:green`, `:blue`, etc.)
  - `0..255` - 256-color palette index
  - `{r, g, b}` - True color RGB values (0-255 each)
  """
  @type color :: :default | atom() | 0..255 | {r :: 0..255, g :: 0..255, b :: 0..255}

  @typedoc """
  A terminal cell for backend rendering.

  Simplified tuple format for the backend interface:
  - `char` - The character to display (grapheme cluster)
  - `fg` - Foreground color
  - `bg` - Background color
  - `attrs` - Style attributes (`:bold`, `:underline`, etc.)

  This is a simplified representation for backend communication. The full
  `TermUI.Renderer.Cell` struct is used internally by the renderer.
  """
  @type cell :: {char :: String.t(), fg :: color(), bg :: color(), attrs :: [atom()]}

  @typedoc """
  Input event from the terminal.

  Alias for `TermUI.Event.t()` which includes key, mouse, focus, and other events.
  """
  @type event :: TermUI.Event.t()

  @typedoc """
  Backend-specific internal state.

  Each backend implementation maintains its own state structure.
  This is opaque to callers - only the backend module interprets it.
  """
  @type state :: term()

  # Lifecycle Callbacks

  @doc """
  Initializes the backend with the given options.

  Called once during runtime startup. The options may include:
  - `:capabilities` - Map of detected terminal capabilities (TTY mode)
  - Backend-specific options

  Returns `{:ok, state}` on success or `{:error, reason}` on failure.

  ## Implementation Notes

  - Raw backend receives options from successful `:shell.start_interactive/1`
  - TTY backend receives capabilities map from `Backend.Selector`
  - Should set up terminal state (alternate screen, cursor hiding, etc.)
  """
  @callback init(opts :: keyword()) :: {:ok, state()} | {:error, reason :: term()}

  @doc """
  Shuts down the backend and restores terminal state.

  Called during runtime shutdown. Must:
  - Restore terminal to its original state
  - Release any held resources
  - Be idempotent (safe to call multiple times)
  - Handle errors gracefully (always return `:ok`)

  ## Implementation Notes

  - Should restore cursor visibility
  - Should exit alternate screen if entered
  - Should reset all attributes
  """
  @callback shutdown(state()) :: :ok

  # Query Callbacks

  @doc """
  Returns the current terminal dimensions.

  Returns `{:ok, {rows, cols}}` with the terminal size.
  Returns `{:error, :enotsup}` if size cannot be determined.

  ## Implementation Notes

  - Size may be cached and require explicit refresh after resize events
  - TTY backend may use `:io.columns/0` and `:io.rows/0`
  - Raw backend may query terminal directly
  """
  @callback size(state()) :: {:ok, size()} | {:error, :enotsup}

  # Cursor Callbacks

  @doc """
  Moves the cursor to the specified position.

  Position is 1-indexed: `{1, 1}` is the top-left corner.

  Returns `{:ok, updated_state}` after positioning.

  ## Implementation Notes

  - Maps to ANSI CSI sequence `ESC[row;colH`
  - Position should be clamped to terminal bounds
  """
  @callback move_cursor(state(), position()) :: {:ok, state()}

  @doc """
  Hides the terminal cursor.

  Returns `{:ok, updated_state}` after hiding cursor.

  Typically called before rendering to prevent cursor flicker.
  Maps to ANSI CSI sequence `ESC[?25l`.
  """
  @callback hide_cursor(state()) :: {:ok, state()}

  @doc """
  Shows the terminal cursor.

  Returns `{:ok, updated_state}` after showing cursor.

  Called after rendering or when cursor visibility is needed.
  Maps to ANSI CSI sequence `ESC[?25h`.
  """
  @callback show_cursor(state()) :: {:ok, state()}

  # Rendering Callbacks

  @doc """
  Clears the entire screen.

  Returns `{:ok, updated_state}` after clearing.

  Typically resets cursor to home position as well.
  Maps to ANSI CSI sequence `ESC[2J` followed by `ESC[H`.
  """
  @callback clear(state()) :: {:ok, state()}

  @doc """
  Draws cells to the terminal at specified positions.

  Receives a list of `{position, cell}` tuples. Cells are sorted by position
  (row-major order) for efficient sequential output.

  Returns `{:ok, updated_state}` after drawing.

  ## Implementation Notes

  - Raw backend uses differential rendering (only changed cells)
  - TTY backend may use full redraw depending on configuration
  - Should optimize cursor movement between cells
  """
  @callback draw_cells(state(), [{position(), cell()}]) :: {:ok, state()}

  @doc """
  Flushes pending output to the terminal.

  Ensures all buffered output is sent to the terminal device.
  Returns `{:ok, updated_state}` after flushing.

  ## Implementation Notes

  - May be a no-op if output is unbuffered
  - Should be called after `draw_cells/2` to ensure visibility
  """
  @callback flush(state()) :: {:ok, state()}

  # Input Callback

  @doc """
  Polls for input events with the specified timeout.

  - `timeout` - Milliseconds to wait for input (0 for non-blocking)

  Returns:
  - `{:ok, event, updated_state}` - Event received
  - `{:timeout, updated_state}` - No input within timeout
  - `{:error, reason, state}` - Error occurred

  ## Implementation Notes

  - Raw backend provides immediate keystroke detection
  - TTY backend uses `IO.getn/2` for character-by-character input
  - Timeout may not be honored precisely in TTY mode (blocking IO)
  - Events should be parsed into `TermUI.Event` structs
  """
  @callback poll_event(state(), timeout :: non_neg_integer()) ::
              {:ok, event(), state()} | {:timeout, state()} | {:error, reason :: term(), state()}
end
