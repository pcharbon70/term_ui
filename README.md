# TermUI

[![Hex.pm](https://img.shields.io/hexpm/v/term_ui.svg)](https://hex.pm/packages/term_ui)
[![Docs](https://img.shields.io/badge/hex-docs-blue.svg)](https://hexdocs.pm/term_ui)
[![License](https://img.shields.io/hexpm/l/term_ui.svg)](https://github.com/pcharbon70/term_ui/blob/main/LICENSE)

A direct-mode Terminal UI framework for Elixir/BEAM, inspired by [BubbleTea](https://github.com/charmbracelet/bubbletea) (Go) and [Ratatui](https://github.com/ratatui-org/ratatui) (Rust).

TermUI leverages BEAM's unique strengths—fault tolerance, actor model, hot code reloading—to build robust terminal applications using The Elm Architecture.

<p align="center">
  <img src="https://raw.githubusercontent.com/pcharbon70/term_ui/main/assets/blue_theme.jpg" width="45%" alt="Blue Theme">
  &nbsp;&nbsp;
  <img src="https://raw.githubusercontent.com/pcharbon70/term_ui/main/assets/yellow_theme.jpg" width="45%" alt="Yellow Theme">
</p>

## Features

- **Elm Architecture** - Predictable state management with `init/update/view`
- **Rich Widget Library** - Gauges, tables, menus, charts, dialogs, and more
- **Efficient Rendering** - Double-buffered differential updates at 60 FPS
- **Themable** - True color RGB support (16 million colors)
- **Cross-Platform** - Linux, macOS, Windows 10+ terminal support
- **OTP Integration** - Supervision trees, fault tolerance, hot code reload

## Installation

Add `term_ui` to your dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:term_ui, "~> 0.1.0"}
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
| [dashboard](https://github.com/pcharbon70/term_ui/tree/main/examples/dashboard) | System monitoring dashboard with multiple widgets |
| [gauge](https://github.com/pcharbon70/term_ui/tree/main/examples/gauge) | Progress bars and percentage indicators |
| [sparkline](https://github.com/pcharbon70/term_ui/tree/main/examples/sparkline) | Inline data visualization |
| [bar_chart](https://github.com/pcharbon70/term_ui/tree/main/examples/bar_chart) | Horizontal and vertical bar charts |
| [line_chart](https://github.com/pcharbon70/term_ui/tree/main/examples/line_chart) | Braille-based line charts |
| [table](https://github.com/pcharbon70/term_ui/tree/main/examples/table) | Scrollable data tables with selection |
| [menu](https://github.com/pcharbon70/term_ui/tree/main/examples/menu) | Nested menus with keyboard navigation |
| [tabs](https://github.com/pcharbon70/term_ui/tree/main/examples/tabs) | Tab-based navigation |
| [dialog](https://github.com/pcharbon70/term_ui/tree/main/examples/dialog) | Modal dialogs with buttons |
| [viewport](https://github.com/pcharbon70/term_ui/tree/main/examples/viewport) | Scrollable content areas |
| [canvas](https://github.com/pcharbon70/term_ui/tree/main/examples/canvas) | Free-form drawing with box/braille characters |

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
