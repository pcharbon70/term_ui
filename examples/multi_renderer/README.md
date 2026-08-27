# TermUI Multi-Renderer Examples

This directory contains example applications demonstrating TermUI's multi-renderer capabilities, including automatic backend selection (raw vs TTY mode) and graceful feature degradation.

## Prerequisites

- Elixir 1.15+
- OTP 28+ recommended for full raw mode support
- A terminal emulator (Alacritty, Kitty, WezTerm, iTerm2, GNOME Terminal, etc.)

## Examples

### 1. Basic Example (`basic.ex`)

A simple list navigation application that receives the same normalized events
in raw and TTY modes. TTY delivery may be buffered until Enter.

```bash
# Run with auto-detection
elixir -r examples/multi_renderer/basic.ex -e "Basic.run()"

# Force TTY mode
elixir -r examples/multi_renderer/basic.ex -e "Basic.run(backend: :tty)"

# Force raw mode (requires OTP 28+ and terminal support)
elixir -r examples/multi_renderer/basic.ex -e "Basic.run(backend: :raw)"
```

**Features:**
- Navigate a list using arrow keys or j/k
- Toggle details view with Enter
- Shows current backend mode
- Works in both raw and TTY modes

**Controls:**
- `↑`/`↓` or `j`/`k` - Navigate list
- `Enter` - Toggle details view
- `q` - Quit

---

### 2. Text Input Example (`text_input.ex`)

Demonstrates text input behavior differences between raw and TTY modes.

```bash
# Run with auto-detection
elixir -r examples/multi_renderer/text_input.ex -e "TextInputExample.run()"

# Force TTY mode
elixir -r examples/multi_renderer/text_input.ex -e "TextInputExample.run(backend: :tty)"
```

**Features:**
- Shows how text input works in different modes
- Raw mode: Character-by-character input with live editing
- TTY mode: Line-based input (press Enter to submit)

**Controls:**
- Type text and press Enter to submit
- `c` - Clear submitted values
- `h` - Toggle help
- `q` - Quit

---

### 3. Capabilities Example (`capabilities.ex`)

Displays detected terminal capabilities and backend mode.

```bash
# Run with auto-detection
elixir -r examples/multi_renderer/capabilities.ex -e "CapabilitiesExample.run()"

# Run in demo mode (no full UI)
elixir -r examples/multi_renderer/capabilities.ex -e "CapabilitiesExample.run(demo: true)"
```

**Features:**
- Shows detected backend mode (raw/tty)
- Displays color support level (true_color, color_256, color_16, monochrome)
- Shows Unicode support status
- Displays terminal dimensions
- Interactive tabs for different capability categories

**Controls:**
- `Tab` - Switch between tabs
- `1`-`4` - Jump to specific tab
- `Enter` - Refresh capabilities
- `q` - Quit

---

## Backend Modes

### Raw Mode (OTP 28+)

Full terminal control with:
- Character-by-character input
- Arrow key navigation
- Mouse support (when available)
- True color and Unicode
- Live UI updates

### TTY Mode (Fallback)

Graceful degradation with:
- Line-based input (type and press Enter)
- Single key commands
- Reduced but functional UI
- Works in non-terminal environments

### Auto-Detection

By default, TermUI automatically selects the appropriate backend:
1. Attempts raw mode first (OTP 28+)
2. Falls back to TTY mode if:
   - OTP < 28
   - A shell is already running
   - Raw mode activation fails
   - Not in a terminal (piped input, etc.)

## Running Examples in Different Environments

### Local Terminal

```bash
# Standard terminal (supports raw mode)
elixir -r examples/multi_renderer/basic.ex -e "Basic.run()"
```

### SSH Session

```bash
# Should auto-detect and use appropriate mode
elixir -r examples/multi_renderer/basic.ex -e "Basic.run()"
```

### Within IEx

```elixir
# In IEx, you can run examples directly
iex> Code.require_file("examples/multi_renderer/basic.ex")
iex> Basic.run()
```

### Forcing Specific Mode

```bash
# Force TTY mode (useful for testing)
elixir -r examples/multi_renderer/basic.ex -e "Basic.run(backend: :tty)"

# Force raw mode (will fail if unavailable)
elixir -r examples/multi_renderer/basic.ex -e "Basic.run(backend: :raw)"
```

## Configuration

You can also configure the default backend in your `config/config.exs`:

```elixir
# config/config.exs
config :term_ui,
  backend: :auto  # :auto, :raw, or :tty
```

## Troubleshooting

### "Raw mode unavailable" message

This is expected when:
- Running on OTP < 28
- A shell is already running in the terminal
- The terminal doesn't support raw mode

The system will automatically fall back to TTY mode.

### No colors or wrong colors

TermUI automatically detects color support. If colors aren't displaying correctly:
1. Check your terminal's color settings
2. Try setting `COLORTERM=truecolor` environment variable
3. Some terminals require explicit color enabling

### Unicode characters not displaying

TermUI detects UTF-8 support from locale variables:
- Ensure `LANG` or `LC_CTYPE` includes "UTF-8"
- The system will fall back to ASCII if Unicode isn't detected

## Development

### Example Structure

Each example follows the same pattern:

1. Uses `TermUI.Elm` for the Elm Architecture
2. Implements `init/1`, `event_to_msg/2`, `update/2`, and `view/1`
3. Provides a `run/1` function that accepts options
4. Includes comments explaining the code

### Adapting Examples

To create your own application:

1. Copy an example file as a template
2. Modify the `init/1` function for your initial state
3. Implement your event handlers in `event_to_msg/2`
4. Add your state logic in `update/2`
5. Design your UI in `view/1`

## See Also

- [TermUI Documentation](../../README.md)
- [Multi-Renderer Planning Document](../../notes/planning/multi-renderer/)
- [Configuration Guide](../../lib/term_ui/config.ex)
