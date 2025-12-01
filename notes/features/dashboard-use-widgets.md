# Feature Plan: Dashboard Widget Integration

## Problem Statement

The dashboard example at `examples/dashboard/lib/dashboard/app.ex` currently renders UI elements manually using `stack/2` and `text/2` primitives. This approach:

1. Duplicates logic that already exists in TermUI widgets
2. Does not demonstrate best practices for using the widget library
3. Requires manual handling of styling zones that widgets handle automatically
4. Misses opportunities to showcase widget features like zones in gauges

**Impact:**
- The example fails to demonstrate how to use key TermUI widgets
- Users may copy manual patterns instead of using the widget system
- Widget APIs are not validated through real usage

## Solution Overview

Update the dashboard example to use proper TermUI widgets for:
- **CPU gauge** - Replace manual bar rendering with `TermUI.Widgets.Gauge`
- **Memory gauge** - Replace manual bar rendering with `TermUI.Widgets.Gauge`
- **Process table** - Replace manual table rendering with `TermUI.Widgets.Table`

The Sparkline widget is already used correctly and will remain unchanged.

### Key Design Decisions

1. Use `Gauge.render/1` with zones for color-coded thresholds
2. Use `Table` with `Column` definitions for process list
3. Preserve all existing functionality (theming, keyboard navigation, theme toggle)
4. Maintain visual consistency with current dashboard appearance
5. Keep system info panel and help bar as manual rendering (no suitable widgets yet)

## Technical Analysis

### Current Dashboard Components

| Component | Current Implementation | Proposed Widget | Status |
|-----------|----------------------|-----------------|--------|
| CPU Gauge | Manual bar with `█` and `░` | `TermUI.Widgets.Gauge` | ✅ Done |
| Memory Gauge | Manual bar with `█` and `░` | `TermUI.Widgets.Gauge` | ✅ Done |
| System Info | Manual text box | Keep as-is (no widget) | No Change |
| Network Sparklines | `TermUI.Widgets.Sparkline` | Keep as-is | No Change |
| Process Table | Manual text formatting | `TermUI.Widgets.Table.Column` | ✅ Done |
| Help Bar | Manual text box | Keep as-is | No Change |

### Gauge Widget API

From `lib/term_ui/widgets/gauge.ex`:

```elixir
Gauge.render(
  value: 75,
  min: 0,
  max: 100,
  width: 30,
  zones: [
    {0, Style.new(fg: :green)},
    {60, Style.new(fg: :yellow)},
    {80, Style.new(fg: :red)}
  ],
  show_value: true,
  show_range: true,
  label: "CPU Usage"
)
```

**Relevant Options:**
- `:value` - Current value (required)
- `:min` / `:max` - Range (defaults: 0, 100)
- `:width` - Gauge width (default: 40)
- `:type` - `:bar` or `:arc` (default: `:bar`)
- `:show_value` - Show numeric value (default: true)
- `:show_range` - Show min/max labels (default: true)
- `:zones` - Color thresholds `[{threshold, style}]`
- `:label` - Label text
- `:bar_char` / `:empty_char` - Custom characters

### Table Widget API

The Table widget uses Column definitions for cell rendering. From `lib/term_ui/widgets/table/column.ex`:

```elixir
Column.new(:name, "Name",
  width: Constraint.length(20),
  align: :right,
  render: &format_func/1
)
```

**Current Dashboard Process Columns:**
- PID (7 chars, left-aligned)
- Name (20 chars, left-aligned)
- CPU% (8 chars, right-aligned)
- Memory (12 chars, right-aligned)

## Implementation Plan

### Task 1: Update CPU Gauge ✅
- [x] Add `alias TermUI.Widgets.Gauge` to module
- [x] Replace `render_cpu_gauge/2` function to use `Gauge.render/1`
- [x] Configure zones for green (0-60), yellow (60-80), red (80+)
- [x] Keep border rendering separate for theming consistency

### Task 2: Update Memory Gauge ✅
- [x] Replace `render_memory_gauge/2` function to use `Gauge.render/1`
- [x] Configure zones for green (0-70), yellow (70-85), red (85+)
- [x] Keep border rendering separate for theming consistency

### Task 3: Update Process Table ✅
- [x] Add `alias TermUI.Widgets.Table.Column` to module
- [x] Add `alias TermUI.Layout.Constraint` to module
- [x] Replace `render_processes/3` to use Column definitions
- [x] Use `Column.new/3` for column definitions
- [x] Preserve selection highlighting

### Task 4: Cleanup ✅
- [x] Remove unused helper functions (`get_gauge_style/2`, `get_memory_style/2`)
- [x] Verify all imports are correct
- [x] Fix credo suggestions (use `Enum.map_join/3`, convert cond to if)

### Task 5: Testing ✅
- [x] Dashboard compiles without errors
- [x] All TermUI tests pass (3535 tests, 0 failures)
- [x] Credo --strict passes on dashboard

### Task 6: Documentation ✅
- [x] Update plan with completed tasks
- [x] Create summary document

## Success Criteria

1. Dashboard compiles without errors
2. Visual appearance matches or improves upon current design
3. CPU gauge uses `Gauge` widget with green/yellow/red zones
4. Memory gauge uses `Gauge` widget with appropriate zones
5. Process table uses `Column` helpers for cell rendering
6. All keyboard navigation preserved (q/r/t/arrow keys)
7. Theme switching continues to work
8. No regression in functionality

## Notes/Considerations

1. **Gauge Value Display**: The Gauge widget's default value display may differ from current layout. May need to adjust positioning.

2. **Border Consistency**: Keeping borders separate from widgets allows consistent theming but adds complexity. This is an acceptable trade-off.

3. **Table Width**: The process table uses a fixed width. Column-based approach may need width adjustments.

## Files to Modify

- `examples/dashboard/lib/dashboard/app.ex` - Main file to update with widget usage

## Reference Files

- `lib/term_ui/widgets/gauge.ex` - Gauge widget API
- `lib/term_ui/widgets/table/column.ex` - Column helpers for table cells
- `lib/term_ui/layout/constraint.ex` - Constraint types for column widths
- `examples/gauge/lib/gauge/app.ex` - Reference for Gauge usage patterns
