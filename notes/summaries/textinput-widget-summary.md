# TextInput Widget Implementation Summary

## Overview

Implemented a TextInput widget for TermUI that supports both single-line and multi-line text input with cursor movement, auto-growing height, and scrolling capabilities.

## Files Created/Modified

### New Files

1. **`lib/term_ui/widgets/text_input.ex`** (~710 lines)
   - StatefulComponent-based widget implementation
   - Single-line and multi-line modes
   - Cursor management (row, column)
   - Text operations (insert, delete, newline)
   - Scrolling with adjustable scroll_offset
   - Focus state handling
   - Callback support (on_change, on_submit)

2. **`test/term_ui/widgets/text_input_test.exs`** (~430 lines)
   - 58 comprehensive unit tests
   - Tests for initialization, character input, backspace/delete
   - Tests for cursor movement (all directions)
   - Tests for newline insertion and line operations
   - Tests for scrolling behavior
   - Tests for focus handling and callbacks
   - Tests for public API functions
   - Tests for edge cases

3. **`examples/text_input/`** - Example application
   - `mix.exs` - Project configuration
   - `lib/text_input.ex` - Entry point
   - `lib/text_input/app.ex` - Demo application showcasing:
     - Single-line input with submit callback
     - Multi-line input with Ctrl+Enter for newlines
     - Chat-style input with Enter for submit

4. **`notes/features/textinput-widget.md`** - Planning document

5. **`notes/summaries/textinput-widget-summary.md`** - This summary

### Modified Files

1. **`lib/term_ui/elm.ex`**
   - Fixed import conflict between `TermUI.Elm.Helpers` and `TermUI.Component.Helpers`
   - Both modules had `text/1` which caused compilation errors
   - Solution: Exclude conflicting functions from Elm.Helpers import

## Key Features

### Text Input Modes

1. **Single-line mode** (`multiline: false`)
   - Enter key submits input
   - Horizontal cursor movement only
   - No line breaks allowed

2. **Multi-line mode** (`multiline: true`)
   - Ctrl+Enter inserts newlines
   - Enter behavior configurable via `enter_submits` option
   - Up/Down arrow keys move between lines
   - Auto-growing height up to `max_visible_lines`
   - Scrollable area when content exceeds visible lines

### Keyboard Controls

| Key | Action |
|-----|--------|
| Left/Right | Move cursor horizontally |
| Up/Down | Move cursor between lines (multiline) |
| Home/End | Move to start/end of line |
| Ctrl+Home/End | Move to start/end of text |
| Backspace | Delete character before cursor |
| Delete | Delete character at cursor |
| Ctrl+Enter | Insert newline (multiline) |
| Enter | Submit (single-line) or configurable (multiline) |
| Escape | Blur input |

### Configuration Options

```elixir
TextInput.new(
  value: "",                    # Initial text
  placeholder: "Enter text...", # Placeholder when empty
  width: 40,                    # Widget width
  multiline: false,             # Enable multi-line mode
  max_lines: nil,               # Max lines (nil = unlimited)
  max_visible_lines: 5,         # Lines before scrolling
  enter_submits: false,         # Enter submits in multiline
  on_change: fn(value) -> ... end,
  on_submit: fn(value) -> ... end,
  disabled: false,
  style: Style.new(),
  focused_style: Style.new(),
  placeholder_style: Style.new()
)
```

### Public API

```elixir
TextInput.get_value(state)          # Get current text
TextInput.set_value(state, value)   # Set text programmatically
TextInput.clear(state)              # Clear content
TextInput.set_focused(state, bool)  # Set focus state
TextInput.get_line_count(state)     # Number of lines
TextInput.get_cursor(state)         # {row, col} cursor position
```

## Technical Decisions

1. **Text Storage**: Lines stored as list of strings for efficient line operations
2. **Cursor Model**: `{row, col}` tracked separately from scroll position
3. **Scrolling**: Virtual scroll with `scroll_offset` tracking visible window
4. **Newline Key**: Ctrl+Enter for newlines (common in chat apps)
5. **Focus Events**: Uses `Event.Focus` with `:gained`/`:lost` actions

## Bug Fix

During implementation, discovered and fixed a bug in `use TermUI.Elm`:
- Both `TermUI.Elm.Helpers` and `TermUI.Component.Helpers` defined `text/1`
- Caused "ambiguous function call" compilation errors
- Fixed by excluding conflicting functions from Elm.Helpers import:
  ```elixir
  import TermUI.Elm.Helpers, except: [text: 1, styled: 2, box: 1, box: 2]
  ```

## Test Results

- 58 tests created
- All tests pass
- Covers initialization, editing, cursor movement, scrolling, focus, callbacks, and edge cases

## Running the Example

```bash
cd examples/text_input
mix deps.get
mix run -e "TextInput.run()"
```

## Future Enhancements (Not Implemented)

- Word wrap
- Tab handling (insert spaces or focus navigation)
- Selection and copy/paste
- Undo/redo
- Mouse click positioning
