# TermUI

[![Hex.pm](https://img.shields.io/hexpm/v/term_ui.svg)](https://hex.pm/packages/term_ui)
[![Docs](https://img.shields.io/badge/hex-docs-blue.svg)](https://hexdocs.pm/term_ui)
[![License](https://img.shields.io/hexpm/l/term_ui.svg)](https://github.com/pcharbon70/term_ui/blob/main/LICENSE)

A direct-mode Terminal UI framework for Elixir/BEAM, inspired by [BubbleTea](https://github.com/charmbracelet/bubbletea) (Go) and [Ratatui](https://github.com/ratatui-org/ratatui) (Rust).

TermUI leverages BEAM's unique strengths—fault tolerance, actor model, hot code reloading—to build robust terminal applications using The Elm Architecture.

<p align="center">
  <img src="https://raw.githubusercontent.com/pcharbon70/term_ui/main/assets/dashboard_blue.jpg" width="45%" alt="Blue Theme">
  &nbsp;&nbsp;
  <img src="https://raw.githubusercontent.com/pcharbon70/term_ui/main/assets/dashboard_yellow.jpg" width="45%" alt="Yellow Theme">
</p>

## Features

- **Elm Architecture** - Predictable state management with `init/update/view`
- **Rich Widget Library** - Gauges, tables, menus, charts, dialogs, and more
- **Efficient Rendering** - Double-buffered differential updates at 60 FPS
- **Themable** - True color RGB support (16 million colors)
- **Cross-Platform** - Linux, macOS, Windows 10+ terminal support
- **OTP Integration** - Supervision trees, fault tolerance, hot code reload

## Widgets

| Widget | Description |
|--------|-------------|
| **Gauge** | Progress bar with color zones |
| **Sparkline** | Compact inline trend graph |
| **Table** | Scrollable data table with selection and sorting |
| **Menu** | Hierarchical menu with submenus |
| **TextInput** | Single-line and multi-line text input |
| **Dialog** | Modal dialog with buttons |
| **PickList** | Modal selection with type-ahead filtering |
| **Tabs** | Tabbed interface for switchable panels |
| **AlertDialog** | Modal dialog for confirmations with standard button configurations |
| **ContextMenu** | Right-click context menu with keyboard and mouse support |
| **Toast** | Auto-dismissing notifications with stacking |
| **Viewport** | Scrollable view with keyboard and mouse support |
| **SplitPane** | Resizable multi-pane layouts for IDE-style interfaces |
| **TreeView** | Hierarchical data display with expand/collapse |
| **FormBuilder** | Structured forms with validation and multiple field types |
| **CommandPalette** | VS Code-style command discovery with fuzzy search |
| **BarChart** | Horizontal/vertical bar charts for categorical data |
| **LineChart** | Line charts using Braille characters for sub-character resolution |
| **Canvas** | Direct drawing surface for custom visualizations |
| **LogViewer** | High-performance log viewer with virtual scrolling and filtering |
| **StreamWidget** | GenStage-integrated widget with backpressure support |
| **ProcessMonitor** | Live BEAM process inspection with sorting and filtering |
| **SupervisionTreeViewer** | OTP supervision hierarchy visualization |
| **ClusterDashboard** | Distributed Erlang cluster monitoring |

## Installation

Add `term_ui` to your dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:term_ui, "~> 0.2.0"}
  ]
end
```

## Quick Start

```elixir
defmodule Counter do
  use TermUI.Elm

  alias TermUI.Event
  alias TermUI.Renderer.Style

  def init(_opts), do: %{count: 0}

  def event_to_msg(%Event.Key{key: :up}, _state), do: {:msg, :increment}
  def event_to_msg(%Event.Key{key: :down}, _state), do: {:msg, :decrement}
  def event_to_msg(%Event.Key{key: "q"}, _state), do: {:msg, :quit}
  def event_to_msg(_, _), do: :ignore

  def update(:increment, state), do: {%{state | count: state.count + 1}, []}
  def update(:decrement, state), do: {%{state | count: state.count - 1}, []}
  def update(:quit, state), do: {state, [:quit]}

  def view(state) do
    stack(:vertical, [
      text("Counter Example", Style.new(fg: :cyan, attrs: [:bold])),
      text("", nil),
      text("Count: #{state.count}", nil),
      text("", nil),
      text("↑/↓ to change, Q to quit", Style.new(fg: :bright_black))
    ])
  end
end

# Run the application
TermUI.Runtime.run(root: Counter)
```

## Documentation

### User Guides

| Guide | Description |
|-------|-------------|
| [Overview](https://github.com/pcharbon70/term_ui/blob/main/guides/user/01-overview.md) | Introduction to TermUI concepts |
| [Getting Started](https://github.com/pcharbon70/term_ui/blob/main/guides/user/02-getting-started.md) | First steps and setup |
| [Elm Architecture](https://github.com/pcharbon70/term_ui/blob/main/guides/user/03-elm-architecture.md) | Understanding init/update/view |
| [Events](https://github.com/pcharbon70/term_ui/blob/main/guides/user/04-events.md) | Handling keyboard and mouse input |
| [Styling](https://github.com/pcharbon70/term_ui/blob/main/guides/user/05-styling.md) | Colors, attributes, and themes |
| [Layout](https://github.com/pcharbon70/term_ui/blob/main/guides/user/06-layout.md) | Arranging components on screen |
| [Widgets](https://github.com/pcharbon70/term_ui/blob/main/guides/user/07-widgets.md) | Using built-in widgets |
| [Terminal](https://github.com/pcharbon70/term_ui/blob/main/guides/user/08-terminal.md) | Terminal capabilities and modes |
| [Commands](https://github.com/pcharbon70/term_ui/blob/main/guides/user/09-commands.md) | Side effects and async operations |
| [Advanced Widgets](https://github.com/pcharbon70/term_ui/blob/main/guides/user/10-advanced-widgets.md) | Navigation, visualization, streaming, and BEAM introspection widgets |

### Developer Guides

| Guide | Description |
|-------|-------------|
| [Architecture Overview](https://github.com/pcharbon70/term_ui/blob/main/guides/developer/01-architecture-overview.md) | System layers and design |
| [Runtime Internals](https://github.com/pcharbon70/term_ui/blob/main/guides/developer/02-runtime-internals.md) | GenServer event loop and state |
| [Rendering Pipeline](https://github.com/pcharbon70/term_ui/blob/main/guides/developer/03-rendering-pipeline.md) | View to terminal output stages |
| [Event System](https://github.com/pcharbon70/term_ui/blob/main/guides/developer/04-event-system.md) | Input parsing and dispatch |
| [Buffer Management](https://github.com/pcharbon70/term_ui/blob/main/guides/developer/05-buffer-management.md) | ETS double buffering |
| [Terminal Layer](https://github.com/pcharbon70/term_ui/blob/main/guides/developer/06-terminal-layer.md) | Raw mode and ANSI sequences |
| [Elm Implementation](https://github.com/pcharbon70/term_ui/blob/main/guides/developer/07-elm-implementation.md) | Elm Architecture for OTP |
| [Creating Widgets](https://github.com/pcharbon70/term_ui/blob/main/guides/developer/08-creating-widgets.md) | How to build and contribute widgets |
| [Testing Framework](https://github.com/pcharbon70/term_ui/blob/main/guides/developer/09-testing-framework.md) | Component and widget testing |

## Examples

The `examples/` directory contains standalone applications demonstrating each widget:

| Example | Description |
|---------|-------------|
| [alert_dialog](https://github.com/pcharbon70/term_ui/tree/main/examples/alert_dialog) | Confirmation dialogs with standard buttons |
| [bar_chart](https://github.com/pcharbon70/term_ui/tree/main/examples/bar_chart) | Horizontal and vertical bar charts |
| [canvas](https://github.com/pcharbon70/term_ui/tree/main/examples/canvas) | Free-form drawing with box/braille characters |
| [cluster_dashboard](https://github.com/pcharbon70/term_ui/tree/main/examples/cluster_dashboard) | Distributed Erlang cluster monitoring |
| [command_palette](https://github.com/pcharbon70/term_ui/tree/main/examples/command_palette) | VS Code-style command discovery |
| [context_menu](https://github.com/pcharbon70/term_ui/tree/main/examples/context_menu) | Right-click context menus |
| [dashboard](https://github.com/pcharbon70/term_ui/tree/main/examples/dashboard) | System monitoring dashboard with multiple widgets |
| [dialog](https://github.com/pcharbon70/term_ui/tree/main/examples/dialog) | Modal dialogs with buttons |
| [form_builder](https://github.com/pcharbon70/term_ui/tree/main/examples/form_builder) | Structured forms with validation |
| [gauge](https://github.com/pcharbon70/term_ui/tree/main/examples/gauge) | Progress bars and percentage indicators |
| [line_chart](https://github.com/pcharbon70/term_ui/tree/main/examples/line_chart) | Braille-based line charts |
| [log_viewer](https://github.com/pcharbon70/term_ui/tree/main/examples/log_viewer) | Real-time log display with filtering |
| [menu](https://github.com/pcharbon70/term_ui/tree/main/examples/menu) | Nested menus with keyboard navigation |
| [pick_list](https://github.com/pcharbon70/term_ui/tree/main/examples/pick_list) | Modal selection with type-ahead |
| [process_monitor](https://github.com/pcharbon70/term_ui/tree/main/examples/process_monitor) | Live BEAM process inspection |
| [sparkline](https://github.com/pcharbon70/term_ui/tree/main/examples/sparkline) | Inline data visualization |
| [split_pane](https://github.com/pcharbon70/term_ui/tree/main/examples/split_pane) | Resizable multi-pane layouts |
| [stream_widget](https://github.com/pcharbon70/term_ui/tree/main/examples/stream_widget) | Backpressure-aware data streaming |
| [supervision_tree_viewer](https://github.com/pcharbon70/term_ui/tree/main/examples/supervision_tree_viewer) | OTP supervision hierarchy |
| [table](https://github.com/pcharbon70/term_ui/tree/main/examples/table) | Scrollable data tables with selection |
| [tabs](https://github.com/pcharbon70/term_ui/tree/main/examples/tabs) | Tab-based navigation |
| [text_input](https://github.com/pcharbon70/term_ui/tree/main/examples/text_input) | Single and multi-line text input |
| [toast](https://github.com/pcharbon70/term_ui/tree/main/examples/toast) | Auto-dismissing notifications |
| [tree_view](https://github.com/pcharbon70/term_ui/tree/main/examples/tree_view) | Hierarchical data with expand/collapse |
| [viewport](https://github.com/pcharbon70/term_ui/tree/main/examples/viewport) | Scrollable content areas |

```bash
# Run any example
cd examples/dashboard
mix deps.get
mix run run.exs
```

## Requirements

- Elixir 1.15+
- OTP 28+ (required for native raw terminal mode)
- Terminal with Unicode support

## License

MIT License - see [LICENSE](https://github.com/pcharbon70/term_ui/blob/main/LICENSE) for details.
