# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.0.0-rc.1] - 2026-08-22

### Added

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
- Replaced the component process system with one Elm application runtime.
- Made `TermUI.Frame` the only application render value.
- Moved terminal lifecycle, input, output, size, cursor, and capabilities into backends.
- Split printable text from named and modified key events.
- Replaced effect tuples with `TermUI.Command` data.
- Replaced process widgets with parent-owned pure widgets.
- Made synchronous runtime startup use an atomic process monitor so fast exits
  preserve the application or backend result.
- Made terminal cleanup state-aware and idempotent after partial setup.
- Added CI for every push and pull requests to `develop`, with supported runtime,
  quality, package, and coverage gates.
- Set the package requirement to Elixir 1.18.4 or later and documented the
  tested Elixir and OTP combinations.

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

[Unreleased]: https://github.com/pcharbon70/term_ui/compare/v1.0.0-rc.1...HEAD
[1.0.0-rc.1]: https://github.com/pcharbon70/term_ui/compare/v1.0.0-rc...v1.0.0-rc.1
[1.0.0-rc]: https://github.com/pcharbon70/term_ui/releases/tag/v1.0.0-rc
[0.2.0]: https://github.com/pcharbon70/term_ui/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/pcharbon70/term_ui/releases/tag/v0.1.0
