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

  ## Mouse Tracking Modes

  The Raw backend uses intuitive mode names that map to underlying ANSI protocol modes:

  | Raw Backend | ANSI Protocol | Escape Sequence | Description |
  |-------------|---------------|-----------------|-------------|
  | `:none`     | (disabled)    | -               | No mouse tracking |
  | `:click`    | Normal (1000) | `ESC[?1000h`    | Button press/release only |
  | `:drag`     | Button (1002) | `ESC[?1002h`    | Press/release + motion while pressed |
  | `:all`      | Any (1003)    | `ESC[?1003h`    | All mouse motion events |

  When mouse tracking is enabled, SGR extended mode (`ESC[?1006h`) is also activated
  for accurate coordinate encoding beyond column 223.

  Note: The `TermUI.ANSI` module uses protocol names (`:normal`, `:button`, `:all`),
  while this backend uses user-friendly names (`:click`, `:drag`, `:all`). The mapping
  is handled internally when emitting sequences.

  ## Style Delta Optimization

  The `current_style` field in the backend state tracks the last-emitted SGR (Select
  Graphic Rendition) attributes. This enables **style delta optimization** in
  `draw_cells/2`:

  Instead of emitting full style sequences for every cell:
  ```
  ESC[0;38;2;255;0;0;48;2;0;0;0mA  <- 25 bytes per cell
  ESC[0;38;2;255;0;0;48;2;0;0;0mB
  ```

  We only emit changes from the previous style:
  ```
  ESC[38;2;255;0;0;48;2;0;0;0mA   <- Full style for first cell
  B                                <- No escape needed, same style!
  ESC[38;2;0;255;0mC              <- Only foreground changed
  ```

  This optimization can reduce escape sequence output by 80-90% for typical UIs
  where adjacent cells share styles (text blocks, borders, backgrounds).

  The `current_style` map tracks:
  - `:fg` - Current foreground color
  - `:bg` - Current background color
  - `:attrs` - Current text attributes (`:bold`, `:underline`, `:reverse`, etc.)

  ## See Also

  - `TermUI.Backend` - Behaviour definition
  - `TermUI.Backend.Selector` - Backend selection logic
  - `TermUI.Backend.TTY` - Fallback backend for non-raw environments
  - `TermUI.ANSI` - Escape sequence generation
  """

  @behaviour TermUI.Backend

  alias TermUI.ANSI
  require Logger

  # Comprehensive mouse disable sequence - disables ALL mouse modes defensively
  # This ensures cleanup even if state is inconsistent
  @all_mouse_off "\e[?1006l\e[?1003l\e[?1002l\e[?1000l"

  # ===========================================================================
  # Type Definitions and State Structure
  # ===========================================================================

  @typedoc """
  Mouse tracking mode for the terminal.

  These are user-friendly names that map to ANSI protocol modes internally:

  - `:none` - No mouse tracking (disabled)
  - `:click` - Track button press/release only (ANSI "normal" mode, 1000)
  - `:drag` - Track clicks and motion while button pressed (ANSI "button" mode, 1002)
  - `:all` - Track all mouse movement (ANSI "any" mode, 1003)

  See the "Mouse Tracking Modes" section in the module documentation for details.
  """
  @type mouse_mode :: :none | :click | :drag | :all

  @typedoc """
  Current SGR (Select Graphic Rendition) style state.

  Tracks the current foreground color, background color, and text attributes
  to enable style delta optimization - only emitting escape sequences for
  changed attributes.

  ## Fields

  - `:fg` - Current foreground color (see `TermUI.Backend.color()`)
  - `:bg` - Current background color (see `TermUI.Backend.color()`)
  - `:attrs` - List of active text attributes:
    - `:bold` - Bold/bright text
    - `:dim` - Dimmed text
    - `:italic` - Italic text
    - `:underline` - Underlined text
    - `:blink` - Blinking text
    - `:reverse` - Swapped foreground/background
    - `:hidden` - Hidden text
    - `:strikethrough` - Struck-through text

  See the "Style Delta Optimization" section in the module documentation for
  how this enables efficient rendering.
  """
  @type style_state :: %{
          fg: TermUI.Backend.color(),
          bg: TermUI.Backend.color(),
          attrs: [atom()]
        }

  @typedoc """
  Internal state for the Raw backend.

  Tracks all terminal state needed for rendering and input handling.

  ## Fields

  - `:size` - Terminal dimensions as `{rows, cols}`
  - `:cursor_visible` - Whether cursor is currently visible (default: `false`)
  - `:cursor_position` - Current cursor position as `{row, col}` or `nil`
  - `:alternate_screen` - Whether alternate screen buffer is active
  - `:mouse_mode` - Current mouse tracking mode
  - `:current_style` - Current SGR state for style delta tracking
  """
  @type t :: %__MODULE__{
          size: {pos_integer(), pos_integer()},
          cursor_visible: boolean(),
          cursor_position: {pos_integer(), pos_integer()} | nil,
          alternate_screen: boolean(),
          mouse_mode: mouse_mode(),
          current_style: style_state() | nil
        }

  defstruct size: {24, 80},
            cursor_visible: false,
            cursor_position: nil,
            alternate_screen: false,
            mouse_mode: :none,
            current_style: nil

  # ===========================================================================
  # Behaviour Callbacks - Lifecycle, Queries, Cursor, Rendering, Input
  # ===========================================================================
  # Full implementations will be added in subsequent tasks

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
  - `{:error, :invalid_size}` if size option is malformed
  - `{:error, :terminal_setup_failed}` if terminal configuration fails
  - `{:error, :size_detection_failed}` if auto-detect fails and no size provided

  ## Examples

      # Default initialization
      {:ok, state} = Raw.init([])

      # With explicit options
      {:ok, state} = Raw.init(
        alternate_screen: true,
        hide_cursor: true,
        mouse_tracking: :click,
        size: {24, 80}
      )
  """
  @spec init(keyword()) :: {:ok, t()} | {:error, term()}
  def init(opts \\ []) do
    # Parse options with defaults
    alternate_screen = Keyword.get(opts, :alternate_screen, true)
    hide_cursor = Keyword.get(opts, :hide_cursor, true)
    mouse_tracking = Keyword.get(opts, :mouse_tracking, :none)
    size_opt = Keyword.get(opts, :size, nil)

    # Validate and get terminal size
    with {:ok, size} <- get_terminal_size(size_opt) do
      # Perform terminal setup sequence
      # Order: alternate screen -> hide cursor -> mouse tracking -> clear
      if alternate_screen do
        write_to_terminal(ANSI.enter_alternate_screen())
      end

      if hide_cursor do
        write_to_terminal(ANSI.cursor_hide())
      end

      if mouse_tracking != :none do
        ansi_mode = mouse_mode_to_ansi(mouse_tracking)

        if ansi_mode do
          write_to_terminal(ANSI.enable_mouse_tracking(ansi_mode))
          write_to_terminal(ANSI.enable_sgr_mouse())
        end
      end

      # Clear screen and home cursor
      write_to_terminal(ANSI.clear_screen())
      write_to_terminal(ANSI.cursor_position(1, 1))

      # Build initial state
      state = %__MODULE__{
        size: size,
        cursor_visible: not hide_cursor,
        cursor_position: {1, 1},
        alternate_screen: alternate_screen,
        mouse_mode: mouse_tracking,
        current_style: nil
      }

      {:ok, state}
    end
  end

  @impl true
  @doc """
  Shuts down the backend and restores terminal state.

  Performs cleanup in order: disable mouse, show cursor, reset attributes,
  leave alternate screen, return to cooked mode.

  ## Error Safety

  This function is designed to be error-safe:
  - Each cleanup step is wrapped in try/rescue
  - Individual failures are logged but don't prevent subsequent steps
  - Always returns `:ok` regardless of individual step failures
  - Idempotent: safe to call multiple times

  ## Cleanup Sequence

  1. Disable mouse tracking (if enabled)
  2. Show cursor (ANSI: `ESC[?25h`)
  3. Reset all text attributes (ANSI: `ESC[0m`)
  4. Leave alternate screen (ANSI: `ESC[?1049l`)
  5. Return to cooked mode via `:shell.start_interactive({:noshell, :cooked})`
  """
  @spec shutdown(t()) :: :ok
  def shutdown(state) do
    # Disable mouse tracking if it was enabled
    # Use defensive cleanup - disable ALL modes regardless of state
    safe_write(@all_mouse_off)

    # Show cursor (always, even if state says visible - defensive)
    safe_write(ANSI.cursor_show())

    # Reset all text attributes
    safe_write(ANSI.reset())

    # Leave alternate screen if it was entered
    if state.alternate_screen do
      safe_write(ANSI.leave_alternate_screen())
    end

    # Return to cooked mode
    safe_cooked_mode()

    :ok
  end

  @impl true
  @doc """
  Returns the current terminal dimensions.

  Returns cached size from state. Use `refresh_size/1` to re-query.
  """
  @spec size(t()) :: {:ok, TermUI.Backend.size()} | {:error, :enotsup}
  def size(state) do
    # Stub - will be implemented in Task 2.4.2
    {:ok, state.size}
  end

  @impl true
  @doc """
  Moves the cursor to the specified position.

  Position is 1-indexed: `{1, 1}` is the top-left corner.

  ## Position Validation

  Positions must have positive integer coordinates. The position will be
  clamped to terminal bounds in the implementation to prevent invalid
  cursor states.

  ## Examples

      {:ok, state} = Raw.move_cursor(state, {1, 1})   # Top-left
      {:ok, state} = Raw.move_cursor(state, {24, 80}) # Bottom-right (80x24)
  """
  @spec move_cursor(t(), TermUI.Backend.position()) :: {:ok, t()}
  def move_cursor(state, {row, col} = position)
      when is_integer(row) and is_integer(col) and row > 0 and col > 0 do
    # Generate and write cursor position escape sequence
    sequence = ANSI.cursor_position(row, col)
    write_to_terminal(sequence)

    # Update state with new cursor position
    updated_state = %{state | cursor_position: position}

    {:ok, updated_state}
  end

  @impl true
  @doc """
  Hides the terminal cursor.

  Uses ANSI sequence `ESC[?25l` (DECTCEM off).

  This operation is idempotent - if the cursor is already hidden,
  no escape sequence is written and the state is returned unchanged.
  """
  @spec hide_cursor(t()) :: {:ok, t()}
  def hide_cursor(%__MODULE__{cursor_visible: false} = state) do
    # Already hidden - idempotent no-op
    {:ok, state}
  end

  def hide_cursor(state) do
    # Write hide cursor sequence
    write_to_terminal(ANSI.cursor_hide())

    # Update state
    updated_state = %{state | cursor_visible: false}

    {:ok, updated_state}
  end

  @impl true
  @doc """
  Shows the terminal cursor.

  Uses ANSI sequence `ESC[?25h` (DECTCEM on).

  This operation is idempotent - if the cursor is already visible,
  no escape sequence is written and the state is returned unchanged.
  """
  @spec show_cursor(t()) :: {:ok, t()}
  def show_cursor(%__MODULE__{cursor_visible: true} = state) do
    # Already visible - idempotent no-op
    {:ok, state}
  end

  def show_cursor(state) do
    # Write show cursor sequence
    write_to_terminal(ANSI.cursor_show())

    # Update state
    updated_state = %{state | cursor_visible: true}

    {:ok, updated_state}
  end

  @impl true
  @doc """
  Clears the entire screen and moves cursor to home.

  Uses ANSI sequences `ESC[2J` (clear) and `ESC[1;1H` (home).
  """
  @spec clear(t()) :: {:ok, t()}
  def clear(state) do
    # Stub - full implementation in Section 2.4
    {:ok, state}
  end

  @impl true
  @doc """
  Draws cells to the terminal at specified positions.

  Cells are rendered with optimized cursor movement and style delta tracking
  to minimize escape sequence output. See the "Style Delta Optimization" section
  in the module documentation for details on how this works.

  ## Cell Format

  Each cell is a tuple `{position, cell_data}` where:
  - `position` is `{row, col}` (1-indexed)
  - `cell_data` is `{char, fg, bg, attrs}`

  ## Performance

  This function uses several optimizations:
  - Style delta tracking (only emit changed attributes)
  - Relative cursor movement when cheaper than absolute
  - Batched I/O writes
  """
  @spec draw_cells(t(), [{TermUI.Backend.position(), TermUI.Backend.cell()}]) :: {:ok, t()}
  def draw_cells(state, _cells) do
    # Stub - full implementation in Section 2.5
    {:ok, state}
  end

  @impl true
  @doc """
  Flushes pending output to the terminal.

  For the Raw backend, `IO.write/1` is synchronous so this is largely a no-op.
  """
  @spec flush(t()) :: {:ok, t()}
  def flush(state) do
    # Stub - full implementation in Section 2.6
    {:ok, state}
  end

  @impl true
  @doc """
  Polls for input events with the specified timeout.

  In raw mode, input arrives character-by-character enabling real-time
  keyboard and mouse event handling.

  ## Parameters

  - `state` - Current backend state
  - `timeout` - Milliseconds to wait (0 for non-blocking)

  ## Returns

  - `{:ok, event, state}` - Event received and parsed
  - `{:timeout, state}` - No input within timeout period
  - `{:error, :io_error, state}` - Terminal I/O error occurred
  - `{:error, :parse_error, state}` - Failed to parse input sequence
  """
  @spec poll_event(t(), non_neg_integer()) ::
          {:ok, TermUI.Backend.event(), t()}
          | {:timeout, t()}
          | {:error, term(), t()}
  def poll_event(state, _timeout) do
    # Stub - full implementation in Section 2.7
    {:timeout, state}
  end

  # ===========================================================================
  # Helper Functions
  # ===========================================================================

  @doc """
  Checks if a position is valid within the terminal bounds.

  Returns `true` if the position has positive coordinates and is within
  the terminal dimensions stored in state.

  ## Examples

      iex> state = %Raw{size: {24, 80}}
      iex> Raw.valid_position?(state, {1, 1})
      true
      iex> Raw.valid_position?(state, {24, 80})
      true
      iex> Raw.valid_position?(state, {25, 1})
      false
      iex> Raw.valid_position?(state, {0, 1})
      false
  """
  @spec valid_position?(t(), {integer(), integer()}) :: boolean()
  def valid_position?(%__MODULE__{size: {max_rows, max_cols}}, {row, col})
      when is_integer(row) and is_integer(col) do
    row > 0 and col > 0 and row <= max_rows and col <= max_cols
  end

  def valid_position?(_state, _position), do: false

  @doc """
  Maps a Raw backend mouse mode to the corresponding ANSI protocol mode.

  This is used internally when emitting mouse tracking escape sequences.

  ## Examples

      iex> Raw.mouse_mode_to_ansi(:click)
      :normal
      iex> Raw.mouse_mode_to_ansi(:drag)
      :button
      iex> Raw.mouse_mode_to_ansi(:all)
      :all
  """
  @spec mouse_mode_to_ansi(mouse_mode()) :: :normal | :button | :all | nil
  def mouse_mode_to_ansi(:none), do: nil
  def mouse_mode_to_ansi(:click), do: :normal
  def mouse_mode_to_ansi(:drag), do: :button
  def mouse_mode_to_ansi(:all), do: :all

  # Provides access to the ANSI module for escape sequence generation
  @doc false
  def ansi_module, do: ANSI

  # ===========================================================================
  # Private Functions
  # ===========================================================================

  # Gets terminal size from explicit option or auto-detection
  @spec get_terminal_size({pos_integer(), pos_integer()} | nil) ::
          {:ok, {pos_integer(), pos_integer()}} | {:error, term()}
  defp get_terminal_size({rows, cols})
       when is_integer(rows) and is_integer(cols) and rows > 0 and cols > 0 do
    {:ok, {rows, cols}}
  end

  defp get_terminal_size(nil) do
    # Try :io.rows/0 and :io.columns/0 first
    case {:io.rows(), :io.columns()} do
      {{:ok, rows}, {:ok, cols}} when rows > 0 and cols > 0 ->
        {:ok, {rows, cols}}

      _ ->
        # Fall back to environment variables
        get_size_from_env()
    end
  end

  defp get_terminal_size(_invalid) do
    {:error, :invalid_size}
  end

  # Gets terminal size from LINES and COLUMNS environment variables
  defp get_size_from_env do
    with {:ok, lines} <- get_env_int("LINES"),
         {:ok, columns} <- get_env_int("COLUMNS") do
      {:ok, {lines, columns}}
    else
      _ -> {:error, :size_detection_failed}
    end
  end

  # Parses an environment variable as a positive integer
  defp get_env_int(var) do
    case System.get_env(var) do
      nil ->
        {:error, :not_set}

      value ->
        case Integer.parse(value) do
          {int, ""} when int > 0 -> {:ok, int}
          _ -> {:error, :invalid}
        end
    end
  end

  # Writes data to the terminal, wrapping in try/rescue for error safety
  defp write_to_terminal(data) do
    IO.write(data)
  rescue
    _ -> :ok
  end

  # Error-safe write for shutdown - logs errors but continues
  defp safe_write(data) do
    IO.write(data)
  rescue
    e ->
      Logger.warning("Failed to write during shutdown: #{Exception.message(e)}")
      :ok
  end

  # Error-safe cooked mode restoration
  defp safe_cooked_mode do
    :shell.start_interactive({:noshell, :cooked})
  rescue
    e in UndefinedFunctionError ->
      # :shell.start_interactive/1 not available (pre-OTP 28)
      Logger.warning(
        "Cooked mode restoration not available (OTP 28+ required): #{Exception.message(e)}"
      )

      :ok

    e ->
      Logger.warning("Failed to restore cooked mode: #{Exception.message(e)}")
      :ok
  catch
    kind, reason ->
      Logger.warning("Failed to restore cooked mode: #{kind} - #{inspect(reason)}")
      :ok
  end
end
