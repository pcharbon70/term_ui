# Dashboard Example

This example demonstrates building a comprehensive system monitoring dashboard using multiple TermUI widgets including Gauge, Sparkline, and Table components.

## Overview

The dashboard displays real-time system metrics in a terminal-based interface. While this example uses the Dashboard namespace rather than a single widget, it showcases how to compose multiple widgets into a cohesive application.

**Key Features:**
- CPU and memory usage gauges with color zones
- Network traffic sparklines (RX/TX)
- Process table with selection
- System information display
- Theme switching (dark/light)
- Responsive layout with bordered sections

**Widgets Demonstrated:**
- `TermUI.Widgets.Gauge` - CPU and memory percentage bars
- `TermUI.Widgets.Sparkline` - Network traffic history
- `TermUI.Widgets.Table.Column` - Process table formatting

## Example Structure

```
dashboard/
├── lib/
│   ├── dashboard/
│   │   ├── app.ex              # Main dashboard component
│   │   ├── application.ex      # OTP application
│   │   └── data/
│   │       └── metrics.ex      # Mock metrics generator
│   └── dashboard.ex            # Application entry point
├── mix.exs                      # Project configuration
└── README.md                   # This file
```

**app.ex** - Main dashboard implementation:
- Implements Elm Architecture (init/update/view)
- Composes gauges, sparklines, and tables
- Handles theme switching
- Manages process selection

**metrics.ex** - Provides simulated system metrics:
- CPU and memory percentages
- Network RX/TX data streams
- Process list with stats
- System info (hostname, uptime, load average)

## Running the Example

### Raw Mode (Full TUI Experience)

For the best experience with full terminal control and alternate screen:

```bash
cd examples/dashboard
mix termui.run
```

Or manually:

```bash
cd examples/dashboard
mix run -e "Dashboard.run()" --no-halt
```

### TTY Mode (IEx Compatible)

To run from IEx without taking over the shell:

```bash
cd examples/dashboard
iex -S mix
```

Then in IEx:

```elixir
Dashboard.run()
```

**Note:** TTY mode works inside IEx but has limitations:
- Input is read through the shell; some terminals buffer keys until Enter is pressed
- For full TUI, use raw mode instead

## Controls

- **Q** - Quit the application
- **R** - Refresh display (triggers re-render)
- **T** - Toggle theme between dark and light
- **Up/Down** - Navigate through process list

## Layout Details

The dashboard uses a fixed-width layout (58 characters) with these sections:

1. **Header** - Title with decorative border
2. **Gauges Row** - CPU and Memory gauges side-by-side with color zones
3. **System Info** - Hostname, uptime, and load averages
4. **Network Section** - RX/TX sparklines showing traffic history
5. **Process Table** - Sortable process list with PID, name, CPU%, and memory
6. **Controls Bar** - Help text with keyboard shortcuts

**Color Zones:**
- CPU Gauge: Green (0-59%), Yellow (60-79%), Red (80-100%)
- Memory Gauge: Green (0-69%), Yellow (70-84%), Red (85-100%)

## Themes

**Dark Theme:**
- Cyan borders and headers
- White text on black background
- Green/blue sparklines
- Cyan selection highlight

**Light Theme:**
- Yellow borders and headers
- Bright white text
- Bright green/cyan sparklines
- Yellow selection highlight
