# Terminal

TermUI manages low-level terminal operations automatically, but understanding these features helps you build better applications.

## Terminal Modes

### Cooked Mode (Default)

Normal terminal operation:
- Line buffering (input sent on Enter)
- Character echoing
- Signal handling (Ctrl+C sends SIGINT)

### Raw Mode

TermUI's operating mode:
- Character-by-character input
- No echoing
- No signal handling
- Full control over display

The runtime enables raw mode automatically. It's restored when your app exits.

## Alternate Screen

Terminals have two screen buffers:

- **Main screen** - The normal scrollback buffer
- **Alternate screen** - A separate buffer for full-screen apps

TermUI uses the alternate screen, preserving the user's shell history. When your app exits, the terminal returns to the main screen with history intact.

```
┌─────────────────────┐     ┌─────────────────────┐
│ $ ls                │     │ ┌─────────────────┐ │
│ file1.txt           │     │ │  Your TermUI    │ │
│ file2.txt           │ --> │ │  Application    │ │
│ $ my_app            │     │ │                 │ │
│                     │     │ └─────────────────┘ │
│  Main Screen        │     │  Alternate Screen   │
└─────────────────────┘     └─────────────────────┘
                                     │
                                     │ (exit)
                                     ▼
                            ┌─────────────────────┐
                            │ $ ls                │
                            │ file1.txt           │
                            │ file2.txt           │
                            │ $ my_app            │
                            │ $                   │
                            │  Back to Main       │
                            └─────────────────────┘
```

## Mouse Tracking

TermUI can capture mouse events.

### Tracking Modes

| Mode | Events Captured |
|------|-----------------|
| `:click` | Button press/release |
| `:drag` | Click + drag movements |
| `:all` | All mouse movement |

The runtime enables click tracking by default.

### Mouse Coordinates

Mouse positions are 0-indexed:
- `x` = column (0 = leftmost)
- `y` = row (0 = topmost)

```elixir
def event_to_msg(%Event.Mouse{action: :click, x: x, y: y}, state) do
  # Check if click is within a region
  if x >= 10 and x < 30 and y >= 5 and y < 10 do
    {:msg, :button_clicked}
  else
    :ignore
  end
end
```

### Scroll Events

Mouse wheel generates scroll events:

```elixir
def event_to_msg(%Event.Mouse{action: :scroll_up}, _state) do
  {:msg, :scroll_up}
end

def event_to_msg(%Event.Mouse{action: :scroll_down}, _state) do
  {:msg, :scroll_down}
end
```

## Focus Events

Know when the terminal window gains or loses focus:

```elixir
def event_to_msg(%Event.Focus{action: :gained}, _state) do
  {:msg, :focus_gained}
end

def event_to_msg(%Event.Focus{action: :lost}, _state) do
  {:msg, :focus_lost}
end

def update(:focus_lost, state) do
  # Pause updates, dim display, etc.
  {%{state | paused: true}, []}
end

def update(:focus_gained, state) do
  # Resume updates
  {%{state | paused: false}, []}
end
```

**Note:** Focus events require terminal support. They work on most modern terminals (xterm, iTerm2, Alacritty, Kitty, Windows Terminal).

## Terminal Size

### Getting Size

Query current dimensions:

```elixir
{:ok, {rows, cols}} = TermUI.Terminal.get_terminal_size()
```

### Handling Resize

Respond to window size changes:

```elixir
def event_to_msg(%Event.Resize{width: w, height: h}, _state) do
  {:msg, {:resize, w, h}}
end

def update({:resize, width, height}, state) do
  {%{state | width: width, height: height}, []}
end

def view(state) do
  if state.width < 80 do
    render_compact_layout(state)
  else
    render_full_layout(state)
  end
end
```

## Cursor Control

The runtime manages cursor visibility and position. The cursor is hidden during normal operation to avoid flicker.

For text input widgets that need a visible cursor:

```elixir
# The cursor position is managed by the renderer
# Your TextInput widget indicates where the cursor should be
TextInput.render(
  value: state.text,
  cursor_position: state.cursor_pos,
  focused: true  # Shows cursor
)
```

## Color Support

### Detection

TermUI detects terminal color capabilities:
- 16 colors (basic)
- 256 colors (extended)
- True color (24-bit RGB)

### Graceful Degradation

Use named colors for maximum compatibility:

```elixir
# Works everywhere
Style.new(fg: :red)

# Requires 256-color support
Style.new(fg: 196)

# Requires true color support
Style.new(fg: {255, 100, 50})
```

The renderer automatically degrades colors for less capable terminals.

## Clipboard

### Paste Events

Bracketed paste mode delivers pasted text as a single event:

```elixir
def event_to_msg(%Event.Paste{content: text}, _state) do
  {:msg, {:paste, text}}
end

def update({:paste, text}, state) do
  # Insert pasted text at cursor
  new_text = state.text <> text
  {%{state | text: new_text}, []}
end
```

Without bracketed paste, pasted text would arrive as individual key events, which is slower and may trigger unintended shortcuts.

## Terminal Requirements

### Minimum Requirements

- ANSI escape sequence support
- UTF-8 encoding
- 80x24 minimum size

### Recommended

- 256-color or true color support
- Mouse tracking support
- Focus event support
- Unicode box drawing characters

### Supported Terminals

Tested and working:

| Terminal | Platform | Notes |
|----------|----------|-------|
| Alacritty | Cross-platform | Full support |
| Kitty | Linux/macOS | Full support |
| iTerm2 | macOS | Full support |
| WezTerm | Cross-platform | Full support |
| GNOME Terminal | Linux | Full support |
| Windows Terminal | Windows | Full support |
| Terminal.app | macOS | Limited mouse |
| xterm | Cross-platform | Full support |

### SSH Sessions

TermUI works over SSH when the remote terminal supports required features. The runtime detects terminal capabilities through multiple methods to ensure SSH compatibility.

## Error Handling

### Terminal Not Available

Handle cases where no terminal is present:

```elixir
case TermUI.Runtime.start_link(root: MyApp) do
  {:ok, pid} ->
    # Running normally
    pid

  {:error, :not_a_terminal} ->
    IO.puts("Error: Must run in a terminal")
    System.halt(1)
end
```

### Cleanup on Crash

The runtime traps exits and restores terminal state even if your app crashes:

```elixir
# In Runtime.init/1
Process.flag(:trap_exit, true)

# In Runtime.terminate/2
Terminal.restore()  # Always runs
```

This ensures users don't get stuck in raw mode with no echo.

## Direct Terminal Access

For advanced use cases, access terminal functions directly:

```elixir
alias TermUI.Terminal

# These are managed by Runtime, but available if needed:
Terminal.enable_raw_mode()
Terminal.disable_raw_mode()
Terminal.enter_alternate_screen()
Terminal.leave_alternate_screen()
Terminal.show_cursor()
Terminal.hide_cursor()
Terminal.clear_screen()
Terminal.set_cursor_position(row, col)
```

**Warning:** Direct terminal access can interfere with the runtime. Use only when necessary.

## Next Steps

- [Events](04-events.md) - Handle terminal input
- [Commands](09-commands.md) - Async operations
- [Styling](05-styling.md) - Colors and attributes
