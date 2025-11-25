# Gauge Widget Example

This example demonstrates how to use the `TermUI.Widgets.Gauge` widget for displaying values within a range.

## Features Demonstrated

- Simple percentage gauge
- Color zones (green/yellow/red based on value)
- Bar and arc display styles
- Custom bar characters
- Value and range labels

## Installation

```bash
cd examples/gauge
mix deps.get
```

## Running

```bash
mix run run.exs
```

## Controls

| Key | Action |
|-----|--------|
| ↑/↓ | Adjust value by 5 |
| ←/→ | Adjust value by 10 |
| S | Toggle bar/arc style |
| Q | Quit |

## Code Overview

### Basic Gauge

```elixir
# Simple percentage gauge (0-100)
Gauge.percentage(75, width: 30)
```

### Gauge with Options

```elixir
Gauge.render(
  value: 75,           # Current value (required)
  min: 0,              # Minimum value (default: 0)
  max: 100,            # Maximum value (default: 100)
  width: 30,           # Gauge width in characters
  style_type: :bar,    # :bar or :arc display
  show_value: true,    # Show numeric value
  show_range: true,    # Show min/max labels
  label: "CPU Usage"   # Optional label
)
```

### Color Zones

```elixir
Gauge.render(
  value: 85,
  zones: [
    {0, Style.new(fg: :green)},    # Green when value >= 0
    {60, Style.new(fg: :yellow)},  # Yellow when value >= 60
    {80, Style.new(fg: :red)}      # Red when value >= 80
  ]
)
```

### Custom Characters

```elixir
Gauge.render(
  value: 50,
  bar_char: "▓",       # Character for filled portion
  empty_char: "░"      # Character for empty portion
)
```

## Widget API

See `lib/term_ui/widgets/gauge.ex` for the full API documentation.
