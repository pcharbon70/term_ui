# Canvas Widget Example

This example demonstrates the TermUI Canvas widget, which provides a direct character buffer for custom drawing with primitives for lines, rectangles, text, and Braille graphics.

## Widget Overview

The Canvas widget offers a low-level drawing surface for creating custom visualizations, diagrams, charts, and graphics that don't fit standard widget patterns. It provides:

- **Direct buffer access** - Set individual characters at any position
- **Drawing primitives** - Lines (horizontal, vertical, diagonal), rectangles, text
- **Braille graphics** - Sub-character resolution (2x4 dots per character cell)
- **Flexible rendering** - Use callback functions or direct manipulation
- **Clear and fill operations** - Reset or fill entire canvas

Use Canvas when you need complete control over rendering, want to create custom visualizations, or need higher resolution than standard character-based rendering.

## Widget Options

The `Canvas.new/1` function accepts the following options:

- `:width` - Canvas width in characters (default: 40)
- `:height` - Canvas height in characters (default: 20)
- `:default_char` - Character to fill canvas initially (default: `" "`)
- `:on_draw` - Callback function `fn(state) -> state` to draw on canvas

The `Canvas.draw/3` utility function creates a canvas inline:

```elixir
Canvas.draw(width, height, fn state ->
  # Draw operations here
end)
```

## Drawing Functions

**Character buffer operations:**
- `clear/1` - Clear canvas with default character
- `fill/2` - Fill canvas with specific character
- `set_char/4` - Set character at (x, y) position
- `get_char/3` - Get character at (x, y) position
- `draw_text/4` - Draw text string at position

**Line primitives:**
- `draw_hline/5` - Horizontal line at (x, y) with length
- `draw_vline/5` - Vertical line at (x, y) with length
- `draw_line/6` - Arbitrary line between two points (Bresenham's algorithm)

**Rectangle primitives:**
- `draw_rect/6` - Rectangle outline with customizable border characters
- `fill_rect/6` - Filled rectangle

**Braille graphics (sub-character resolution):**
- `set_dot/3` - Set dot at (x, y) in dot space (width*2, height*4)
- `clear_dot/3` - Clear dot at position
- `draw_braille_line/5` - Line with sub-character precision
- `dots_to_braille/1` - Convert dot coordinates to Braille character
- `braille_resolution/1` - Get canvas resolution in dots

## Example Structure

The example consists of:

- `lib/canvas/app.ex` - Main application with three demos:
  - **Shapes demo** - Basic lines, points, and text
  - **Boxes demo** - Rectangle drawing with different border styles
  - **Braille demo** - Sub-character resolution explanation and patterns

## Running the Example

```bash
cd examples/canvas
mix deps.get
iex -S mix
```

Then in the IEx shell:

```elixir
Canvas.App.run()
```

## Controls

- `1` - Show basic shapes demo
- `2` - Show box drawing demo
- `3` - Show Braille drawing demo
- `C` - Clear canvas
- `Q` - Quit application

## Implementation Notes

The example demonstrates:
- Creating and drawing on a canvas using the `Canvas.draw/3` function
- Drawing horizontal and vertical lines
- Drawing diagonal lines with Bresenham's algorithm
- Drawing rectangles with different border styles (single-line, double-line, rounded)
- Nested rectangles
- Text rendering at arbitrary positions
- Braille graphics for sub-character resolution (each character = 2x4 dots)
- Converting canvas state to string lines for rendering

### Braille Graphics

Braille characters provide 2x4 dot resolution per character cell:
- Canvas character resolution: width × height
- Canvas dot resolution: (width × 2) × (height × 4)

Each Braille dot position is numbered:
```
1 4
2 5
3 6
7 8
```

This enables smooth curves and higher-resolution graphics within the character grid.
