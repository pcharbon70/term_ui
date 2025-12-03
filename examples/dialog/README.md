# Dialog Widget Example

This example demonstrates the Dialog widget for displaying modal dialogs with customizable buttons and content.

## Widget Overview

The Dialog widget provides modal overlays that appear centered on screen with focus trapping. It's ideal for:

- Confirmation dialogs (Yes/No, OK/Cancel)
- Information alerts (single OK button)
- Warning messages with multiple options
- Simple forms or prompts

**Key Features:**
- Centered modal display with backdrop
- Customizable width and content
- Multiple button configurations
- Button navigation with keyboard and mouse
- Focus trapping (Tab cycles within dialog)
- Escape to close (configurable)
- Default button selection
- Button highlighting for focused state

## Widget Options

The `Dialog.new/1` function accepts the following options:

- `:title` (required) - Dialog title displayed in header
- `:content` - Dialog body content (render node, default: empty)
- `:buttons` - List of button definitions (default: single OK button)
  - Each button: `%{id: atom, label: string, default: boolean}`
- `:width` - Dialog width in characters (default: 40)
- `:on_close` - Callback function `(() -> any)` when dialog closes
- `:on_confirm` - Callback function `(button_id -> any)` when button is activated
- `:closeable` - Whether Escape closes dialog (default: true)
- `:title_style` - Style for title bar
- `:content_style` - Style for content area
- `:button_style` - Style for buttons
- `:focused_button_style` - Style for focused button

## Example Structure

```
dialog/
├── lib/
│   └── dialog/
│       └── app.ex          # Main application component
├── mix.exs                  # Project configuration
└── README.md               # This file
```

**app.ex** - Implements the Elm Architecture pattern:
- Maintains dialog state (visibility, button focus, result)
- Shows different dialog types (info, confirm, warning)
- Forwards keyboard events to dialog widget when visible
- Tracks last selected button for demonstration

## Running the Example

```bash
# From the dialog directory
mix deps.get
mix run -e "Dialog.App.run()" --no-halt
```

## Controls

- **1** - Show Info Dialog (single "OK" button)
- **2** - Show Confirm Dialog (Cancel/Confirm buttons)
- **3** - Show Warning Dialog (Don't Save/Cancel/Save buttons with default)
- **Tab / Shift+Tab** - Navigate between buttons (when dialog open)
- **Left/Right** - Navigate between buttons (when dialog open)
- **Enter** - Select focused button
- **Space** - Select focused button
- **Escape** - Close dialog (calls on_close callback)
- **Q** - Quit the application

## Dialog Types Demonstrated

**Info Dialog:**
```elixir
Dialog.new(
  title: "Information",
  content: text("This is an informational message.\nPress OK to continue.", nil),
  buttons: [%{id: :ok, label: "OK"}]
)
```

**Confirm Dialog:**
```elixir
Dialog.new(
  title: "Confirm Action",
  content: text("Are you sure you want to proceed?", nil),
  buttons: [
    %{id: :cancel, label: "Cancel"},
    %{id: :confirm, label: "Confirm"}
  ]
)
```

**Warning Dialog with Default:**
```elixir
Dialog.new(
  title: "Warning",
  content: text("Unsaved changes will be lost!", nil),
  buttons: [
    %{id: :dont_save, label: "Don't Save"},
    %{id: :cancel, label: "Cancel"},
    %{id: :save, label: "Save", default: true}
  ]
)
```

The `default: true` option sets initial focus to that button.
