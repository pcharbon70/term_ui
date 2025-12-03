# SupervisionTreeViewer Widget Example

A demonstration of the TermUI SupervisionTreeViewer widget for visualizing OTP supervision hierarchies in real-time.

## Widget Overview

The SupervisionTreeViewer displays live OTP supervision trees with status indicators, process information, and management controls. It provides an interactive view of your application's supervisor hierarchy, making it easy to understand process relationships and monitor system health.

**Key Features:**
- Tree view of supervision hierarchy
- Live status indicators (running, restarting, terminated)
- Process information display (memory, reductions, message queue)
- Supervisor strategy visualization (one_for_one, one_for_all, etc.)
- Process restart/terminate controls with confirmation
- Tree filtering by process name
- Auto-refresh capability

**When to Use:**
- Debugging OTP application structure
- Monitoring process health in development
- Understanding supervisor hierarchies
- Process management during development
- Educational demonstrations of OTP supervision

## Widget Options

The `SupervisionTreeViewer.new/1` function accepts these options:

- `:root` - Root supervisor (pid, registered name, or module) (required)
- `:update_interval` - Refresh interval in milliseconds (default: 2000)
- `:on_select` - Callback when node is selected: `fn node -> ... end`
- `:on_action` - Callback when action is performed: `fn {:restarted | :terminated, pid} -> ... end`
- `:show_workers` - Show worker processes (default: true)
- `:auto_expand` - Expand all nodes initially (default: true)

## Example Structure

This example consists of:

- `lib/supervision_tree_viewer/app.ex` - Main application demonstrating:
  - SupervisionTreeViewer initialization
  - Tree navigation and expansion
  - Process information display
  - Process restart/terminate operations
  - Filter functionality
- `lib/supervision_tree_viewer/sample_tree.ex` - Sample supervision tree for demonstration
- `lib/supervision_tree_viewer/application.ex` - Application supervisor
- `mix.exs` - Mix project configuration
- `run.exs` - Helper script to run the example

## Running the Example

From this directory:

```bash
# Run with the helper script
elixir run.exs

# Or run directly with mix
mix run -e "SupervisionTreeViewerExample.App.run()" --no-halt
```

## Controls

### Navigation
- **Up/Down** - Move selection up/down in tree
- **Left** - Collapse node or move to parent
- **Right** - Expand node or move to first child
- **Page Up/Page Down** - Scroll by page
- **Home** - Jump to first node
- **End** - Jump to last node

### Tree Operations
- **Enter** - Toggle expand/collapse for selected node

### Information
- **i** - Show/hide process info panel for selected process

### Process Management (with confirmation)
- **r** - Restart selected process (prompts for confirmation)
- **k** - Terminate selected process (prompts for confirmation)
- **y** - Confirm pending action
- **n** - Cancel pending action

### Filtering
- **/** - Start filter input mode
- Type to filter by process name
- **Enter** - Apply filter
- **Escape** - Clear filter or cancel input

### Refresh
- **R** - Force refresh tree

### Application
- **q** - Quit (only when not in filter input mode)
- **Escape** - Clear filter/close info panel/cancel action

## Status Indicators

The tree view uses color-coded icons to show process status:

- **● (green)** - Process is running normally
- **◐ (yellow)** - Process is restarting
- **○ (red)** - Process is terminated
- **? (white)** - Process status is undefined

## Node Types

- **□** - Supervisor node
- **◇** - Worker node

## Supervisor Strategies

Supervisor strategies are displayed with compact indicators:

- **[1:1]** - `:one_for_one` - Restart only the failed child
- **[1:*]** - `:one_for_all` - Restart all children when one fails
- **[1:→]** - `:rest_for_one` - Restart failed child and those started after it
- **[1:1+]** - `:simple_one_for_one` - Dynamically add children of the same type

## Process Information Panel

When opened with **i**, the panel displays:

- **ID** - Process identifier
- **PID** - Process ID
- **Name** - Registered name (if any)
- **Type** - Supervisor or worker
- **Status** - Current process status
- **Strategy** - Supervisor strategy (supervisors only)
- **Max restarts** - Restart intensity and period (supervisors only)
- **Memory** - Current memory usage
- **Reductions** - Total reductions (execution steps)
- **Msg Queue** - Message queue length

## Sample Tree

The example includes a sample supervision tree that demonstrates:
- Multiple levels of supervisors
- Various supervisor strategies
- Worker processes
- Nested supervision hierarchies

This provides a realistic example for exploring the widget's capabilities.
