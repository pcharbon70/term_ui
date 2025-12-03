# AlertDialog Widget Example

This example demonstrates the TermUI AlertDialog widget, which provides standardized message dialogs and confirmations with predefined button configurations and visual icons.

## Widget Overview

The AlertDialog widget is designed for displaying modal dialogs that require user attention or confirmation. It provides six predefined alert types, each with appropriate icons and button configurations:

- **Info** - General information messages
- **Success** - Operation success confirmations
- **Warning** - Caution messages requiring attention
- **Error** - Error notifications
- **Confirm** - Yes/No decision dialogs
- **OK/Cancel** - Cancellable action dialogs

Use AlertDialog when you need to interrupt the user's workflow to display important messages or request confirmation before proceeding with an action.

## Widget Options

The `AlertDialog.new/1` function accepts the following options:

- `:type` - Alert type (required): `:info`, `:success`, `:warning`, `:error`, `:confirm`, `:ok_cancel`
- `:title` - Dialog title (required)
- `:message` - Message to display (required)
- `:on_result` - Callback function to handle result (`:ok`, `:cancel`, `:yes`, `:no`)
- `:width` - Dialog width in characters (default: 50)
- `:icon_style` - Custom style for the icon
- `:message_style` - Custom style for the message text
- `:button_style` - Custom style for buttons
- `:focused_button_style` - Custom style for the focused button

## Example Structure

The example consists of:

- `lib/alert_dialog/app.ex` - Main application demonstrating all alert types
  - Handles number keys (1-6) to trigger different alert types
  - Manages alert state and captures user responses
  - Displays the result of the last closed dialog

## Running the Example

```bash
cd examples/alert_dialog
mix deps.get
iex -S mix
```

Then in the IEx shell:

```elixir
AlertDialog.App.run()
```

## Controls

**When no alert is visible:**
- `1` - Show Info Alert (informational message)
- `2` - Show Success Alert (operation succeeded)
- `3` - Show Warning Alert (caution message)
- `4` - Show Error Alert (error message)
- `5` - Show Confirm Dialog (Yes/No choice)
- `6` - Show OK/Cancel Dialog (OK/Cancel choice)
- `Q` - Quit application

**When alert is visible:**
- `Tab` / `←` / `→` - Navigate between buttons
- `Enter` - Select focused button
- `Y` / `N` - Quick select (in confirm dialogs only)
- `Escape` - Cancel/Close alert

## Implementation Notes

The example demonstrates:
- Creating different alert types with appropriate messages
- Handling alert events and button selection
- Capturing and displaying dialog results
- Conditional rendering based on alert visibility
- The difference between message alerts (OK only) and decision dialogs (Yes/No, OK/Cancel)

### Alert Types Reference

| Type | Icon | Buttons | Use Case |
|------|------|---------|----------|
| info | ℹ | OK | Informational messages |
| success | ✓ | OK | Operation succeeded |
| warning | ⚠ | OK | Caution messages |
| error | ✗ | OK | Error messages |
| confirm | ? | No, Yes | Yes/No decisions |
| ok_cancel | ? | Cancel, OK | OK/Cancel decisions |
