# TermUI Overview

TermUI is a direct-mode Terminal UI framework for Elixir/BEAM applications. It enables building rich, interactive terminal interfaces that leverage the BEAM's unique strengths: fault tolerance, the actor model, hot code reloading, and distribution.

## What is TermUI?

TermUI provides everything you need to build terminal-based user interfaces:

- **The Elm Architecture** - A proven pattern for building interactive UIs with predictable state management
- **Rich Widget Library** - Pre-built components like gauges, tables, sparklines, and more
- **Declarative Styling** - Fluent API for colors, attributes, and themes
- **Flexible Layout** - Constraint-based layout system with automatic sizing
- **Full Input Support** - Keyboard, mouse, paste, and focus events
- **High Performance** - Differential rendering at 60 FPS with minimal terminal updates

## Architecture Overview

```
┌─────────────────────────────────────────────────────────┐
│                    Your Application                      │
│  ┌─────────────────────────────────────────────────┐    │
│  │              Elm Components                      │    │
│  │   init → event_to_msg → update → view           │    │
│  └─────────────────────────────────────────────────┘    │
├─────────────────────────────────────────────────────────┤
│                      TermUI Runtime                      │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐              │
│  │  Events  │  │ Commands │  │ Renderer │              │
│  └──────────┘  └──────────┘  └──────────┘              │
├─────────────────────────────────────────────────────────┤
│                    Terminal Layer                        │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐              │
│  │ Raw Mode │  │  Mouse   │  │  Screen  │              │
│  └──────────┘  └──────────┘  └──────────┘              │
└─────────────────────────────────────────────────────────┘
```

## Core Concepts

### The Elm Architecture

TermUI uses The Elm Architecture, a pattern for building interactive programs:

1. **Model** - Your application state (a plain Elixir map or struct)
2. **Update** - A function that takes a message and state, returns new state
3. **View** - A function that renders state to the screen

```elixir
defmodule Counter do
  use TermUI.Elm

  def init(_opts), do: %{count: 0}

  def event_to_msg(%Event.Key{key: :up}, _state), do: {:msg, :increment}
  def event_to_msg(%Event.Key{key: :down}, _state), do: {:msg, :decrement}
  def event_to_msg(_, _), do: :ignore

  def update(:increment, state), do: {%{state | count: state.count + 1}, []}
  def update(:decrement, state), do: {%{state | count: state.count - 1}, []}

  def view(state) do
    text("Count: #{state.count}")
  end
end
```

### Events and Messages

Terminal input (keys, mouse, resize) arrives as **events**. Your component converts events to **messages** via `event_to_msg/2`. Messages drive state changes through `update/2`.

### Commands

Side effects (timers, file I/O, etc.) are represented as **commands** returned from `update/2`. The runtime executes them asynchronously and delivers results back as messages.

### Rendering

The `view/1` function returns a **render tree** - a declarative description of what should appear on screen. TermUI diffs this against the previous frame and sends only the changes to the terminal.

## Key Features

### Widgets

Pre-built components for common UI patterns:

| Widget | Description |
|--------|-------------|
| `Gauge` | Progress bar with color zones |
| `Sparkline` | Compact inline trend graph |
| `Table` | Scrollable data table |
| `Menu` | Selectable menu items |
| `TextInput` | Text entry field |
| `Dialog` | Modal dialog box |

### Styling

Rich styling with colors and attributes:

```elixir
Style.new(fg: :cyan, bg: :black, attrs: [:bold, :underline])
```

Supports 16 colors, 256-color palette, and true color (24-bit RGB).

### Layout

Declarative constraints for flexible layouts:

```elixir
stack(:horizontal, [
  {gauge, Constraint.percentage(30)},
  {table, Constraint.fill()}
])
```

### Terminal Features

- **Raw Mode** - Character-by-character input without line buffering
- **Alternate Screen** - Preserves user's shell history
- **Mouse Tracking** - Click, drag, and scroll events
- **Focus Events** - Know when the terminal gains/loses focus

## Requirements

- Elixir 1.15+
- OTP 28+
- A terminal emulator with ANSI support

## Next Steps

- [Getting Started](02-getting-started.md) - Build your first TermUI app
- [The Elm Architecture](03-elm-architecture.md) - Deep dive into the component model
- [Events](04-events.md) - Handle keyboard, mouse, and other input
- [Styling](05-styling.md) - Colors, attributes, and themes
- [Layout](06-layout.md) - Positioning and sizing components
- [Widgets](07-widgets.md) - Using built-in widgets
- [Terminal](08-terminal.md) - Low-level terminal control
- [Commands](09-commands.md) - Side effects and async operations
