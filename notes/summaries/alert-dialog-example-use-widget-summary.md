# Summary: Alert Dialog Example Widget Integration

## Overview

Updated the alert_dialog example to use the proper `TermUI.Widgets.AlertDialog` widget instead of manual implementation, demonstrating best practices for widget usage.

## Changes Made

### 1. State Structure Simplified (lines 44-51)
- Replaced 6 manual alert fields with single `alert` field
- Alert state is `nil` when no dialog visible, holds AlertDialog state otherwise
- Kept `last_result` and `last_alert_type` for result tracking

### 2. Event Handling Delegated to Widget (lines 57-69)
- Number keys (1-6) create new alerts via `AlertDialog.new/1` + `AlertDialog.init/1`
- When alert visible, all events forwarded to `AlertDialog.handle_event/2`
- Widget handles Tab, Enter, Escape, Y/N internally

### 3. Message Handlers Simplified (lines 71-104)
- Used helper `show_alert/4` to create AlertDialog with `AlertDialog.new/1` + `AlertDialog.init/1`
- Forward events via `{:alert_event, event}` message
- Capture result when `AlertDialog.visible?/1` returns false after event

### 4. View Function Uses Widget (lines 106-121)
- Uses `AlertDialog.render/2` instead of manual rendering
- Passes area dimensions for dialog positioning

### 5. Removed Manual Helpers
- `render_alert/1`
- `get_alert_icon_and_style/1`
- `render_alert_title/4`
- `render_alert_message/2`
- `render_alert_buttons/2`

## Code Reduction

| Metric | Before | After | Change |
|--------|--------|-------|--------|
| Lines of code | ~348 | ~186 | -162 (~47% reduction) |
| Private functions | 8 | 3 | -5 |
| State fields | 6 | 3 | -3 |

## New Dependencies Used

```elixir
alias TermUI.Widgets.AlertDialog
```

## Code Quality

- All 3535 TermUI tests pass
- Credo --strict passes on alert_dialog example
- No warnings

## Widget API Usage Pattern

```elixir
# Create and show alert
props = AlertDialog.new(type: :confirm, title: "Title", message: "Message")
{:ok, alert} = AlertDialog.init(props)
state = %{state | alert: alert}

# Handle events (forwarded from Elm event_to_msg)
{:ok, new_alert} = AlertDialog.handle_event(event, state.alert)
if AlertDialog.visible?(new_alert) do
  %{state | alert: new_alert}
else
  result = AlertDialog.get_focused_button(new_alert)
  %{state | alert: nil, last_result: result}
end

# Render
AlertDialog.render(state.alert, %{width: 80, height: 24})
```

## Files Modified

- `examples/alert_dialog/lib/alert_dialog/app.ex` - Main example application
- `lib/term_ui/runtime/node_renderer.ex` - Added overlay node support

## Benefits

1. Example now demonstrates proper AlertDialog widget usage
2. Keyboard navigation, icons, and styling handled by widget
3. Removed ~160 lines of duplicate code
4. Example serves as reference for AlertDialog API usage
5. Widget API validated through real usage
6. Overlay support enables other widgets (Dialog, ContextMenu, Toast) to work with Elm renderer
