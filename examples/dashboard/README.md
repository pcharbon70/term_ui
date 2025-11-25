# System Dashboard Example

A terminal-based system monitoring dashboard built with TermUI. This example demonstrates the framework's key features including real-time updates, multiple widget types, and keyboard navigation.

## Features

- **CPU Gauge** - Real-time CPU usage with color zones
- **Memory Gauge** - Memory utilization with visual feedback
- **System Info** - Hostname, uptime, and load averages
- **Network Sparklines** - RX/TX activity visualization
- **Process Table** - Navigable list of running processes
- **Theme Switching** - Toggle between dark and light themes

## Requirements

- Elixir 1.15+
- OTP 28+
- Terminal with Unicode support
- 80x24 minimum terminal size (larger recommended)

## Installation

```bash
# From the project root, navigate to the example
cd examples/dashboard

# Install dependencies
mix deps.get
```

## Running

```bash
# Run the dashboard
mix run run.exs
```

The dashboard will take over your terminal. Press `Q` to quit and restore normal terminal operation.

## Controls

| Key | Action |
|-----|--------|
| `Q` | Quit the application |
| `R` | Force refresh data |
| `T` | Toggle theme (dark/light) |
| `↑` | Select previous process |
| `↓` | Select next process |

Keys are case-insensitive (both `q` and `Q` work).

## Architecture

```
lib/
  dashboard.ex              # Entry points (start/run)
  dashboard/
    application.ex          # OTP application
    app.ex                  # Root Elm component
    data/
      metrics.ex            # Simulated metrics generator
```

### The Elm Architecture

The dashboard uses TermUI's Elm Architecture pattern:

1. **init/1** - Initialize component state
2. **event_to_msg/2** - Convert terminal events to messages
3. **update/2** - Handle messages and return new state + commands
4. **view/1** - Render state to UI tree

```elixir
def event_to_msg(%Event.Key{key: key}, _state) when key in ["q", "Q"] do
  {:msg, :quit}
end

def update(:quit, state) do
  {state, [:quit]}  # Return quit command
end

def view(state) do
  stack(:vertical, [
    render_header(theme),
    stack(:horizontal, [gauge1, gauge2, info]),
    render_processes(...)
  ])
end
```

## Simulated Metrics

The dashboard uses simulated metrics that follow realistic patterns:

- **CPU** - Smooth variations with occasional spikes
- **Memory** - Gradual increase with periodic drops (simulating GC)
- **Network** - Bursty traffic patterns
- **Processes** - Stable list with slight variations

This ensures the example works on any system without requiring actual system metrics access.

## Customization

### Adding Themes

Add new themes in `get_theme/1`:

```elixir
defp get_theme(:custom) do
  %{
    header: Style.new(fg: :magenta, attrs: [:bold]),
    border: Style.new(fg: :magenta),
    # ... other styles
  }
end
```

### Adding Widgets

Import widget modules and add to the render tree:

```elixir
alias TermUI.Widgets.{Gauge, Sparkline, Table}

def view(state) do
  stack(:vertical, [
    Gauge.render(value: cpu, width: 20),
    Sparkline.render(values: history, min: 0, max: 100)
  ])
end
```
