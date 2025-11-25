# Dialog Widget Example

This example demonstrates how to use the `TermUI.Widgets.Dialog` widget for displaying modal dialogs.

## Features Demonstrated

- Dialog with title and content
- Multiple button options
- Button navigation with Tab/arrows
- Dialog open/close states
- Different dialog types (info, confirm, warning)

## Installation

```bash
cd examples/dialog
mix deps.get
```

## Running

```bash
mix run run.exs
```

## Controls

| Key | Action |
|-----|--------|
| 1 | Show Info dialog |
| 2 | Show Confirm dialog |
| 3 | Show Warning dialog |
| Tab/←/→ | Navigate buttons (in dialog) |
| Enter/Space | Select button |
| Escape | Close dialog |
| Q | Quit |

## Code Overview

### Creating a Dialog

```elixir
Dialog.new(
  title: "Confirm Delete",
  content: text("Are you sure you want to delete this item?"),
  buttons: [
    %{id: :cancel, label: "Cancel"},
    %{id: :delete, label: "Delete", style: :danger}
  ],
  on_close: fn -> handle_close() end,
  on_confirm: fn button_id -> handle_button(button_id) end
)
```

### Dialog Options

```elixir
Dialog.new(
  title: "Dialog Title",       # Required: title text
  content: render_node,        # Dialog body content
  buttons: [...],              # List of button definitions
  width: 40,                   # Dialog width
  closeable: true,             # Whether Escape closes dialog
  on_close: fn -> ... end,     # Called when dialog closes
  on_confirm: fn id -> ... end # Called when button selected
)
```

### Button Definition

```elixir
%{
  id: :confirm,        # Unique identifier
  label: "Confirm",    # Display text
  default: true,       # Initially focused
  style: :danger       # Visual style hint
}
```

### Styling Options

```elixir
Dialog.new(
  title: "Styled Dialog",
  backdrop_style: Style.new(fg: :bright_black),
  title_style: Style.new(fg: :cyan, attrs: [:bold]),
  content_style: Style.new(fg: :white),
  button_style: Style.new(fg: :white),
  focused_button_style: Style.new(fg: :black, bg: :cyan)
)
```

### Dialog API

```elixir
# Check visibility
Dialog.visible?(state)

# Show/hide
Dialog.show(state)
Dialog.hide(state)

# Get focused button
Dialog.get_focused_button(state)

# Focus specific button
Dialog.focus_button(state, :confirm)

# Update content
Dialog.set_content(state, new_content)
Dialog.set_title(state, "New Title")
```

## Dialog Types

The example shows three common dialog patterns:

| Type | Buttons | Use Case |
|------|---------|----------|
| Info | OK | Display information |
| Confirm | Cancel, Confirm | Yes/No decisions |
| Warning | Don't Save, Cancel, Save | Complex choices |

## Widget API

See `lib/term_ui/widgets/dialog.ex` for the full API documentation.
