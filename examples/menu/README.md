# Menu Widget Example

This example demonstrates how to use the `TermUI.Widgets.Menu` widget for displaying hierarchical menus with various item types.

## Features Demonstrated

- Action items (selectable menu items)
- Submenus (expandable/collapsible nested menus)
- Separators (visual dividers)
- Checkboxes (toggleable items)
- Keyboard shortcuts display
- Focus navigation

## Installation

```bash
cd examples/menu
mix deps.get
```

## Running

```bash
mix run run.exs
```

## Controls

| Key | Action |
|-----|--------|
| ↑/↓ | Navigate between items |
| → | Expand submenu |
| ← | Collapse submenu |
| Enter/Space | Select item or toggle checkbox |
| Q | Quit |

## Code Overview

### Item Constructors

```elixir
# Action item with shortcut
Menu.action(:save, "Save", shortcut: "Ctrl+S")

# Disabled action
Menu.action(:paste, "Paste", disabled: true)

# Submenu with children
Menu.submenu(:recent, "Recent Files", [
  Menu.action(:file1, "document.txt"),
  Menu.action(:file2, "notes.md")
])

# Separator line
Menu.separator()

# Checkbox item
Menu.checkbox(:autosave, "Auto Save", checked: true)
```

### Creating a Menu

```elixir
Menu.new(
  items: [
    Menu.action(:new, "New File", shortcut: "Ctrl+N"),
    Menu.action(:open, "Open...", shortcut: "Ctrl+O"),
    Menu.separator(),
    Menu.submenu(:recent, "Recent Files", [
      Menu.action(:file1, "document.txt"),
      Menu.action(:file2, "notes.md")
    ]),
    Menu.separator(),
    Menu.checkbox(:autosave, "Auto Save", checked: true),
    Menu.action(:exit, "Exit", shortcut: "Ctrl+Q")
  ],
  on_select: fn item_id ->
    # Called when action is selected
    handle_action(item_id)
  end,
  on_toggle: fn item_id, checked ->
    # Called when checkbox is toggled
    handle_toggle(item_id, checked)
  end
)
```

### Styling Options

```elixir
Menu.new(
  items: items,
  item_style: Style.new(fg: :white),
  selected_style: Style.new(fg: :black, bg: :cyan),
  disabled_style: Style.new(fg: :bright_black)
)
```

### Menu API

```elixir
# Get current cursor position
Menu.get_cursor(state)

# Expand/collapse submenu
Menu.expand(state, :recent)
Menu.collapse(state, :recent)

# Check if submenu is expanded
Menu.expanded?(state, :recent)

# Get checkbox state
Menu.checked?(state, :autosave)
```

## Item Types

| Type | Description |
|------|-------------|
| `:action` | Selectable item that triggers `on_select` |
| `:submenu` | Item that expands to show children |
| `:separator` | Visual divider line |
| `:checkbox` | Toggleable item with check state |

## Widget API

See `lib/term_ui/widgets/menu.ex` for the full API documentation.
