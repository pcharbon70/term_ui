# Phase 6: Advanced Widgets and Developer Experience

## Overview

This phase implements advanced widgets that handle complex UI patterns and developer experience features that improve productivity. Advanced widgets build on the foundation established in previous phases—using layouts for complex positioning, styling for visual polish, and the event system for rich interactions. Developer experience features leverage BEAM's introspection and hot code reloading for rapid development.

By the end of this phase, we will have Table for multi-column data display with sorting and scrolling, Tabs and Menu for navigation patterns, Dialog for modal overlays, Chart for data visualization, Viewport for scrollable content, Canvas for custom drawing, a development mode with UI inspector showing component boundaries and state, hot reload integration for code updates without restart, and a testing framework for component testing.

These additions transform TermUI from a foundation into a complete framework ready for production applications. Advanced widgets cover the remaining common UI patterns. Developer experience features make building applications faster and more enjoyable. Together they provide everything needed to build professional terminal applications.

---

## 6.1 Table Widget

- [x] **Section 6.1 Complete**

Table displays tabular data with columns, headers, sorting, and scrolling. Tables are complex widgets handling large datasets efficiently, supporting user interaction (selection, sorting, editing), and providing flexible column configuration. This is one of the most commonly needed widgets for data-driven applications.

We implement virtual scrolling for performance with large datasets—only visible rows render. Columns support fixed and proportional widths. Headers enable click-to-sort. Cells support custom rendering for formatted data (dates, currencies, status indicators).

### 6.1.1 Table Structure

- [x] **Task 6.1.1 Complete**

Table structure defines columns, data, and configuration. Columns specify header text, width constraints, data accessor, and optional renderer. Data is a list of rows, each row a map or struct. Configuration includes selection mode, sorting, and visual options.

- [x] 6.1.1.1 Define column spec: `%Column{header: String.t(), key: atom, width: constraint, render: fun}`
- [x] 6.1.1.2 Implement data binding accepting list of row maps
- [x] 6.1.1.3 Implement configuration props: `:single_select`, `:multi_select`, `:sortable`
- [x] 6.1.1.4 Implement style props for header, rows, selected rows, alternating backgrounds

### 6.1.2 Column Layout

- [x] **Task 6.1.2 Complete**

Column layout distributes available width among columns. Columns may have fixed widths, percentages, or flexible sizing. The table integrates with the constraint solver from Phase 4 for width calculation. Column widths update on table resize.

- [x] 6.1.2.1 Implement column width calculation using constraint solver
- [x] 6.1.2.2 Support fixed width: `Constraint.length(20)`
- [x] 6.1.2.3 Support proportional width: `Constraint.ratio(2)`
- [x] 6.1.2.4 Implement column resize handles (drag to adjust width)

### 6.1.3 Virtual Scrolling

- [x] **Task 6.1.3 Complete**

Virtual scrolling renders only visible rows, enabling tables with thousands of rows without performance degradation. We calculate visible range from scroll position and table height, render only those rows, and update on scroll.

- [x] 6.1.3.1 Implement scroll state tracking scroll offset
- [x] 6.1.3.2 Implement visible range calculation from offset and height
- [x] 6.1.3.3 Implement row recycling rendering only visible rows
- [x] 6.1.3.4 Implement smooth scrolling with keyboard and mouse wheel

### 6.1.4 Selection and Navigation

- [x] **Task 6.1.4 Complete**

Selection supports single row, multiple rows, and range selection. Navigation uses arrow keys for row movement and Tab for cell navigation. Selection state notifies parent through callbacks.

- [x] 6.1.4.1 Implement single selection with arrow keys and click
- [x] 6.1.4.2 Implement multi-selection with Ctrl+click and Shift+click
- [x] 6.1.4.3 Implement keyboard navigation: arrows, PageUp/Down, Home/End
- [x] 6.1.4.4 Implement `on_select` callback for selection changes

### 6.1.5 Sorting

- [x] **Task 6.1.5 Complete**

Sorting reorders rows by column values. Clicking column header toggles sort direction (ascending, descending, none). We support multiple sort criteria for secondary sorting. Sort state displays indicator in header.

- [x] 6.1.5.1 Implement sort state tracking sort column and direction
- [x] 6.1.5.2 Implement header click handling toggling sort
- [x] 6.1.5.3 Implement row sorting by column values
- [x] 6.1.5.4 Implement sort indicator (▲/▼) in header

### Unit Tests - Section 6.1

