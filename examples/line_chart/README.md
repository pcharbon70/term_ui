# Line Chart Widget Example

This example demonstrates how to use the `TermUI.Widgets.LineChart` widget for time series visualization using Braille patterns.

## Features Demonstrated

- Single series line charts
- Multiple series comparison
- Custom min/max scaling
- Axis display toggle
- Dynamic data updates
- Braille character rendering

## Installation

```bash
cd examples/line_chart
mix deps.get
```

## Running

```bash
mix run run.exs
```

## Controls

| Key | Action |
|-----|--------|
| Space | Add new data point |
| R | Reset/randomize data |
| A | Toggle axis display |
| Q | Quit |

## Code Overview

### Single Series Chart

```elixir
LineChart.render(
  data: [10, 25, 15, 30, 20, 35, 25],
  width: 40,
  height: 10
)
```

### Multi-Series Chart

```elixir
LineChart.render(
  series: [
    %{data: cpu_data, color: Style.new(fg: :cyan)},
    %{data: memory_data, color: Style.new(fg: :magenta)}
  ],
  width: 40,
  height: 10
)
```

### With Fixed Scale

```elixir
LineChart.render(
  data: values,
  width: 40,
  height: 10,
  min: 0,
  max: 100,
  show_axis: true
)
```

### All Options

```elixir
LineChart.render(
  data: values,           # Single series data
  series: [...],          # Or multiple series
  width: 40,              # Chart width in characters
  height: 10,             # Chart height in characters
  min: 0,                 # Minimum Y value (auto if not set)
  max: 100,               # Maximum Y value (auto if not set)
  show_axis: true,        # Show axis lines
  style: Style.new(...)   # Overall chart style
)
```

## How Braille Rendering Works

The line chart uses Unicode Braille characters (U+2800-U+28FF) which provide sub-character resolution:

```
Each Braille cell is a 2x4 dot grid:
1 4
2 5
3 6
7 8

This gives 2x4 = 8 dots per character cell.
For a 40x10 character chart, that's 80x40 dot resolution!
```

### Braille Helpers

```elixir
# Empty Braille character
LineChart.empty_braille()  # "⠀"

# Full Braille character (all dots)
LineChart.full_braille()   # "⣿"

# Specific dots
LineChart.dots_to_braille([{0, 0}, {1, 1}])  # Top-left and middle-right dots
```

## Widget API

See `lib/term_ui/widgets/line_chart.ex` for the full API documentation.
