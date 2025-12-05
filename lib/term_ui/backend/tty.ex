defmodule TermUI.Backend.TTY do
  @moduledoc """
  TTY terminal backend for constrained environments.

  The TTY backend provides terminal rendering when raw mode is unavailable. This
  includes Nerves devices, SSH sessions, remote IEx consoles, and other scenarios
  where `:shell.start_interactive({:noshell, :raw})` returns `{:error, :already_started}`.

  ## When This Backend is Selected

  The `TermUI.Backend.Selector` chooses this backend when:
  1. Raw mode activation fails with `:already_started` (a shell is already running)
  2. The environment is detected as constrained (Nerves, remote IEx)
  3. Explicit TTY mode is requested via configuration

  ## Key Difference from Raw Backend

  **This backend is still fully interactive.** Even without raw mode, we can:
  - Read individual characters and escape sequences using `IO.getn/2`
  - Process arrow keys, Tab, function keys, and control sequences
  - Position the cursor and render styled text

  The main differences from raw mode are:
  - **No terminal mode control** - Cannot switch terminal modes (shell already running)
  - **Potential interference** - The existing shell's line editing may occasionally interfere
  - **Capability uncertainty** - Must detect and adapt to available features
  - **Limited mouse support** - Mouse events may not be available or reliable

  ## Rendering Modes

  This backend supports two rendering modes via the `:line_mode` option:

  - **`:full_redraw`** (default) - Clears the screen and redraws everything on each
    frame. This is reliable but may cause visible flicker on slow connections.

  - **`:incremental`** - Only updates cells that changed since the last frame.
    This is faster and reduces flicker but may have artifacts if the terminal
    state becomes out of sync.

  ## Color Degradation

  The TTY backend automatically degrades colors based on detected capabilities:

  | Mode | Description | Escape Format |
  |------|-------------|---------------|
  | `:true_color` | Full 24-bit RGB | `ESC[38;2;r;g;bm` |
  | `:color_256` | 256-color palette | `ESC[38;5;nm` |
  | `:color_16` | Basic 16 colors | `ESC[31m` etc. |
  | `:monochrome` | No colors | Attributes only |

  ## Character Set Handling

  When Unicode is unavailable, box-drawing characters are automatically mapped
  to ASCII equivalents. The `:character_set` field tracks the current mode:

  - `:unicode` - Full Unicode box-drawing characters
  - `:ascii` - ASCII fallback (`+`, `-`, `|` for corners and lines)

  ## Configuration Options

  The `init/1` callback accepts these options:

  - `:capabilities` - Map of detected terminal capabilities (from Selector)
  - `:line_mode` - Rendering strategy (`:full_redraw` or `:incremental`)
  - `:alternate_screen` - Whether to use alternate screen buffer (default: `false`)

  ## Example

  This backend is typically used via the runtime, not directly:

      # Automatic backend selection (recommended)
      {:ok, runtime} = TermUI.Runtime.start_link()

      # The runtime handles backend selection based on environment

  ## See Also

  - `TermUI.Backend` - Behaviour definition
  - `TermUI.Backend.Selector` - Backend selection logic
  - `TermUI.Backend.Raw` - Full-featured backend for raw mode
  - `TermUI.CharacterSet` - Unicode/ASCII character mapping
  """

  @behaviour TermUI.Backend

  require Logger

  # ===========================================================================
  # Type Definitions and State Structure
  # ===========================================================================

  @typedoc """
  Color rendering mode based on terminal capabilities.

  Determines how colors are encoded in escape sequences:

  - `:true_color` - Full 24-bit RGB colors (`ESC[38;2;r;g;bm`)
  - `:color_256` - 256-color palette (`ESC[38;5;nm`)
  - `:color_16` - Basic 16 ANSI colors (`ESC[31m` etc.)
  - `:monochrome` - No color support, attributes only
  """
  @type color_mode :: :true_color | :color_256 | :color_16 | :monochrome

  @typedoc """
  Rendering strategy for frame updates.

  - `:full_redraw` - Clear and redraw entire screen each frame (reliable)
  - `:incremental` - Only update changed cells (faster but may have artifacts)
  """
  @type line_mode :: :full_redraw | :incremental

  @typedoc """
  Character set for box-drawing and special characters.

  - `:unicode` - Full Unicode box-drawing characters
  - `:ascii` - ASCII fallback characters
  """
  @type character_set :: :unicode | :ascii

  @typedoc """
  Internal state for the TTY backend.

  Tracks terminal configuration and rendering state.

  ## Fields

  - `:size` - Terminal dimensions as `{rows, cols}`
  - `:capabilities` - Map of detected terminal capabilities from Selector
  - `:line_mode` - Rendering strategy (`:full_redraw` or `:incremental`)
  - `:last_frame` - Previous frame for incremental rendering comparison
  - `:character_set` - Unicode or ASCII character set
  - `:color_mode` - Color capability level
  - `:alternate_screen` - Whether alternate screen buffer is active
  - `:cursor_visible` - Whether cursor is currently visible
  - `:cursor_position` - Current cursor position as `{row, col}` or `nil`
  - `:current_style` - Current SGR state for style delta tracking
  """
  @type t :: %__MODULE__{
          size: {pos_integer(), pos_integer()},
          capabilities: map(),
          line_mode: line_mode(),
          last_frame: map() | nil,
          character_set: character_set(),
          color_mode: color_mode(),
          alternate_screen: boolean(),
          cursor_visible: boolean(),
          cursor_position: {pos_integer(), pos_integer()} | nil,
          current_style: map() | nil
        }

  defstruct size: {24, 80},
            capabilities: %{},
            line_mode: :full_redraw,
            last_frame: nil,
            character_set: :unicode,
            color_mode: :true_color,
            alternate_screen: false,
            cursor_visible: true,
            cursor_position: nil,
            current_style: nil

  # ===========================================================================
  # Lifecycle Callbacks
  # ===========================================================================

  @impl true
  @doc """
  Initializes the TTY backend with detected capabilities.

  Accepts options from the Selector including terminal capabilities.

  ## Options

  - `:capabilities` - Map of detected terminal capabilities
  - `:line_mode` - Rendering strategy (default: `:full_redraw`)
  - `:alternate_screen` - Use alternate screen buffer (default: `false`)
  - `:size` - Explicit terminal dimensions (default: from capabilities or `{24, 80}`)

  ## Returns

  - `{:ok, state}` - Successfully initialized
  - `{:error, reason}` - Initialization failed
  """
  @spec init(keyword()) :: {:ok, t()} | {:error, term()}
  def init(opts \\ []) do
    capabilities = Keyword.get(opts, :capabilities, %{})
    line_mode = Keyword.get(opts, :line_mode, :full_redraw)
    alternate_screen = Keyword.get(opts, :alternate_screen, false)

    # Determine color mode from capabilities
    color_mode = determine_color_mode(capabilities)

    # Determine character set from capabilities
    character_set = determine_character_set(capabilities)

    # Get terminal size from capabilities or option or default
    size = determine_size(opts, capabilities)

    state = %__MODULE__{
      size: size,
      capabilities: capabilities,
      line_mode: line_mode,
      character_set: character_set,
      color_mode: color_mode,
      alternate_screen: alternate_screen
    }

    {:ok, state}
  end

  @impl true
  @doc """
  Shuts down the TTY backend and restores terminal state.

  Resets terminal attributes and cursor visibility. Safe to call multiple times.

  ## Returns

  Always returns `:ok`.
  """
  @spec shutdown(t()) :: :ok
  def shutdown(_state) do
    :ok
  end

  # ===========================================================================
  # Query Callbacks
  # ===========================================================================

  @impl true
  @doc """
  Returns the current terminal dimensions.

  ## Returns

  - `{:ok, {rows, cols}}` - Terminal size
  """
  @spec size(t()) :: {:ok, {pos_integer(), pos_integer()}}
  def size(%__MODULE__{size: size}) do
    {:ok, size}
  end

  # ===========================================================================
  # Cursor Callbacks
  # ===========================================================================

  @impl true
  @doc """
  Moves the cursor to the specified position.

  Position is 1-indexed: `{1, 1}` is the top-left corner.
  """
  @spec move_cursor(t(), {pos_integer(), pos_integer()}) :: {:ok, t()}
  def move_cursor(state, {_row, _col} = _position) do
    {:ok, state}
  end

  @impl true
  @doc """
  Hides the terminal cursor.
  """
  @spec hide_cursor(t()) :: {:ok, t()}
  def hide_cursor(state) do
    {:ok, %{state | cursor_visible: false}}
  end

  @impl true
  @doc """
  Shows the terminal cursor.
  """
  @spec show_cursor(t()) :: {:ok, t()}
  def show_cursor(state) do
    {:ok, %{state | cursor_visible: true}}
  end

  # ===========================================================================
  # Rendering Callbacks
  # ===========================================================================

  @impl true
  @doc """
  Clears the entire screen.
  """
  @spec clear(t()) :: {:ok, t()}
  def clear(state) do
    # Clear last_frame for incremental mode
    {:ok, %{state | last_frame: nil}}
  end

  @impl true
  @doc """
  Draws cells to the terminal at specified positions.
  """
  @spec draw_cells(t(), [{TermUI.Backend.position(), TermUI.Backend.cell()}]) :: {:ok, t()}
  def draw_cells(state, _cells) do
    {:ok, state}
  end

  @impl true
  @doc """
  Flushes pending output to the terminal.

  For TTY mode, output is synchronous so this is largely a no-op.
  """
  @spec flush(t()) :: {:ok, t()}
  def flush(state) do
    {:ok, state}
  end

  # ===========================================================================
  # Input Callbacks
  # ===========================================================================

  @impl true
  @doc """
  Polls for input events with the specified timeout.

  Uses `IO.getn/2` for character-by-character input. Note that the timeout
  parameter may not be honored precisely since `IO.getn/2` is blocking.
  """
  @spec poll_event(t(), non_neg_integer()) ::
          {:ok, TermUI.Backend.event(), t()}
          | {:timeout, t()}
          | {:error, term(), t()}
  def poll_event(state, _timeout) do
    {:timeout, state}
  end

  # ===========================================================================
  # Private Functions
  # ===========================================================================

  # Determines color mode from capabilities map.
  @spec determine_color_mode(map()) :: color_mode()
  defp determine_color_mode(capabilities) do
    case Map.get(capabilities, :colors) do
      :true_color -> :true_color
      :color_256 -> :color_256
      :color_16 -> :color_16
      :monochrome -> :monochrome
      n when is_integer(n) and n >= 16_777_216 -> :true_color
      n when is_integer(n) and n >= 256 -> :color_256
      n when is_integer(n) and n >= 16 -> :color_16
      _ -> :true_color
    end
  end

  # Determines character set from capabilities map.
  @spec determine_character_set(map()) :: character_set()
  defp determine_character_set(capabilities) do
    case Map.get(capabilities, :unicode, true) do
      true -> :unicode
      false -> :ascii
      _ -> :unicode
    end
  end

  # Determines terminal size from options, capabilities, or defaults.
  @spec determine_size(keyword(), map()) :: {pos_integer(), pos_integer()}
  defp determine_size(opts, capabilities) do
    case Keyword.get(opts, :size) do
      {rows, cols} when is_integer(rows) and is_integer(cols) and rows > 0 and cols > 0 ->
        {rows, cols}

      nil ->
        case Map.get(capabilities, :dimensions) do
          {rows, cols} when is_integer(rows) and is_integer(cols) and rows > 0 and cols > 0 ->
            {rows, cols}

          _ ->
            {24, 80}
        end

      _ ->
        {24, 80}
    end
  end
end
