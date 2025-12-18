# Widget Compatibility Guide

This document describes widget behavior across different terminal backends (Raw Mode and TTY Mode) and provides best practices for building compatible widgets.

## Overview

TermUI supports two terminal backends:

- **Raw Mode**: Full terminal control with mouse support, 60 FPS rendering, and immediate key handling. Requires OTP 28+ with native raw mode support.
- **TTY Mode**: Compatible mode using standard I/O operations. Works on all systems but with limited features.

Most widgets work identically in both modes because keyboard navigation (arrows, Tab, Enter) uses `IO.getn/2` which provides character-by-character input regardless of terminal mode.

## Widget Compatibility Matrix

| Widget | Raw Mode | TTY Mode | Notes |
|--------|----------|----------|-------|
| **Navigation & Selection** |
| Menu | Full | Full | Keyboard navigation works identically |
| Tabs | Full | Full | Tab switching via keyboard |
| Table | Full | Full | Arrow keys for navigation, sorting |
| TreeView | Full | Full | Expand/collapse via arrow keys |
| CommandPalette | Full | Full | Fuzzy search and selection |
| **Input** |
| TextInput | Full | Full | Character-by-character input |
| TextInput.Line | Full | Full | Shell line editing via `IO.gets/1` |
| FormBuilder | Full | Full | Tab navigation between fields |
| **Feedback** |
| Dialog | Full | Full | Modal with button navigation |
| AlertDialog | Full | Full | Type-based icons and styling |
| Toast | Full | Full | Auto-dismissing notifications |
| **Layout** |
| SplitPane | Full | Keyboard | Mouse drag unavailable; use Ctrl+arrows |
| Viewport | Full | Full | Keyboard scrolling |
| ScrollBar | Full | Keyboard | Click unavailable; use arrow keys |
| **Data Visualization** |
| Gauge | Full | Full | Progress bars |
| BarChart | Full | Full | Vertical bar charts |
| LineChart | Full | Full | Line graphs |
| Sparkline | Full | Full | Inline mini charts |
| Canvas | Full | Full | Pixel/character drawing |
| **Context Menus** |
| ContextMenu | Full | Position N/A | Use ContextMenu.Inline for TTY |
| ContextMenu.Inline | Full | Full | Numbered selection, no positioning |
| **Monitoring** |
| ProcessMonitor | Full | Full | Process list display |
| SupervisionTreeViewer | Full | Full | Tree visualization |
| ClusterDashboard | Full | Full | Cluster status |
| LogViewer | Full | Full | Log streaming |

### Legend

- **Full**: All features work as expected
- **Keyboard**: Mouse features unavailable; keyboard alternatives provided
- **Position N/A**: Requires mouse positioning; use inline variant instead

## Widget Variants

Some widgets have variants optimized for different backends:

### TextInput vs TextInput.Line

| Feature | TextInput | TextInput.Line |
|---------|-----------|----------------|
| Input Method | Character-by-character | Line-based (`IO.gets/1`) |
| Shell Editing | No | Yes (history, readline) |
| Real-time Validation | Yes | On submit only |
| Cursor Control | Full | Shell-controlled |
| Best For | Real-time input, search | Free-form text entry |

**Usage:**
```elixir
# Real-time input (e.g., search)
TextInput.new(placeholder: "Search...")

# Line-based input with shell editing
alias TermUI.Widgets.TextInput.Line
Line.new(prompt: "> ", label: "Enter command")
```

### ContextMenu vs ContextMenu.Inline

| Feature | ContextMenu | ContextMenu.Inline |
|---------|-------------|-------------------|
| Positioning | Mouse cursor | Below current focus |
| Selection | Click or arrows | Numbers or arrows |
| Best For | Right-click menus | Keyboard-only environments |

**Usage:**
```elixir
alias TermUI.Widgets.ContextMenu
alias TermUI.Widgets.ContextMenu.Inline, as: InlineMenu

# Create menu items (same for both variants)
items = [
  ContextMenu.action(:copy, "Copy"),
  ContextMenu.action(:paste, "Paste"),
  ContextMenu.separator(),
  ContextMenu.action(:delete, "Delete")
]

# Positioned context menu (requires mouse)
ContextMenu.new(items: items, position: {x, y})

# Inline menu with number keys
InlineMenu.new(items: items)
# Renders: [1] Copy  [2] Paste  [3] Delete
```

## Features with Keyboard Alternatives

### SplitPane Resize

Mouse dragging is unavailable in TTY mode. Use keyboard shortcuts:

| Action | Shortcut |
|--------|----------|
| Decrease left/top pane | Ctrl+Left / Ctrl+Up |
| Increase left/top pane | Ctrl+Right / Ctrl+Down |

```elixir
alias TermUI.Widgets.SplitPane

# SplitPane uses :panes list for pane definitions
SplitPane.new(
  orientation: :horizontal,
  panes: [
    %{id: :left, content: left_panel, size: 0.5},
    %{id: :right, content: right_panel, size: 0.5}
  ],
  ctrl_resize_step: 0.05,  # 5% per keystroke
  min_ratio: 0.1,          # Minimum 10%
  max_ratio: 0.9           # Maximum 90%
)
```

### ScrollBar Interaction

Click-to-scroll is unavailable in TTY mode. Scrolling via:
- Arrow keys (line by line)
- Page Up/Page Down (page by page)
- Home/End (jump to start/end)

---

## Best Practices for Widget Development

### 1. Always Use Theme for Colors

