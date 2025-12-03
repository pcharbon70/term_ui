# ClusterDashboard Widget Example

This example demonstrates the TermUI ClusterDashboard widget for visualizing and monitoring distributed Erlang/BEAM clusters.

## Widget Overview

The ClusterDashboard widget provides comprehensive cluster monitoring and debugging capabilities for distributed BEAM applications. It displays:

- **Nodes view** - Connected nodes with status indicators and health metrics
- **Global names** - Cross-node process registry (`:global` module)
- **PG groups** - Process group membership (`:pg` module)
- **Events log** - Node connection/disconnection history
- **Network partition detection** - Alerts when multiple nodes disconnect
- **Remote inspection** - RPC-based node details

Use ClusterDashboard when building distributed applications that need visibility into cluster topology, node health, process distribution, and connection stability.

## Widget Options

The `ClusterDashboard.new/1` function accepts the following options:

- `:update_interval` - Refresh interval in milliseconds (default: 2000)
- `:show_health_metrics` - Fetch and display CPU/memory/load (default: `true`)
- `:show_pg_groups` - Display `:pg` process groups (default: `true`)
- `:show_global_names` - Display `:global` registered names (default: `true`)
- `:on_node_select` - Callback function when node is selected

## Example Structure

The example consists of:

- `lib/cluster_dashboard/app.ex` - Main application demonstrating:
  - Cluster monitoring with automatic refresh
  - View switching between nodes, globals, PG groups, and events
  - Interactive navigation and details panels
  - Test functions for spawning global processes and joining PG groups

## Running the Example

### Single Node (Non-Distributed)

```bash
cd examples/cluster_dashboard
mix deps.get
iex -S mix
```

Then in the IEx shell:

```elixir
ClusterDashboardExample.App.run()
```

### Multiple Nodes (Distributed)

To see the full cluster capabilities, start multiple nodes:

**Terminal 1:**
```bash
iex --sname node1 -S mix
```
```elixir
ClusterDashboardExample.App.run()
```

**Terminal 2:**
```bash
iex --sname node2 -S mix
```
```elixir
Node.connect(:node1@hostname)  # Replace hostname with your machine name
```

**Terminal 3:**
```bash
iex --sname node3 -S mix
```
```elixir
Node.connect(:node1@hostname)
```

The dashboard on node1 will show all connected nodes with their metrics.

## Controls

**View switching:**
- `n` - Switch to Nodes view
- `g` - Switch to Global names view
- `p` - Switch to PG groups view
- `e` - Switch to Events view

**Navigation:**
- `↑` / `↓` - Navigate through list items
- `PageUp` / `PageDown` - Scroll by page
- `Home` - Jump to first item
- `End` - Jump to last item

**Actions:**
- `Enter` - Toggle details panel for selected item
- `i` - Inspect selected node (in Nodes view)
- `r` - Refresh data now
- `Escape` - Close details panel / clear alerts
- `q` - Quit application

**Testing:**
- `G` - Register a test global process
- `P` - Join a test PG group

## Implementation Notes

The example demonstrates:

- **Real-time monitoring** - Automatic data refresh at configurable intervals
- **Node monitoring** - Subscribe to `:nodeup` and `:nodedown` events
- **Health metrics** - Fetch process count, memory usage, scheduler info via RPC
- **Multiple views** - Switch between different cluster aspects
- **Scrollable lists** - Handle large datasets with viewport scrolling
- **Details panels** - Show expanded information for selected items
- **Network partition detection** - Alert when multiple nodes disconnect rapidly
- **Event logging** - Track connection/disconnection history with timestamps

### Node Health Metrics

The dashboard displays:
- **Process count** - Number of running processes
- **Memory usage** - Total and process memory (formatted as B/KB/MB/GB)
- **Scheduler count** - Number of online schedulers
- **Uptime** - Node runtime duration
- **OTP release** - OTP version

### Distributed Features

- **:global names** - Shows processes registered globally across the cluster
- **:pg groups** - Shows process groups and their membership across nodes
- **RPC calls** - Remote procedure calls with timeout protection
- **Partition alerts** - Detects when 2+ nodes disconnect within 5 seconds

## Use Cases

- Monitor cluster health in production
- Debug distributed system issues
- Visualize process distribution across nodes
- Track node connectivity stability
- Inspect cross-node process registries
- Detect network partitions early
