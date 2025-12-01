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

## Widget Types

### Rule 6: Know the Two Widget Types

TermUI has two types of widgets:

1. **Simple Widgets** - Stateless, call `Widget.render(keyword_opts)` directly in view
2. **Stateful Widgets** - Use the StatefulComponent pattern: `new/init/handle_event/render`

**Simple Widgets (render with keyword options):**
- `Gauge` - Progress bars
- `Sparkline` - Inline trend graphs
- `BarChart` - Bar charts
- `LineChart` - Line charts

**Stateful Widgets (use StatefulComponent pattern):**
- `Table` - Data tables
- `Menu` - Menus with submenus
- `TextInput` - Text input fields
- `Dialog` - Modal dialogs
- `AlertDialog` - Alert dialogs
- `FormBuilder` - Forms with validation
- `TreeView` - Hierarchical trees
- `Tabs` - Tabbed interfaces
- `LogViewer` - Log display
- `ProcessMonitor` - BEAM process viewer
- `SupervisionTreeViewer` - Supervision tree viewer
- `ClusterDashboard` - Cluster dashboard
- `CommandPalette` - Command palette
- `SplitPane` - Resizable split layouts
- `Viewport` - Scrollable viewports
- `Toast` - Toast notifications
- `ContextMenu` - Context menus

### Rule 7: Simple Widget Usage

Simple widgets render directly with keyword options:

```elixir
alias TermUI.Widgets.Gauge
alias TermUI.Widgets.Sparkline

# In view/1 - call render directly
def view(state) do
  stack(:vertical, [
    # Gauge - progress bar
    Gauge.render(value: state.cpu_percent, width: 30, show_value: true),

    # Sparkline - inline trend graph
    Sparkline.render(values: state.cpu_history, style: Style.new(fg: :cyan))
  ])
end
```

### Rule 8: Stateful Widget Usage (CRITICAL)

Stateful widgets MUST follow the StatefulComponent pattern:

```elixir
# 1. Widget.new(opts) - Create props map
# 2. Widget.init(props) - Initialize state, returns {:ok, state}
# 3. Widget.handle_event(event, state) - Handle events, returns {:ok, new_state}
# 4. Widget.render(state, area) - Render to nodes
```

**Complete Example with TextInput:**

```elixir
defmodule MyApp do
  use TermUI.Elm

  alias TermUI.Event
  alias TermUI.Widgets.TextInput

  # 1. Initialize widget in init/1
  def init(_opts) do
    props = TextInput.new(
      placeholder: "Enter your name...",
      width: 40
    )
    {:ok, input_state} = TextInput.init(props)

    %{
      input: TextInput.set_focused(input_state, true),
      submitted_value: nil
    }
  end

  # 2. Route events to widget in event_to_msg/2
  def event_to_msg(%Event.Key{key: "q"}, state) do
    # Only quit if input is empty
    if TextInput.get_value(state.input) == "" do
      {:msg, :quit}
    else
      {:msg, {:input_event, %Event.Key{key: "q", char: "q"}}}
    end
  end

  def event_to_msg(%Event.Key{key: :enter}, state) do
    {:msg, {:submit, TextInput.get_value(state.input)}}
  end

  def event_to_msg(event, _state) do
    {:msg, {:input_event, event}}
  end

  # 3. Handle widget events in update/2
  def update(:quit, state), do: {state, [:quit]}

  def update({:submit, value}, state) do
    {%{state | submitted_value: value}, []}
  end

  def update({:input_event, event}, state) do
    {:ok, new_input} = TextInput.handle_event(event, state.input)
    {%{state | input: new_input}, []}
  end

  # 4. Render widget in view/1
  def view(state) do
    stack(:vertical, [
      text("Name:", Style.new(fg: :cyan)),
      TextInput.render(state.input, %{width: 50, height: 1}),
      text(""),
      if state.submitted_value do
        text("Hello, #{state.submitted_value}!", Style.new(fg: :green))
      else
        text("Press Enter to submit", Style.new(fg: :bright_black))
      end
    ])
  end
end
```

### Rule 9: Stateful Widget Helper Functions

Stateful widgets provide helper functions to query and modify state:

**TextInput helpers:**
```elixir
# Get current value
value = TextInput.get_value(input_state)

# Get cursor position {row, col}
{row, col} = TextInput.get_cursor(input_state)

# Get number of lines
count = TextInput.get_line_count(input_state)

# Set focus state
input_state = TextInput.set_focused(input_state, true)

# Clear the input
input_state = TextInput.clear(input_state)
```

**FormBuilder helpers:**
```elixir
# Get all form values as a map
values = FormBuilder.get_values(form_state)

# Check if form is valid
valid? = FormBuilder.valid?(form_state)
```

**Table helpers:**
```elixir
# Get selected rows
selected = Table.get_selected(table_state)

# Update data
table_state = Table.set_data(table_state, new_data)
```

### Rule 10: Common Stateful Widget Configurations

**TextInput:**
```elixir
TextInput.new(
  value: "",                    # Initial text
  placeholder: "Enter text...", # Shown when empty
  width: 40,                    # Character width
  multiline: false,             # Enable multi-line
  max_visible_lines: 5,         # Lines before scrolling
  enter_submits: false          # Enter submits vs newline
)
```

