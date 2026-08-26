# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Added a tested interactive showcase for live widgets, input, rich content,
  BEAM snapshots, and the TermUI architecture.
- Added pure checkbox, toggle, radio group, select, spinner, and breadcrumb
  widgets, with a Controls page in the showcase.
- Added pure row, column, fixed-grid, inset, placement, and mouse-region layout
  helpers.
- Added complete raw control-byte input on OTP 28 and OTP 29. A small native
  terminal layer now passes Ctrl+O, Ctrl+C, Ctrl+S, and Ctrl+Q to applications
  and restores the original terminal flags during shutdown.
- Restored the general widget feature set as parent-owned pure widgets under
  `TermUI.Widget`.
- Added an MDEx Markdown renderer and scrollable Markdown viewer.
- Added unified and side-by-side terminal diff views.
- Added frame overlay composition for widget frames.
- Added Zoi schemas as the source for all production struct fields and defaults.
- Added public schemas for cells, styles, frames, events, commands, and table columns.
- Added bounded clipboard commands that run through the serialized backend owner.
- Added pure Unicode grapheme selection for single-line and multiline text input.
- Added pure mouse regions, local-coordinate routing, hover state, and drag tracking.
- Added local mouse behavior for interactive widgets, scrollbars, and split panes.

### Changed

- Process, stream, supervision, and cluster widgets now render data snapshots
  supplied by the parent application. They do not own effect processes.
- Markdown rendering and incremental documents now share one internal parser
  dependency, which removes their cross-reference cycle.
- Buttons, lists, menus, tabs, trees, blocks, and dialogs now support richer
  decoration, disabled-item navigation, and child-frame composition.

### Fixed

- Unsupported terminal control sequences no longer emit their parameter bytes
  as application text.
- Frame mutations preserve wide-grapheme pairs and cannot place a wide
  grapheme past the frame boundary.
- Timed-out terminal command tasks are now stopped.
- SGR mouse releases retain their button, and X10 releases are no longer
  reported as presses.

## [1.0.0-rc] - 2026-08-19

### Changed

- Replaced the component process system with one Elm application runtime.
- Made `TermUI.Frame` the only application render value.
- Moved terminal lifecycle, input, output, size, cursor, and capabilities into backends.
- Split printable text from named and modified key events.
- Replaced effect tuples with `TermUI.Command` data.
- Replaced process widgets with parent-owned pure widgets.

### Removed

- Removed component servers, registries, supervisors, event routers, and focus managers.
- Removed legacy input handlers, render nodes, renderer buffers, and duplicate widget namespaces.
- Removed the SSH backend until it can own a complete terminal session lifecycle.

See `guides/migration-1.0.md` for the replacement map.

## [0.2.0] - 2024-12-01

### Added

- **New Widgets**
  - PickList - Modal selection list for choosing items from a scrollable list
  - FormBuilder - Structured form handling with validation and field management
  - CommandPalette - VS Code-style fuzzy-search command discovery interface
  - TreeView - Hierarchical data display with expand/collapse navigation
  - SplitPane - Resizable multi-pane layouts with draggable dividers
  - LogViewer - Real-time log display with filtering and scrolling
  - StreamWidget - Backpressure-aware data streaming with GenStage integration
  - ProcessMonitor - BEAM process introspection and monitoring
  - SupervisionTreeViewer - OTP supervision hierarchy visualization
  - ClusterDashboard - Distributed cluster node visualization and monitoring
  - TextInput - Single-line and multi-line text input with cursor navigation

- **Backend Abstraction**
  - Backend behaviour for terminal abstraction
  - Raw backend for full terminal control
  - TTY backend for line-based terminals
  - Test backend for unit testing
  - Automatic backend selection based on terminal capabilities
  - Character set selection (Unicode/ASCII) with graceful degradation

- **Rendering**
  - Overlay node support in NodeRenderer for absolute-positioned widgets (AlertDialog, Dialog, ContextMenu, Toast)

- **Documentation**
  - Advanced widgets user guide
  - Updated widget examples with run.exs entry points

## [0.1.0] - 2024-11-26

### Added

- Initial release
- **Core Framework**
  - Elm Architecture implementation (`use TermUI.Elm`)
  - Runtime with 60 FPS rendering loop
  - Event system for keyboard and mouse input
  - Command system for side effects

- **Rendering Engine**
  - ETS-based double buffering
  - Differential rendering (only changed cells are updated)
  - ANSI escape sequence batching
  - Style system with colors and attributes

- **Layout System**
  - Constraint-based layout solver
  - Flexbox-style alignment
  - Stack layouts (vertical/horizontal)

- **Widgets**
  - Gauge (bar and arc styles with color zones)
  - Sparkline (trend visualization)
  - BarChart (horizontal/vertical)
  - LineChart (Braille-based)
  - Table (with selection and scrolling)
  - Menu (hierarchical with submenus)
  - Tabs (tabbed interface)
  - Dialog (modal dialogs)
  - Viewport (scrollable content)
  - Canvas (custom drawing)
  - Toast (notifications)
  - ScrollBar
  - ContextMenu
  - AlertDialog

- **Terminal Support**
  - Raw mode activation
  - Cross-platform compatibility (Linux, macOS, Windows 10+)
  - Terminal capability detection
  - Color degradation (true color → 256 → 16)

- **Developer Experience**
  - Development mode with hot reload
  - Performance monitoring
  - Testing framework
  - Comprehensive documentation

### Documentation

- User guides (overview, getting started, architecture, events, styling, layout, widgets)
- Developer guides (architecture, runtime, rendering, events, buffers, terminal, creating widgets)
- Widget examples with READMEs

[Unreleased]: https://github.com/mikehostetler/term_ui/compare/v1.0.0-rc...HEAD
[1.0.0-rc]: https://github.com/mikehostetler/term_ui/compare/v0.2.0...v1.0.0-rc
[0.2.0]: https://github.com/mikehostetler/term_ui/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/mikehostetler/term_ui/releases/tag/v0.1.0
