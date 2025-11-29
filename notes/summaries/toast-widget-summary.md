# Toast Widget Implementation Summary

## Overview

The `TermUI.Widgets.Toast` and `TermUI.Widgets.ToastManager` were already implemented. This task added the missing example application.

## Existing Implementation

### Widget: `lib/term_ui/widgets/toast.ex`

#### Toast Module
- Auto-dismissing notifications at screen edge
- 6 position options (top/bottom + left/center/right)
- Type-specific icons (ℹ, ✓, ⚠, ✗)
- Configurable duration (default 3000ms)
- Z-order rendering (z: 150, above dialogs)
- Click or Escape to dismiss manually

#### ToastManager Module
- Manages multiple toast notifications
- Toast stacking with configurable spacing
- Max toast limit (default 5)
- Auto-dismiss via tick() method
- Clear all functionality

### Tests: `test/term_ui/widgets/toast_test.exs`
- 30 tests covering all functionality
- Toast types, positions, duration
- ToastManager stacking and lifecycle
- Public API methods

## New Files Created

### Example: `examples/toast/`
- `mix.exs` - Mix project configuration
- `lib/toast/application.ex` - OTP application
- `lib/toast/app.ex` - Example demonstrating toast functionality
- `run.exs` - Script to run the example
- `README.md` - Documentation with usage instructions

## Features Demonstrated in Example

- Info, Success, Warning, Error toast types
- All 6 screen positions with cycling
- Auto-dismiss after 3 seconds
- Multiple toasts stacking (press 5)
- Manual dismiss with click/Escape
- Active toast count tracking
- Position switching at runtime

## Phase 6.3.3 Requirements Met

- [x] 6.3.3.1 Toast positioning at screen edge
- [x] 6.3.3.2 Auto-dismiss with configurable duration
- [x] 6.3.3.3 Toast stacking for multiple notifications
- [x] 6.3.3.4 Toast types: info, success, warning, error

## Section 6.3 Complete

With Toast Notifications done, Section 6.3 (Overlay Widgets) is now complete:
- [x] 6.3.1 Dialog Widget (25 tests)
- [x] 6.3.2 Alert Dialog (22 tests)
- [x] 6.3.3 Toast Notifications (30 tests)

## Running the Example

```bash
cd examples/toast
mix deps.get
mix run run.exs
```

## Widget Usage

### Single Toast

```elixir
alias TermUI.Widgets.Toast

props = Toast.new(
  message: "File saved successfully",
  type: :success,
  duration: 3000,
  position: :bottom_right,
  on_dismiss: fn -> handle_dismiss() end
)

{:ok, state} = Toast.init(props)

# Check auto-dismiss
if Toast.should_dismiss?(state) do
  state = Toast.dismiss_toast(state)
end
```

### Multiple Toasts with ToastManager

```elixir
alias TermUI.Widgets.ToastManager

manager = ToastManager.new(
  position: :bottom_right,
  max_toasts: 5,
  default_duration: 3000
)

manager = ToastManager.add_toast(manager, "Message 1", :info)
manager = ToastManager.add_toast(manager, "Message 2", :success)

# On tick (removes expired)
manager = ToastManager.tick(manager)

# Clear all
manager = ToastManager.clear_all(manager)
```

## Toast Types Reference

| Type | Icon | Color |
|------|------|-------|
| info | ℹ | cyan/blue |
| success | ✓ | green |
| warning | ⚠ | yellow |
| error | ✗ | red |

## Public API - Toast

- `Toast.visible?(state)` - Check if visible
- `Toast.dismiss_toast(state)` - Manually dismiss
- `Toast.should_dismiss?(state)` - Check if duration expired
- `Toast.get_type(state)` - Get toast type
- `Toast.get_position(state)` - Get position
- `Toast.elapsed_time(state)` - Time since creation

## Public API - ToastManager

- `ToastManager.new(opts)` - Create manager
- `ToastManager.add_toast(manager, msg, type, opts)` - Add toast
- `ToastManager.tick(manager)` - Remove expired toasts
- `ToastManager.get_toasts(manager)` - Get visible toasts
- `ToastManager.toast_count(manager)` - Count visible
- `ToastManager.clear_all(manager)` - Remove all toasts
