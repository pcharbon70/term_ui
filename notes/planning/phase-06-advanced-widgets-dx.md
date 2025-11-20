# Phase 6: Advanced Widgets and Developer Experience

## Overview

This phase implements advanced widgets that handle complex UI patterns and developer experience features that improve productivity. Advanced widgets build on the foundation established in previous phases—using layouts for complex positioning, styling for visual polish, and the event system for rich interactions. Developer experience features leverage BEAM's introspection and hot code reloading for rapid development.

By the end of this phase, we will have Table for multi-column data display with sorting and scrolling, Tabs and Menu for navigation patterns, Dialog for modal overlays, Chart for data visualization, Viewport for scrollable content, Canvas for custom drawing, a development mode with UI inspector showing component boundaries and state, hot reload integration for code updates without restart, and a testing framework for component testing.

These additions transform TermUI from a foundation into a complete framework ready for production applications. Advanced widgets cover the remaining common UI patterns. Developer experience features make building applications faster and more enjoyable. Together they provide everything needed to build professional terminal applications.

---

## 6.1 Table Widget

- [ ] **Section 6.1 Complete**

Table displays tabular data with columns, headers, sorting, and scrolling. Tables are complex widgets handling large datasets efficiently, supporting user interaction (selection, sorting, editing), and providing flexible column configuration. This is one of the most commonly needed widgets for data-driven applications.

We implement virtual scrolling for performance with large datasets—only visible rows render. Columns support fixed and proportional widths. Headers enable click-to-sort. Cells support custom rendering for formatted data (dates, currencies, status indicators).

### 6.1.1 Table Structure

- [ ] **Task 6.1.1 Complete**

Table structure defines columns, data, and configuration. Columns specify header text, width constraints, data accessor, and optional renderer. Data is a list of rows, each row a map or struct. Configuration includes selection mode, sorting, and visual options.

- [ ] 6.1.1.1 Define column spec: `%Column{header: String.t(), key: atom, width: constraint, render: fun}`
- [ ] 6.1.1.2 Implement data binding accepting list of row maps
- [ ] 6.1.1.3 Implement configuration props: `:single_select`, `:multi_select`, `:sortable`
- [ ] 6.1.1.4 Implement style props for header, rows, selected rows, alternating backgrounds

### 6.1.2 Column Layout

- [ ] **Task 6.1.2 Complete**

Column layout distributes available width among columns. Columns may have fixed widths, percentages, or flexible sizing. The table integrates with the constraint solver from Phase 4 for width calculation. Column widths update on table resize.

- [ ] 6.1.2.1 Implement column width calculation using constraint solver
- [ ] 6.1.2.2 Support fixed width: `Constraint.length(20)`
- [ ] 6.1.2.3 Support proportional width: `Constraint.ratio(2)`
- [ ] 6.1.2.4 Implement column resize handles (drag to adjust width)

### 6.1.3 Virtual Scrolling

- [ ] **Task 6.1.3 Complete**

Virtual scrolling renders only visible rows, enabling tables with thousands of rows without performance degradation. We calculate visible range from scroll position and table height, render only those rows, and update on scroll.

- [ ] 6.1.3.1 Implement scroll state tracking scroll offset
- [ ] 6.1.3.2 Implement visible range calculation from offset and height
- [ ] 6.1.3.3 Implement row recycling rendering only visible rows
- [ ] 6.1.3.4 Implement smooth scrolling with keyboard and mouse wheel

### 6.1.4 Selection and Navigation

- [ ] **Task 6.1.4 Complete**

Selection supports single row, multiple rows, and range selection. Navigation uses arrow keys for row movement and Tab for cell navigation. Selection state notifies parent through callbacks.

- [ ] 6.1.4.1 Implement single selection with arrow keys and click
- [ ] 6.1.4.2 Implement multi-selection with Ctrl+click and Shift+click
- [ ] 6.1.4.3 Implement keyboard navigation: arrows, PageUp/Down, Home/End
- [ ] 6.1.4.4 Implement `on_select` callback for selection changes

