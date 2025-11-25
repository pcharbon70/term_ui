# Canvas Widget Example

This example demonstrates how to use the `TermUI.Widgets.Canvas` widget for custom drawing with direct buffer access.

## Features Demonstrated

- Basic canvas creation and clearing
- Drawing text at specific positions
- Drawing lines (horizontal, vertical, diagonal)
- Drawing rectangles with different border styles
- Braille characters for sub-character resolution

## Installation

```bash
cd examples/canvas
mix deps.get
```

## Running

```bash
mix run run.exs
```

## Controls

| Key | Action |
|-----|--------|
| 1 | Basic shapes demo |
| 2 | Box drawing demo |
| 3 | Braille drawing demo |
| C | Clear canvas |
| Q | Quit |

## Code Overview

### Creating a Canvas

```elixir
Canvas.new(
  width: 40,
  height: 20,
  default_char: " ",
  on_draw: fn canvas ->
    canvas
    |> Canvas.draw_text(2, 2, "Hello!")
    |> Canvas.draw_rect(0, 0, 10, 5)
  end
)
```

### Drawing Primitives

```elixir
# Set a single character
Canvas.set_char(canvas, x, y, "●")

# Get a character
char = Canvas.get_char(canvas, x, y)

# Draw text
Canvas.draw_text(canvas, x, y, "Hello World")

# Draw horizontal line
Canvas.draw_hline(canvas, x, y, length, "─")

# Draw vertical line
Canvas.draw_vline(canvas, x, y, length, "│")

# Draw arbitrary line (Bresenham's algorithm)
Canvas.draw_line(canvas, x1, y1, x2, y2, "•")
```

### Drawing Rectangles

```elixir
# Simple box
Canvas.draw_rect(canvas, x, y, width, height)

# Box with custom border characters
Canvas.draw_rect(canvas, x, y, width, height, %{
  h: "═",     # Horizontal
  v: "║",     # Vertical
  tl: "╔",    # Top-left corner
  tr: "╗",    # Top-right corner
  bl: "╚",    # Bottom-left corner
  br: "╝"     # Bottom-right corner
})

# Rounded corners
Canvas.draw_rect(canvas, x, y, width, height, %{
  tl: "╭", tr: "╮", bl: "╰", br: "╯"
})

# Fill a rectangle
Canvas.fill_rect(canvas, x, y, width, height, "░")
```

### Canvas Operations

```elixir
# Clear entire canvas
Canvas.clear(canvas)

# Fill canvas with character
Canvas.fill(canvas, "·")

# Resize canvas
Canvas.resize(canvas, new_width, new_height)

# Convert to list of strings
lines = Canvas.to_strings(canvas)
```

### Braille Graphics

Each character cell provides 2x4 dot resolution using Unicode Braille:

```elixir
# Set a single dot
Canvas.set_dot(canvas, x, y)

# Clear a dot
Canvas.clear_dot(canvas, x, y)

# Draw a braille line
Canvas.draw_braille_line(canvas, x1, y1, x2, y2)

# Get braille resolution
{dot_width, dot_height} = Canvas.braille_resolution(canvas)
# For 40x20 canvas: {80, 80} dots

# Create braille characters from dot positions
Canvas.dots_to_braille([{0, 0}, {1, 1}])  # Diagonal dots

# Empty and full braille characters
Canvas.empty_braille()  # "⠀"
Canvas.full_braille()   # "⣿"
```

## Braille Dot Positions

Each Braille character has 8 dots arranged as:

```
1 4
2 5
3 6
7 8
```

In code, coordinates are `{column, row}` from 0:
- `{0, 0}` = dot 1 (top-left)
- `{1, 0}` = dot 4 (top-right)
- `{0, 3}` = dot 7 (bottom-left)
- `{1, 3}` = dot 8 (bottom-right)

## Widget API

See `lib/term_ui/widgets/canvas.ex` for the full API documentation.
