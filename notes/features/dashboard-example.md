# Feature Plan: Dashboard Example Application

## Problem Statement

The TermUI framework needs example applications to demonstrate its capabilities and help users understand how to build real applications. A dashboard is an ideal first example as it showcases multiple widgets, layout system, theming, and real-time updates.

**Impact:**
- Provides reference implementation for users
- Demonstrates best practices for TermUI applications
- Validates that the framework can build real-world applications
- Serves as integration test for the full framework

## Solution Overview

Create a system monitoring dashboard example that displays:
- CPU and memory usage gauges
- Network activity sparklines
- Process table with sorting
- System information panel
- Real-time updates using the command system

### Key Design Decisions

- Use simulated data (not real system metrics) for portability
- Showcase as many widgets as reasonable without clutter
- Demonstrate keyboard navigation and focus management
- Include theme switching capability
- Use the Runtime for proper application lifecycle

## Technical Details

### Directory Structure

```
examples/
  dashboard/
    lib/
      dashboard.ex           # Main application module
      dashboard/
        app.ex               # Root component
        widgets/
          system_info.ex     # System info panel
          cpu_gauge.ex       # CPU usage gauge
          memory_gauge.ex    # Memory usage gauge
          network_chart.ex   # Network activity chart
          process_table.ex   # Process list table
        data/
          metrics.ex         # Simulated metrics generator
    mix.exs                  # Mix project file
    README.md                # Documentation
```

### Widgets to Showcase

1. **Gauges** - CPU and memory usage (circular progress indicators)
2. **Sparklines** - Network RX/TX activity over time
3. **Bar Chart** - Memory breakdown by category
4. **Table** - Running processes with PID, name, CPU%, memory
5. **Block** - Panels with borders and titles
6. **Labels** - Headers and static text
7. **Tabs** - Switch between dashboard views

### Layout Design

```
┌─ System Dashboard ──────────────────────────────────────┐
│ ┌─ CPU ──┐ ┌─ Memory ─┐ ┌─ System Info ───────────────┐ │
│ │  45%   │ │   72%    │ │ Hostname: localhost         │ │
│ │  [##]  │ │  [####]  │ │ Uptime: 5d 3h 42m           │ │
│ └────────┘ └──────────┘ │ Load: 1.24 0.89 0.76        │ │
│ ┌─ Network ───────────┐ └─────────────────────────────┘ │
│ │ RX: ▂▃▅▇▅▃▂▁▂▃▅▇   │                                  │
│ │ TX: ▁▂▃▂▁▂▃▅▃▂▁▂   │                                  │
│ └─────────────────────┘                                  │
│ ┌─ Processes ───────────────────────────────────────────┐│
│ │ PID    Name              CPU%    Memory               ││
│ │ 1234   beam.smp          12.3    256 MB               ││
│ │ 5678   postgres          8.1     128 MB               ││
│ │ 9012   nginx             2.4     64 MB                ││
│ └───────────────────────────────────────────────────────┘│
│ [q] Quit  [r] Refresh  [t] Theme  [Tab] Navigate        │
└─────────────────────────────────────────────────────────┘
```

### Features to Demonstrate

1. **Layout System** - Nested constraints, percentage widths, flex alignment
2. **Component Lifecycle** - Mount, update, commands for async data
3. **Event Handling** - Keyboard shortcuts, focus navigation
4. **Theming** - Switch between light/dark themes
5. **Real-time Updates** - Periodic data refresh using subscriptions
6. **Table Interactions** - Sorting, scrolling through processes

## Implementation Plan

### Task 1: Project Setup

- [x] 1.1 Create examples/dashboard directory structure
- [x] 1.2 Create mix.exs with TermUI dependency
- [x] 1.3 Create README.md with usage instructions

### Task 2: Data Layer

- [x] 2.1 Create metrics generator for simulated data
- [x] 2.2 Implement CPU/memory/network data simulation
- [x] 2.3 Implement process list generation

### Task 3: Widget Components

- [x] 3.1 Create system info panel component
- [x] 3.2 Create CPU gauge component
- [x] 3.3 Create memory gauge component
- [x] 3.4 Create network chart component
- [x] 3.5 Create process table component

### Task 4: Main Application

- [x] 4.1 Create root App component with layout
- [x] 4.2 Implement keyboard shortcuts (quit, refresh, theme)
- [x] 4.3 Add periodic refresh using commands
- [x] 4.4 Implement theme switching

### Task 5: Documentation and Testing

- [x] 5.1 Complete README with screenshots/usage
- [x] 5.2 Test application runs correctly
- [x] 5.3 Verify all widgets render properly

## Success Criteria

1. Dashboard application starts and renders correctly
2. All widgets display simulated data
3. Keyboard navigation works between components
4. Theme switching works
5. Real-time updates occur periodically
6. Application exits cleanly with 'q' key
7. README provides clear instructions to run

## Notes/Considerations

- Keep simulated data realistic but simple
- Ensure the example works on different terminal sizes
- Consider adding command-line arguments for refresh rate
- The example should be self-contained (no external dependencies beyond TermUI)
