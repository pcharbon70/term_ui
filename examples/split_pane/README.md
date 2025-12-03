# SplitPane Widget Example

A demonstration of the TermUI SplitPane widget for creating resizable multi-pane layouts similar to IDE editors.

## Widget Overview

The SplitPane widget divides screen space between multiple panes with resizable dividers, enabling complex layouts like code editors with sidebars and bottom panels. Panes can be arranged horizontally (side-by-side) or vertically (stacked), and can be nested for sophisticated multi-section layouts.

**Key Features:**
- Horizontal and vertical split orientations
- Keyboard and mouse-controlled divider resizing
- Min/max size constraints per pane
- Collapsible panes for maximizing workspace
- Nested splits for complex layouts (like IDEs)
- Layout state persistence

**When to Use:**
- Multi-panel applications (editors, file browsers, terminals)
- IDE-style layouts with sidebars and panels
- Split-screen comparisons
- Any application requiring flexible, user-adjustable layouts

## Widget Options

The `SplitPane.new/1` function accepts these options:

- `:orientation` - `:horizontal` (side by side) or `:vertical` (stacked) (default: `:horizontal`)
- `:panes` - List of pane specifications created with `SplitPane.pane/3` (required)
- `:divider_size` - Divider thickness in characters (default: 1)
- `:divider_style` - Style for unfocused dividers
- `:focused_divider_style` - Style for the focused divider
- `:resizable` - Whether dividers can be dragged (default: true)
- `:on_resize` - Callback function when panes are resized: `fn panes -> ... end`
- `:on_collapse` - Callback when pane is collapsed/expanded: `fn {id, collapsed} -> ... end`
- `:persist_key` - Key for layout persistence (optional)

**Pane Specification** using `SplitPane.pane(id, content, opts)`:

- `id` - Unique identifier for the pane
- `content` - Render tree or nested SplitPane state
- `:size` - Size as float (0.0-1.0 proportion) or integer (fixed chars/lines) (default: 1.0)
- `:min_size` - Minimum size in characters/lines
- `:max_size` - Maximum size in characters/lines
- `:collapsed` - Whether pane starts collapsed (default: false)

## Example Structure

This example consists of:

- `lib/split_pane/app.ex` - Main application demonstrating:
  - Horizontal layout (3 panes side-by-side)
  - Vertical layout (3 panes stacked)
  - Nested layout (IDE-style with sidebar and editor/terminal split)
  - Keyboard-controlled divider resizing
  - Min/max size constraints
  - Layout save/restore functionality
- `mix.exs` - Mix project configuration
- `run.exs` - Helper script to run the example

## Running the Example

From this directory:

```bash
# Run with the helper script
elixir run.exs

# Or run directly with mix
mix run -e "SplitPane.App.run()" --no-halt
```

## Controls

### Navigation
- **Tab** - Focus next divider
- **Shift+Tab** - Focus previous divider

### Resizing
- **Left/Up** - Move focused divider left/up (1 unit)
- **Right/Down** - Move focused divider right/down (1 unit)
- **Shift+Arrow** - Move divider by larger step (5 units)
- **Home** - Move divider to minimum position
- **End** - Move divider to maximum position

### Pane Operations
- **Enter** - Toggle collapse/expand pane after divider

### Layout Management
- **H** - Switch to horizontal layout mode
- **V** - Switch to vertical layout mode
- **N** - Switch to nested IDE-style layout
- **S** - Save current layout (pane sizes and states)
- **R** - Restore previously saved layout

### Application
- **Q** - Quit

## Layout Modes

The example demonstrates three layout modes:

1. **Horizontal** - Three panes arranged side-by-side with adjustable dividers
2. **Vertical** - Three panes stacked vertically with adjustable dividers
3. **Nested (IDE)** - Two-level split with a sidebar and a main area that's further divided into editor and terminal sections
