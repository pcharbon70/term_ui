# Gauge Widget Example

This example demonstrates the Gauge widget for displaying numeric values within a range using visual bars or arcs.

## Widget Overview

The Gauge widget provides visual representation of values with support for color zones and multiple display styles. It's ideal for:

- Progress indicators
- Resource usage displays (CPU, memory, disk)
- Percentage visualizations
- Status meters
- Loading indicators

**Key Features:**
- Bar style (horizontal filled bar)
- Arc style (semi-circular arc)
- Color zones for visual feedback
- Customizable characters for bar display
- Min/max range labels
- Value display
- Custom labeling

## Widget Options

The `Gauge.render/1` function accepts the following options:

- `:value` (required) - Current numeric value to display
- `:min` - Minimum value (default: 0)
- `:max` - Maximum value (default: 100)
- `:width` - Gauge width in characters (default: 40)
- `:type` - Display type, `:bar` or `:arc` (default: `:bar`)
- `:show_value` - Show numeric value below gauge (default: true)
- `:show_range` - Show min/max labels (default: true)
- `:zones` - List of `{threshold, style}` tuples for color zones
- `:label` - Label text displayed above gauge
- `:bar_char` - Character for filled portion (default: "█")
- `:empty_char` - Character for empty portion (default: "░")

**Helper Functions:**

- `Gauge.percentage(value, opts)` - Quick percentage gauge (0-100 range)
- `Gauge.traffic_light(opts)` - Gauge with green/yellow/red zones

**Color Zones:**

Zones define style changes at thresholds:
```elixir
zones: [
  {0, Style.new(fg: :green)},    # Green from 0-59
  {60, Style.new(fg: :yellow)},  # Yellow from 60-79
  {80, Style.new(fg: :red)}      # Red from 80-100
]
```

## Example Structure

```
gauge/
├── lib/
│   └── gauge/
│       └── app.ex          # Main application component
├── mix.exs                  # Project configuration
└── README.md               # This file
```

**app.ex** - Demonstrates various gauge configurations:
- Simple percentage gauge using helper
- Gauge with color zones (green/yellow/red)
- Gauge with custom characters
- Interactive value adjustment
- Style switching (bar/arc)

## Running the Example

```bash
# From the gauge directory
mix deps.get
mix run -e "Gauge.App.run()" --no-halt
```

## Controls

- **Up Arrow** - Increase value by 5
- **Down Arrow** - Decrease value by 5
- **Right Arrow** - Increase value by 10
- **Left Arrow** - Decrease value by 10
- **S** - Toggle between bar and arc display styles
- **Q** - Quit the application

The value is automatically clamped between 0 and 100.

## Display Styles

**Bar Style:**
```
Simple Percentage Gauge:
████████████████████░░░░░░░░░░
       50
```

**Arc Style:**
```
╭────────────────────────────╮
│          ▼                 │
╰────────────────────────────╯
           50
```

## Gauge Examples

**Simple Percentage:**
```elixir
Gauge.percentage(75, width: 30)
```

**With Color Zones:**
```elixir
Gauge.render(
  value: 75,
  min: 0,
  max: 100,
  width: 30,
  zones: [
    {0, Style.new(fg: :green)},
    {60, Style.new(fg: :yellow)},
    {80, Style.new(fg: :red)}
  ],
  label: "CPU Usage"
)
```

**Custom Characters:**
```elixir
Gauge.render(
  value: 75,
  min: 0,
  max: 100,
  width: 30,
  bar_char: "▓",
  empty_char: "░"
)
```

**Arc Style:**
```elixir
Gauge.render(
  value: 75,
  min: 0,
  max: 100,
  width: 30,
  type: :arc,
  show_value: true
)
```

## Use Cases

- **System Monitoring:** Display CPU, memory, or disk usage
- **Progress Tracking:** Show download/upload progress
- **Resource Limits:** Visualize quota usage
- **Performance Metrics:** Display response times or throughput
- **Health Indicators:** Show service health status