- [x] **Unit Tests 6.1 Complete**
- [x] Test table renders correct columns and headers
- [x] Test column width calculation distributes space correctly
- [x] Test virtual scrolling renders only visible rows
- [x] Test selection state updates on row click
- [x] Test keyboard navigation moves between rows
- [x] Test sorting reorders rows by column

---

## 6.2 Navigation Widgets

- [x] **Section 6.2 Complete**

Navigation widgets provide patterns for organizing content and actions. Tabs display multiple panels with tab bar for switching. Menu displays hierarchical actions with keyboard navigation. These widgets are essential for any non-trivial application.

### 6.2.1 Tabs Widget

- [x] **Task 6.2.1 Complete**

Tabs organize content into switchable panels. A tab bar displays tab labels; clicking a tab shows its content panel. Tabs support dynamic addition/removal, disabled tabs, and closeable tabs.

- [x] 6.2.1.1 Implement tab bar rendering with tab labels
- [x] 6.2.1.2 Implement content panel switching on tab selection
- [x] 6.2.1.3 Implement keyboard navigation: Left/Right for tabs, Enter to select
- [x] 6.2.1.4 Implement disabled and closeable tab variants
- [x] 6.2.1.5 Implement `on_change` callback for tab switches

### 6.2.2 Menu Widget

- [x] **Task 6.2.2 Complete**

Menu displays a hierarchical list of actions. Items can be selectable actions, submenus, separators, or checkboxes. Menu supports keyboard navigation, mnemonics, and shortcuts display.

- [x] 6.2.2.1 Implement menu item types: action, submenu, separator, checkbox
- [x] 6.2.2.2 Implement menu rendering with indentation for hierarchy
- [x] 6.2.2.3 Implement keyboard navigation: arrows to move, Enter to select
- [x] 6.2.2.4 Implement submenu expansion showing nested items
- [x] 6.2.2.5 Implement shortcut display aligned right

### 6.2.3 Context Menu

- [x] **Task 6.2.3 Complete**

Context menu appears at cursor position on right-click or shortcut key. It uses the Menu widget rendered as a floating overlay. Context menu closes on selection, Escape, or click outside.

- [x] 6.2.3.1 Implement context menu trigger on right-click or shortcut
- [x] 6.2.3.2 Implement floating overlay positioning at click location
- [x] 6.2.3.3 Implement close on selection, Escape, or outside click
- [x] 6.2.3.4 Implement z-order ensuring context menu above other content

### Unit Tests - Section 6.2

- [x] **Unit Tests 6.2 Complete**
- [x] Test tabs render tab bar with labels
- [x] Test tab selection shows correct content panel
- [x] Test keyboard navigation moves between tabs
- [x] Test menu renders items with correct hierarchy
- [x] Test menu selection triggers action
- [x] Test context menu appears at click position
- [x] Test context menu closes on selection

---

## 6.3 Overlay Widgets

- [x] **Section 6.3 Complete**

Overlay widgets display content above the normal component tree—modals, dialogs, and toasts. They use z-ordering to appear on top, focus trapping to keep interaction within the overlay, and backdrop to visually separate from background content.

### 6.3.1 Dialog Widget

- [x] **Task 6.3.1 Complete**

Dialog is a modal overlay for user interaction—confirmations, forms, messages. It appears centered over the application with a backdrop. Dialog traps focus and handles Escape for cancellation.

- [x] 6.3.1.1 Implement dialog container with title bar and content area
- [x] 6.3.1.2 Implement centering within terminal window
- [x] 6.3.1.3 Implement backdrop rendering behind dialog
- [x] 6.3.1.4 Implement focus trapping preventing Tab escape
- [x] 6.3.1.5 Implement Escape handling for dialog close
- [x] 6.3.1.6 Implement `on_close` and `on_confirm` callbacks

### 6.3.2 Alert Dialog

- [x] **Task 6.3.2 Complete**

Alert dialog is a specialized dialog for confirmations and messages. It includes standard buttons (OK, Cancel, Yes/No) and icon indication for type (info, warning, error, success).

- [x] 6.3.2.1 Implement alert types: info, warning, error, success, confirm
- [x] 6.3.2.2 Implement standard button configurations: OK, OK/Cancel, Yes/No
- [x] 6.3.2.3 Implement icon display for alert type
- [x] 6.3.2.4 Implement default focus on appropriate button

### 6.3.3 Toast Notifications

- [x] **Task 6.3.3 Complete**

