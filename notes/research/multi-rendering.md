# Multi-Renderer Architecture for TermUI: From OTP 28 Raw Mode to Nerves-Compatible ASCII

**TermUI can support both full-featured raw-mode rendering and graceful ASCII fallback through a behaviour-based abstraction layer.** The key insight is that OTP 28's raw mode is fundamentally incompatible with Nerves' shell architecture, requiring a complete separation of input handling from output rendering. This report provides a concrete implementation strategy using Elixir behaviours, inspired by Ratatui's proven backend pattern.

The proposed architecture introduces a `TermUI.Backend` behaviour that abstracts terminal operations, enabling the existing double-buffered ETS renderer to output through different backends—a full-featured `RawBackend` for standard terminals and a `TTYBackend` for constrained environments. Widgets remain unchanged; only the final output stage differs.

---

## Why raw mode fails on Nerves

The fundamental barrier is architectural, not technical. OTP 28's `shell:start_interactive({:noshell, :raw})` is designed to **start a new shell** in raw mode, not convert an existing one. On Nerves devices, whether connected via SSH or serial console, an IEx shell is **already running** in cooked mode before user code executes.

Nerves uses **erlinit** as the init system, which directly launches the Erlang VM and IEx. When you SSH into a Nerves device, `nerves_ssh` wraps Erlang's SSH daemon (`ssh_cli.erl`), which provides a virtual channel—not a real TTY. The `io:getopts()` call returns `{terminal, false}` or limited options over SSH connections. Similarly, serial connections route through `nbtty` and the Erlang `group` process, which handles line editing in cooked mode with no API to switch dynamically.

**What does work on Nerves**: ANSI escape sequences for output function normally. Cursor positioning (`\e[row;colH`), colors (`\e[32m`), screen clearing (`\e[2J`), and even the alternate screen buffer (`\e[?1049h`) all work. The limitation is input—characters arrive only after the user presses Enter, making real-time keystroke detection impossible.

---

## Backend selection: Try raw mode first

The **only reliable way** to determine whether raw mode is available is to attempt to start it. Heuristics based on OTP version, `io:getopts/0`, or environment variables are insufficient—they cannot detect cases where a shell is already running (Nerves, remote IEx sessions, etc.).

The selection algorithm is simple:

1. Attempt `:shell.start_interactive({:noshell, :raw})`
2. If it succeeds (`:ok`), use the **Raw backend**—raw mode is now active
3. If it returns `{:error, :already_started}`, use the **TTY backend**—a shell is already running and cannot be replaced

**Terminal capability detection only happens in TTY mode.** When raw mode succeeds, we have full control over the terminal and can assume maximum capabilities. When falling back to TTY mode, we must probe for color depth, Unicode support, and dimensions since the environment is constrained.

```elixir
defmodule TermUI.Backend.Selector do
  @moduledoc """
  Selects the appropriate backend by attempting raw mode initialization.

  This is the ONLY reliable method—heuristics cannot detect all cases
  where a shell is already running.
  """

  @doc """
  Attempts to start raw mode and returns the appropriate backend module
  along with initialization state.

  Returns `{:raw, state}` if raw mode started successfully, or
  `{:tty, capabilities}` if a shell was already running.
  """
  def select do
    case :shell.start_interactive({:noshell, :raw}) do
      :ok ->
        # Raw mode is now active—we have full terminal control
        {:raw, %{raw_mode_started: true}}

      {:error, :already_started} ->
        # A shell is already running—fall back to TTY mode
        # Only now do we need to detect terminal capabilities
        capabilities = detect_tty_capabilities()
        {:tty, capabilities}
    end
  end

  # Capability detection is only needed for TTY mode
  defp detect_tty_capabilities do
    %{
      colors: detect_color_depth(),
      dimensions: detect_size(),
      unicode: supports_unicode?(),
      terminal: has_terminal?()
    }
  end

  defp detect_color_depth do
    colorterm = System.get_env("COLORTERM")
    term = System.get_env("TERM") || ""

    cond do
      colorterm in ["truecolor", "24bit"] -> :true_color
      String.contains?(term, "256color") -> :color_256
      String.contains?(term, "color") -> :color_16
      true -> :monochrome
    end
  end

  defp detect_size do
    # Try ANSI query first, fall back to environment/defaults
    case query_terminal_size() do
      {:ok, size} -> size
      :error -> {String.to_integer(System.get_env("COLUMNS") || "80"),
                 String.to_integer(System.get_env("LINES") || "24")}
    end
  end

  defp supports_unicode? do
    lang = System.get_env("LANG") || ""
    String.contains?(String.downcase(lang), "utf")
  end

  defp has_terminal? do
    case :io.getopts() do
      opts when is_list(opts) -> Keyword.get(opts, :terminal, false)
      _ -> false
    end
  end

  defp query_terminal_size do
    # Implementation would send CSI 18 t and parse response
    # For now, return :error to use fallback
    :error
  end
end
```

