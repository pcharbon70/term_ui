# LineChart Example

A demonstration of the LineChart widget for time series visualization using Braille patterns.

## Widget Overview

The LineChart widget renders line graphs in the terminal using Unicode Braille characters (U+2800-U+28FF), which provide 2x4 dot resolution per character cell. This enables smooth line rendering with sub-character precision, perfect for visualizing metrics, sensor data, and time series.

### Key Features

- Single and multi-series line charts
- Braille patterns for smooth line rendering (2x4 dots per character)
- Custom min/max scaling
- Optional axis display
- Dynamic data updates
- Automatic scaling based on data range

### When to Use

Use LineChart when you need to visualize:
- Time series data (CPU/memory usage, metrics)
- Trends and patterns in numerical data
- Multiple data series for comparison
- Real-time data streams

## Widget Options

The LineChart widget accepts the following options in its `render/1` function:

- `:data` - Single series data (list of numbers), alternative to `:series`
- `:series` - List of series maps with `:data` and optional `:color` keys
- `:width` - Chart width in characters (default: 40)
- `:height` - Chart height in characters (default: 10)
- `:min` - Minimum Y value (default: auto-calculated from data)
- `:max` - Maximum Y value (default: auto-calculated from data)
- `:show_axis` - Show axis lines (default: false)
- `:style` - Style for the chart

### Example Usage

```elixir
# Single series
LineChart.render(
  data: [1, 3, 5, 2, 8],
  width: 40,
  height: 8,
  min: 0,
  max: 100,
  show_axis: true
)

# Multiple series
LineChart.render(
  series: [
    %{data: [1, 3, 5, 2, 8], color: Style.new(fg: :cyan)},
    %{data: [2, 4, 3, 6, 4], color: Style.new(fg: :magenta)}
  ],
  width: 40,
  height: 8
)
```

## Example Structure

This example contains:

- `lib/line_chart/app.ex` - Main application demonstrating the LineChart widget
  - Simulates CPU and memory usage data
  - Demonstrates single and multi-series charts
  - Shows how to update data dynamically
  - Includes Braille pattern demonstration

## Running the Example

From the `examples/line_chart` directory:

```bash
mix deps.get
mix run -e "LineChart.App.run()"
```

Or using the Mix task:

```bash
mix line_chart
```

## Controls

- **Space** - Add new data point to both series (sliding window)
- **R** - Reset/randomize data with new values
- **A** - Toggle axis display on/off
- **Q** - Quit the application

## Features Demonstrated

1. **Single Series Chart** - Shows CPU usage over time with green line
2. **Multi-Series Chart** - Displays CPU (cyan) and memory (magenta) together
3. **Braille Pattern Demo** - Shows various Braille characters used for rendering
4. **Dynamic Updates** - Data can be added in real-time with sliding window
5. **Axis Control** - Toggle axis display to see coordinate frame

## Implementation Notes

- Data is generated using a random walk algorithm to simulate realistic metrics
- Each series maintains a maximum of 25 points (sliding window)
- Values are bounded between 10 and 90 to keep them visible
- Braille patterns provide 2x horizontal and 4x vertical resolution per character