Toast notifications display brief messages that auto-dismiss. They appear at screen edge (typically bottom-right) and stack when multiple appear. Toasts don't capture focus or block interaction.

- [x] 6.3.3.1 Implement toast positioning at screen edge
- [x] 6.3.3.2 Implement auto-dismiss with configurable duration
- [x] 6.3.3.3 Implement toast stacking for multiple notifications
- [x] 6.3.3.4 Implement toast types: info, success, warning, error

### Unit Tests - Section 6.3

- [x] **Unit Tests 6.3 Complete**
- [x] Test dialog renders centered with backdrop
- [x] Test dialog traps focus within content
- [x] Test Escape closes dialog
- [x] Test alert shows correct buttons for type
- [x] Test toast appears at correct position
- [x] Test toast auto-dismisses after duration
- [x] Test multiple toasts stack

---

## 6.4 Visualization Widgets

- [x] **Section 6.4 Complete**

Visualization widgets display data graphically using text characters. Charts use block elements and Braille characters for higher resolution. These widgets make data dashboards and monitoring applications possible.

### 6.4.1 Bar Chart

- [x] **Task 6.4.1 Complete**

Bar chart displays data as horizontal or vertical bars. Bars scale to data values within available space. Labels show data values. Colors differentiate series.

- [x] 6.4.1.1 Implement horizontal bar chart with value-proportional bars
- [x] 6.4.1.2 Implement vertical bar chart with value-proportional bars
- [x] 6.4.1.3 Implement axis labels and value display
- [x] 6.4.1.4 Implement multiple series with different colors

### 6.4.2 Sparkline

- [x] **Task 6.4.2 Complete**

Sparkline is a compact inline chart showing trends. It uses vertical bar characters (▁▂▃▄▅▆▇█) to display values in minimal space. Sparklines fit within text lines for inline data display.

- [x] 6.4.2.1 Implement value to bar character mapping
- [x] 6.4.2.2 Implement automatic value scaling to available range
- [x] 6.4.2.3 Implement horizontal sparkline rendering
- [x] 6.4.2.4 Implement color coding for value ranges

### 6.4.3 Line Chart (Braille)

- [x] **Task 6.4.3 Complete**

Line chart uses Braille patterns for sub-character resolution. Each Braille cell is 2x4 pixels, enabling smooth lines in text mode. This provides detailed visualization for time series data.

- [x] 6.4.3.1 Implement Braille dot pattern calculation from coordinates
- [x] 6.4.3.2 Implement line drawing between data points
- [x] 6.4.3.3 Implement axis rendering with labels
- [x] 6.4.3.4 Implement multiple data series with colors

### 6.4.4 Gauge Widget

- [x] **Task 6.4.4 Complete**

Gauge displays a single value in context of its range—like a speedometer. Uses arc or bar representation with labeled min/max and colored zones (green/yellow/red).

- [x] 6.4.4.1 Implement gauge rendering with value indicator
- [x] 6.4.4.2 Implement range display with min/max labels
- [x] 6.4.4.3 Implement color zones for value ranges
- [x] 6.4.4.4 Implement value label display

### Unit Tests - Section 6.4

- [x] **Unit Tests 6.4 Complete**
- [x] Test bar chart renders bars proportional to values
- [x] Test sparkline maps values to correct bar characters
- [x] Test Braille chart calculates dot patterns correctly
- [x] Test line chart draws lines between points
- [x] Test gauge displays value within range

---

## 6.5 Scrollable Content Widgets

- [x] **Section 6.5 Complete**

Scrollable content widgets handle content larger than their display area. Viewport scrolls arbitrary content. Canvas provides direct drawing access for custom rendering. These widgets enable complex content patterns.

### 6.5.1 Viewport Widget

- [x] **Task 6.5.1 Complete**

Viewport displays a scrollable view of larger content. It maintains scroll position and clips content to display area. Scroll bars indicate position and provide click-to-scroll.

- [x] 6.5.1.1 Implement content area larger than viewport
- [x] 6.5.1.2 Implement scroll position tracking
- [x] 6.5.1.3 Implement content clipping to viewport bounds
- [x] 6.5.1.4 Implement scroll bars (vertical and horizontal)
- [x] 6.5.1.5 Implement scroll bar interaction (click and drag)

### 6.5.2 ScrollBar Widget

- [x] **Task 6.5.2 Complete**

ScrollBar is a standalone widget for scroll indication and control. It shows position within content and allows drag to scroll. Used by Viewport and other scrollable widgets.