### 6.1.5 Sorting

- [ ] **Task 6.1.5 Complete**

Sorting reorders rows by column values. Clicking column header toggles sort direction (ascending, descending, none). We support multiple sort criteria for secondary sorting. Sort state displays indicator in header.

- [ ] 6.1.5.1 Implement sort state tracking sort column and direction
- [ ] 6.1.5.2 Implement header click handling toggling sort
- [ ] 6.1.5.3 Implement row sorting by column values
- [ ] 6.1.5.4 Implement sort indicator (▲/▼) in header

### Unit Tests - Section 6.1

- [ ] **Unit Tests 6.1 Complete**
- [ ] Test table renders correct columns and headers
- [ ] Test column width calculation distributes space correctly
- [ ] Test virtual scrolling renders only visible rows
- [ ] Test selection state updates on row click
- [ ] Test keyboard navigation moves between rows
- [ ] Test sorting reorders rows by column

---

## 6.2 Navigation Widgets

- [ ] **Section 6.2 Complete**

Navigation widgets provide patterns for organizing content and actions. Tabs display multiple panels with tab bar for switching. Menu displays hierarchical actions with keyboard navigation. These widgets are essential for any non-trivial application.

### 6.2.1 Tabs Widget

- [ ] **Task 6.2.1 Complete**

Tabs organize content into switchable panels. A tab bar displays tab labels; clicking a tab shows its content panel. Tabs support dynamic addition/removal, disabled tabs, and closeable tabs.

- [ ] 6.2.1.1 Implement tab bar rendering with tab labels
- [ ] 6.2.1.2 Implement content panel switching on tab selection
- [ ] 6.2.1.3 Implement keyboard navigation: Left/Right for tabs, Enter to select
- [ ] 6.2.1.4 Implement disabled and closeable tab variants
- [ ] 6.2.1.5 Implement `on_change` callback for tab switches

### 6.2.2 Menu Widget

- [ ] **Task 6.2.2 Complete**

Menu displays a hierarchical list of actions. Items can be selectable actions, submenus, separators, or checkboxes. Menu supports keyboard navigation, mnemonics, and shortcuts display.

- [ ] 6.2.2.1 Implement menu item types: action, submenu, separator, checkbox
- [ ] 6.2.2.2 Implement menu rendering with indentation for hierarchy
- [ ] 6.2.2.3 Implement keyboard navigation: arrows to move, Enter to select
- [ ] 6.2.2.4 Implement submenu expansion showing nested items
- [ ] 6.2.2.5 Implement shortcut display aligned right

### 6.2.3 Context Menu

- [ ] **Task 6.2.3 Complete**

Context menu appears at cursor position on right-click or shortcut key. It uses the Menu widget rendered as a floating overlay. Context menu closes on selection, Escape, or click outside.

- [ ] 6.2.3.1 Implement context menu trigger on right-click or shortcut
- [ ] 6.2.3.2 Implement floating overlay positioning at click location
- [ ] 6.2.3.3 Implement close on selection, Escape, or outside click
- [ ] 6.2.3.4 Implement z-order ensuring context menu above other content

### Unit Tests - Section 6.2

- [ ] **Unit Tests 6.2 Complete**
- [ ] Test tabs render tab bar with labels
- [ ] Test tab selection shows correct content panel
- [ ] Test keyboard navigation moves between tabs
- [ ] Test menu renders items with correct hierarchy
- [ ] Test menu selection triggers action
- [ ] Test context menu appears at click position
- [ ] Test context menu closes on selection

---

## 6.3 Overlay Widgets

- [ ] **Section 6.3 Complete**

Overlay widgets display content above the normal component tree—modals, dialogs, and toasts. They use z-ordering to appear on top, focus trapping to keep interaction within the overlay, and backdrop to visually separate from background content.

### 6.3.1 Dialog Widget

