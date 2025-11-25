# Sparkline Widget Example

This example demonstrates how to use the `TermUI.Widgets.Sparkline` widget for compact inline trend visualization.

## Features Demonstrated

- Basic sparkline rendering
- Fixed scale sparklines (explicit min/max)
- Labeled sparklines with range display
- Styled sparklines with colors
- Color-coded sparklines based on value thresholds

## Installation

```bash
cd examples/sparkline
mix deps.get
```

## Running

```bash
mix run run.exs
```

## Controls

| Key | Action |
|-----|--------|
| Space | Add a random data point |
| R | Reset data to initial values |
| C | Toggle color mode |
| Q | Quit |

## Code Overview

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
sparkline_str = Sparkline.to_string([1, 3, 5, 2, 8])
# Returns: "▁▃▅▂█"
```

## Bar Characters

Sparklines use 8 levels of vertical bar characters:

```
▁ (1/8), ▂ (2/8), ▃ (3/8), ▄ (4/8), ▅ (5/8), ▆ (6/8), ▇ (7/8), █ (8/8)
```

## Widget API

See `lib/term_ui/widgets/sparkline.ex` for the full API documentation.
