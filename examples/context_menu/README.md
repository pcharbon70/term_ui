# Context Menu Widget Example

This example demonstrates the `TermUI.Widgets.ContextMenu` widget for displaying floating menus at cursor position.

## Features Demonstrated

- Right-click to show context menu at click position
- Keyboard shortcuts to show menu at preset positions
- Up/Down arrow navigation between items
- Enter/Space to select items
- Escape or outside click to close menu
- Disabled menu items
- Keyboard shortcuts display

## Running the Example

```bash
cd examples/context_menu
mix deps.get
mix run run.exs
```

## Controls

| Key | Action |
|-----|--------|
| Right-click | Show context menu at cursor |
| 1 | Show menu at top-left |
| 2 | Show menu at center |
| 3 | Show menu at right |
| Up/Down | Navigate items (when menu open) |
| Enter/Space | Select item |
| Escape | Close menu |
| Q | Quit |

## Widget Usage

```elixir
alias TermUI.Widgets.ContextMenu

# Create context menu
props = ContextMenu.new(
  items: [
    ContextMenu.action(:cut, "Cut", shortcut: "Ctrl+X"),
    ContextMenu.action(:copy, "Copy", shortcut: "Ctrl+C"),
    ContextMenu.action(:paste, "Paste", shortcut: "Ctrl+V"),
    ContextMenu.separator(),
    ContextMenu.action(:delete, "Delete", shortcut: "Del")
  ],
  position: {x, y},
  on_select: fn id -> handle_action(id) end,
  on_close: fn -> handle_close() end
)

# Initialize state
{:ok, state} = ContextMenu.init(props)

# The menu will render at the specified position
# and handle keyboard/mouse events for navigation
```

## Features

- **Floating Overlay**: Menu appears at specified {x, y} position
- **Keyboard Navigation**: Up/Down arrows, Enter to select, Escape to close
- **Mouse Support**: Click to select items, click outside to close
- **Disabled Items**: Items can be marked as disabled
- **Keyboard Shortcuts**: Display shortcuts aligned to the right
- **Z-Order**: Menu renders above other content (z: 100)
