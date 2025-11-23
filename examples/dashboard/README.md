# System Dashboard Example

A terminal-based system monitoring dashboard built with TermUI. This example demonstrates the framework's key features including real-time updates, multiple widget types, and keyboard navigation.

## Features

- **CPU Gauge** - Real-time CPU usage with color zones
- **Memory Gauge** - Memory utilization with visual feedback
- **System Info** - Hostname, uptime, and load averages
- **Network Sparklines** - RX/TX activity visualization
- **Process Table** - Sortable list of running processes
- **Theme Switching** - Toggle between dark and light themes

## Running the Dashboard

```bash
# Navigate to the example directory
cd examples/dashboard

# Install dependencies
mix deps.get

# Run the dashboard
mix run --no-halt
```

Alternatively, from the project root:

```bash
cd examples/dashboard && mix deps.get && mix run --no-halt
```

## Controls

| Key | Action |
|-----|--------|
| `q` | Quit the application |
| `r` | Force refresh data |
| `t` | Toggle theme (dark/light) |
| `↑` | Select previous process |
| `↓` | Select next process |

## Architecture

```
lib/
  dashboard.ex              # Main module and entry point
  dashboard/
    application.ex          # OTP application
    app.ex                  # Root StatefulComponent
    data/
      metrics.ex            # Simulated metrics generator
```

### Key Concepts Demonstrated

1. **StatefulComponent** - The main `Dashboard.App` uses stateful component pattern with `init/1`, `handle_event/2`, and `render/2`

2. **Commands** - Timer commands for periodic data refresh:
   ```elixir
   commands = [{:timer, @refresh_interval, :refresh}]
   ```

3. **Event Handling** - Keyboard events for navigation and actions:
   ```elixir
   def handle_event(%KeyEvent{key: "q"}, state) do
     {:stop, :normal, state}
   end
   ```

4. **Render Tree** - Building UI with `stack/2` and widget helpers:
   ```elixir
   stack(:vertical, [
     render_header(theme),
     stack(:horizontal, [gauge1, gauge2, info]),
     render_table(...)
   ])
   ```

5. **Theming** - Dynamic style switching with Style structs:
   ```elixir
   Style.new(fg: :cyan, attrs: [:bold])
   ```

## Simulated Metrics

The dashboard uses simulated metrics that follow realistic patterns:

- **CPU** - Smooth variations with occasional spikes
- **Memory** - Gradual increase with periodic drops (simulating GC)
- **Network** - Bursty traffic patterns
- **Processes** - Stable with slight variations

This approach ensures the example works on any system without requiring actual system metrics access.

## Customization

### Refresh Rate

Modify the `@refresh_interval` module attribute in `lib/dashboard/app.ex`:

```elixir
@refresh_interval 500  # Update every 500ms
```

### Adding Widgets

The dashboard showcases several TermUI widgets. To add more:

1. Import the widget module
2. Add to the render tree using `stack` or other layout helpers
3. Style with `Style.new/1`

### Custom Themes

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

## Requirements

- Elixir 1.15+
- OTP 28+
- Terminal with Unicode support
- 80x24 minimum terminal size (larger recommended)