- [ ] **Task 6.3.1 Complete**

Dialog is a modal overlay for user interaction—confirmations, forms, messages. It appears centered over the application with a backdrop. Dialog traps focus and handles Escape for cancellation.

- [ ] 6.3.1.1 Implement dialog container with title bar and content area
- [ ] 6.3.1.2 Implement centering within terminal window
- [ ] 6.3.1.3 Implement backdrop rendering behind dialog
- [ ] 6.3.1.4 Implement focus trapping preventing Tab escape
- [ ] 6.3.1.5 Implement Escape handling for dialog close
- [ ] 6.3.1.6 Implement `on_close` and `on_confirm` callbacks

### 6.3.2 Alert Dialog

- [ ] **Task 6.3.2 Complete**

Alert dialog is a specialized dialog for confirmations and messages. It includes standard buttons (OK, Cancel, Yes/No) and icon indication for type (info, warning, error, success).

- [ ] 6.3.2.1 Implement alert types: info, warning, error, success, confirm
- [ ] 6.3.2.2 Implement standard button configurations: OK, OK/Cancel, Yes/No
- [ ] 6.3.2.3 Implement icon display for alert type
- [ ] 6.3.2.4 Implement default focus on appropriate button

### 6.3.3 Toast Notifications

- [ ] **Task 6.3.3 Complete**

Toast notifications display brief messages that auto-dismiss. They appear at screen edge (typically bottom-right) and stack when multiple appear. Toasts don't capture focus or block interaction.

- [ ] 6.3.3.1 Implement toast positioning at screen edge
- [ ] 6.3.3.2 Implement auto-dismiss with configurable duration
- [ ] 6.3.3.3 Implement toast stacking for multiple notifications
- [ ] 6.3.3.4 Implement toast types: info, success, warning, error

### Unit Tests - Section 6.3

- [ ] **Unit Tests 6.3 Complete**
- [ ] Test dialog renders centered with backdrop
- [ ] Test dialog traps focus within content
- [ ] Test Escape closes dialog
- [ ] Test alert shows correct buttons for type
- [ ] Test toast appears at correct position
- [ ] Test toast auto-dismisses after duration
- [ ] Test multiple toasts stack

---

## 6.4 Visualization Widgets

- [ ] **Section 6.4 Complete**

Visualization widgets display data graphically using text characters. Charts use block elements and Braille characters for higher resolution. These widgets make data dashboards and monitoring applications possible.

### 6.4.1 Bar Chart

- [ ] **Task 6.4.1 Complete**

Bar chart displays data as horizontal or vertical bars. Bars scale to data values within available space. Labels show data values. Colors differentiate series.

- [ ] 6.4.1.1 Implement horizontal bar chart with value-proportional bars
- [ ] 6.4.1.2 Implement vertical bar chart with value-proportional bars
- [ ] 6.4.1.3 Implement axis labels and value display
- [ ] 6.4.1.4 Implement multiple series with different colors

### 6.4.2 Sparkline

- [ ] **Task 6.4.2 Complete**

Sparkline is a compact inline chart showing trends. It uses vertical bar characters (▁▂▃▄▅▆▇█) to display values in minimal space. Sparklines fit within text lines for inline data display.

- [ ] 6.4.2.1 Implement value to bar character mapping
- [ ] 6.4.2.2 Implement automatic value scaling to available range
- [ ] 6.4.2.3 Implement horizontal sparkline rendering
- [ ] 6.4.2.4 Implement color coding for value ranges

### 6.4.3 Line Chart (Braille)

- [ ] **Task 6.4.3 Complete**

Line chart uses Braille patterns for sub-character resolution. Each Braille cell is 2x4 pixels, enabling smooth lines in text mode. This provides detailed visualization for time series data.

- [ ] 6.4.3.1 Implement Braille dot pattern calculation from coordinates
- [ ] 6.4.3.2 Implement line drawing between data points
- [ ] 6.4.3.3 Implement axis rendering with labels
- [ ] 6.4.3.4 Implement multiple data series with colors

