# TextInput Widget Example

This example demonstrates how to use the `TermUI.Widgets.TextInput` widget for single-line and multi-line text input.

## Features Demonstrated

- Single-line text input with Enter to submit
- Multi-line text input with auto-growing height
- Chat-style input with Enter to submit (Ctrl+Enter for newlines)
- Scrollable area after max_visible_lines
- Placeholder text
- Focus states with visual feedback
- Cursor positioning and movement
- Text editing operations

## Installation

```bash
cd examples/text_input
mix deps.get
```

## Running

```bash
mix run run.exs
```

## Controls

| Key | Action |
|-----|--------|
| Arrow keys | Move cursor |
| Home/End | Move to start/end of line |
| Ctrl+Home/End | Move to start/end of text (multiline) |
| Backspace/Delete | Delete characters |
| Ctrl+Enter | Insert newline (multiline mode) |
| Enter | Submit (single-line) or newline (multiline) |
| Tab | Switch between inputs |
| Escape | Blur input (remove focus) |
| Q | Quit (when input is empty) |

## Code Overview

### Creating a Single-Line Input

```elixir
alias TermUI.Widgets.TextInput

props = TextInput.new(
  placeholder: "Enter your name...",
  width: 40,
  on_submit: fn value ->
    IO.puts("Submitted: #{value}")
  end
)

{:ok, state} = TextInput.init(props)
```

### Creating a Multi-Line Input

```elixir
props = TextInput.new(
  placeholder: "Enter your message...",
  width: 50,
  multiline: true,
  max_visible_lines: 5,
  on_change: fn value ->
    IO.puts("Current text: #{value}")
  end
)

{:ok, state} = TextInput.init(props)
```

### Chat-Style Input (Enter Submits)

```elixir
props = TextInput.new(
  placeholder: "Type a message and press Enter...",
  width: 50,
  multiline: true,
  max_visible_lines: 3,
  enter_submits: true,  # Enter submits, Ctrl+Enter inserts newline
  on_submit: fn value ->
    send_message(value)
  end
)

{:ok, state} = TextInput.init(props)
```

### Widget Options

```elixir
TextInput.new(
  value: "",                    # Initial text value
  placeholder: "Enter text...", # Placeholder when empty
  width: 40,                    # Widget width in characters
  multiline: false,             # Enable multi-line mode
  max_lines: nil,               # Max lines allowed (nil = unlimited)
  max_visible_lines: 5,         # Lines visible before scrolling
  enter_submits: false,         # Enter submits instead of newline
  disabled: false,              # Disable input
  style: nil,                   # Text style
  focused_style: nil,           # Style when focused
  placeholder_style: nil,       # Placeholder text style
  on_change: fn value -> ... end,  # Value change callback
  on_submit: fn value -> ... end   # Submit callback
)
```

## TextInput API

```elixir
# Get current value
value = TextInput.get_value(state)

# Set value programmatically
state = TextInput.set_value(state, "New text")

# Clear the input
state = TextInput.clear(state)

# Set focus state
state = TextInput.set_focused(state, true)

# Get line count
lines = TextInput.get_line_count(state)

# Get cursor position
{row, col} = TextInput.get_cursor(state)
```

## Features

### Auto-Growing Height

Multi-line inputs automatically grow their height as you type, up to `max_visible_lines`. After that, the content becomes scrollable with a scroll indicator showing position.

### Scrolling

When content exceeds `max_visible_lines`, a scroll indicator appears showing:
- Current position (e.g., "↓ 6-10/25")
- Scroll arrows (↑, ↓, or ↕)

### Focus States

Inputs have different visual states:
- **Focused**: Shows cursor and active style
- **Unfocused**: Shows content without cursor
- **Empty & Unfocused**: Shows placeholder text (dimmed)

### Text Editing

Supports standard text editing operations:
- Character insertion at cursor
- Backspace/Delete character removal
- Line joining on backspace at line start
- Newline insertion (multiline mode)
- Cursor movement with arrow keys

## Example Modes

The example demonstrates three different input configurations:

1. **Single-line Input**: Traditional text field that submits on Enter
2. **Multi-line Input**: Text area with Ctrl+Enter for newlines, Enter also adds newlines
3. **Chat Input**: Chat-style with Enter to submit and Ctrl+Enter for newlines

Use Tab to cycle between the three inputs and see how they behave differently.

## Widget API

See `lib/term_ui/widgets/text_input.ex` for the full API documentation.