This approach has several advantages:

- **No false positives**: Environment checks might incorrectly suggest raw mode is available when a shell is already running
- **No false negatives**: We don't reject valid raw mode environments due to missing environment variables
- **Single source of truth**: The `:shell` module itself tells us definitively whether raw mode can be used
- **Lazy capability detection**: We only probe terminal capabilities when we actually need them (TTY mode)

---

## The backend behaviour abstraction

Following Ratatui's proven pattern, the backend abstraction defines a minimal interface that all renderers must implement. The key operations map directly to terminal primitives:

```elixir
defmodule TermUI.Backend do
  @moduledoc "Behaviour for terminal rendering backends"

  @type position :: {non_neg_integer(), non_neg_integer()}
  @type size :: {cols :: non_neg_integer(), rows :: non_neg_integer()}
  @type cell :: {char :: String.t(), fg :: term(), bg :: term(), attrs :: list()}

  @callback init(opts :: keyword()) :: {:ok, state :: term()} | {:error, term()}
  @callback shutdown(state :: term()) :: :ok
  @callback size(state :: term()) :: {:ok, size()} | {:error, :enotsup}
  @callback clear(state :: term()) :: :ok
  @callback move_cursor(state :: term(), position()) :: :ok
  @callback hide_cursor(state :: term()) :: :ok
  @callback show_cursor(state :: term()) :: :ok
  @callback draw_cells(state :: term(), [{position(), cell()}]) :: :ok
  @callback flush(state :: term()) :: :ok
  @callback poll_event(state :: term(), timeout()) :: {:ok, event()} | :timeout
end
```

The critical design decision is that **widgets never interact with backends directly**. The existing TermUI renderer writes to an ETS buffer of cells; the backend abstraction sits between that buffer and the actual terminal. This preserves the efficient double-buffered diff rendering while allowing different output strategies.

---

## Raw backend implementation for full terminals

The `RawBackend` assumes raw mode was already started by the selector. It outputs optimized ANSI sequences with true color support:

```elixir
defmodule TermUI.Backend.Raw do
  @behaviour TermUI.Backend

  defstruct [:size]

  @impl true
  def init(opts) do
    # Raw mode was already started by Backend.Selector
    # We just need to set up the terminal state

    # Enable alternate screen, hide cursor
    IO.write(["\e[?1049h", "\e[?25l"])
    {:ok, %__MODULE__{size: fetch_size()}}
  end

  @impl true
  def shutdown(_state) do
    # Show cursor, restore main screen
    IO.write(["\e[?25h", "\e[?1049l"])
    # Return to cooked mode
    :shell.start_interactive({:noshell, :cooked})
    :ok
  end

  @impl true
  def draw_cells(_state, cells) do
    # Batch cells by row for efficient output
    cells
    |> Enum.group_by(fn {{_col, row}, _cell} -> row end)
    |> Enum.sort_by(fn {row, _} -> row end)
    |> Enum.each(fn {row, row_cells} ->
      row_cells
      |> Enum.sort_by(fn {{col, _}, _} -> col end)
      |> Enum.each(&write_cell/1)
    end)
    :ok
  end

  defp write_cell({{col, row}, {char, fg, bg, _attrs}}) do
    IO.write([
      "\e[#{row};#{col}H",           # Move cursor
      "\e[38;2;#{rgb(fg)}m",         # True color foreground
      "\e[48;2;#{rgb(bg)}m",         # True color background
      char
    ])
  end

  defp rgb({r, g, b}), do: "#{r};#{g};#{b}"

  defp fetch_size do
    # In raw mode, we can query the terminal directly
    # For now, use a reasonable default
    {80, 24}
  end
end
```