- [x] 6.5.2.1 Implement scroll bar rendering with track and thumb
- [x] 6.5.2.2 Implement thumb size proportional to visible fraction
- [x] 6.5.2.3 Implement drag scrolling moving content
- [x] 6.5.2.4 Implement track click scrolling by page

### 6.5.3 Canvas Widget

- [x] **Task 6.5.3 Complete**

Canvas provides direct access to render buffer for custom drawing. Applications draw using graphics primitives (line, rectangle, text). Canvas enables custom widgets and visualizations not covered by standard widgets.

- [x] 6.5.3.1 Implement canvas with direct buffer access
- [x] 6.5.3.2 Implement drawing primitives: `draw_line`, `draw_rect`, `draw_text`
- [x] 6.5.3.3 Implement Braille drawing for sub-character graphics
- [x] 6.5.3.4 Implement clear and fill operations
- [x] 6.5.3.5 Implement custom render callback for application drawing

### Unit Tests - Section 6.5

- [x] **Unit Tests 6.5 Complete**
- [x] Test viewport clips content to bounds
- [x] Test viewport scrolls with keyboard and mouse
- [x] Test scroll bar thumb size reflects content ratio
- [x] Test scroll bar drag updates scroll position
- [x] Test canvas draws primitives correctly
- [x] Test Braille drawing produces correct patterns

---

## 6.6 Development Mode

- [x] **Section 6.6 Complete**

Development mode provides tools for building and debugging TUI applications. The UI inspector shows component boundaries and state. Hot reload updates code without restarting. These features leverage BEAM's runtime capabilities for excellent developer experience.

### 6.6.1 UI Inspector

- [x] **Task 6.6.1 Complete**

UI inspector overlays information about components during development. It shows component boundaries, names, state summaries, and render times. Inspector toggles with keyboard shortcut and doesn't affect component behavior.

- [x] 6.6.1.1 Implement inspector overlay rendering component boundaries
- [x] 6.6.1.2 Implement component name and type display
- [x] 6.6.1.3 Implement state summary for selected component
- [x] 6.6.1.4 Implement render time display for performance debugging
- [x] 6.6.1.5 Implement toggle shortcut (e.g., Ctrl+Shift+I)

### 6.6.2 State Inspector

- [x] **Task 6.6.2 Complete**

State inspector shows detailed component state in a side panel. It displays state tree with expandable nodes. State updates highlight for visibility. Useful for debugging state management issues.

- [x] 6.6.2.1 Implement state panel as side drawer
- [x] 6.6.2.2 Implement tree view of component state
- [x] 6.6.2.3 Implement expand/collapse for nested state
- [x] 6.6.2.4 Implement state change highlighting

### 6.6.3 Hot Reload Integration

- [x] **Task 6.6.3 Complete**

Hot reload updates component code without restarting the application. We leverage BEAM's hot code swapping through the code server. State is preserved across reloads where possible. This dramatically speeds up development iteration.

- [x] 6.6.3.1 Implement file watcher for .ex file changes
- [x] 6.6.3.2 Implement module recompilation on change
- [x] 6.6.3.3 Implement code purge and load for updated modules
- [x] 6.6.3.4 Implement state preservation across reload
- [x] 6.6.3.5 Implement reload notification in UI

### 6.6.4 Performance Monitor

- [x] **Task 6.6.4 Complete**

Performance monitor displays real-time metrics: FPS, frame time, memory usage, message queue depth. This helps identify performance issues during development.

- [x] 6.6.4.1 Implement FPS counter with rolling average
- [x] 6.6.4.2 Implement frame time graph
- [x] 6.6.4.3 Implement memory usage display
- [x] 6.6.4.4 Implement message queue monitoring

### Unit Tests - Section 6.6

- [x] **Unit Tests 6.6 Complete**
- [x] Test inspector overlay renders component boundaries
- [x] Test state panel displays component state tree
- [x] Test hot reload updates component code
- [x] Test state preservation across reload
- [x] Test performance metrics update in real-time

---

## 6.7 Testing Framework

- [x] **Section 6.7 Complete**

The testing framework provides utilities for testing TermUI components. It includes test renderers, event simulation, and assertion helpers. This enables unit and integration testing of TUI applications without actual terminal interaction.

### 6.7.1 Test Renderer

- [x] **Task 6.7.1 Complete**

