# Summary: Dashboard Example Application

## Overview

Created a complete system monitoring dashboard example application that demonstrates TermUI's capabilities. The example showcases multiple widgets, real-time updates, keyboard navigation, and theming.

## Files Created

```
examples/dashboard/
├── lib/
│   ├── dashboard.ex                 # Main module and entry point
│   └── dashboard/
│       ├── application.ex           # OTP application
│       ├── app.ex                   # Root StatefulComponent
│       └── data/
│           └── metrics.ex           # Simulated metrics generator
├── mix.exs                          # Mix project file
└── README.md                        # Usage documentation
```

## Features Implemented

### Widgets Demonstrated

1. **Gauges** - CPU and memory usage with color zones (green/yellow/red)
2. **Sparklines** - Network RX/TX activity visualization
3. **Text-based Table** - Process list with selection highlighting
4. **Labels** - System info, headers, help bar

### Application Features

- **Real-time Updates** - 1-second refresh interval using timer commands
- **Keyboard Navigation** - Arrow keys to select processes
- **Theme Switching** - Toggle between dark and light themes
- **Clean Exit** - Proper shutdown with 'q' key

### Data Patterns

The metrics generator produces realistic patterns:
- **CPU** - Smooth sinusoidal base with random spikes
- **Memory** - Gradual increase with periodic drops (GC simulation)
- **Network** - Bursty traffic patterns
- **Processes** - Stable values with slight variations

## Key Concepts Demonstrated

### 1. StatefulComponent Pattern

```elixir
use TermUI.StatefulComponent

def init(_props) do
  {:ok, state, [{:timer, 1000, :refresh}]}
end

def handle_event(%Key{key: "q"}, state) do
  {:stop, :normal, state}
end

def render(state, area) do
  stack(:vertical, [...])
end
```

### 2. Timer Commands

```elixir
def handle_info(:refresh, state) do
  new_state = %{state | metrics: Metrics.get_metrics()}
  {:ok, new_state, [{:timer, @refresh_interval, :refresh}]}
end
```

### 3. Render Tree Building

```elixir
stack(:vertical, [
  render_header(theme),
  stack(:horizontal, [gauge1, gauge2, info]),
  render_network(metrics, theme),
  render_processes(processes, selected, area, theme)
])
```

### 4. Style System

```elixir
Style.new(fg: :cyan, attrs: [:bold])
```

## Running the Example

```bash
cd examples/dashboard
mix deps.get
mix run --no-halt
```

## Controls

| Key | Action |
|-----|--------|
| `q` | Quit |
| `r` | Force refresh |
| `t` | Toggle theme |
| `↑/↓` | Navigate processes |

## Technical Notes

- Uses simulated data for portability (no real system metrics)
- Compiles without errors
- Minimal dependencies (only TermUI)
- Self-contained Mix project

## Branch

`feature/dashboard-example`
