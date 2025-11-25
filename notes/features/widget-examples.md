# Feature: Widget Examples

## Problem Statement

TermUI has 15 widgets but no simple, standalone examples demonstrating how to use each one. New users need easy-to-understand examples showing widget usage patterns, initialization, event handling, and rendering.

## Solution Overview

Create a series of simple, self-contained examples in `examples/` directory, one per widget. Each example will:
- Be a standalone Mix project
- Include a README with installation and run instructions
- Have well-commented code explaining the widget API
- Demonstrate key features of each widget

## Widgets to Create Examples For

Based on analysis of `lib/term_ui/widgets/`:

1. **gauge** - Progress/value indicator with zones
2. **sparkline** - Inline trend visualization
3. **bar_chart** - Comparative bar charts
4. **line_chart** - Time series data
5. **table** - Tabular data with selection
6. **menu** - Hierarchical menu with actions
7. **dialog** - Modal dialogs
8. **alert_dialog** - Alert/confirmation dialogs
9. **tabs** - Tabbed content panels
10. **viewport** - Scrollable content area
11. **scroll_bar** - Scrollbar indicator
12. **canvas** - Freeform drawing
13. **context_menu** - Right-click menus
14. **toast** - Notification toasts

## Implementation Plan

### Phase 1: Simple Display Widgets
- [x] gauge example - Shows percentage gauge with color zones
- [x] sparkline example - Shows trend data visualization
- [x] bar_chart example - Horizontal and vertical bar charts

### Phase 2: Data Widgets
- [x] table example - Data table with selection and scrolling
- [x] line_chart example - Time series with multiple data points

### Phase 3: Navigation Widgets
- [x] menu example - Hierarchical menu with submenus and actions
- [x] tabs example - Tabbed interface switching content
- [ ] context_menu example - Right-click context menu (deferred - similar to menu)

### Phase 4: Overlay Widgets
- [x] dialog example - Modal dialog with buttons
- [ ] alert_dialog example - Confirmation dialog (deferred - covered by dialog)
- [ ] toast example - Toast notifications (deferred)

### Phase 5: Container Widgets
- [x] viewport example - Scrollable content viewport
- [ ] scroll_bar example - Standalone scrollbar (deferred - used within viewport)
- [x] canvas example - Drawing on canvas

### Phase 6: Documentation
- [x] Update examples/README.md with list of all examples
- [x] Create notes/summaries/widget-examples.md

## Example Structure

Each example follows this structure:

```
examples/<widget_name>/
├── mix.exs              # Mix project file
├── README.md            # Installation and usage instructions
├── run.exs              # Script to run the example
└── lib/
    └── <widget_name>/
        ├── application.ex  # Application module
        └── app.ex          # Main component with widget usage
```

## Status

- Completed: 2024-11-25
- Branch: feature/widget-examples

## Examples Created

| Example | Files | Features Demonstrated |
|---------|-------|----------------------|
| gauge | 5 | Color zones, bar/arc styles, labels |
| sparkline | 5 | Value colors, min/max tracking |
| bar_chart | 5 | Horizontal/vertical, colors, labels |
| table | 5 | Columns, selection, scrolling |
| line_chart | 5 | Braille graphics, multiple series |
| menu | 5 | Actions, submenus, checkboxes, radio |
| tabs | 5 | Tab switching, dynamic tabs |
| dialog | 5 | Confirmation, info, warning, error |
| viewport | 5 | Keyboard/mouse scrolling |
| canvas | 5 | Primitives, rectangles, Braille |

## Notes

- Keep examples minimal - focus on demonstrating the widget, not complex application logic
- Include comments in code explaining each widget option
- Some widgets were deferred as they are variations of implemented examples
- Pre-existing dashboard example serves as a multi-widget integration example