**Table:**
```elixir
alias TermUI.Widgets.Table
alias TermUI.Widgets.Table.Column

Table.new(
  columns: [
    Column.new(:name, "Name"),
    Column.new(:age, "Age", width: 10, align: :right)
  ],
  data: [
    %{name: "Alice", age: 30},
    %{name: "Bob", age: 25}
  ],
  selection_mode: :single,  # :none, :single, :multi
  sortable: true
)
```

**Menu:**
```elixir
Menu.new(
  items: [
    Menu.action(:new, "New File", shortcut: "Ctrl+N"),
    Menu.action(:open, "Open...", shortcut: "Ctrl+O"),
    Menu.separator(),
    Menu.submenu(:recent, "Recent Files", [
      Menu.action(:file1, "doc.txt"),
      Menu.action(:file2, "notes.md")
    ]),
    Menu.checkbox(:autosave, "Auto Save", checked: true)
  ]
)
```

**Dialog:**
```elixir
Dialog.new(
  title: "Confirm Delete",
  content: text("Are you sure?"),
  buttons: [
    %{id: :cancel, label: "Cancel"},
    %{id: :confirm, label: "Delete"}
  ],
  width: 50
)
```

**FormBuilder:**
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
  submit_label: "Register",
  label_width: 15,
  field_width: 30
)
```

**ProcessMonitor:**
```elixir
ProcessMonitor.new(
  update_interval: 1000,
  show_system_processes: false,
  thresholds: %{
    queue_warning: 1000,
    memory_warning: 50_000_000
  }
)
```

**Viewport:**
```elixir
Viewport.new(
  content: my_render_tree,     # The content to scroll (render node)
  content_width: 200,          # Total width of content
  content_height: 100,         # Total height of content
  width: 60,                   # Viewport width
  height: 20,                  # Viewport height
  scroll_x: 0,                 # Initial horizontal scroll
  scroll_y: 0,                 # Initial vertical scroll
  scroll_bars: :both           # :none, :vertical, :horizontal, or :both
)
```

Viewport helper functions:
```elixir
# Get current scroll position
{x, y} = Viewport.get_scroll(state)

# Set scroll position (clamped to valid range)
state = Viewport.set_scroll(state, 50, 100)

# Scroll to make a position visible
state = Viewport.scroll_into_view(state, target_x, target_y)

# Update content
state = Viewport.set_content(state, new_content)

# Update content dimensions
state = Viewport.set_content_size(state, new_width, new_height)

# Check if scrollable
Viewport.can_scroll_vertical?(state)    # true/false
Viewport.can_scroll_horizontal?(state)  # true/false
```

## Layout Rules

### Rule 11: Use Stack for Layout

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

### Rule 12: Constraint Types

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

### Rule 13: Loading States

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

### Rule 14: Modal/Dialog Pattern with Stateful Widget

```elixir
def init(_opts) do
  %{items: [], show_dialog: false, dialog: nil}
end

def update({:request_delete, item}, state) do
  props = Dialog.new(
    title: "Confirm Delete",
    content: text("Delete #{item.name}?"),
    buttons: [
      %{id: :cancel, label: "Cancel"},
      %{id: :confirm, label: "Delete"}
    ]
  )
  {:ok, dialog_state} = Dialog.init(props)

  {%{state | show_dialog: true, dialog: dialog_state, deleting: item}, []}
end

def event_to_msg(event, %{show_dialog: true} = state) do
  {:msg, {:dialog_event, event}}
end

def update({:dialog_event, %Event.Key{key: :enter}}, state) do
  # Check which button is focused and handle accordingly
  if state.dialog.focused_button == 1 do  # Confirm button
    items = Enum.reject(state.items, &(&1.id == state.deleting.id))
    {%{state | items: items, show_dialog: false, dialog: nil}, []}
  else
    {%{state | show_dialog: false, dialog: nil}, []}
  end
end

def update({:dialog_event, event}, state) do
  {:ok, dialog} = Dialog.handle_event(event, state.dialog)
  {%{state | dialog: dialog}, []}
end

def view(state) do
  base_view = render_items(state.items)

  if state.show_dialog do
    stack(:vertical, [
      base_view,
      Dialog.render(state.dialog, %{width: 80, height: 24})
    ])
  else
    base_view
  end
end
```

### Rule 15: Focus Management with Multiple Widgets

```elixir
def init(_opts) do
  {:ok, input1} = TextInput.init(TextInput.new(placeholder: "Name"))
  {:ok, input2} = TextInput.init(TextInput.new(placeholder: "Email"))

  %{
    focused: :input1,
    input1: TextInput.set_focused(input1, true),
    input2: input2
  }
end

def event_to_msg(%Event.Key{key: :tab}, _state), do: {:msg, :next_focus}

