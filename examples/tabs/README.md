# Tabs Widget Example

This example demonstrates how to use the `TermUI.Widgets.Tabs` widget for organizing content into switchable panels.

## Features Demonstrated

- Tab bar with multiple tabs
- Content switching on tab selection
- Disabled tabs
- Focus and selection states
- Dynamic tab addition and removal
- Keyboard navigation

## Installation

```bash
cd examples/tabs
mix deps.get
```

## Running

```bash
mix run run.exs
```

## Controls

| Key | Action |
|-----|--------|
| ←/→ | Navigate between tabs |
| Enter/Space | Select focused tab |
| Home/End | Jump to first/last tab |
| A | Add a new tab |
| D | Remove current tab |
| Q | Quit |

## Code Overview

### Creating Tabs

```elixir
Tabs.new(
  tabs: [
    %{id: :home, label: "Home", content: home_content()},
    %{id: :settings, label: "Settings", content: settings_content()},
    %{id: :about, label: "About", disabled: true}
  ],
  selected: :home,  # Initially selected tab
  on_change: fn tab_id ->
    IO.puts("Selected: #{tab_id}")
  end
)
```

### Tab Options

```elixir
%{
  id: :home,              # Unique identifier (required)
  label: "Home",          # Display text (required)
  content: render_node,   # Content when selected
  disabled: false,        # Whether tab is disabled
  closeable: false        # Whether tab shows close button
}
```

### Styling Options

```elixir
Tabs.new(
  tabs: tabs,
  tab_style: Style.new(fg: :white),
  selected_style: Style.new(fg: :cyan, attrs: [:bold]),
  disabled_style: Style.new(fg: :bright_black)
)
```

### Tab API

```elixir
# Get selected tab
Tabs.get_selected(state)

# Select a tab programmatically
Tabs.select(state, :settings)

# Add a new tab
Tabs.add_tab(state, %{id: :new, label: "New Tab"})

# Remove a tab
Tabs.remove_tab(state, :old_tab)

# Get tab count
Tabs.tab_count(state)
```

## Visual States

Tabs have three visual states:

| State | Decoration | Description |
|-------|------------|-------------|
| Selected | `[Tab]` | Currently showing content |
| Focused | `(Tab)` | Keyboard focus but not selected |
| Normal | ` Tab ` | Neither selected nor focused |
| Disabled | ` Tab ` (dimmed) | Cannot be selected |

## Widget API

See `lib/term_ui/widgets/tabs.ex` for the full API documentation.