### 6.4.4 Gauge Widget

- [ ] **Task 6.4.4 Complete**

Gauge displays a single value in context of its range—like a speedometer. Uses arc or bar representation with labeled min/max and colored zones (green/yellow/red).

- [ ] 6.4.4.1 Implement gauge rendering with value indicator
- [ ] 6.4.4.2 Implement range display with min/max labels
- [ ] 6.4.4.3 Implement color zones for value ranges
- [ ] 6.4.4.4 Implement value label display

### Unit Tests - Section 6.4

- [ ] **Unit Tests 6.4 Complete**
- [ ] Test bar chart renders bars proportional to values
- [ ] Test sparkline maps values to correct bar characters
- [ ] Test Braille chart calculates dot patterns correctly
- [ ] Test line chart draws lines between points
- [ ] Test gauge displays value within range

---

## 6.5 Scrollable Content Widgets

- [ ] **Section 6.5 Complete**

Scrollable content widgets handle content larger than their display area. Viewport scrolls arbitrary content. Canvas provides direct drawing access for custom rendering. These widgets enable complex content patterns.

### 6.5.1 Viewport Widget

- [ ] **Task 6.5.1 Complete**

Viewport displays a scrollable view of larger content. It maintains scroll position and clips content to display area. Scroll bars indicate position and provide click-to-scroll.

- [ ] 6.5.1.1 Implement content area larger than viewport
- [ ] 6.5.1.2 Implement scroll position tracking
- [ ] 6.5.1.3 Implement content clipping to viewport bounds
- [ ] 6.5.1.4 Implement scroll bars (vertical and horizontal)
- [ ] 6.5.1.5 Implement scroll bar interaction (click and drag)

### 6.5.2 ScrollBar Widget

- [ ] **Task 6.5.2 Complete**

ScrollBar is a standalone widget for scroll indication and control. It shows position within content and allows drag to scroll. Used by Viewport and other scrollable widgets.

- [ ] 6.5.2.1 Implement scroll bar rendering with track and thumb
- [ ] 6.5.2.2 Implement thumb size proportional to visible fraction
- [ ] 6.5.2.3 Implement drag scrolling moving content
- [ ] 6.5.2.4 Implement track click scrolling by page

### 6.5.3 Canvas Widget

- [ ] **Task 6.5.3 Complete**

Canvas provides direct access to render buffer for custom drawing. Applications draw using graphics primitives (line, rectangle, text). Canvas enables custom widgets and visualizations not covered by standard widgets.

- [ ] 6.5.3.1 Implement canvas with direct buffer access
- [ ] 6.5.3.2 Implement drawing primitives: `draw_line`, `draw_rect`, `draw_text`
- [ ] 6.5.3.3 Implement Braille drawing for sub-character graphics
- [ ] 6.5.3.4 Implement clear and fill operations
- [ ] 6.5.3.5 Implement custom render callback for application drawing

### Unit Tests - Section 6.5

- [ ] **Unit Tests 6.5 Complete**
- [ ] Test viewport clips content to bounds
- [ ] Test viewport scrolls with keyboard and mouse
- [ ] Test scroll bar thumb size reflects content ratio
- [ ] Test scroll bar drag updates scroll position
- [ ] Test canvas draws primitives correctly
- [ ] Test Braille drawing produces correct patterns

---

## 6.6 Development Mode

- [ ] **Section 6.6 Complete**

Development mode provides tools for building and debugging TUI applications. The UI inspector shows component boundaries and state. Hot reload updates code without restarting. These features leverage BEAM's runtime capabilities for excellent developer experience.

### 6.6.1 UI Inspector

- [ ] **Task 6.6.1 Complete**

UI inspector overlays information about components during development. It shows component boundaries, names, state summaries, and render times. Inspector toggles with keyboard shortcut and doesn't affect component behavior.

