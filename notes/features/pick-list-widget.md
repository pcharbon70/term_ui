# PickList Widget Feature

## Problem Statement

JidoCode Phase 4 requires a pick-list widget for provider and model selection. The widget should display a scrollable modal overlay allowing users to select from a list of items with keyboard navigation and type-ahead filtering.

## Solution Overview

Create `TermUI.Widget.PickList` as a stateful component that:
- Renders as a modal overlay centered on screen with a border
- Displays a scrollable list with current selection highlighted
- Supports keyboard navigation (Up/Down, Page Up/Down, Home/End)
- Supports type-ahead filtering
- Returns selected value on Enter, nil on Escape

## Technical Details

### File Locations
- Widget: `lib/term_ui/widget/pick_list.ex`
- Tests: `test/term_ui/widget/pick_list_test.exs`

### Dependencies
- Uses `TermUI.StatefulComponent` behaviour
- Uses `TermUI.Widget.Block` border characters for modal frame
- Uses `TermUI.Component.RenderNode` for rendering
- Uses `TermUI.Renderer.Style` for styling

### Props
- `:items` - List of items (required)
- `:title` - Modal title (optional)
- `:on_select` - Callback when item selected `fn item -> ... end`
- `:on_cancel` - Callback when cancelled `fn -> ... end`
- `:width` - Modal width (default: 40)
- `:height` - Modal height (default: 10)
- `:style` - Border/text style
- `:highlight_style` - Selected item style

### State
- `selected_index` - Currently highlighted item index
- `scroll_offset` - For scrolling long lists
- `filter_text` - Current type-ahead filter
- `filtered_items` - Items matching filter
- `props` - Stored props

## Implementation Plan

### 4.3.1.1 Create PickList module structure
- [x] Create `lib/term_ui/widget/pick_list.ex`
- [x] Add module docs and `use TermUI.StatefulComponent`
- [x] Define type specs

### 4.3.1.2 Implement init/1
- [x] Initialize state with items, selected_index: 0, scroll_offset: 0
- [x] Initialize filter_text: "", filtered_items: items

### 4.3.1.3 Implement keyboard navigation
- [x] Up/Down arrows - move selection
- [x] Page Up/Down - jump 10 items
- [x] Home/End - jump to first/last
- [x] Keep selection within bounds

### 4.3.1.4 Implement type-ahead filtering
- [x] Printable characters append to filter_text
- [x] Backspace removes last character from filter
- [x] Filter items case-insensitively
- [x] Reset selection to 0 when filter changes

### 4.3.1.5 Implement selection/cancel
- [x] Enter confirms selection, sends {:select, item}
- [x] Escape cancels, sends :cancel

### 4.3.1.6 Implement render/2
- [x] Calculate modal position (centered)
- [x] Render border with title
- [x] Render filter input if filter_text not empty
- [x] Render visible items with scroll
- [x] Highlight selected item
- [x] Render status line: "Item X of Y" or filter status

### 4.3.1.7 Implement handle_info/2
- [x] Handle {:select, item} - call on_select callback
- [x] Handle :cancel - call on_cancel callback

### 4.3.1.8 Handle empty list
- [x] Display "No items" message
- [x] Only allow Escape

### 4.3.1.9 Write tests
- [x] Test init with items
- [x] Test navigation (up/down/page/home/end)
- [x] Test filtering
- [x] Test selection/cancel
- [x] Test empty list
- [x] Test scroll behavior

## Success Criteria

- [x] Widget renders correctly as modal overlay
- [x] All keyboard navigation works
- [x] Type-ahead filtering works
- [x] Selection/cancel callbacks work
- [x] Empty list handled gracefully
- [x] All tests pass (32 tests)

## Current Status

**Completed**: All implementation tasks done. 32 tests passing.
