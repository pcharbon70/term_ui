# Sparkline Widget Example

A demonstration of the TermUI Sparkline widget for compact inline trend visualization using vertical bar characters.

## Widget Overview

The Sparkline widget displays numeric data as compact inline charts using Unicode vertical bar characters (▁▂▃▄▅▆▇█). It's perfect for showing trends in minimal space, such as CPU usage, memory consumption, or any time-series data that needs quick visual representation without taking up much screen real estate.

**Key Features:**
- Compact visualization using 8 levels of vertical bars
- Auto-scaling or fixed min/max ranges
- Labeled sparklines with min/max values
- Color-coded sparklines based on value thresholds
- Simple integration into any text-based layout

**When to Use:**
- Dashboard displays with multiple metrics
- Inline trend indicators in tables or lists
- Resource monitoring (CPU, memory, disk I/O)
- Real-time data visualization in minimal space

## Widget Options

The `Sparkline.render/1` function accepts these options:

- `:values` - List of numeric values (required)
- `:min` - Minimum value for scaling (default: auto-calculated from data)
- `:max` - Maximum value for scaling (default: auto-calculated from data)
- `:style` - Style for the entire sparkline
- `:color_ranges` - List of `{threshold, style}` tuples for value-based coloring

The `Sparkline.render_labeled/1` function includes:

- `:values` - List of numeric values (required)
- `:label` - Label text to display before the sparkline
- `:show_range` - Show min/max values (default: true)

## Example Structure

This example consists of:

- `lib/sparkline/app.ex` - Main application demonstrating:
  - Basic sparkline rendering
  - Sparkline with fixed scale (0-100)
  - Labeled sparkline with min/max values
  - Styled sparkline with custom colors
  - Color-coded sparkline based on value thresholds
- `mix.exs` - Mix project configuration
- `run.exs` - Helper script to run the example

## Running the Example

From this directory:

```bash
# Install dependencies
mix deps.get

# Run with the helper script
elixir run.exs

# Or run directly with mix
mix run -e "Sparkline.App.run()" --no-halt
```

## Controls

| Key | Action |
|-----|--------|
| Space | Add a random data point |
| R | Reset data to initial values |
| C | Toggle color mode |
| Q | Quit |

## Code Examples

### Basic Sparkline

```elixir
# Just pass a list of values
Sparkline.render(values: [1, 3, 5, 2, 8, 4, 6])
```

### Fixed Scale

```elixir
# Set explicit min/max for consistent scaling
Sparkline.render(
  values: [35, 42, 55, 48, 62],
  min: 0,
  max: 100
)
```

### Labeled Sparkline

```elixir
# Show label and min/max values
Sparkline.render_labeled(
  values: data,
  label: "CPU",
  show_range: true
)
# Output: CPU 35 ▃▄▆▅▇ 62
```

### Styled Sparkline

```elixir
# Apply a single color to the entire sparkline
Sparkline.render(
  values: data,
  style: Style.new(fg: :green)
)
```

### Color-Coded by Value

```elixir
# Different colors based on value thresholds
Sparkline.render(
  values: data,
  color_ranges: [
    {0, Style.new(fg: :green)},   # Green when value >= 0
    {50, Style.new(fg: :yellow)}, # Yellow when value >= 50
    {75, Style.new(fg: :red)}     # Red when value >= 75
  ]
)
```

### Get Sparkline as String

```elixir
# For embedding in other text
sparkline_str = Sparkline.to_sparkline([1, 3, 5, 2, 8])
# Returns: "▁▃▅▂█"
```

## Bar Characters

Sparklines use 8 levels of vertical bar characters:

```
▁ (1/8), ▂ (2/8), ▃ (3/8), ▄ (4/8), ▅ (5/8), ▆ (6/8), ▇ (7/8), █ (8/8)
```

## Color Ranges

When color mode is enabled in the example, values are colored based on thresholds:
- Green: 0-49 (low values)
- Yellow: 50-74 (medium values)
- Red: 75+ (high values)

This demonstrates how sparklines can use color to convey additional information about value ranges.

## Widget API

See `lib/term_ui/widgets/sparkline.ex` for the full API documentation.
