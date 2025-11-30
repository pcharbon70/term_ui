# TermUI Usage Rules for AI Assistants

> This document provides rules and patterns for AI assistants to follow when helping users build terminal UIs with TermUI.

## Overview

TermUI is a direct-mode Terminal UI framework for Elixir using The Elm Architecture. Applications are built as components with:
- `init/1` - Initialize state
- `event_to_msg/2` - Convert terminal events to domain messages
- `update/2` - Handle messages and return new state + commands
- `view/1` - Render state to a render tree

## Core Rules

### Rule 1: Always Use the Elm Architecture

Every TermUI component MUST use `use TermUI.Elm` and implement the required callbacks:

```elixir
defmodule MyApp do
  use TermUI.Elm

  alias TermUI.Event
  alias TermUI.Renderer.Style

  def init(_opts) do
    %{count: 0}
  end

  def event_to_msg(%Event.Key{key: :up}, _state), do: {:msg, :increment}
  def event_to_msg(%Event.Key{key: :down}, _state), do: {:msg, :decrement}
  def event_to_msg(%Event.Key{key: "q"}, _state), do: {:msg, :quit}
  def event_to_msg(_event, _state), do: :ignore

  def update(:increment, state), do: {%{state | count: state.count + 1}, []}
  def update(:decrement, state), do: {%{state | count: state.count - 1}, []}
  def update(:quit, state), do: {state, [:quit]}

  def view(state) do
    stack(:vertical, [
      text("Count: #{state.count}", Style.new(fg: :cyan)),
      text("Press Up/Down to change, Q to quit")
    ])
  end
end

# Run with:
TermUI.Runtime.run(root: MyApp)
```

### Rule 2: Event Handling Pattern

The `event_to_msg/2` callback transforms raw events into application messages:

```elixir
# Return {:msg, message} to send to update/2
def event_to_msg(%Event.Key{key: :enter}, _state), do: {:msg, :submit}

# Return :ignore to discard events
def event_to_msg(%Event.Key{key: :f1}, _state), do: :ignore

# Return :propagate to pass to parent component
def event_to_msg(%Event.Key{key: :escape}, _state), do: :propagate

# Always include a catch-all clause
def event_to_msg(_event, _state), do: :ignore
```

**Event Types:**

```elixir
# Keyboard - key can be atom (:enter, :escape, :tab, :up, :down, etc.) or string ("a", "1")
%Event.Key{key: :enter | "a", char: nil | "a", modifiers: [:ctrl, :alt, :shift]}

# Mouse - action is :click, :double_click, :press, :release, :drag, :move, :scroll_up, :scroll_down
%Event.Mouse{action: :click, button: :left | :middle | :right, x: 0, y: 0, modifiers: []}

# Focus changes
%Event.Focus{action: :gained | :lost}

# Terminal resize
%Event.Resize{width: 80, height: 24}

# Clipboard paste
%Event.Paste{content: "pasted text"}

# Timer tick
%Event.Tick{interval: 1000}
```

**Creating events for testing:**
```elixir
Event.key(:enter)
Event.key("a", modifiers: [:ctrl])
Event.mouse(:click, :left, 10, 5)
Event.focus(:gained)
```

### Rule 3: Update Must Be Pure and Return Tuple

The `update/2` function MUST be pure (no side effects) and return `{new_state, commands}`:

```elixir
# Correct - return tuple with state and command list
def update(:save, state) do
  {%{state | saved: true}, []}
end

def update(:quit, state) do
  {state, [:quit]}
end

# Commands are for side effects
def update(:start_timer, state) do
  {state, [Command.timer(1000, :timer_fired)]}
end
```

**Available Commands:**
- `:quit` - Exit the application
- `Command.timer(ms, message)` - Send message after delay
- `Command.none()` - No-op command

### Rule 4: View Must Return Render Nodes

The `view/1` function returns a render tree using these helpers (imported by `use TermUI.Elm`):

```elixir
# Text nodes
text("Plain text")
text("Styled", Style.new(fg: :red, attrs: [:bold]))

# Vertical/horizontal stacking
stack(:vertical, [child1, child2, child3])
stack(:horizontal, [left, middle, right])

# Empty node for conditional rendering
empty()

# Box container
box([child1, child2])
```