- [ ] 6.6.1.1 Implement inspector overlay rendering component boundaries
- [ ] 6.6.1.2 Implement component name and type display
- [ ] 6.6.1.3 Implement state summary for selected component
- [ ] 6.6.1.4 Implement render time display for performance debugging
- [ ] 6.6.1.5 Implement toggle shortcut (e.g., Ctrl+Shift+I)

### 6.6.2 State Inspector

- [ ] **Task 6.6.2 Complete**

State inspector shows detailed component state in a side panel. It displays state tree with expandable nodes. State updates highlight for visibility. Useful for debugging state management issues.

- [ ] 6.6.2.1 Implement state panel as side drawer
- [ ] 6.6.2.2 Implement tree view of component state
- [ ] 6.6.2.3 Implement expand/collapse for nested state
- [ ] 6.6.2.4 Implement state change highlighting

### 6.6.3 Hot Reload Integration

- [ ] **Task 6.6.3 Complete**

Hot reload updates component code without restarting the application. We leverage BEAM's hot code swapping through the code server. State is preserved across reloads where possible. This dramatically speeds up development iteration.

- [ ] 6.6.3.1 Implement file watcher for .ex file changes
- [ ] 6.6.3.2 Implement module recompilation on change
- [ ] 6.6.3.3 Implement code purge and load for updated modules
- [ ] 6.6.3.4 Implement state preservation across reload
- [ ] 6.6.3.5 Implement reload notification in UI

### 6.6.4 Performance Monitor

- [ ] **Task 6.6.4 Complete**

Performance monitor displays real-time metrics: FPS, frame time, memory usage, message queue depth. This helps identify performance issues during development.

- [ ] 6.6.4.1 Implement FPS counter with rolling average
- [ ] 6.6.4.2 Implement frame time graph
- [ ] 6.6.4.3 Implement memory usage display
- [ ] 6.6.4.4 Implement message queue monitoring

### Unit Tests - Section 6.6

- [ ] **Unit Tests 6.6 Complete**
- [ ] Test inspector overlay renders component boundaries
- [ ] Test state panel displays component state tree
- [ ] Test hot reload updates component code
- [ ] Test state preservation across reload
- [ ] Test performance metrics update in real-time

---

## 6.7 Testing Framework

- [ ] **Section 6.7 Complete**

The testing framework provides utilities for testing TermUI components. It includes test renderers, event simulation, and assertion helpers. This enables unit and integration testing of TUI applications without actual terminal interaction.

### 6.7.1 Test Renderer

- [ ] **Task 6.7.1 Complete**

Test renderer captures render output for assertions without actual terminal output. It implements the renderer interface, storing output in testable format. Tests can inspect rendered content, styles, and positions.

- [ ] 6.7.1.1 Implement test renderer capturing to buffer
- [ ] 6.7.1.2 Implement buffer inspection: `get_text_at(x, y, width)`
- [ ] 6.7.1.3 Implement style inspection: `get_style_at(x, y)`
- [ ] 6.7.1.4 Implement snapshot comparison for render output

### 6.7.2 Event Simulation

- [ ] **Task 6.7.2 Complete**

Event simulation generates events for testing without terminal input. We provide functions to create key events, mouse events, and other input. Events inject into the event system for handling.

- [ ] 6.7.2.1 Implement `simulate_key(key, modifiers)` creating key event
- [ ] 6.7.2.2 Implement `simulate_click(x, y, button)` creating mouse event
- [ ] 6.7.2.3 Implement `simulate_type(string)` for text input
- [ ] 6.7.2.4 Implement event injection into runtime

### 6.7.3 Assertion Helpers

- [ ] **Task 6.7.3 Complete**

Assertion helpers provide TUI-specific assertions for tests. They check rendered content, component state, and focus. Helpers produce clear failure messages showing expected vs actual.

