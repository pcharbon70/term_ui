# Widget Examples Summary

## Overview

Created a comprehensive set of widget examples demonstrating TermUI's widget library. Each example is a standalone Mix project with documentation and well-commented code.

## Examples Created

### 1. Gauge (`examples/gauge/`)
Demonstrates progress indicators with:
- Color zones (green/yellow/red based on value)
- Bar and arc display styles
- Label positioning
- Interactive value adjustment

### 2. Sparkline (`examples/sparkline/`)
Demonstrates compact time series visualization with:
- Value-based color coding
- Min/max value tracking
- Data history management
- Real-time updates

### 3. Bar Chart (`examples/bar_chart/`)
Demonstrates categorical data visualization with:
- Horizontal and vertical orientations
- Custom bar colors
- Value labels
- Auto-scaling

### 4. Table (`examples/table/`)
Demonstrates structured data display with:
- Column definitions and constraints (fixed, flex, percentage)
- Row selection and highlighting
- Keyboard navigation
- Scrolling for large datasets

### 5. Line Chart (`examples/line_chart/`)
Demonstrates trend visualization with:
- Braille characters for sub-character resolution
- Multiple data series
- Auto-scaling Y-axis
- Legend display
- Pattern generation (sine, sawtooth, random)

### 6. Menu (`examples/menu/`)
Demonstrates hierarchical menus with:
- Action items with keyboard shortcuts
- Submenus (nested menus)
- Checkbox items (toggle state)
- Radio groups (mutually exclusive selection)
- Disabled items
- Separators

### 7. Tabs (`examples/tabs/`)
Demonstrates tabbed interfaces with:
- Multiple tab panels
- Tab switching with keyboard
- Dynamic tab creation
- Tab closing
- Active tab highlighting

### 8. Dialog (`examples/dialog/`)
Demonstrates modal dialogs with:
- Confirmation dialogs (Yes/No/Cancel)
- Information dialogs
- Warning dialogs
- Error dialogs
- Button navigation
- Dialog overlay rendering

### 9. Viewport (`examples/viewport/`)
Demonstrates scrollable content with:
- Keyboard scrolling (arrow keys, Page Up/Down, Home/End)
- Content larger than viewport
- Scroll position indicators
- Dynamic content generation

### 10. Canvas (`examples/canvas/`)
Demonstrates custom drawing with:
- Text rendering at positions
- Line drawing (horizontal, vertical, diagonal with Bresenham)
- Rectangle drawing with various border styles
- Braille characters for sub-character resolution
- Multiple demo modes

## Structure

Each example follows a consistent structure:

```
example_name/
├── mix.exs              # Mix project configuration
├── run.exs              # Entry point script
├── README.md            # Documentation with API examples
└── lib/
    └── example_name/
        ├── application.ex  # OTP application
        └── app.ex          # Main component (well-documented)
```

## Files Created

- `examples/README.md` - Overview of all examples
- 10 example directories with complete implementations
- Each example contains 5 files (mix.exs, run.exs, README.md, application.ex, app.ex)

## Key Patterns Demonstrated

### Elm Architecture
All examples implement the `TermUI.Component` behaviour:
- `init/1` - State initialization
- `event_to_msg/2` - Event to message conversion
- `update/2` - State updates with commands
- `view/1` - Render tree construction

### Event Handling
- Keyboard events with case-insensitive matching
- Quit command pattern
- Message-based state updates

### Widget Composition
- Using `stack/2` for layout
- Combining multiple widgets
- Styling with `TermUI.Style`

## Pre-existing Example

The `dashboard` example existed before this work and demonstrates combining multiple widgets into a complete application.

## Running Examples

```bash
cd examples/<name>
mix deps.get
mix run run.exs
```

All examples support `Q` to quit.