Test renderer captures render output for assertions without actual terminal output. It implements the renderer interface, storing output in testable format. Tests can inspect rendered content, styles, and positions.

- [x] 6.7.1.1 Implement test renderer capturing to buffer
- [x] 6.7.1.2 Implement buffer inspection: `get_text_at(x, y, width)`
- [x] 6.7.1.3 Implement style inspection: `get_style_at(x, y)`
- [x] 6.7.1.4 Implement snapshot comparison for render output

### 6.7.2 Event Simulation

- [x] **Task 6.7.2 Complete**

Event simulation generates events for testing without terminal input. We provide functions to create key events, mouse events, and other input. Events inject into the event system for handling.

- [x] 6.7.2.1 Implement `simulate_key(key, modifiers)` creating key event
- [x] 6.7.2.2 Implement `simulate_click(x, y, button)` creating mouse event
- [x] 6.7.2.3 Implement `simulate_type(string)` for text input
- [x] 6.7.2.4 Implement event injection into runtime

### 6.7.3 Assertion Helpers

- [x] **Task 6.7.3 Complete**

Assertion helpers provide TUI-specific assertions for tests. They check rendered content, component state, and focus. Helpers produce clear failure messages showing expected vs actual.

- [x] 6.7.3.1 Implement `assert_text(buffer, x, y, expected)` for content assertions
- [x] 6.7.3.2 Implement `assert_focused(component)` for focus assertions
- [x] 6.7.3.3 Implement `assert_state(component, path, expected)` for state assertions
- [x] 6.7.3.4 Implement `refute_*` variants for negative assertions

### 6.7.4 Component Test Helper

- [x] **Task 6.7.4 Complete**

Component test helper provides a test harness for individual components. It mounts the component in isolation, provides event simulation, and captures renders. This enables focused component testing.

- [x] 6.7.4.1 Implement `mount_test(module, props)` creating test harness
- [x] 6.7.4.2 Implement `send_event(harness, event)` for event testing
- [x] 6.7.4.3 Implement `get_state(harness)` for state inspection
- [x] 6.7.4.4 Implement `get_render(harness)` for render output

### Unit Tests - Section 6.7

- [x] **Unit Tests 6.7 Complete**
- [x] Test test renderer captures output correctly
- [x] Test buffer inspection returns correct content
- [x] Test event simulation creates valid events
- [x] Test assertions produce clear failure messages
- [x] Test component harness mounts and renders

---

## 6.8 Integration Tests

- [x] **Section 6.8 Complete**

Integration tests validate advanced widgets and developer tools working together. We test complex UI patterns, development workflow, and testing framework functionality.

### 6.8.1 Advanced Widget Testing

- [x] **Task 6.8.1 Complete**

We test advanced widgets in realistic scenarios: tables with sorting and selection, tabs with dynamic content, dialogs with forms.

- [x] 6.8.1.1 Test table with 1000 rows virtual scrolling and selection
- [x] 6.8.1.2 Test tabs switching with dynamic content loading
- [x] 6.8.1.3 Test dialog form with validation and submission
- [x] 6.8.1.4 Test chart rendering with real-time data updates

### 6.8.2 Development Workflow Testing

- [x] **Task 6.8.2 Complete**

We test development workflow features: inspector toggle, hot reload cycle, performance monitoring.

- [x] 6.8.2.1 Test inspector toggle shows/hides component boundaries
- [x] 6.8.2.2 Test hot reload updates component behavior
- [x] 6.8.2.3 Test state preservation across hot reload
- [x] 6.8.2.4 Test performance metrics display correctly

### 6.8.3 Testing Framework Validation

- [x] **Task 6.8.3 Complete**

We test the testing framework itself, ensuring test utilities work correctly.

- [x] 6.8.3.1 Test test renderer matches actual render output
- [x] 6.8.3.2 Test event simulation produces expected state changes
- [x] 6.8.3.3 Test assertions detect both passing and failing conditions
- [x] 6.8.3.4 Test component harness isolates components correctly

---

## 6.9 Advanced Input Widgets

- [ ] **Section 6.9 Complete**

Advanced input widgets provide structured data collection and power-user command interfaces. FormBuilder handles complex forms with validation. CommandPalette provides VS Code-style command discovery and execution.

### 6.9.1 FormBuilder Widget

- [ ] **Task 6.9.1 Complete**

FormBuilder renders structured forms with multiple field types, validation, and navigation. It handles complex data entry scenarios with conditional fields and grouping.

