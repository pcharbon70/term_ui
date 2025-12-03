# ContextMenu Widget Example

This example demonstrates the ContextMenu widget for displaying floating menus at cursor position, typically triggered by right-click or keyboard shortcuts.

## Widget Overview

The ContextMenu widget provides context-sensitive menus that appear at a specific screen position. It's ideal for:

- Right-click context menus
- Location-specific action lists
- Dropdown menus at arbitrary positions
- Quick action palettes

**Key Features:**
- Floating overlay positioned at exact coordinates
- Keyboard navigation (Up/Down/Enter/Escape)
- Mouse hover highlighting and click selection
- Automatic closure on selection or outside click
- Support for separators and disabled items
- Shortcut hints display
- Custom styling for different item states

## Widget Options

The `ContextMenu.new/1` function accepts the following options:

- `:items` (required) - List of menu items created with `ContextMenu.action/3` or `ContextMenu.separator/0`
- `:position` (required) - `{x, y}` tuple for menu position on screen
- `:on_select` - Callback function `(item_id -> any)` when item is selected
- `:on_close` - Callback function `(() -> any)` when menu is closed
- `:item_style` - Style for normal items
- `:selected_style` - Style for focused/hovered item
- `:disabled_style` - Style for disabled items

**Menu Item Helpers:**
- `ContextMenu.action(id, label, opts)` - Create an action item
  - `:shortcut` - Display shortcut hint (e.g., "Ctrl+X")
  - `:disabled` - Whether item is disabled
- `ContextMenu.separator()` - Create a separator line

## Example Structure

```
context_menu/
├── lib/
│   └── context_menu/
│       └── app.ex          # Main application component
├── mix.exs                  # Project configuration
└── README.md               # This file
```

**app.ex** - Implements the Elm Architecture pattern:
- Maintains menu state (position, visibility, selection)
- Handles right-click events to show menu at mouse position
- Forwards keyboard/mouse events to menu widget when visible
- Tracks last selected action for demonstration

## Running the Example

```bash
# From the context_menu directory
mix deps.get
mix run -e "ContextMenu.App.run()" --no-halt
```

## Controls

- **Right-click** - Show context menu at click position
- **1/2/3** - Show context menu at preset positions (top-left, center, right)
- **Up/Down** - Navigate menu items (when menu visible)
- **Enter/Space** - Select highlighted item
- **Escape** - Close menu without selecting
- **Q** - Quit the application

**Mouse Support:**
- Hover over items to highlight them
- Click on item to select it
- Click outside menu to close without selecting
