# Bar Chart Widget Example

This example demonstrates how to use the `TermUI.Widgets.BarChart` widget for displaying comparative values as bars.

## Features Demonstrated

- Horizontal bar charts
- Vertical bar charts
- Colored bars
- Value and label display toggles
- Simple single bar helper

## Installation

```bash
cd examples/bar_chart
mix deps.get
```

## Running

```bash
mix run run.exs
```

## Controls

| Key | Action |
|-----|--------|
| D | Toggle direction (horizontal/vertical) |
| V | Toggle value display |
| L | Toggle label display |
| R | Randomize data |
| Q | Quit |

## Code Overview

### Basic Horizontal Bar Chart

```elixir
BarChart.render(
  data: [
    %{label: "Sales", value: 150},
    %{label: "Marketing", value: 85},
    %{label: "Engineering", value: 200}
  ],
  direction: :horizontal,
  width: 50,
  show_values: true,
  show_labels: true
)
```

### Vertical Bar Chart

```elixir
BarChart.render(
  data: data,
  direction: :vertical,
  width: 30,
  height: 10,
  show_values: true,
  show_labels: true
)
```

### Colored Bars

```elixir
# Colors cycle through the list for each bar
BarChart.render(
  data: data,
  colors: [
    Style.new(fg: :red),
    Style.new(fg: :green),
    Style.new(fg: :blue)
  ]
)
```

### Simple Single Bar

```elixir
# Quick helper for showing a single value as a bar
BarChart.bar(
  value: 75,
  max: 100,
  width: 30,
  bar_char: "█",
  empty_char: "░"
)
```

### All Options

```elixir
BarChart.render(
  data: data,               # Required: list of %{label: string, value: number}
  direction: :horizontal,   # :horizontal or :vertical
  width: 40,                # Chart width in characters
  height: 10,               # Chart height (for vertical)
  show_values: true,        # Display numeric values
  show_labels: true,        # Display bar labels
  bar_char: "█",            # Character for bars
  colors: [],               # List of styles for bars
  style: nil                # Overall chart style
)
```

## Data Format

The `data` option expects a list of maps with `label` and `value` keys:

```elixir
[
  %{label: "Item 1", value: 100},
  %{label: "Item 2", value: 75},
  %{label: "Item 3", value: 150}
]
```

## Widget API

See `lib/term_ui/widgets/bar_chart.ex` for the full API documentation.
