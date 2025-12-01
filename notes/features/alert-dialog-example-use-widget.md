# Feature Plan: Alert Dialog Example Widget Integration

## Problem Statement

The alert_dialog example at `examples/alert_dialog/lib/alert_dialog/app.ex` currently implements alert dialogs manually without using the `TermUI.Widgets.AlertDialog` widget. This approach:

1. Duplicates all logic that already exists in the AlertDialog widget
2. Does not demonstrate best practices for using the widget library
3. Manually handles button focus, keyboard events, and styling
4. Manually renders icons, titles, messages, and buttons

**Impact:**
- The example fails to demonstrate how to use the AlertDialog widget
- Users may copy manual patterns instead of using the widget system
- Widget API is not validated through real usage in examples

## Solution Overview

Update the alert_dialog example to use the proper `TermUI.Widgets.AlertDialog` widget for all dialog rendering and event handling.

### Key Design Decisions

1. Use `AlertDialog.new/1` to create dialog props
2. Use `AlertDialog.init/1` to initialize dialog state
3. Use `AlertDialog.handle_event/2` for keyboard navigation
4. Use `AlertDialog.render/2` for dialog rendering
5. Track multiple alert configurations (not just one dialog state)
6. Preserve all existing functionality (6 alert types, result tracking)

## Technical Analysis

### Current Implementation (Manual)

The current example manually implements:
- State tracking: `alert_visible`, `alert_type`, `alert_title`, `alert_message`, `alert_buttons`, `focused_button`
- Event handling: Tab, Enter, Escape, Y/N keys
- Rendering: `render_alert/1`, `render_alert_title/4`, `render_alert_message/2`, `render_alert_buttons/2`
- Icon/style mapping: `get_alert_icon_and_style/1`

### AlertDialog Widget API

```elixir
# Create props
props = AlertDialog.new(
  type: :confirm,
  title: "Confirm Action",
  message: "Are you sure?",
  on_result: fn result -> IO.puts("Got: #{result}") end
)

# Initialize state
{:ok, dialog} = AlertDialog.init(props)

# Handle events
{:ok, dialog} = AlertDialog.handle_event(event, dialog)

# Render
AlertDialog.render(dialog, %{width: 80, height: 24})

# Query state
AlertDialog.visible?(dialog)
AlertDialog.get_focused_button(dialog)
AlertDialog.get_type(dialog)
AlertDialog.show(dialog)
AlertDialog.hide(dialog)
```

### State Management Approach

Since the example needs to show different alert types on demand, we'll:
1. Store the current alert dialog state (when visible)
2. Create new alert dialogs via `AlertDialog.new/1` + `AlertDialog.init/1` when user presses 1-6
3. Forward keyboard events to `AlertDialog.handle_event/2` when alert is visible
4. Track last result for display

## Implementation Plan

### Task 1: Update Module Aliases ✅
- [x] Add `alias TermUI.Widgets.AlertDialog`
- [x] Keep existing Event and Style aliases

### Task 2: Simplify State Structure ✅
- [x] Replace manual alert fields with single `alert` field (holds AlertDialog state or nil)
- [x] Keep `last_result` and `last_alert_type` for result display

### Task 3: Update Message Handlers ✅
- [x] Update `:show_info` to create AlertDialog with type: :info
- [x] Update `:show_success` to create AlertDialog with type: :success
- [x] Update `:show_warning` to create AlertDialog with type: :warning
- [x] Update `:show_error` to create AlertDialog with type: :error
- [x] Update `:show_confirm` to create AlertDialog with type: :confirm
- [x] Update `:show_ok_cancel` to create AlertDialog with type: :ok_cancel
- [x] Forward events to AlertDialog.handle_event/2 and capture results when dialog closes

### Task 4: Update Event Handling ✅
- [x] Forward events to `AlertDialog.handle_event/2` when alert is visible
- [x] Remove manual button navigation handlers
- [x] Remove manual Y/N shortcut handlers (widget handles these)

### Task 5: Update View Function ✅
- [x] Use `AlertDialog.render/2` instead of manual `render_alert/1`
- [x] Remove all manual alert rendering helpers

### Task 6: Cleanup ✅
- [x] Remove `render_alert/1`, `render_alert_title/4`, `render_alert_message/2`, `render_alert_buttons/2`
- [x] Remove `get_alert_icon_and_style/1`
- [x] Verify credo --strict passes

### Task 7: Testing ✅
- [x] Example compiles without errors
- [x] All 6 alert types display correctly
- [x] Keyboard navigation works (Tab, Enter, Escape, Y/N)
- [x] Result tracking displays correctly
- [x] All 3535 TermUI tests pass

### Task 8: Add Overlay Support to NodeRenderer ✅
- [x] Add `render_node` clause for `%{type: :overlay, ...}` maps
- [x] Overlay renders content at absolute x, y position
- [x] Enables AlertDialog, Dialog, ContextMenu, Toast widgets to work with Elm renderer

## Success Criteria

1. Example compiles without errors
2. All 6 alert types work: info, success, warning, error, confirm, ok_cancel
3. Keyboard navigation preserved (Tab, Enter, Escape, Y/N for confirm)
4. Result tracking displays last action
5. Uses AlertDialog widget exclusively for dialog rendering
6. No duplicate/manual alert implementation code
7. Credo --strict passes

## Files to Modify

- `examples/alert_dialog/lib/alert_dialog/app.ex` - Main file to update
- `lib/term_ui/runtime/node_renderer.ex` - Add overlay support for widgets

## Reference Files

- `lib/term_ui/widgets/alert_dialog.ex` - AlertDialog widget API
- `examples/dashboard/lib/dashboard/app.ex` - Reference for widget usage patterns