- [ ] 6.9.1.1 Define field types: text, password, checkbox, radio, select, multi-select
- [ ] 6.9.1.2 Implement field rendering with labels and error display
- [ ] 6.9.1.3 Implement Tab navigation between fields
- [ ] 6.9.1.4 Implement validation with error messages
- [ ] 6.9.1.5 Implement conditional fields (show/hide based on values)
- [ ] 6.9.1.6 Implement field grouping with collapsible sections
- [ ] 6.9.1.7 Implement `on_submit` and `on_change` callbacks

### 6.9.2 CommandPalette Widget

- [ ] **Task 6.9.2 Complete**

CommandPalette provides VS Code-style command interface with fuzzy search. It enables power users to quickly discover and execute commands without memorizing shortcuts.

- [ ] 6.9.2.1 Implement modal overlay with search input
- [ ] 6.9.2.2 Implement fuzzy search with scoring algorithm
- [ ] 6.9.2.3 Implement command categories with prefixes (>, @, #, :)
- [ ] 6.9.2.4 Implement recent commands tracking
- [ ] 6.9.2.5 Implement keyboard shortcut hints display
- [ ] 6.9.2.6 Implement nested command menus
- [ ] 6.9.2.7 Implement async command loading for dynamic sources

### Unit Tests - Section 6.9

- [ ] **Unit Tests 6.9 Complete**
- [ ] Test form renders all field types correctly
- [ ] Test Tab navigation moves between fields
- [ ] Test validation displays error messages
- [ ] Test command palette fuzzy search ranks results
- [ ] Test command execution triggers callbacks

---

## 6.10 Layout Widgets

- [ ] **Section 6.10 Complete**

Layout widgets provide advanced content organization. TreeView displays hierarchical data with expand/collapse. SplitPane enables resizable multi-pane layouts for IDE-style interfaces.

### 6.10.1 TreeView Widget

- [ ] **Task 6.10.1 Complete**

TreeView renders hierarchical data with expand/collapse functionality. It supports lazy loading for large trees and provides rich navigation and selection.

- [ ] 6.10.1.1 Define tree node structure with children and metadata
- [ ] 6.10.1.2 Implement tree rendering with indentation
- [ ] 6.10.1.3 Implement expand/collapse with persistence
- [ ] 6.10.1.4 Implement lazy loading of children (on_expand callback)
- [ ] 6.10.1.5 Implement keyboard navigation (arrows, Enter to toggle)
- [ ] 6.10.1.6 Implement multi-select with Shift/Ctrl modifiers
- [ ] 6.10.1.7 Implement search/filter with path highlighting
- [ ] 6.10.1.8 Implement custom node icons

### 6.10.2 SplitPane Widget

- [ ] **Task 6.10.2 Complete**

SplitPane divides space between two or more panes with draggable dividers. It enables complex layouts like IDE editors with sidebars and bottom panels.

- [ ] 6.10.2.1 Implement horizontal split with two panes
- [ ] 6.10.2.2 Implement vertical split with two panes
- [ ] 6.10.2.3 Implement draggable divider (keyboard and mouse)
- [ ] 6.10.2.4 Implement min/max size constraints per pane
- [ ] 6.10.2.5 Implement collapse to zero (hide pane)
- [ ] 6.10.2.6 Implement nested splits for complex layouts
- [ ] 6.10.2.7 Implement layout state persistence

### Unit Tests - Section 6.10

- [ ] **Unit Tests 6.10 Complete**
- [ ] Test tree renders nodes with correct indentation
- [ ] Test expand/collapse updates visible nodes
- [ ] Test lazy loading fetches children on expand
- [ ] Test split pane divider drag updates sizes
- [ ] Test min/max constraints are enforced

---

## 6.11 Data Streaming Widgets

- [ ] **Section 6.11 Complete**

Data streaming widgets handle real-time data display efficiently. LogViewer displays logs with virtual scrolling for millions of lines. StreamWidget integrates with GenStage for backpressure-aware data streaming.

### 6.11.1 LogViewer Widget

- [ ] **Task 6.11.1 Complete**

LogViewer displays real-time logs with virtual scrolling, search, and filtering. It handles millions of lines efficiently and provides tail mode for live log monitoring.

- [ ] 6.11.1.1 Implement virtual scrolling for millions of lines
- [ ] 6.11.1.2 Implement tail mode (auto-scroll to bottom)
- [ ] 6.11.1.3 Implement search with regex support and highlighting
- [ ] 6.11.1.4 Implement syntax highlighting (log levels, timestamps)
- [ ] 6.11.1.5 Implement filter by level/source/pattern
- [ ] 6.11.1.6 Implement line bookmarking
- [ ] 6.11.1.7 Implement selection and copy to clipboard
- [ ] 6.11.1.8 Implement wrap/truncate toggle for long lines

### 6.11.2 StreamWidget

- [ ] **Task 6.11.2 Complete**

StreamWidget integrates with GenStage for backpressure-aware data streaming. It manages demand-based data flow and provides controls for stream management.

- [ ] 6.11.2.1 Implement GenStage consumer for data source
- [ ] 6.11.2.2 Implement backpressure handling (demand-based)
- [ ] 6.11.2.3 Implement buffer management with overflow strategies
- [ ] 6.11.2.4 Implement pause/resume stream control
- [ ] 6.11.2.5 Implement rate limiting for rendering
- [ ] 6.11.2.6 Implement stream statistics display (items/sec)

### Unit Tests - Section 6.11

- [ ] **Unit Tests 6.11 Complete**
- [ ] Test log viewer renders visible lines only
- [ ] Test tail mode scrolls on new content
- [ ] Test search highlights matching lines
- [ ] Test stream widget handles backpressure
- [ ] Test pause/resume controls stream flow

---

## 6.12 BEAM Introspection Widgets

- [ ] **Section 6.12 Complete**

BEAM introspection widgets leverage Erlang's runtime introspection for live system visualization. These widgets differentiate TermUI by providing tools unique to the BEAM ecosystem—process monitoring, supervision tree visualization, ETS inspection, and cluster management.

### 6.12.1 ProcessMonitor Widget

- [ ] **Task 6.12.1 Complete**

ProcessMonitor displays live process information including reductions, memory, and message queues. It provides controls for process management and debugging.

- [ ] 6.12.1.1 Implement process list with PID, name, reductions, memory
- [ ] 6.12.1.2 Implement live stats updates (configurable interval)
- [ ] 6.12.1.3 Implement message queue depth display and warnings
- [ ] 6.12.1.4 Implement process links/monitors visualization
- [ ] 6.12.1.5 Implement stack trace display on selection
- [ ] 6.12.1.6 Implement process actions (kill, suspend, resume)
- [ ] 6.12.1.7 Implement sorting by reductions/memory/queue
- [ ] 6.12.1.8 Implement process filtering by name/module

### 6.12.2 SupervisionTreeViewer Widget

- [ ] **Task 6.12.2 Complete**

SupervisionTreeViewer displays the supervision hierarchy with live status indicators. It shows restart counts and provides controls for supervisor management.

- [ ] 6.12.2.1 Implement tree view of supervision hierarchy
- [ ] 6.12.2.2 Implement live status indicators (running, restarting, terminated)
- [ ] 6.12.2.3 Implement restart count and history display
- [ ] 6.12.2.4 Implement supervisor strategy display
- [ ] 6.12.2.5 Implement click to inspect child process state
- [ ] 6.12.2.6 Implement restart/terminate controls with confirmation
- [ ] 6.12.2.7 Implement auto-refresh on supervision tree changes

### 6.12.3 ETSBrowser Widget

- [ ] **Task 6.12.3 Complete**

ETSBrowser provides inspection and manipulation of ETS/DETS tables. It displays table metadata, supports queries with match specs, and enables record editing.

- [ ] 6.12.3.1 Implement ETS/DETS table listing with metadata
- [ ] 6.12.3.2 Implement table schema detection
- [ ] 6.12.3.3 Implement record browser with pagination
- [ ] 6.12.3.4 Implement query interface with match specs
- [ ] 6.12.3.5 Implement record editing (insert, update, delete)
- [ ] 6.12.3.6 Implement memory usage and size statistics
- [ ] 6.12.3.7 Implement table creation wizard

### 6.12.4 ClusterDashboard Widget

- [ ] **Task 6.12.4 Complete**

ClusterDashboard visualizes distributed Erlang clusters with node status, health metrics, and cross-node process information.

- [ ] 6.12.4.1 Implement connected nodes list with status
- [ ] 6.12.4.2 Implement node health metrics (CPU, memory, load)
- [ ] 6.12.4.3 Implement cross-node process registry display
- [ ] 6.12.4.4 Implement pg group membership visualization
- [ ] 6.12.4.5 Implement network partition detection and alerts
- [ ] 6.12.4.6 Implement node connection/disconnection events
- [ ] 6.12.4.7 Implement RPC interface for remote inspection

### Unit Tests - Section 6.12

- [ ] **Unit Tests 6.12 Complete**
- [ ] Test process monitor displays correct process info
- [ ] Test supervision tree reflects actual hierarchy
- [ ] Test ETS browser lists tables correctly
- [ ] Test cluster dashboard shows connected nodes
- [ ] Test live updates reflect system changes

---

## 6.13 Architectural Patterns

- [ ] **Section 6.13 Complete**

Architectural patterns provide reusable infrastructure for advanced widgets. VirtualScrolling enables efficient handling of large datasets. AsyncDataSource manages background data fetching. LiveBinding connects widgets to PubSub for real-time updates.

### 6.13.1 VirtualScrolling Engine

- [ ] **Task 6.13.1 Complete**

VirtualScrolling provides a shared implementation for efficient rendering of large datasets. It calculates visible ranges and handles smooth scrolling.

- [ ] 6.13.1.1 Implement visible range calculation from offset and viewport
- [ ] 6.13.1.2 Implement buffer zone for smooth scrolling
- [ ] 6.13.1.3 Implement variable height item support
- [ ] 6.13.1.4 Implement scroll position preservation on data change
- [ ] 6.13.1.5 Implement momentum scrolling for mouse wheel
- [ ] 6.13.1.6 Implement scroll-to-item API

### 6.13.2 AsyncDataSource

- [ ] **Task 6.13.2 Complete**

AsyncDataSource provides background data fetching leveraging BEAM concurrency. It manages loading states, errors, and caching.

- [ ] 6.13.2.1 Implement async fetch with Task supervision
- [ ] 6.13.2.2 Implement loading state management
- [ ] 6.13.2.3 Implement error handling with retry logic
- [ ] 6.13.2.4 Implement cancelation on unmount
- [ ] 6.13.2.5 Implement caching layer with TTL
- [ ] 6.13.2.6 Implement pagination support

### 6.13.3 LiveBinding

- [ ] **Task 6.13.3 Complete**

LiveBinding connects widgets to Phoenix PubSub for automatic real-time updates. It manages subscriptions and batches rapid updates.

- [ ] 6.13.3.1 Implement PubSub subscription on mount
- [ ] 6.13.3.2 Implement automatic state update on message
- [ ] 6.13.3.3 Implement transform function for incoming data
- [ ] 6.13.3.4 Implement batching for rapid updates
- [ ] 6.13.3.5 Implement unsubscribe on unmount
- [ ] 6.13.3.6 Implement reconnection handling

### Unit Tests - Section 6.13

- [ ] **Unit Tests 6.13 Complete**
- [ ] Test virtual scrolling calculates visible range correctly
- [ ] Test async data source handles loading/error states
- [ ] Test live binding updates state on PubSub messages
- [ ] Test batching coalesces rapid updates

---

## Success Criteria

1. **Advanced Widgets**: Table, Tabs, Menu, Dialog, Chart, Viewport, Canvas fully functional
2. **Table Performance**: Virtual scrolling handles 10,000+ rows at 60 FPS
3. **Development Mode**: Inspector and hot reload working for rapid development
4. **Testing Framework**: Complete testing utilities for component testing
5. **Documentation**: All widgets documented with examples
6. **Test Coverage**: 85% test coverage with comprehensive unit and integration tests
7. **Advanced Input Widgets**: FormBuilder and CommandPalette fully functional
8. **Layout Widgets**: TreeView and SplitPane fully functional
9. **Data Streaming**: LogViewer handles 1M+ lines, StreamWidget handles backpressure
10. **BEAM Introspection**: ProcessMonitor, SupervisionTreeViewer, ETSBrowser, ClusterDashboard provide live system insights

## Provides Foundation

This phase completes the framework, providing:
- Full widget set for building complete applications
- Developer tools for productive development
- Testing utilities for maintainable applications
- Production-ready framework for terminal UIs
- BEAM-specific introspection tools unique to the Elixir ecosystem

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
- Advanced input widgets (FormBuilder, CommandPalette)
- Layout widgets (TreeView, SplitPane)
- Data streaming widgets (LogViewer, StreamWidget)
- BEAM introspection widgets (ProcessMonitor, SupervisionTreeViewer, ETSBrowser, ClusterDashboard)
- Architectural patterns (VirtualScrolling, AsyncDataSource, LiveBinding)
