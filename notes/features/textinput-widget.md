# TextInput Widget

## Problem Statement

Implement a TextInput widget that supports both single-line and multi-line text input. The widget should handle cursor movement, text editing, and provide a scrollable view when content exceeds the visible area.

### Requirements

- Multi-line text input support
- New line insertion via Ctrl+Enter
- Auto-growing height (up to 5 lines)
- Scrollable area after 5 lines
- Cursor movement and text editing
- Placeholder text support
- Focus state handling

## Solution Overview

Create a StatefulComponent-based widget that:
1. Manages text content as a list of lines
2. Tracks cursor position (row, column)
3. Handles keyboard input for editing
4. Renders with auto-grow up to max_lines
5. Provides scrolling when content exceeds max visible lines

### Key Design Decisions

1. **Text Storage**: Store as list of strings (one per line) for efficient line operations
2. **Cursor Model**: Track as `{row, col}` tuple
3. **Scrolling**: Virtual scroll when lines exceed `max_visible_lines` (default 5)
4. **Newline Key**: Ctrl+Enter to insert newline (Enter alone can be used for form submission)
5. **StatefulComponent**: Use the behavior for internal state management

## Technical Details

### Dependencies

- `TermUI.StatefulComponent` behavior
- `TermUI.Event` for keyboard handling
- `TermUI.Renderer.Style` for styling
- `TermUI.Widgets.WidgetHelpers` for common utilities

### Files to Create

1. `lib/term_ui/widgets/text_input.ex` - Main widget implementation
2. `test/term_ui/widgets/text_input_test.exs` - Unit tests
3. `examples/text_input/` - Example application

### API Design

```elixir
# Create widget props
TextInput.new(
  value: "",                    # Initial text value
  placeholder: "Enter text...", # Placeholder when empty
  width: 40,                    # Widget width
  max_lines: nil,               # nil = unlimited, or max line count
  max_visible_lines: 5,         # Lines before scrolling
  on_change: &callback/1,       # Value change callback
  on_submit: &callback/1,       # Submit callback (Enter key in single-line)
  multiline: true,              # Enable multi-line mode
  disabled: false,              # Disable input
  style: Style.new(),           # Text style
  focused_style: Style.new(),   # Style when focused
  placeholder_style: Style.new() # Placeholder text style
)

# Keyboard controls
# - Left/Right: Move cursor horizontally
# - Up/Down: Move cursor between lines (multiline)
# - Home/End: Move to start/end of line
# - Ctrl+Home/End: Move to start/end of text
# - Backspace: Delete character before cursor
# - Delete: Delete character at cursor
# - Ctrl+Enter: Insert newline (multiline mode)
# - Enter: Submit (single-line) or configurable
# - Escape: Blur/cancel
```

## Implementation Plan

### Task 1: Core Widget Structure
- [x] Create `text_input.ex` with StatefulComponent behavior
- [x] Implement `new/1` props function with configuration options
- [x] Implement `init/1` with state initialization
- [x] Define state structure (lines, cursor_row, cursor_col, scroll_offset, etc.)

### Task 2: Text Storage and Cursor Management
- [x] Implement text-to-lines conversion
- [x] Implement lines-to-text conversion
- [x] Implement cursor position validation
- [x] Implement cursor movement helpers (move_left, move_right, move_up, move_down)

### Task 3: Text Editing Operations
- [x] Implement character insertion at cursor
- [x] Implement character deletion (backspace, delete)
- [x] Implement newline insertion (Ctrl+Enter)
- [x] Implement line joining on backspace at line start

### Task 4: Keyboard Event Handling
- [x] Handle arrow keys for cursor movement
- [x] Handle Home/End for line navigation
- [x] Handle Ctrl+Home/End for document navigation
- [x] Handle printable character input
- [x] Handle Backspace and Delete keys
- [x] Handle Ctrl+Enter for newline
- [x] Handle Enter for submit (configurable)
- [x] Handle Escape for blur

### Task 5: Scrolling
- [x] Calculate visible line range based on cursor and scroll_offset
- [x] Implement scroll adjustment when cursor moves out of view
- [x] Implement scroll_to_cursor helper

### Task 6: Rendering
- [x] Render visible lines within max_visible_lines
- [x] Render cursor indicator when focused
- [x] Render placeholder when empty
- [x] Render scroll indicators when content exceeds view
- [x] Apply appropriate styles (normal, focused, placeholder)

### Task 7: Public API
- [x] Implement `get_value/1` to retrieve current text
- [x] Implement `set_value/2` to set text programmatically
- [x] Implement `focus/1` and `blur/1` for focus management
- [x] Implement `clear/1` to clear content

### Task 8: Unit Tests
- [x] Test initialization with various options
- [x] Test cursor movement in all directions
- [x] Test text insertion and deletion
- [x] Test newline insertion and line joining
- [x] Test scrolling behavior
- [x] Test rendering output
- [x] Test edge cases (empty, single char, very long lines)

### Task 9: Example Application
- [x] Create example app structure
- [x] Implement demo showing single-line and multi-line modes
- [x] Show various configurations

## Success Criteria

1. ✅ Single-line text input works
2. ✅ Multi-line text input with Ctrl+Enter for newlines
3. ✅ Auto-growing height up to max_visible_lines
4. ✅ Scrolling when content exceeds max_visible_lines
5. ✅ Cursor movement works correctly
6. ✅ Text editing (insert, delete, backspace) works
7. ✅ Placeholder text displays when empty
8. ✅ Focus state is visually indicated
9. ✅ All tests pass
10. ✅ Example application demonstrates features

## Notes

- Ctrl+Enter for newline is common in chat applications
- Single-line mode should use Enter for submit
- Consider word wrap in future enhancement
- Tab handling could be added (insert spaces or focus navigation)
