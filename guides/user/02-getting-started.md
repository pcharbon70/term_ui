# Getting Started

This guide walks you through creating your first TermUI application.

## Installation

Add TermUI to your dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:term_ui, path: "../term_ui"}  # Or from Hex when published
  ]
end
```

Then fetch dependencies:

```bash
mix deps.get
```

## Understanding Backends: Raw vs TTY

TermUI supports two terminal backends that are automatically selected based on your environment:

### Raw Mode (Full TUI Experience)

Raw mode provides complete terminal control:

- **Alternate screen buffer** - Preserves your shell history
- **Character-by-character input** - No line buffering
- **Full mouse support** - Click, drag, and scroll events
- **Live UI updates** - Smooth 60 FPS rendering

**When it's used:**
- Running from command line (`mix run`, `mix termui.run`)
- Terminal supports raw mode (OTP 28+)
- No other shell is running

### TTY Mode (IEx Compatible)

TTY mode works inside IEx and other constrained environments:

- **No alternate screen** - Output appears directly in terminal
- **Immediate character input** - Uses `:io.get_chars/2` for IEx compatibility
- **Reduced feature set** - Mouse support may be limited
- **Works in IEx** - Perfect for development and debugging

**When it's used:**
- Running inside IEx
- A shell is already running
- Raw mode activation fails

### Automatic Backend Selection

TermUI automatically selects the appropriate backend:

1. Attempts raw mode first
2. Falls back to TTY mode if:
   - IEx is detected
   - A shell is already running
   - Raw mode is unavailable

You can also force a specific mode:

```elixir
# Force raw mode
TermUI.Runtime.run(root: MyApp.Counter, backend: :raw)

# Force TTY mode
TermUI.Runtime.run(root: MyApp.Counter, backend: :tty)
```

### Which Should You Use?

| Scenario | Recommended Mode |
|----------|------------------|
| Production application | Raw (auto-detected) |
| Development in IEx | TTY (auto-detected) |
| Testing/Debugging | TTY for IEx convenience |
| SSH sessions | Auto (usually TTY) |

The same code works in both modes - no changes needed!

## Your First Application

Let's build a simple counter that responds to keyboard input.

### Step 1: Create the Component

Create `lib/my_app/counter.ex`:

```elixir
defmodule MyApp.Counter do
  @moduledoc """
  A simple counter component demonstrating TermUI basics.
  """

  use TermUI.Elm

  alias TermUI.Event
  alias TermUI.Renderer.Style

  # Initialize state
  def init(_opts) do
    %{count: 0}
  end

  # Convert events to messages
  def event_to_msg(%Event.Key{key: key}, _state) when key in ["q", "Q"] do
    {:msg, :quit}
  end

  def event_to_msg(%Event.Key{key: :up}, _state), do: {:msg, :increment}
  def event_to_msg(%Event.Key{key: :down}, _state), do: {:msg, :decrement}
  def event_to_msg(_, _state), do: :ignore

  # Update state based on messages
  def update(:quit, state) do
    {state, [:quit]}
  end

  def update(:increment, state) do
    {%{state | count: state.count + 1}, []}
  end

  def update(:decrement, state) do
    {%{state | count: state.count - 1}, []}
  end

  # Render the view
  def view(state) do
    stack(:vertical, [
      text("Simple Counter", Style.new(fg: :cyan, attrs: [:bold])),
      text(""),
      text("Count: #{state.count}", Style.new(fg: :white)),
      text(""),
      text("[↑] Increment  [↓] Decrement  [Q] Quit", Style.new(fg: :bright_black))
    ])
  end
end
```

### Step 2: Create the Entry Point

Create `lib/my_app.ex`:

```elixir
defmodule MyApp do
  @moduledoc """
  Entry point for the counter application.
  """

  def run do
    TermUI.Runtime.run(root: MyApp.Counter)
  end

  def start do
    TermUI.Runtime.start_link(root: MyApp.Counter)
  end
end
```

### Step 3: Run the Application

```bash
mix termui.run
```

The `mix termui.run` command will automatically discover and run your root module (`MyApp` in this case).

You should see your counter application. Press `↑` to increment, `↓` to decrement, and `Q` to quit.

## Understanding the Code

### The `use TermUI.Elm` Macro

This sets up your module as an Elm Architecture component, importing necessary functions like `text/1`, `text/2`, and `stack/2`.

### The Four Callbacks

1. **`init/1`** - Called once when the component starts. Returns initial state.

2. **`event_to_msg/2`** - Converts terminal events to application messages. Return values:
   - `{:msg, message}` - Send message to `update/2`
   - `:ignore` - Discard the event
   - `:propagate` - Pass to parent component

3. **`update/2`** - Handles messages and returns `{new_state, commands}`. Commands are side effects like timers or quit requests.

4. **`view/1`** - Returns a render tree describing what to display.

### Render Tree Primitives

- `text(string)` - Plain text
- `text(string, style)` - Styled text
- `stack(:vertical, children)` - Vertical layout
- `stack(:horizontal, children)` - Horizontal layout

## Adding More Features

### Color Based on Value

```elixir
def view(state) do
  count_style = cond do
    state.count > 0 -> Style.new(fg: :green)
    state.count < 0 -> Style.new(fg: :red)
    true -> Style.new(fg: :white)
  end

  stack(:vertical, [
    text("Count: #{state.count}", count_style),
    # ...
  ])
end
```

### Reset Functionality

Add to `event_to_msg/2`:

```elixir
def event_to_msg(%Event.Key{key: key}, _state) when key in ["r", "R"] do
  {:msg, :reset}
end
```

Add to `update/2`:

```elixir
def update(:reset, state) do
  {%{state | count: 0}, []}
end
```

### Using Widgets

```elixir
alias TermUI.Widgets.Gauge

def view(state) do
  # Normalize count to 0-100 range for gauge
  gauge_value = max(0, min(100, state.count + 50))

  stack(:vertical, [
    text("Counter with Gauge"),
    text(""),
    Gauge.render(value: gauge_value, width: 30),
    text(""),
    text("Count: #{state.count}")
  ])
end
```

## Running in IEx

For development and debugging, you can run your app in IEx using TTY mode:

```bash
iex -S mix
```

Then in IEx:

```elixir
iex> MyApp.run()
```

The app will run in TTY mode, which:
- Works inside IEx without taking over the shell completely
- Provides immediate character input (no Enter needed)
- Displays output directly in the terminal

For the full TUI experience with alternate screen, run from command line instead:

```bash
mix termui.run
```

or

```bash
mix run -e "MyApp.run()" --no-halt
```

## Next Steps

- [The Elm Architecture](03-elm-architecture.md) - Learn the pattern in depth
- [Events](04-events.md) - Handle all types of input
- [Styling](05-styling.md) - Make your app visually appealing
- [Widgets](07-widgets.md) - Use pre-built components
