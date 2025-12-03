# ProcessMonitor Example

A demonstration of the ProcessMonitor widget for live BEAM process inspection and management.

## Widget Overview

The ProcessMonitor widget provides real-time monitoring of BEAM processes with detailed information including PID, name, reductions, memory usage, and message queue depth. It includes powerful features for debugging and process management.

### Key Features

- Live process list with automatic updates
- Process information (PID, name, reductions, memory, queue length, status)
- Configurable update interval
- Sorting by any field (PID, name, reductions, memory, queue, status)
- Filtering by name or module (regex support)
- Process details panel with multiple views
- Process actions (kill, suspend, resume) with confirmation
- Stack trace visualization
- Links and monitors display
- Warning thresholds for queue depth and memory usage
- System process filtering

### When to Use

Use ProcessMonitor when you need to:
- Debug BEAM application performance
- Identify memory leaks or high CPU usage
- Monitor message queue buildup
- Inspect process relationships (links/monitors)
- Analyze process behavior and stack traces
- Manage running processes (kill/suspend/resume)
- Track system resource usage

## Widget Options

The ProcessMonitor widget accepts the following options in its `new/1` function:

- `:update_interval` - Refresh interval in milliseconds (default: 1000)
- `:show_system_processes` - Include system processes (default: false)
- `:thresholds` - Warning thresholds map (default: see below)
- `:on_select` - Callback when process is selected `fn process -> ... end`
- `:on_action` - Callback when action is performed `fn action -> ... end`

### Default Thresholds

```elixir
%{
  queue_warning: 1000,        # Yellow warning
  queue_critical: 10_000,     # Red alert
  memory_warning: 50 * 1024 * 1024,   # 50MB warning
  memory_critical: 200 * 1024 * 1024  # 200MB alert
}
```

### Example Usage

```elixir
ProcessMonitor.new(
  update_interval: 1000,
  show_system_processes: false,
  thresholds: %{
    queue_warning: 500,
    queue_critical: 5000
  }
)
```

## Example Structure

This example contains:

- `lib/process_monitor/app.ex` - Main application demonstrating the ProcessMonitor widget
  - Spawns test worker processes
  - Demonstrates various process states
  - Shows all monitoring features
  - Handles process actions and confirmations

The example spawns test workers that:
- Generate reductions (simulate work)
- Build up message queues
- Allocate memory
- Can be filtered by name "Worker"

## Running the Example

From the `examples/process_monitor` directory:

```bash
mix deps.get
mix run -e "ProcessMonitorExample.App.run()"
```

Or using the Mix task:

```bash
mix process_monitor
```

## Controls

### Navigation
- **Up/Down** - Move selection between processes
- **PageUp/PageDown** - Scroll by page (20 processes)
- **Home/End** - Jump to first/last process

### Display & Sorting
- **r** - Refresh process list immediately
- **s** - Cycle sort field (PID → name → reductions → memory → queue → status)
- **S** - Toggle sort direction (ascending/descending)
- **Enter** - Toggle details panel

### Details Views
- **l** - Show links and monitors
- **t** - Show stack trace
- **Enter** - Toggle general info panel

### Filtering
- **/** - Start filter input (supports regex)
- **Type** - Enter filter pattern
- **Enter** - Apply filter
- **Escape** - Clear filter

### Process Actions
- **k** - Kill selected process (requires confirmation)
- **p** - Pause (suspend) or resume selected process
- **y** - Confirm action
- **n** - Cancel action

### Example Actions
- **w** - Spawn 5 test worker processes
- **q** - Quit the application

## Features Demonstrated

1. **Live Updates** - Process list refreshes every second
2. **Sorting** - Sort by any column with direction toggle
3. **Filtering** - Filter processes by name/module (try "Worker")
4. **Color Coding** - Highlights processes with high queue/memory (yellow/red)
5. **Details Panel** - Shows comprehensive process information
6. **Stack Traces** - Displays current call stack
7. **Links/Monitors** - Shows process relationships
8. **Process Actions** - Kill, suspend, resume with confirmation
9. **Test Workers** - Spawn workers to see monitoring in action

## Process Information Display

### Main List Columns
- **PID** - Process identifier
- **Name** - Registered name or initial call
- **Reductions** - CPU work performed (formatted as K/M/B)
- **Memory** - Process memory usage (formatted as KB/MB/GB)
- **Queue** - Message queue length
- **Status** - Process status (running, waiting, suspended, etc.)

### Details Panel Modes

#### Info View (default)
- Full PID and registered name
- Current and initial function calls
- Process status
- Link and monitor counts

#### Links View
- Lists linked processes (up to 5)
- Lists monitored processes (up to 5)
- Lists processes monitoring this one (up to 5)

#### Trace View
- Current stack trace (up to 6 frames)
- Shows module, function, arity, file, and line number

## Color Coding

- **Blue background** - Selected process
- **Red** - Critical threshold exceeded (queue ≥ 10,000 or memory ≥ 200MB)
- **Yellow** - Warning threshold exceeded (queue ≥ 1,000 or memory ≥ 50MB)
- **Magenta** - Suspended process
- **White** - Normal process

## Implementation Notes

- System processes are filtered by default (kernel, code server, logger, etc.)
- Update interval can be changed dynamically
- Process list is fetched on each refresh
- Dead processes are automatically removed
- Actions are confirmed before execution
- Stack traces are fetched on demand
- The selected process is preserved across refreshes when possible
