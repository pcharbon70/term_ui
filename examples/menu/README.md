# Menu Example

A demonstration of the Menu widget for displaying hierarchical menus with various item types.

## Widget Overview

The Menu widget displays a list of interactive items including actions, submenus, separators, and checkboxes. It supports keyboard navigation, shortcut display, and hierarchical organization.

### Key Features

- Multiple item types (actions, submenus, separators, checkboxes)
- Keyboard navigation with arrow keys
- Shortcut display (e.g., "Ctrl+N")
- Hierarchical submenus with expand/collapse
- Checkbox items with toggle state
- Disabled item support
- Customizable styling for normal, selected, and disabled states
- Mouse support with hover highlighting

### When to Use

Use Menu when you need to:
- Present a list of commands or actions
- Organize options hierarchically in submenus
- Display shortcuts alongside menu items
- Provide toggleable settings with checkboxes
- Create dropdown or context menus

## Widget Options

The Menu widget accepts the following options in its `new/1` function:

- `:items` - List of menu items (required)
- `:on_select` - Callback when item is selected `fn id -> ... end`
- `:on_toggle` - Callback when checkbox is toggled `fn id, checked -> ... end`
- `:width` - Menu width (default: auto-calculated)
- `:item_style` - Style for normal items
- `:selected_style` - Style for focused item
- `:disabled_style` - Style for disabled items

### Item Constructors

```elixir
# Action item
Menu.action(:new, "New File", shortcut: "Ctrl+N")

# Submenu with children
Menu.submenu(:recent, "Recent Files", [
  Menu.action(:file1, "document.txt"),
  Menu.action(:file2, "notes.md")
])

# Separator (visual divider)
Menu.separator()

# Checkbox item
Menu.checkbox(:autosave, "Auto Save", checked: true)
```

### Example Usage

```elixir
Menu.new(
  items: [
    Menu.action(:new, "New File", shortcut: "Ctrl+N"),
    Menu.action(:open, "Open...", shortcut: "Ctrl+O"),
    Menu.separator(),
    Menu.submenu(:export, "Export As", [
      Menu.action(:pdf, "PDF"),
      Menu.action(:html, "HTML")
    ]),
    Menu.checkbox(:autosave, "Auto Save", checked: true)
  ],
  selected_style: Style.new(fg: :black, bg: :cyan),
  on_select: fn id -> handle_action(id) end
)
```

## Example Structure

This example contains:

- `lib/menu/app.ex` - Main application demonstrating the Menu widget
  - File menu example with New, Open, Save actions
  - Recent Files submenu
  - Export As submenu
  - Settings checkboxes (Auto Save, Dark Mode, Notifications)
  - Displays last action and checkbox states

## Running the Example

From the `examples/menu` directory:

```bash
mix deps.get
mix run -e "Menu.App.run()"
```

Or using the Mix task:

```bash
mix menu
```

## Controls

### Navigation
- **Up/Down** - Navigate between items (skips separators)
- **Right** - Expand submenu
- **Left** - Collapse submenu

### Selection
- **Enter/Space** - Select item or toggle checkbox
- **Q** - Quit the application

### Mouse
- **Click** - Select item at position
- **Hover** - Highlights item under cursor

## Features Demonstrated

1. **Action Items** - New File, Open, Save with shortcuts
2. **Submenus** - Recent Files and Export As with nested items
3. **Separators** - Visual dividers between sections
4. **Checkboxes** - Auto Save, Dark Mode, Notifications with toggle state
5. **Shortcut Display** - Shows keyboard shortcuts aligned right
6. **State Tracking** - Displays last action and checkbox states
7. **Hierarchical Navigation** - Expand/collapse submenus

## Item Types

### Action
Selectable menu item that triggers an action. Displays label and optional shortcut.

### Submenu
Item that contains child items. Shows expand/collapse arrow (▶/▼) based on state.

### Separator
Visual divider (horizontal line) that cannot be selected.

### Checkbox
Toggleable item showing checked state with [×] or [ ]. Can be toggled with Enter/Space.

## Implementation Notes

- The example tracks checkbox states in the widget state
- Last action is displayed when an action item is selected
- Submenus are collapsed by default
- Disabled items (if configured) cannot be selected
- Width auto-adjusts to longest item + shortcut
- Cursor wraps around at list ends