### Rule 5: Styling with Style Module

Always use `TermUI.Renderer.Style` for colors and attributes:

```elixir
alias TermUI.Renderer.Style

# Create styles
style = Style.new(fg: :cyan, bg: :black, attrs: [:bold])

# Fluent API
style = Style.new()
  |> Style.fg(:green)
  |> Style.bg(:black)
  |> Style.bold()
  |> Style.underline()

# Merge styles (later overrides)
combined = Style.merge(base_style, override_style)
```

**Valid colors:** `:black`, `:red`, `:green`, `:yellow`, `:blue`, `:magenta`, `:cyan`, `:white`, `:bright_black`, `:bright_red`, etc., integers 0-255, or `{r, g, b}` tuples.

**Valid attributes:** `:bold`, `:dim`, `:italic`, `:underline`, `:blink`, `:reverse`, `:hidden`, `:strikethrough`

## Widget Usage Rules

### Rule 6: Widgets Use render/1 or StatefulComponent Pattern

**Simple widgets** use `Widget.render(opts)`:

```elixir
alias TermUI.Widgets.Gauge
alias TermUI.Widgets.Sparkline
alias TermUI.Widgets.Table
alias TermUI.Widgets.Menu

# Gauge - progress bar
Gauge.render(value: 75, width: 30, show_value: true)

# Sparkline - inline trend graph
Sparkline.render(values: [10, 25, 40, 30, 50])

# Table - data grid
Table.render(
  data: [%{name: "Alice", age: 30}, %{name: "Bob", age: 25}],
  columns: [
    %{key: :name, header: "Name", width: 15},
    %{key: :age, header: "Age", width: 5}
  ],
  selected: state.selected_row,
  height: 10
)

# Menu - selectable list
Menu.render(
  items: ["File", "Edit", "View"],
  selected: state.menu_index,
  direction: :vertical
)
```

**Stateful widgets** use the `new/1`, `init/1`, `handle_event/2`, `render/2` pattern:

```elixir
alias TermUI.Widgets.TextInput
alias TermUI.Widgets.FormBuilder

# In init/1 - create widget state
def init(_opts) do
  props = TextInput.new(
    placeholder: "Enter text...",
    width: 40,
    multiline: true,
    on_change: fn value -> send(self(), {:text_changed, value}) end
  )
  {:ok, input_state} = TextInput.init(props)

  %{text_input: input_state}
end

# In event_to_msg/2 - forward events to widget
def event_to_msg(event, state) do
  {:msg, {:input_event, event}}
end

# In update/2 - handle widget events
def update({:input_event, event}, state) do
  {:ok, new_input} = TextInput.handle_event(event, state.text_input)
  {%{state | text_input: new_input}, []}
end

# In view/1 - render widget
def view(state) do
  TextInput.render(state.text_input, %{width: 80, height: 24})
end
```

### Rule 7: Common Widget Configurations

**TextInput** - Single or multi-line text input:
```elixir
TextInput.new(
  value: "",                    # Initial text
  placeholder: "Enter text...", # Shown when empty
  width: 40,                    # Character width
  multiline: false,             # Enable multi-line
  max_visible_lines: 5,         # Lines before scrolling
  enter_submits: false,         # Enter submits vs newline
  on_change: fn(value) -> ... end,
  on_submit: fn(value) -> ... end
)
```

**FormBuilder** - Structured forms:
```elixir
FormBuilder.new(
  fields: [
    %{id: :username, type: :text, label: "Username", required: true},
    %{id: :password, type: :password, label: "Password"},
    %{id: :role, type: :select, label: "Role",
      options: [{"admin", "Admin"}, {"user", "User"}]},
    %{id: :active, type: :checkbox, label: "Active"},
    %{id: :theme, type: :radio, label: "Theme",
      options: [{"light", "Light"}, {"dark", "Dark"}]}
  ],
  on_submit: fn(values) -> ... end,
  validate_on_blur: true
)
```

**Dialog/AlertDialog** - Modal dialogs:
```elixir
Dialog.render(
  title: "Confirm",
  content: "Are you sure?",
  buttons: ["Cancel", "OK"],
  selected_button: 0,
  width: 40
)

AlertDialog.render(
  type: :confirm,  # :info, :warning, :error, :success, :confirm
  title: "Delete",
  message: "Delete this item?",
  buttons: :yes_no,  # :ok, :ok_cancel, :yes_no, or list
  selected_button: 0
)
```