---

## TTY backend for Nerves and constrained environments

The `TTYBackend` operates without raw mode, using line-at-a-time output. It receives capabilities detected by the selector and adapts its output accordingly:

```elixir
defmodule TermUI.Backend.TTY do
  @behaviour TermUI.Backend

  defstruct [:size, :last_frame, :line_mode, :capabilities]

  @impl true
  def init(opts) do
    # Capabilities were detected by Backend.Selector
    capabilities = Keyword.get(opts, :capabilities, %{})
    line_mode = Keyword.get(opts, :line_mode, :full_redraw)

    {:ok, %__MODULE__{
      size: Map.get(capabilities, :dimensions, {80, 24}),
      last_frame: nil,
      line_mode: line_mode,
      capabilities: capabilities
    }}
  end

  @impl true
  def draw_cells(state, cells) do
    case state.line_mode do
      :full_redraw -> full_redraw(cells, state.size)
      :incremental -> incremental_update(cells, state.last_frame)
    end
    :ok
  end

  # Render entire frame, suitable for periodic updates
  defp full_redraw(cells, {cols, rows}) do
    # Clear and redraw from top
    IO.write("\e[2J\e[H")

    # Build frame buffer
    frame = build_frame(cells, cols, rows)

    # Output line by line
    frame
    |> Enum.with_index(1)
    |> Enum.each(fn {line, row} ->
      IO.write(["\e[#{row};1H", line])
    end)
  end

  @impl true
  def poll_event(_state, _timeout) do
    # Line-based input only - return :not_supported or implement
    # a line-based command interface
    {:error, :line_mode_only}
  end

  @impl true
  def shutdown(_state) do
    # No raw mode to restore, just reset terminal state
    IO.write("\e[0m\e[?25h")
    :ok
  end
end
```

The TTY backend supports two operational modes: **full_redraw** clears the screen and redraws everything (works reliably but causes flicker), while **incremental** attempts cursor-addressed updates (faster but may have artifacts depending on the terminal).

---

## ASCII character rendering for box drawing

When Unicode box-drawing characters aren't available or reliable, an ASCII character set provides fallback rendering. This is implemented through a separate concern—a `CharacterSet` module—that backends can use:

| Element | Unicode | ASCII |
|---------|---------|-------|
| Top-left corner | `┌` | `+` |
| Horizontal line | `─` | `-` |
| Vertical line | `│` | `\|` |
| Bottom-right corner | `┘` | `+` |
| T-junction down | `┬` | `+` |
| Cross | `┼` | `+` |

```elixir
defmodule TermUI.CharacterSet do
  @moduledoc "Character sets for box drawing"

  def get(:unicode) do
    %{
      h_line: "─", v_line: "│",
      tl: "┌", tr: "┐", bl: "└", br: "┘",
      t_down: "┬", t_up: "┴", t_left: "┤", t_right: "├",
      cross: "┼"
    }
  end

  def get(:ascii) do
    %{
      h_line: "-", v_line: "|",
      tl: "+", tr: "+", bl: "+", br: "+",
      t_down: "+", t_up: "+", t_left: "+", t_right: "+",
      cross: "+"
    }
  end
end
```

The character set selection happens at initialization based on capability detection (in TTY mode) or defaults to Unicode (in raw mode). Widgets don't change—they specify "draw a box here" and the rendering layer chooses the characters.

---

## Recommended module structure

The idiomatic Elixir approach uses nested modules with behaviours, not file suffixes like `_ascii`:

```
lib/term_ui/
├── backend.ex                    # Behaviour definition
├── backend/
│   ├── selector.ex               # TermUI.Backend.Selector (try raw, detect caps)
│   ├── raw.ex                    # TermUI.Backend.Raw
│   ├── tty.ex                    # TermUI.Backend.TTY
│   └── test.ex                   # TermUI.Backend.Test (in-memory)
├── character_set.ex              # Unicode/ASCII sets
├── renderer.ex                   # Double-buffered renderer (modified)
└── renderer/
    └── output.ex                 # Backend delegation
```