Never hardcode color values. Use the Theme system for automatic degradation:

```elixir
# Bad - hardcoded colors
style = Style.new() |> Style.fg({255, 0, 0})

# Good - theme-based colors
style = Style.new() |> Style.fg(Theme.get_semantic(:error))

# Good - component styles with monochrome fallback
style = Theme.get_component_style(:list, :selected)
```

The Theme system automatically:
- Converts RGB to 256-color when needed
- Converts to 16-color palette when needed
- Provides monochrome fallbacks (reverse, bold, underline)

### 2. Always Use CharacterSet for Special Characters

Never hardcode Unicode characters. Use CharacterSet for automatic ASCII fallback:

```elixir
# Bad - hardcoded Unicode
border = "┌" <> String.duplicate("─", width) <> "┐"

# Good - CharacterSet-based
chars = CharacterSet.current_charset()
border = chars.tl <> String.duplicate(chars.h_line, width) <> chars.tr
```

Available character categories:
- **Box drawing**: `tl`, `tr`, `bl`, `br`, `h_line`, `v_line`, `cross`, etc.
- **Arrows**: `arrow_up`, `arrow_down`, `arrow_left`, `arrow_right`
- **Indicators**: `check`, `cross_mark`, `bullet`, `pointer`
- **Progress**: `bar_full`, `bar_empty`, `bar_levels`, `sparkline_levels`
- **Icons**: `info`, `warning`, `loading`

### 3. Provide Keyboard Alternatives for Mouse Features

Every mouse interaction should have a keyboard equivalent:

```elixir
# Handle both mouse and keyboard for selection
def handle_event(%Event.Mouse{action: :click, y: y}, state) do
  select_item_at(state, y)
end

def handle_event(%Event.Key{key: :enter}, state) do
  select_current_item(state)
end

def handle_event(%Event.Key{key: :down}, state) do
  move_cursor(state, 1)
end
```

Common keyboard patterns:
| Mouse Action | Keyboard Alternative |
|--------------|---------------------|
| Click to select | Enter/Space |
| Drag to resize | Ctrl+Arrow keys |
| Scroll wheel | Arrow keys, Page Up/Down |
| Right-click menu | Context key, Shift+F10 |
| Hover tooltip | Focus + delay |

### 4. Test with Both Backends

Always test widgets in both Raw and TTY modes:

```elixir
# In tests, configure backend explicitly
defmodule MyWidgetTest do
  use ExUnit.Case

  describe "keyboard navigation" do
    test "works in raw mode" do
      Application.put_env(:term_ui, :backend, :raw)
      # Test keyboard navigation
    end

    test "works in tty mode" do
      Application.put_env(:term_ui, :backend, :tty)
      # Same navigation should work identically
    end
  end
end
```

### 5. Use Appropriate Widget State Patterns

Widgets should use the StatefulComponent pattern:

```elixir
defmodule MyWidget do
  use TermUI.StatefulComponent

  @impl true
  def init(props) do
    state = %{
      # Initialize state from props
    }
    {:ok, state}
  end

  @impl true
  def handle_event(event, state) do
    # Handle keyboard and mouse events
    {:ok, new_state}
  end

  @impl true
  def render(state, area) do
    # Return render nodes
    stack(:vertical, [...])
  end
end
```

### 6. Support Capability Degradation

Check capabilities at runtime when needed:

```elixir
defp render_with_fallback(state) do
  chars = CharacterSet.current_charset()

  # CharacterSet automatically provides ASCII fallback
  # based on :term_ui, :character_set config

  border = chars.tl <> String.duplicate(chars.h_line, width) <> chars.tr
  # In Unicode mode: ┌────────┐
  # In ASCII mode:   +--------+
end
```

---

## Color Mode Reference

The Theme system supports multiple color modes:

| Mode | Colors | Use Case |
|------|--------|----------|
| `true_color` | 16M (RGB) | Modern terminals |
| `color_256` | 256 | Most terminals |
| `color_16` | 16 | Basic terminals |
| `monochrome` | 2 | No color support |

Monochrome fallbacks:
- **Selected items**: Reverse video
- **Focused items**: Bold
- **Error states**: Underline
- **Disabled items**: Dim

---

## Character Set Reference

Two character sets are available:

| Character | Unicode | ASCII |
|-----------|---------|-------|
| Corners | `┌┐└┘` | `+` |
| Lines | `─│` | `-\|` |
| Arrows | `↑↓←→` | `^v<>` |
| Triangles | `▲▼◀▶` | `^v<>` |
| Progress | `█░` | `#.` |
| Check | `✓` | `x` |
| Cross | `✗` | `X` |
| Bullet | `●○` | `*o` |

Configure at runtime:
```elixir
# In config/config.exs
config :term_ui, :character_set, :unicode  # or :ascii

# Or at runtime
Application.put_env(:term_ui, :character_set, :ascii)
```

---

## Quick Reference

### Creating a Compatible Widget

1. Use `TermUI.StatefulComponent`
2. Handle keyboard events for all interactions
3. Use `Theme.get_*` for colors
4. Use `CharacterSet.current_charset()` for special characters
5. Test in both Raw and TTY modes

### Checking Current Mode

```elixir
# Get current backend
backend = Application.get_env(:term_ui, :backend, :raw)

# Get current character set
charset = CharacterSet.current()  # :unicode or :ascii

# Get current color capabilities
color_mode = Theme.get_color_mode()  # :true_color, :color_256, etc.
```