**Tabs** - Tabbed interface:
```elixir
Tabs.render(
  tabs: ["Overview", "Details", "Settings"],
  selected: state.active_tab,
  content: render_tab_content(state)
)
```

**TreeView** - Hierarchical data:
```elixir
TreeView.render(
  data: [
    %{id: 1, label: "Root", children: [
      %{id: 2, label: "Child 1"},
      %{id: 3, label: "Child 2"}
    ]}
  ],
  expanded: MapSet.new([1]),
  selected: state.selected_node
)
```

**LogViewer** - Scrollable log display:
```elixir
LogViewer.render(
  lines: state.log_lines,  # List of %{timestamp, level, message}
  height: 20,
  tail_mode: true,         # Auto-scroll to bottom
  show_line_numbers: true
)
```

**ProcessMonitor** - BEAM process inspection:
```elixir
props = ProcessMonitor.new(update_interval: 1000)
{:ok, monitor_state} = ProcessMonitor.init(props)
ProcessMonitor.render(monitor_state, %{width: 100, height: 30})
```

## Layout Rules

### Rule 8: Use Stack for Layout

Primary layout is via `stack/2` and `stack/3`:

```elixir
# Vertical layout (top to bottom)
stack(:vertical, [
  header,
  content,
  footer
])

# Horizontal layout (left to right)
stack(:horizontal, [
  sidebar,
  main_content
])

# With constraints
alias TermUI.Layout.Constraint

stack(:horizontal, [
  {sidebar, Constraint.length(25)},      # Fixed 25 chars
  {content, Constraint.fill()}           # Fill remaining
])

stack(:vertical, [
  {header, Constraint.length(3)},        # Fixed 3 rows
  {content, Constraint.percentage(70)},  # 70% of space
  {footer, Constraint.length(1)}         # Fixed 1 row
])
```

### Rule 9: Constraint Types

```elixir
alias TermUI.Layout.Constraint

Constraint.length(20)       # Fixed size in cells
Constraint.percentage(50)   # Percentage of parent
Constraint.fill()           # Fill remaining space
Constraint.ratio(2)         # Proportional (2 parts)

# With bounds
Constraint.percentage(50)
  |> Constraint.with_min(10)
  |> Constraint.with_max(100)
```

## Common Patterns

### Rule 10: Loading States

```elixir
def init(_opts) do
  %{status: :loading, data: nil, error: nil}
end

def update(:load, state) do
  # Start loading
  {%{state | status: :loading}, [Command.timer(0, :fetch_data)]}
end

def update(:fetch_data, state) do
  case do_fetch() do
    {:ok, data} -> {%{state | status: :ready, data: data}, []}
    {:error, e} -> {%{state | status: :error, error: e}, []}
  end
end

def view(state) do
  case state.status do
    :loading -> text("Loading...", Style.new(fg: :yellow))
    :error -> text("Error: #{state.error}", Style.new(fg: :red))
    :ready -> render_data(state.data)
  end
end
```

### Rule 11: Modal/Dialog Pattern

```elixir
def init(_opts) do
  %{items: [], confirm_delete: nil}
end

def update({:request_delete, item}, state) do
  {%{state | confirm_delete: item}, []}
end

def update(:confirm_delete, state) do
  items = Enum.reject(state.items, &(&1.id == state.confirm_delete.id))
  {%{state | items: items, confirm_delete: nil}, []}
end

def update(:cancel_delete, state) do
  {%{state | confirm_delete: nil}, []}
end

def view(state) do
  base_view = render_items(state.items)

  if state.confirm_delete do
    stack(:vertical, [
      base_view,
      Dialog.render(
        title: "Confirm Delete",
        content: "Delete #{state.confirm_delete.name}?",
        buttons: ["Cancel", "Delete"],
        selected_button: 0
      )
    ])
  else
    base_view
  end
end
```

### Rule 12: Focus Management

