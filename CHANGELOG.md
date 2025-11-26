# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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

[Unreleased]: https://github.com/pcharbon70/term_ui/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/pcharbon70/term_ui/releases/tag/v0.1.0
