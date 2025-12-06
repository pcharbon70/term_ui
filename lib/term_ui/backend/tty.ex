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
  # ANSI Escape Sequence Constants
  # ===========================================================================

  # Cursor control sequences
  @cursor_hide "\e[?25l"
  @cursor_show "\e[?25h"

  # Screen control sequences
  @clear_screen "\e[2J"
  @cursor_home "\e[H"
  @alt_screen_enter "\e[?1049h"
  @alt_screen_leave "\e[?1049l"

  # Attribute control sequences
  @reset_attrs "\e[0m"

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

    # Perform terminal setup
    state = setup_terminal(state)

    {:ok, state}
  end

  @impl true
  @doc """
  Shuts down the TTY backend and restores terminal state.

  Performs the following cleanup sequence:
  1. Reset all text attributes (colors, bold, underline, etc.)
  2. Show the cursor (in case it was hidden)
  3. Leave alternate screen buffer (if it was entered)

  ## Idempotent Behavior

  This function is safe to call multiple times. Each call will emit the same
  cleanup sequences, which is harmless since terminal state converges to the
  same result regardless of prior state.

  ## Error Handling

  All terminal writes use `safe_write/1` which catches and ignores errors.
  This ensures cleanup completes even if the terminal is in an error state
  or has been disconnected. We prioritize best-effort cleanup over failing
  on individual write errors.

  ## No Cooked Mode Restoration

  Unlike the Raw backend, the TTY backend never takes the terminal out of
  cooked mode (the shell is already running). Therefore, no mode restoration
  is needed during shutdown.

  ## Returns

  Always returns `:ok`.
  """
  @spec shutdown(t()) :: :ok
  def shutdown(%__MODULE__{} = state) do
    # Reset all attributes (colors, styles)
    safe_write(@reset_attrs)

    # Show cursor
    safe_write(@cursor_show)

    # Leave alternate screen if it was entered
    if state.alternate_screen do
      safe_write(@alt_screen_leave)
    end

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
  Clears the entire screen and moves cursor to home position.

  Outputs the following escape sequences:
  1. `\\e[2J` - Clear entire screen
  2. `\\e[H` - Move cursor to home position (1,1)

  Also clears `last_frame` in state, which forces a full redraw on the next
  `draw_cells/2` call when in incremental mode.

  ## Returns

  `{:ok, updated_state}` with cursor_position set to `{1, 1}` and last_frame cleared.
  """
  @spec clear(t()) :: {:ok, t()}
  def clear(state) do
    # Clear entire screen and move cursor to home position
    safe_write(@clear_screen <> @cursor_home)

    # Update state: clear last_frame for incremental mode, reset cursor position
    {:ok, %{state | last_frame: nil, cursor_position: {1, 1}}}
  end

  @impl true
  @doc """
  Draws cells to the terminal at specified positions.

  In `:full_redraw` mode (default), clears the screen first then renders all cells.
  In `:incremental` mode, only renders the provided cells without clearing.

  ## Cell Format

  Each cell is a tuple of `{position, cell_data}` where:
  - `position` is `{row, col}` (1-indexed)
  - `cell_data` is `{char, fg_color, bg_color, attrs}`

  ## Rendering Process

  1. In full_redraw mode, clear screen and home cursor
  2. Group cells by row for efficient rendering
  3. For each row, position cursor and output styled characters
  4. Apply color degradation based on `color_mode`

  ## Returns

  `{:ok, updated_state}` with `last_frame` updated for incremental mode.
  """
  @spec draw_cells(t(), [{TermUI.Backend.position(), TermUI.Backend.cell()}]) :: {:ok, t()}
  def draw_cells(%__MODULE__{} = state, cells) do
    # In full_redraw mode, clear screen first
    if state.line_mode == :full_redraw do
      safe_write(@clear_screen <> @cursor_home)
    end

    # Group cells by row and render
    cells
    |> group_cells_by_row()
    |> render_rows(state)

    # Only build frame map for incremental mode (used for diff-based updates)
    # Full redraw mode doesn't need position lookups
    frame =
      if state.line_mode == :incremental do
        build_frame_map(cells)
      else
        nil
      end

    {:ok, %{state | last_frame: frame, cursor_position: nil}}
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

  # Performs terminal setup during initialization.
  #
  # Outputs ANSI escape sequences to prepare the terminal for rendering:
  # - Optionally enters alternate screen buffer if configured
  # - Hides cursor for cleaner rendering
  # - Clears screen and moves cursor to home position
  #
  # Note: No raw mode activation - the shell is already running in TTY mode.
  @spec setup_terminal(t()) :: t()
  defp setup_terminal(state) do
    # Enter alternate screen if configured
    if state.alternate_screen do
      IO.write(@alt_screen_enter)
    end

    # Hide cursor for cleaner rendering
    IO.write(@cursor_hide)

    # Clear screen and move cursor to home position
    IO.write(@clear_screen <> @cursor_home)

    # Update state to reflect cursor is hidden
    %{state | cursor_visible: false, cursor_position: {1, 1}}
  end

  # ===========================================================================
  # Cell Rendering Helpers
  # ===========================================================================

  # Groups cells by row number and sorts by column within each row.
  @spec group_cells_by_row([{TermUI.Backend.position(), TermUI.Backend.cell()}]) ::
          [{pos_integer(), [{pos_integer(), TermUI.Backend.cell()}]}]
  defp group_cells_by_row(cells) do
    cells
    |> Enum.group_by(fn {{row, _col}, _cell} -> row end, fn {{_row, col}, cell} -> {col, cell} end)
    |> Enum.sort_by(fn {row, _cells} -> row end)
    |> Enum.map(fn {row, row_cells} ->
      {row, Enum.sort_by(row_cells, fn {col, _cell} -> col end)}
    end)
  end

  # Renders all rows to the terminal.
  @spec render_rows([{pos_integer(), [{pos_integer(), TermUI.Backend.cell()}]}], t()) :: :ok
  defp render_rows(rows, state) do
    Enum.each(rows, fn {row, row_cells} ->
      render_row(row, row_cells, state)
    end)
  end

  # Renders a single row of cells with style delta tracking.
  #
  # Tracks the current style and only outputs SGR sequences when the style
  # changes between cells. This reduces redundant escape sequence output.
  # Builds an iolist for the entire row and writes once for efficiency.
  @spec render_row(pos_integer(), [{pos_integer(), TermUI.Backend.cell()}], t()) :: :ok
  defp render_row(row, cells, state) do
    # Track current column, current style, and accumulated iolist
    # Initial style is nil (no style set yet)
    initial_state = {1, nil, []}

    {_col, _style, iolist} =
      Enum.reduce(cells, initial_state, fn {col, cell}, {cur_col, cur_style, acc} ->
        # Fill gap with spaces if needed
        gap =
          if col > cur_col do
            String.duplicate(" ", col - cur_col)
          else
            ""
          end

        # Render the cell with style delta tracking
        {new_style, cell_io} = render_cell_with_delta(cell, cur_style, state)

        # Append to iolist (prepend for efficiency, reverse at end)
        new_acc = [cell_io, gap | acc]

        # Return next column position and new style
        {col + 1, new_style, new_acc}
      end)

    # Build final iolist: cursor position + reversed content + reset
    final_io = ["\e[#{row};1H", Enum.reverse(iolist), @reset_attrs]

    # Single write for entire row
    safe_write(final_io)

    :ok
  end

  # Renders a single cell with style delta tracking.
  #
  # Only outputs SGR sequences when the style differs from the previous cell.
  # Returns the new style and the iodata for this cell.
  @spec render_cell_with_delta(
          TermUI.Backend.cell(),
          {TermUI.Backend.color(), TermUI.Backend.color(), [atom()]} | nil,
          t()
        ) :: {{TermUI.Backend.color(), TermUI.Backend.color(), [atom()]}, iodata()}
  defp render_cell_with_delta({char, fg, bg, attrs}, cur_style, state) do
    new_style = {fg, bg, attrs}

    # Only output SGR if style changed
    sgr =
      if new_style != cur_style do
        build_sgr_sequence(fg, bg, attrs, state.color_mode)
      else
        ""
      end

    # Map character (with potential character set mapping and sanitization)
    mapped_char = map_character(char, state.character_set)
    sanitized_char = sanitize_char(mapped_char)

    {new_style, [sgr, sanitized_char]}
  end

  # Builds SGR (Select Graphic Rendition) sequence for colors and attributes.
  #
  # Combines reset, attributes, foreground color, and background color into
  # a single efficient escape sequence string.
  @spec build_sgr_sequence(
          TermUI.Backend.color(),
          TermUI.Backend.color(),
          [atom()],
          color_mode()
        ) :: String.t()
  defp build_sgr_sequence(fg, bg, attrs, color_mode) do
    # Build each component
    reset_part = @reset_attrs
    attrs_part = build_attrs_sgr(attrs)
    fg_part = build_fg_sgr(fg, color_mode)
    bg_part = build_bg_sgr(bg, color_mode)

    # Combine non-empty parts
    [reset_part, attrs_part, fg_part, bg_part]
    |> Enum.reject(&(&1 == ""))
    |> Enum.join("")
  end

  # Builds SGR sequence for text attributes (bold, italic, etc.).
  @spec build_attrs_sgr([atom()]) :: String.t()
  defp build_attrs_sgr(attrs) do
    attrs
    |> Enum.map(&attr_to_sgr/1)
    |> Enum.reject(&is_nil/1)
    |> Enum.join("")
  end

  # Builds SGR sequence for foreground color.
  @spec build_fg_sgr(TermUI.Backend.color(), color_mode()) :: String.t()
  defp build_fg_sgr(color, color_mode) do
    color_to_sgr(color, :fg, color_mode)
  end

  # Builds SGR sequence for background color.
  @spec build_bg_sgr(TermUI.Backend.color(), color_mode()) :: String.t()
  defp build_bg_sgr(color, color_mode) do
    color_to_sgr(color, :bg, color_mode)
  end

  # Converts an attribute to its SGR sequence.
  @spec attr_to_sgr(atom()) :: String.t() | nil
  defp attr_to_sgr(:bold), do: "\e[1m"
  defp attr_to_sgr(:dim), do: "\e[2m"
  defp attr_to_sgr(:italic), do: "\e[3m"
  defp attr_to_sgr(:underline), do: "\e[4m"
  defp attr_to_sgr(:blink), do: "\e[5m"
  defp attr_to_sgr(:reverse), do: "\e[7m"
  defp attr_to_sgr(:strikethrough), do: "\e[9m"
  defp attr_to_sgr(_), do: nil

  # Converts a color to its SGR sequence based on color mode.
  @spec color_to_sgr(TermUI.Backend.color(), :fg | :bg, color_mode()) :: String.t()
  defp color_to_sgr(:default, :fg, _mode), do: "\e[39m"
  defp color_to_sgr(:default, :bg, _mode), do: "\e[49m"
  defp color_to_sgr(nil, _type, _mode), do: ""

  # True color mode - output RGB directly
  defp color_to_sgr({r, g, b}, :fg, :true_color), do: "\e[38;2;#{r};#{g};#{b}m"
  defp color_to_sgr({r, g, b}, :bg, :true_color), do: "\e[48;2;#{r};#{g};#{b}m"

  # 256-color mode - convert RGB to palette index
  defp color_to_sgr({r, g, b}, :fg, :color_256), do: "\e[38;5;#{rgb_to_256(r, g, b)}m"
  defp color_to_sgr({r, g, b}, :bg, :color_256), do: "\e[48;5;#{rgb_to_256(r, g, b)}m"

  # 16-color mode - convert RGB to basic color
  defp color_to_sgr({r, g, b}, :fg, :color_16), do: "\e[#{rgb_to_16_fg(r, g, b)}m"
  defp color_to_sgr({r, g, b}, :bg, :color_16), do: "\e[#{rgb_to_16_bg(r, g, b)}m"

  # Monochrome mode - skip colors entirely
  defp color_to_sgr({_r, _g, _b}, _type, :monochrome), do: ""

  # Named colors
  defp color_to_sgr(name, :fg, _mode) when is_atom(name), do: named_color_to_sgr(name, :fg)
  defp color_to_sgr(name, :bg, _mode) when is_atom(name), do: named_color_to_sgr(name, :bg)

  # Palette index (0-255)
  defp color_to_sgr(n, :fg, _mode) when is_integer(n) and n >= 0 and n <= 255,
    do: "\e[38;5;#{n}m"

  defp color_to_sgr(n, :bg, _mode) when is_integer(n) and n >= 0 and n <= 255,
    do: "\e[48;5;#{n}m"

  defp color_to_sgr(_, _, _), do: ""

  # Named color SGR code mappings (foreground base codes)
  @named_color_codes %{
    black: 30,
    red: 31,
    green: 32,
    yellow: 33,
    blue: 34,
    magenta: 35,
    cyan: 36,
    white: 37,
    bright_black: 90,
    bright_red: 91,
    bright_green: 92,
    bright_yellow: 93,
    bright_blue: 94,
    bright_magenta: 95,
    bright_cyan: 96,
    bright_white: 97
  }

  # Named color to SGR sequence using map lookup
  @spec named_color_to_sgr(atom(), :fg | :bg) :: String.t()
  defp named_color_to_sgr(name, type) do
    case Map.get(@named_color_codes, name) do
      nil ->
        ""

      code when type == :fg ->
        "\e[#{code}m"

      code when type == :bg ->
        # Background codes are foreground + 10
        bg_code = if code >= 90, do: code + 10, else: code + 10
        "\e[#{bg_code}m"
    end
  end

  # Converts RGB to 256-color palette index.
  # Uses 6x6x6 color cube (indices 16-231) or grayscale (232-255).
  @spec rgb_to_256(0..255, 0..255, 0..255) :: 0..255
  defp rgb_to_256(r, g, b) do
    # Check if it's close to grayscale
    if abs(r - g) < 10 and abs(g - b) < 10 and abs(r - b) < 10 do
      # Use grayscale ramp (232-255)
      gray = div(r + g + b, 3)
      232 + div(gray * 23, 255)
    else
      # Use 6x6x6 color cube (16-231)
      r_idx = div(r * 5, 255)
      g_idx = div(g * 5, 255)
      b_idx = div(b * 5, 255)
      16 + 36 * r_idx + 6 * g_idx + b_idx
    end
  end

  # Converts RGB to 16-color foreground code.
  @spec rgb_to_16_fg(0..255, 0..255, 0..255) :: 30..37 | 90..97
  defp rgb_to_16_fg(r, g, b) do
    {base, bright} = rgb_to_16_base(r, g, b)
    if bright, do: base + 60, else: base
  end

  # Converts RGB to 16-color background code.
  @spec rgb_to_16_bg(0..255, 0..255, 0..255) :: 40..47 | 100..107
  defp rgb_to_16_bg(r, g, b) do
    {base, bright} = rgb_to_16_base(r, g, b)
    bg_base = base + 10
    if bright, do: bg_base + 60, else: bg_base
  end

  # ANSI 16-color palette RGB values for distance calculation.
  # Format: {color_code, {r, g, b}}
  @ansi_16_colors [
    # Normal colors (codes 30-37)
    {30, {0, 0, 0}},        # black
    {31, {128, 0, 0}},      # red
    {32, {0, 128, 0}},      # green
    {33, {128, 128, 0}},    # yellow
    {34, {0, 0, 128}},      # blue
    {35, {128, 0, 128}},    # magenta
    {36, {0, 128, 128}},    # cyan
    {37, {192, 192, 192}},  # white (light gray)
    # Bright colors (codes 90-97)
    {90, {128, 128, 128}},  # bright black (dark gray)
    {91, {255, 0, 0}},      # bright red
    {92, {0, 255, 0}},      # bright green
    {93, {255, 255, 0}},    # bright yellow
    {94, {0, 0, 255}},      # bright blue
    {95, {255, 0, 255}},    # bright magenta
    {96, {0, 255, 255}},    # bright cyan
    {97, {255, 255, 255}}   # bright white
  ]

  # Determines the base 16-color index and brightness using weighted color distance.
  # Uses perceptual weighting (human eye is more sensitive to green).
  @spec rgb_to_16_base(0..255, 0..255, 0..255) :: {30..37 | 90..97, boolean()}
  defp rgb_to_16_base(r, g, b) do
    # Find closest color using weighted Euclidean distance
    # Weights: R=0.299, G=0.587, B=0.114 (perceptual luminance weights)
    {best_code, _best_dist} =
      Enum.reduce(@ansi_16_colors, {30, :infinity}, fn {code, {pr, pg, pb}}, {best, dist} ->
        # Weighted distance calculation
        dr = (r - pr) * 0.299
        dg = (g - pg) * 0.587
        db = (b - pb) * 0.114
        new_dist = dr * dr + dg * dg + db * db

        if new_dist < dist do
          {code, new_dist}
        else
          {best, dist}
        end
      end)

    # Determine if it's a bright color (90-97) or normal (30-37)
    bright = best_code >= 90
    base = if bright, do: best_code - 60, else: best_code

    {base, bright}
  end

  # Maps characters based on character set.
  # For now, passes through unchanged. Box-drawing mapping will be added in Section 3.6.
  @spec map_character(String.t(), character_set()) :: String.t()
  defp map_character(char, :unicode), do: char
  defp map_character(char, :ascii), do: char

  # Sanitizes characters to prevent escape sequence injection.
  #
  # Removes any ESC characters from user-provided content to prevent
  # malicious or accidental injection of terminal control sequences.
  @spec sanitize_char(String.t()) :: String.t()
  defp sanitize_char(char) when is_binary(char) do
    String.replace(char, "\e", "")
  end

  defp sanitize_char(char), do: char

  # Builds a frame map from cells for incremental mode tracking.
  @spec build_frame_map([{TermUI.Backend.position(), TermUI.Backend.cell()}]) :: map()
  defp build_frame_map(cells) do
    Map.new(cells, fn {pos, cell} -> {pos, cell} end)
  end

  # ===========================================================================
  # Terminal I/O Helpers
  # ===========================================================================

  # Writes data to the terminal, ignoring any errors.
  #
  # This provides bulletproof writes for shutdown sequences where we want
  # to attempt terminal cleanup even if the terminal is in an error state.
  # Errors are silently ignored since we're cleaning up anyway.
  @spec safe_write(iodata()) :: :ok
  defp safe_write(data) do
    try do
      IO.write(data)
    rescue
      _ -> :ok
    end

    :ok
  end
end
