# PickList Widget Implementation Summary

## Overview

Implemented `TermUI.Widget.PickList`, a modal pick-list widget for selecting from a list of items. The widget renders as a centered modal overlay with keyboard navigation and type-ahead filtering.

## Files Created

- `lib/term_ui/widget/pick_list.ex` - Main widget implementation
- `test/term_ui/widget/pick_list_test.exs` - Comprehensive test suite (32 tests)
- `notes/features/pick-list-widget.md` - Planning document

## Features Implemented

### Modal Display
- Centered modal overlay with configurable width and height
- Single-line border with title support
- Status line showing "Item X of Y" position

### Keyboard Navigation
- Up/Down arrows - move selection one item
- Page Up/Down - jump 10 items
- Home/End - jump to first/last item
- Enter - confirm selection (triggers `on_select` callback)
- Escape - cancel (triggers `on_cancel` callback)

### Type-Ahead Filtering
- Typing filters items case-insensitively
- Backspace removes last filter character
- Filter text displayed when active
- Selection resets to first item when filter changes

### Scroll Behavior
- Automatic scroll adjustment to keep selection visible
- Works with lists larger than visible area

### Props Supported
- `:items` - List of items to display
- `:title` - Modal title
- `:on_select` - Callback when item selected `fn item -> ... end`
- `:on_cancel` - Callback when cancelled `fn -> ... end`
- `:width` - Modal width (default: 40)
- `:height` - Modal height (default: 10)
- `:style` - Border/text style options
- `:highlight_style` - Style for selected item

## Test Coverage

32 tests covering:
- Initialization with default and custom values
- Navigation in all directions with boundary handling
- Selection and cancel event handling
- Type-ahead filtering behavior
- Rendering with title, items, status line, filter display
- Empty list handling
- Scroll behavior for oversized lists
- Message handling for callbacks and item updates

## Usage Example

```elixir
PickList.render(%{
  items: ["Apple", "Banana", "Cherry"],
  title: "Select Fruit",
  on_select: fn item -> IO.puts("Selected: #{item}") end,
  on_cancel: fn -> IO.puts("Cancelled") end
}, state, area)
```

## Implementation Notes

- Uses `TermUI.StatefulComponent` behaviour
- State includes: `selected_index`, `scroll_offset`, `filter_text`, `filtered_items`, `original_items`, `props`
- Commands pattern used for selection/cancel (sends messages to self)
- Border characters match single style from `TermUI.Widget.Block`
