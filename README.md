# TermUI

[![Hex.pm](https://img.shields.io/hexpm/v/term_ui.svg)](https://hex.pm/packages/term_ui)
[![Docs](https://img.shields.io/badge/hex-docs-blue.svg)](https://hexdocs.pm/term_ui)
[![License](https://img.shields.io/hexpm/l/term_ui.svg)](LICENSE)

A direct-mode Terminal UI framework for Elixir/BEAM, inspired by [BubbleTea](https://github.com/charmbracelet/bubbletea) (Go) and [Ratatui](https://github.com/ratatui-org/ratatui) (Rust).

TermUI leverages BEAM's unique strengths—fault tolerance, actor model, hot code reloading—to build robust terminal applications using The Elm Architecture.

## Features

- **Elm Architecture** - Predictable state management with `init/update/view`
- **Rich Widget Library** - Gauges, tables, menus, charts, dialogs, and more
- **Efficient Rendering** - Double-buffered differential updates at 60 FPS
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

- [Getting Started](https://hexdocs.pm/term_ui/getting-started.html)
- [The Elm Architecture](https://hexdocs.pm/term_ui/elm-architecture.html)
- [Widget Reference](https://hexdocs.pm/term_ui/widgets.html)
- [API Reference](https://hexdocs.pm/term_ui/api-reference.html)

## Examples

The `examples/` directory contains standalone applications demonstrating each widget:

| Example | Description |
|---------|-------------|
| [dashboard](examples/dashboard) | System monitoring dashboard with multiple widgets |
| [gauge](examples/gauge) | Progress bars and percentage indicators |
| [sparkline](examples/sparkline) | Inline data visualization |
| [bar_chart](examples/bar_chart) | Horizontal and vertical bar charts |
| [line_chart](examples/line_chart) | Braille-based line charts |
| [table](examples/table) | Scrollable data tables with selection |
| [menu](examples/menu) | Nested menus with keyboard navigation |
| [tabs](examples/tabs) | Tab-based navigation |
| [dialog](examples/dialog) | Modal dialogs with buttons |
| [viewport](examples/viewport) | Scrollable content areas |
| [canvas](examples/canvas) | Free-form drawing with box/braille characters |

```bash
# Run any example
cd examples/dashboard
mix deps.get
mix run run.exs
```

## Requirements

- Elixir 1.15+
- OTP 26+ (OTP 28+ recommended for native raw mode)
- Terminal with Unicode support

## License

MIT License - see [LICENSE](LICENSE) for details.