```elixir
def init(_opts) do
  %{focused: :input1, input1: "", input2: ""}
end

def event_to_msg(%Event.Key{key: :tab}, _state), do: {:msg, :next_focus}
def event_to_msg(%Event.Key{key: :tab, modifiers: [:shift]}, _state), do: {:msg, :prev_focus}

def update(:next_focus, state) do
  next = case state.focused do
    :input1 -> :input2
    :input2 -> :button
    :button -> :input1
  end
  {%{state | focused: next}, []}
end

def view(state) do
  stack(:vertical, [
    text("Name:", style_for_focus(state, :input1)),
    text("Email:", style_for_focus(state, :input2)),
    text("[Submit]", style_for_focus(state, :button))
  ])
end

defp style_for_focus(state, field) do
  if state.focused == field do
    Style.new(fg: :black, bg: :cyan)
  else
    Style.new()
  end
end
```

### Rule 13: Polling/Animation

```elixir
# Polling pattern
def init(_opts) do
  %{data: nil}
end

def update(:start_polling, state) do
  {state, [Command.timer(0, :poll)]}
end

def update(:poll, state) do
  data = fetch_latest_data()
  {%{state | data: data}, [Command.timer(5000, :poll)]}
end

# Animation pattern
def update(:start_animation, state) do
  {%{state | frame: 0, animating: true}, [Command.timer(50, :animate)]}
end

def update(:animate, %{animating: true, frame: frame} = state) do
  if frame >= 60 do
    {%{state | animating: false}, []}
  else
    {%{state | frame: frame + 1}, [Command.timer(50, :animate)]}
  end
end
```

## Testing Rules

### Rule 14: Test Components in Isolation

```elixir
defmodule MyAppTest do
  use ExUnit.Case
  alias TermUI.Event

  test "init returns expected state" do
    state = MyApp.init([])
    assert state.count == 0
  end

  test "up arrow sends increment" do
    event = Event.key(:up)
    assert {:msg, :increment} = MyApp.event_to_msg(event, %{})
  end

  test "increment updates count" do
    state = %{count: 5}
    {new_state, []} = MyApp.update(:increment, state)
    assert new_state.count == 6
  end

  test "quit returns quit command" do
    {_state, commands} = MyApp.update(:quit, %{})
    assert :quit in commands
  end
end
```

## Anti-Patterns to Avoid

### Never Do Side Effects in update/2

```elixir
# BAD - side effect in update
def update(:save, state) do
  File.write!("data.json", Jason.encode!(state.data))  # NO!
  {state, []}
end

# GOOD - use command for side effects
def update(:save, state) do
  {%{state | saving: true}, [Command.timer(0, :do_save)]}
end

def update(:do_save, state) do
  # This runs async, results come back as messages
  spawn(fn ->
    File.write!("data.json", Jason.encode!(state.data))
    send(self(), :save_complete)
  end)
  {state, []}
end
```

### Never Mutate State

```elixir
# BAD - mutating state
def update(:add_item, state) do
  state.items = [new_item | state.items]  # NO!
  {state, []}
end

# GOOD - return new state
def update(:add_item, state) do
  {%{state | items: [new_item | state.items]}, []}
end
```

### Always Handle Unknown Events

```elixir
# BAD - missing catch-all
def event_to_msg(%Event.Key{key: :enter}, _), do: {:msg, :submit}
# Crashes on any other event!

# GOOD - always include catch-all
def event_to_msg(%Event.Key{key: :enter}, _), do: {:msg, :submit}
def event_to_msg(_event, _state), do: :ignore
```

## Quick Reference

```elixir
# Start app
TermUI.Runtime.run(root: MyApp)

# Common imports
alias TermUI.Event
alias TermUI.Renderer.Style
alias TermUI.Widgets.{Gauge, Table, Menu, TextInput, Dialog}

# Layout
stack(:vertical, [child1, child2])
stack(:horizontal, [left, right])
text("content", Style.new(fg: :cyan))
empty()

# Styles
Style.new(fg: :red, bg: :black, attrs: [:bold])
Style.new() |> Style.fg(:green) |> Style.bold()

# Events
%Event.Key{key: :enter | "a", modifiers: [:ctrl]}
%Event.Mouse{action: :click, button: :left, x: 0, y: 0}
%Event.Focus{action: :gained | :lost}

# Commands
{state, [:quit]}
{state, [Command.timer(1000, :tick)]}
{state, []}
```
