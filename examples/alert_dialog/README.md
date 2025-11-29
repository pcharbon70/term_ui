# Alert Dialog Widget Example

This example demonstrates the `TermUI.Widgets.AlertDialog` widget for displaying standardized message dialogs with different types and button configurations.

## Features Demonstrated

- Info alert (informational message with OK button)
- Success alert (success message with OK button)
- Warning alert (warning message with OK button)
- Error alert (error message with OK button)
- Confirm dialog (Yes/No buttons with Y/N shortcuts)
- OK/Cancel dialog (OK/Cancel buttons)
- Type-specific icons and colors
- Keyboard navigation between buttons
- Quick shortcuts for confirm dialogs

## Running the Example

```bash
cd examples/alert_dialog
mix deps.get
mix run run.exs
```

## Controls

| Key | Action |
|-----|--------|
| 1 | Show Info Alert |
| 2 | Show Success Alert |
| 3 | Show Warning Alert |
| 4 | Show Error Alert |
| 5 | Show Confirm Dialog |
| 6 | Show OK/Cancel Dialog |
| Tab/Arrow | Navigate buttons (when alert open) |
| Enter/Space | Select button |
| Y | Select Yes (confirm dialogs only) |
| N | Select No (confirm dialogs only) |
| Escape | Cancel/Close alert |
| Q | Quit |

## Alert Types

| Type | Icon | Buttons | Use Case |
|------|------|---------|----------|
| info | ℹ | OK | Informational messages |
| success | ✓ | OK | Operation succeeded |
| warning | ⚠ | OK | Caution messages |
| error | ✗ | OK | Error messages |
| confirm | ? | No, Yes | Yes/No decisions |
| ok_cancel | ? | Cancel, OK | OK/Cancel decisions |

## Widget Usage

```elixir
alias TermUI.Widgets.AlertDialog

# Create an info alert
props = AlertDialog.new(
  type: :info,
  title: "Information",
  message: "This is an informational message.",
  on_result: fn result -> handle_result(result) end
)

# Create a confirmation dialog
props = AlertDialog.new(
  type: :confirm,
  title: "Confirm Delete",
  message: "Are you sure you want to delete this file?",
  on_result: fn result ->
    case result do
      :yes -> delete_file()
      :no -> :cancelled
    end
  end
)

# Initialize state
{:ok, state} = AlertDialog.init(props)

# The alert will render centered with type-specific icon
# and handle keyboard events for navigation
```

## Features

- **Type-specific Icons**: Each alert type has a distinctive icon
- **Standard Button Configurations**: Appropriate buttons for each type
- **Default Focus**: Focus starts on the appropriate button (e.g., Yes for confirm)
- **Keyboard Shortcuts**: Y/N keys for quick confirm dialog responses
- **Escape Handling**: Escape acts as Cancel/No depending on dialog type
- **Z-Order**: Alert renders above other content (z: 100)