- [ ] 6.7.3.1 Implement `assert_text(buffer, x, y, expected)` for content assertions
- [ ] 6.7.3.2 Implement `assert_focused(component)` for focus assertions
- [ ] 6.7.3.3 Implement `assert_state(component, path, expected)` for state assertions
- [ ] 6.7.3.4 Implement `refute_*` variants for negative assertions

### 6.7.4 Component Test Helper

- [ ] **Task 6.7.4 Complete**

Component test helper provides a test harness for individual components. It mounts the component in isolation, provides event simulation, and captures renders. This enables focused component testing.

- [ ] 6.7.4.1 Implement `mount_test(module, props)` creating test harness
- [ ] 6.7.4.2 Implement `send_event(harness, event)` for event testing
- [ ] 6.7.4.3 Implement `get_state(harness)` for state inspection
- [ ] 6.7.4.4 Implement `get_render(harness)` for render output

### Unit Tests - Section 6.7

- [ ] **Unit Tests 6.7 Complete**
- [ ] Test test renderer captures output correctly
- [ ] Test buffer inspection returns correct content
- [ ] Test event simulation creates valid events
- [ ] Test assertions produce clear failure messages
- [ ] Test component harness mounts and renders

---

## 6.8 Integration Tests

- [ ] **Section 6.8 Complete**

Integration tests validate advanced widgets and developer tools working together. We test complex UI patterns, development workflow, and testing framework functionality.

### 6.8.1 Advanced Widget Testing

- [ ] **Task 6.8.1 Complete**

We test advanced widgets in realistic scenarios: tables with sorting and selection, tabs with dynamic content, dialogs with forms.

- [ ] 6.8.1.1 Test table with 1000 rows virtual scrolling and selection
- [ ] 6.8.1.2 Test tabs switching with dynamic content loading
- [ ] 6.8.1.3 Test dialog form with validation and submission
- [ ] 6.8.1.4 Test chart rendering with real-time data updates

### 6.8.2 Development Workflow Testing

- [ ] **Task 6.8.2 Complete**

We test development workflow features: inspector toggle, hot reload cycle, performance monitoring.

- [ ] 6.8.2.1 Test inspector toggle shows/hides component boundaries
- [ ] 6.8.2.2 Test hot reload updates component behavior
- [ ] 6.8.2.3 Test state preservation across hot reload
- [ ] 6.8.2.4 Test performance metrics display correctly

### 6.8.3 Testing Framework Validation

- [ ] **Task 6.8.3 Complete**

We test the testing framework itself, ensuring test utilities work correctly.

- [ ] 6.8.3.1 Test test renderer matches actual render output
- [ ] 6.8.3.2 Test event simulation produces expected state changes
- [ ] 6.8.3.3 Test assertions detect both passing and failing conditions
- [ ] 6.8.3.4 Test component harness isolates components correctly

---

## Success Criteria

1. **Advanced Widgets**: Table, Tabs, Menu, Dialog, Chart, Viewport, Canvas fully functional
2. **Table Performance**: Virtual scrolling handles 10,000+ rows at 60 FPS
3. **Development Mode**: Inspector and hot reload working for rapid development
4. **Testing Framework**: Complete testing utilities for component testing
5. **Documentation**: All widgets documented with examples
6. **Test Coverage**: 85% test coverage with comprehensive unit and integration tests

## Provides Foundation

This phase completes the framework, providing:
- Full widget set for building complete applications
- Developer tools for productive development
- Testing utilities for maintainable applications
- Production-ready framework for terminal UIs

## Key Outputs

- Table widget with virtual scrolling, sorting, selection
- Navigation widgets (Tabs, Menu, Context Menu)
- Overlay widgets (Dialog, Alert, Toast)
- Visualization widgets (Bar Chart, Sparkline, Line Chart, Gauge)
- Scrollable content widgets (Viewport, ScrollBar, Canvas)
- Development mode with UI inspector and state viewer
- Hot reload integration for rapid development
- Testing framework with test renderer, simulation, assertions
- Comprehensive test suite covering all advanced features
- API documentation for all widgets and tools
