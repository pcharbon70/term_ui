# BarChart Widget Example

This example demonstrates the TermUI BarChart widget for displaying comparative values as horizontal or vertical bars with labels and values.

## Widget Overview

The BarChart widget renders visual representations of numeric data as bars, making it easy to compare values at a glance. It supports:

- **Horizontal bars** - Traditional left-to-right bars with labels
- **Vertical bars** - Column-style charts for different visualization needs
- **Value display** - Show numeric values alongside bars
- **Label display** - Identify each bar with text labels
- **Color coding** - Apply custom colors to individual bars
- **Simple bars** - Single-value progress bars

Use BarChart when you need to visualize comparative data, show progress, or display statistical information in your TUI application.

## Widget Options

The `BarChart.render/1` function accepts the following options:

- `:data` - List of data points (required), each with:
  - `:label` - Bar label (string)
  - `:value` - Numeric value
- `:direction` - `:horizontal` or `:vertical` (default: `:horizontal`)
- `:width` - Chart width in characters (default: 40, max: configurable)
- `:height` - Chart height for vertical charts (default: 10, max: configurable)
- `:show_values` - Display numeric values (default: `true`)
- `:show_labels` - Display bar labels (default: `true`)
- `:bar_char` - Character for filled bars (default: `"█"`)
- `:empty_char` - Character for empty space (default: `" "`)
- `:colors` - List of `Style` structs for bar colors (cycles through list)
- `:style` - Overall chart style

The `BarChart.bar/1` function for simple single bars accepts:

- `:value` - Current value (required)
- `:max` - Maximum value (required)
- `:width` - Bar width (default: 20)
- `:bar_char` - Filled character (default: `"█"`)
- `:empty_char` - Empty character (default: `"░"`)

## Example Structure

The example consists of:

- `lib/bar_chart/app.ex` - Main application demonstrating:
  - Dynamic direction switching (horizontal/vertical)
  - Toggle value and label display
  - Data randomization for live updates
  - Multiple chart configurations:
    - Main interactive chart
    - Simple single-bar progress indicator
    - Colored multi-bar chart

## Running the Example

```bash
cd examples/bar_chart
mix deps.get
iex -S mix
```

Then in the IEx shell:

```elixir
BarChart.App.run()
```

## Controls

- `D` - Toggle chart direction (horizontal/vertical)
- `V` - Toggle value display (ON/OFF)
- `L` - Toggle label display (ON/OFF)
- `R` - Randomize data values
- `Q` - Quit application

## Implementation Notes

The example demonstrates:
- Rendering horizontal bar charts with labels and values
- Rendering vertical column charts with proper scaling
- Dynamic chart reconfiguration based on user input
- Using custom colors for different bars
- Creating simple single-value progress bars
- Proper data formatting and scaling to fit available space
