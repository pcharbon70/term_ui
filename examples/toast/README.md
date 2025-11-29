# Toast Widget Example

This example demonstrates the `TermUI.Widgets.Toast` and `TermUI.Widgets.ToastManager` widgets for displaying auto-dismissing notifications.

## Features Demonstrated

- Info, Success, Warning, Error toast types
- Different screen positions (6 positions)
- Auto-dismiss after configurable duration (3 seconds)
- Toast stacking when multiple appear
- Click or Escape to dismiss manually
- ToastManager for handling multiple toasts

## Running the Example

```bash
cd examples/toast
mix deps.get
mix run run.exs
```

## Controls

| Key | Action |
|-----|--------|
| 1 | Show Info Toast |
| 2 | Show Success Toast |
| 3 | Show Warning Toast |
| 4 | Show Error Toast |
| 5 | Show Multiple Toasts (stacking demo) |
| P | Cycle through positions |
| C | Clear all toasts |
| Q | Quit |

## Toast Types

| Type | Icon | Color |
|------|------|-------|
| info | ℹ | cyan/blue |
| success | ✓ | green |
| warning | ⚠ | yellow |
| error | ✗ | red |

## Toast Positions

| Position | Location |
|----------|----------|
| top_left | Upper left corner |
| top_center | Upper center |
| top_right | Upper right corner |
| bottom_left | Lower left corner |
| bottom_center | Lower center |
| bottom_right | Lower right corner (default) |

## Widget Usage

### Single Toast

```elixir
alias TermUI.Widgets.Toast

# Create a toast
props = Toast.new(
  message: "File saved successfully",
  type: :success,
  duration: 3000,
  position: :bottom_right,
  on_dismiss: fn -> handle_dismiss() end
)

# Initialize state
{:ok, state} = Toast.init(props)

# Check if should auto-dismiss
if Toast.should_dismiss?(state) do
  state = Toast.dismiss_toast(state)
end
```

### Multiple Toasts with ToastManager

```elixir
alias TermUI.Widgets.ToastManager

# Create manager
manager = ToastManager.new(
  position: :bottom_right,
  max_toasts: 5,
  default_duration: 3000
)

# Add toasts
manager = ToastManager.add_toast(manager, "First message", :info)
manager = ToastManager.add_toast(manager, "Second message", :success)

# Update on tick (removes expired toasts)
manager = ToastManager.tick(manager)

# Get visible toasts
toasts = ToastManager.get_toasts(manager)

# Clear all
manager = ToastManager.clear_all(manager)
```

## Features

- **Auto-dismiss**: Toasts automatically disappear after duration (default 3s)
- **Manual dismiss**: Click on toast or press Escape to dismiss early
- **Stacking**: Multiple toasts stack vertically at the chosen position
- **Max limit**: ToastManager limits number of simultaneous toasts (default 5)
- **Type icons**: Each type has a distinctive icon
- **Z-Order**: Toasts render above other content (z: 150)
- **Non-blocking**: Toasts don't capture focus or block interaction
