# Viewport Widget Example

This example demonstrates how to use the `TermUI.Widgets.Viewport` widget for displaying scrollable content.

## Features Demonstrated

- Vertical scrolling through large content
- Scroll position tracking
- Visual scroll bar indicator
- Keyboard navigation (arrows, Page Up/Down, Home/End)

## Installation

```bash
cd examples/viewport
mix deps.get
```

## Running

```bash
mix run run.exs
```

## Controls

| Key | Action |
|-----|--------|
| ↑/↓ | Scroll one line |
| Page Up/Down | Scroll by 5 lines |
| Home/End | Jump to top/bottom |
| Q | Quit |

## Code Overview

### Creating a Viewport

```elixir
Viewport.new(
  content: large_content_tree(),
  width: 40,
  height: 20,
  content_width: 100,   # Total content width
  content_height: 200,  # Total content height
  scroll_bars: :both    # :none, :vertical, :horizontal, :both
)
```

### Viewport Options

```elixir
Viewport.new(
  content: render_node,     # Content to display
  content_width: 100,       # Total content width
  content_height: 200,      # Total content height
  width: 40,                # Viewport width
  height: 20,               # Viewport height
  scroll_x: 0,              # Initial horizontal scroll
  scroll_y: 0,              # Initial vertical scroll
  scroll_bars: :both,       # Scroll bar display
  scroll_step: 1,           # Lines per scroll step
  page_step: 20,            # Lines per page scroll
  on_scroll: fn x, y -> ... end  # Scroll callback
)
```

### Scroll Bar Options

| Value | Description |
|-------|-------------|
| `:none` | No scroll bars |
| `:vertical` | Vertical scroll bar only |
| `:horizontal` | Horizontal scroll bar only |
| `:both` | Both scroll bars |

### Viewport API

```elixir
# Get scroll position
{x, y} = Viewport.get_scroll(state)

# Set scroll position
state = Viewport.set_scroll(state, 0, 50)

# Scroll to make position visible
state = Viewport.scroll_into_view(state, 100, 150)

# Update content
state = Viewport.set_content(state, new_content)

# Update content dimensions
state = Viewport.set_content_size(state, 200, 500)

# Check if scrollable
Viewport.can_scroll_vertical?(state)
Viewport.can_scroll_horizontal?(state)

# Get visible fraction (for scroll bar thumb size)
Viewport.visible_fraction_vertical(state)   # 0.0 - 1.0
Viewport.visible_fraction_horizontal(state) # 0.0 - 1.0
```

### Keyboard Navigation

The Viewport widget handles these keys automatically:

| Key | Action |
|-----|--------|
| ↑/↓ | Scroll by scroll_step |
| ←/→ | Horizontal scroll |
| Page Up/Down | Scroll by page_step |
| Home | Scroll to top |
| End | Scroll to bottom |
| Ctrl+Home | Scroll to top-left |
| Ctrl+End | Scroll to bottom-right |

### Mouse Support

- Mouse wheel: Scroll vertically
- Click scroll bar track: Page scroll
- Drag scroll bar thumb: Direct scroll

## Widget API

See `lib/term_ui/widgets/viewport.ex` for the full API documentation.