def update(:next_focus, state) do
  case state.focused do
    :input1 ->
      {%{state |
        focused: :input2,
        input1: TextInput.set_focused(state.input1, false),
        input2: TextInput.set_focused(state.input2, true)
      }, []}
    :input2 ->
      {%{state |
        focused: :input1,
        input1: TextInput.set_focused(state.input1, true),
        input2: TextInput.set_focused(state.input2, false)
      }, []}
  end
end

def event_to_msg(event, state) do
  {:msg, {:input_event, state.focused, event}}
end

def update({:input_event, :input1, event}, state) do
  {:ok, input} = TextInput.handle_event(event, state.input1)
  {%{state | input1: input}, []}
end

def update({:input_event, :input2, event}, state) do
  {:ok, input} = TextInput.handle_event(event, state.input2)
  {%{state | input2: input}, []}
end

def view(state) do
  stack(:vertical, [
    text("Name:"),
    TextInput.render(state.input1, %{width: 40, height: 1}),
    text("Email:"),
    TextInput.render(state.input2, %{width: 40, height: 1})
  ])
end
```

### Rule 16: Scrollable Content with Viewport

Use the Viewport widget when you have content larger than the display area:

```elixir
defmodule ScrollableLogViewer do
  use TermUI.Elm

  alias TermUI.Event
  alias TermUI.Renderer.Style
  alias TermUI.Widgets.Viewport

  def init(_opts) do
    # Generate large content
    content = generate_log_content()

    props = Viewport.new(
      content: content,
      content_width: 120,        # Content is 120 chars wide
      content_height: 500,       # Content is 500 lines
      width: 80,                 # Viewport shows 80 chars
      height: 20,                # Viewport shows 20 lines
      scroll_bars: :both
    )

    {:ok, viewport} = Viewport.init(props)
    %{viewport: viewport}
  end

  # Route events to viewport
  def event_to_msg(%Event.Key{key: "q"}, _state), do: {:msg, :quit}
  def event_to_msg(event, _state), do: {:msg, {:viewport_event, event}}

  def update(:quit, state), do: {state, [:quit]}

  def update({:viewport_event, event}, state) do
    {:ok, viewport} = Viewport.handle_event(event, state.viewport)
    {%{state | viewport: viewport}, []}
  end

  def view(state) do
    stack(:vertical, [
      text("Log Viewer (Arrow keys to scroll, Q to quit)", Style.new(fg: :cyan)),
      text(""),
      Viewport.render(state.viewport, %{width: 80, height: 20}),
      text(""),
      render_scroll_info(state.viewport)
    ])
  end

  defp render_scroll_info(viewport) do
    {x, y} = Viewport.get_scroll(viewport)
    text("Scroll position: (#{x}, #{y})", Style.new(fg: :bright_black))
  end

  defp generate_log_content do
    lines = for i <- 1..500 do
      {:text, "[#{timestamp(i)}] Log entry ##{i}: Some log message here with details"}
    end
    stack(:vertical, lines)
  end

  defp timestamp(i), do: "2024-01-01 12:#{rem(i, 60) |> Integer.to_string() |> String.pad_leading(2, "0")}:00"
end
```

**Viewport Keyboard Navigation (built-in):**
- Arrow keys: Scroll by one line/column
- Page Up/Down: Scroll by viewport height
- Home/End: Scroll to top/bottom
- Ctrl+Home/End: Scroll to top-left/bottom-right

**Viewport Mouse Support (built-in):**
- Mouse wheel: Scroll vertically
- Click on scroll bar track: Page scroll
- Drag scroll bar thumb: Direct positioning

### Rule 17: Polling/Animation

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

### Rule 17: Test Components in Isolation

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
  File.write!("data.json", Jason.encode!(state.data))
  {%{state | saving: false, saved: true}, []}
end
```

### Never Forget to Initialize Stateful Widgets

```elixir
# BAD - using stateful widget without init
def view(state) do
  TextInput.render(%{value: "hello"}, %{width: 40, height: 1})  # NO!
end

# GOOD - properly initialize in init/1
def init(_opts) do
  {:ok, input} = TextInput.init(TextInput.new(value: "hello"))
  %{input: input}
end

def view(state) do
  TextInput.render(state.input, %{width: 40, height: 1})
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
alias TermUI.Widgets.{Gauge, Sparkline, Table, Menu, TextInput, Dialog, FormBuilder, Viewport}

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

# Simple widgets (call in view)
Gauge.render(value: 75, width: 30)
Sparkline.render(values: [1, 2, 3, 4, 5])

# Stateful widgets (init in init/1, handle in update/2, render in view/1)
props = TextInput.new(placeholder: "Enter...")
{:ok, input_state} = TextInput.init(props)
{:ok, input_state} = TextInput.handle_event(event, input_state)
TextInput.render(input_state, %{width: 40, height: 1})

# Viewport for scrollable content
props = Viewport.new(content: my_content, content_width: 200, content_height: 100, width: 60, height: 20)
{:ok, viewport_state} = Viewport.init(props)
{:ok, viewport_state} = Viewport.handle_event(event, viewport_state)
Viewport.render(viewport_state, %{width: 60, height: 20})
{x, y} = Viewport.get_scroll(viewport_state)
viewport_state = Viewport.scroll_into_view(viewport_state, target_x, target_y)
```