Configuration follows standard Elixir patterns:

```elixir
# config/config.exs
config :term_ui,
  backend: :auto,                    # :auto, TermUI.Backend.Raw, or TermUI.Backend.TTY
  character_set: :unicode,
  fallback_character_set: :ascii

# Runtime initialization
defmodule TermUI.Renderer.Output do
  def init do
    case Application.get_env(:term_ui, :backend, :auto) do
      :auto ->
        # Let the selector decide by attempting raw mode
        case TermUI.Backend.Selector.select() do
          {:raw, init_state} ->
            {TermUI.Backend.Raw, init_state}

          {:tty, capabilities} ->
            {TermUI.Backend.TTY, [capabilities: capabilities]}
        end

      module when is_atom(module) ->
        # Explicit backend selection (for testing or override)
        {module, []}
    end
  end
end
```

---

## Widget degradation strategy

Rather than creating separate widget implementations per backend, widgets should render to the abstract buffer with **semantic styling hints** that the backend interprets appropriately. A gauge widget, for example, specifies "fill 60% of this bar" rather than specific characters:

```elixir
defmodule TermUI.Widgets.Gauge do
  def render(%{percent: pct, width: w}, canvas) do
    filled = round(w * pct / 100)
    empty = w - filled

    canvas
    |> Canvas.put_cells(0, 0, List.duplicate({:bar_filled, @fill_style}, filled))
    |> Canvas.put_cells(filled, 0, List.duplicate({:bar_empty, @empty_style}, empty))
  end
end
```

The backend then interprets `:bar_filled` and `:bar_empty` appropriately—the Raw backend might use Unicode block characters (`█`, `░`), while the TTY backend uses ASCII (`#`, `.`).

For widgets that truly cannot degrade gracefully (e.g., smooth animations requiring 60 FPS input), the widget should check the backend mode and either adapt or decline to render:

```elixir
def render(state, canvas) do
  if state.backend_mode == :raw do
    render_interactive(state, canvas)
  else
    render_static_fallback(state, canvas)
  end
end
```

---

## Input handling divergence

The most significant architectural difference between backends is **input handling**. The Raw backend receives keystrokes immediately; the TTY backend can only receive complete lines. This requires a separate input abstraction:

```elixir
defmodule TermUI.Input do
  @callback read(state :: term()) :: {:key, char()} | {:line, String.t()} | :timeout

  # Raw mode: immediate character reading
  def read(%{mode: :raw} = state) do
    case IO.getn("", 1) do
      char when is_binary(char) -> {:key, char}
      _ -> :timeout
    end
  end

  # TTY mode: line-based reading with prompt
  def read(%{mode: :tty} = state) do
    case IO.gets(state.prompt || "> ") do
      :eof -> :eof
      line -> {:line, String.trim(line)}
    end
  end
end
```

For Nerves applications, this means the TUI must be designed around **command-based interaction** rather than real-time navigation. A menu might display options and wait for the user to type a number and press Enter, rather than responding to arrow key presses.

---

## Implementation roadmap

**Phase 1: Backend Selector**
Implement `TermUI.Backend.Selector` with the try-raw-first approach. This is the foundation—all other work depends on reliable backend selection.

**Phase 2: Backend Abstraction**
Extract current ANSI output code into `TermUI.Backend.Raw`, define the behaviour, ensure existing functionality works through the new abstraction.

**Phase 3: TTY Backend**
Build `TermUI.Backend.TTY` with line-at-a-time output. Focus on clean visual output first; input handling can be basic. This backend receives capabilities from the selector.

**Phase 4: Character Set Abstraction**
Extract box-drawing characters into `TermUI.CharacterSet`, configure selection based on capabilities (TTY mode) or defaults (raw mode).

**Phase 5: Widget Graceful Degradation** (ongoing)
Review each widget for TTY compatibility. Add `:capability_required` metadata where widgets cannot degrade.

This architecture enables TermUI to serve both full-featured terminal applications and Nerves-based embedded systems, with widgets that automatically adapt to their rendering environment while maintaining the efficient double-buffered differential rendering that makes TermUI performant.
