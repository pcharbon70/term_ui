# Component System Guide

This guide covers how to build TUI applications using TermUI's component system. By the end, you'll understand how to create components, handle events, manage focus, and build hierarchical UIs.

## Table of Contents

1. [Core Concepts](#core-concepts)
2. [Creating Components](#creating-components)
3. [Component Lifecycle](#component-lifecycle)
4. [Event Handling](#event-handling)
5. [Focus Management](#focus-management)
6. [Building Hierarchies](#building-hierarchies)
7. [Fault Tolerance](#fault-tolerance)
8. [Best Practices](#best-practices)

## Core Concepts

TermUI's component system is built on OTP processes. Each component is a GenServer that:
- Maintains its own state
- Receives events as messages
- Produces render trees
- Is supervised for fault tolerance

### Component Behaviours

Three behaviours define component types:

| Behaviour | Use Case | Key Callbacks |
|-----------|----------|---------------|
| `Component` | Stateless display | `render/2` |
| `StatefulComponent` | Interactive widgets | `init/1`, `handle_event/2`, `render/2` |
| `Container` | Layout with children | All above + `children/1`, `layout/3` |

## Creating Components

### Stateless Components

Use `Component` for display-only widgets:

```elixir
defmodule MyApp.Divider do
  use TermUI.Component

  @impl true
  def render(props, area) do
    char = props[:char] || "-"
    String.duplicate(char, area.width)
  end
end
```

### Stateful Components

Use `StatefulComponent` for interactive widgets:

```elixir
defmodule MyApp.Counter do
  use TermUI.StatefulComponent

  @impl true
  def init(props) do
    {:ok, %{
      count: props[:initial] || 0,
      step: props[:step] || 1
    }}
  end

  @impl true
  def handle_event(%TermUI.Event.Key{key: :up}, state) do
    {:ok, %{state | count: state.count + state.step}}
  end

  def handle_event(%TermUI.Event.Key{key: :down}, state) do
    {:ok, %{state | count: max(0, state.count - state.step)}}
  end

  def handle_event(_event, state) do
    {:ok, state}
  end

  @impl true
  def render(state, _area) do
    text("Count: #{state.count}")
  end
end
```

### Container Components

Use `Container` to manage children:

```elixir
defmodule MyApp.Panel do
  use TermUI.Container

  @impl true
  def init(props) do
    {:ok, %{
      title: props[:title],
      children: props[:children] || []
    }}
  end

  @impl true
  def children(state) do
    state.children
  end

  @impl true
  def layout(children, area, _state) do
    # Stack children vertically
    Enum.with_index(children)
    |> Enum.map(fn {child, idx} ->
      {child, %{x: area.x, y: area.y + idx, width: area.width, height: 1}}
    end)
  end

  @impl true
  def handle_event(_event, state) do
    {:ok, state}
  end

  @impl true
  def render(state, area) do
    box(border: :single, title: state.title) do
      # Children render here
    end
  end
end
```

## Component Lifecycle

Components go through defined lifecycle stages:

```
┌─────────────────────────────────────────┐
│  init/1                                 │
│  └─ Called with props                   │
│     Returns {:ok, initial_state}        │
└─────────────┬───────────────────────────┘
              │
              ▼
┌─────────────────────────────────────────┐
│  mount/1  (optional)                    │
│  └─ Component added to tree             │
│     Start timers, fetch data            │
│     Returns {:ok, state}                │
└─────────────┬───────────────────────────┘
              │
              ▼
┌─────────────────────────────────────────┐
│  handle_event/2  (loop)                 │
│  └─ Process user input                  │
│     Returns {:ok, new_state}            │
└─────────────┬───────────────────────────┘
              │
              ▼
┌─────────────────────────────────────────┐
│  unmount/1  (optional)                  │
│  └─ Component removed from tree         │
│     Cleanup resources                   │
│     Returns :ok                         │
└─────────────────────────────────────────┘
```

### Lifecycle Hooks

Register hooks for lifecycle events:

```elixir
defmodule MyApp.Widget do
  use TermUI.StatefulComponent

  @impl true
  def init(props) do
    {:ok, %{value: props[:value]}}
  end

  # Called after mount completes
  @impl true
  def mount(state) do
    # Start a timer, register handlers, etc.
    {:ok, state}
  end

  # Called before unmount
  @impl true
  def unmount(state) do
    # Cleanup resources
    :ok
  end
end
```

## Event Handling

### Event Types

TermUI supports these event types:

```elixir
# Keyboard events
%TermUI.Event.Key{
  key: :enter,        # Key symbol
  char: nil,          # Character if printable
  modifiers: [:ctrl]  # Active modifiers
}

# Mouse events
%TermUI.Event.Mouse{
  action: :click,     # :click, :move, :scroll
  button: :left,      # :left, :right, :middle
  x: 10, y: 5,        # Screen coordinates
  modifiers: []
}

# Focus events
%TermUI.Event.Focus{
  type: :gained  # :gained or :lost
}

# Custom events
%TermUI.Event.Custom{
  name: :my_event,
  payload: %{data: "value"}
}
```

### Handling Events

Components receive events via `handle_event/2`:

```elixir
@impl true
def handle_event(%Event.Key{key: :enter}, state) do
  # Handle Enter key
  {:ok, %{state | submitted: true}}
end

def handle_event(%Event.Key{char: char}, state) when char != nil do
  # Handle character input
  {:ok, %{state | text: state.text <> char}}
end

def handle_event(%Event.Mouse{action: :click}, state) do
  # Handle mouse click
  {:ok, %{state | clicked: true}}
end

def handle_event(_event, state) do
  # Ignore other events
  {:ok, state}
end
```

### Event Routing

Events are routed automatically:
- **Keyboard events** → Focused component
- **Mouse events** → Component at click position
- **Focus events** → Component gaining/losing focus

Use `EventRouter` to route events:

```elixir
# Route to focused component
EventRouter.route(%Event.Key{key: :tab})

# Route to specific component
EventRouter.route_to(:my_component, event)

# Broadcast to all components
EventRouter.broadcast({:resize, 80, 24})
```

## Focus Management

### Setting Focus

```elixir
# Set focus to a component
FocusManager.set_focused(:my_input)

# Get currently focused component
{:ok, focused_id} = FocusManager.get_focused()

# Clear focus
FocusManager.clear_focus()
```

### Tab Navigation

Focus traversal follows spatial order (left-to-right, top-to-bottom):

```elixir
# Move to next focusable component
FocusManager.focus_next()

# Move to previous focusable component
FocusManager.focus_prev()
```

### Focus Stack for Modals

When opening modals, push/pop focus to restore properly:

```elixir
# Open modal - save current focus
def open_modal(modal_component) do
  FocusManager.push_focus(modal_component)
end

# Close modal - restore previous focus
def close_modal() do
  FocusManager.pop_focus()
end
```

### Focus Trapping

Keep Tab within a group (e.g., modal dialog):

```elixir
# Register a focus group
FocusManager.register_group(:dialog, [:ok_button, :cancel_button, :input])

# Trap focus in the group
FocusManager.trap_focus(:dialog)

# Release trap when modal closes
FocusManager.release_focus()
```

## Building Hierarchies

### Component Registration

Components must be registered to work with the system:

```elixir
# Start a component under supervision
{:ok, pid} = ComponentSupervisor.start_component(
  MyApp.Counter,
  %{initial: 0},
  id: :my_counter
)

# Mount the component
ComponentServer.mount(pid)

# Register spatial bounds for mouse events
SpatialIndex.update(:my_counter, pid, %{x: 0, y: 0, width: 20, height: 1})
```

### Parent-Child Relationships

```elixir
# Set up hierarchy
ComponentRegistry.set_parent(:child_id, :parent_id)

# Query hierarchy
{:ok, parent} = ComponentRegistry.get_parent(:child_id)
children = ComponentRegistry.get_children(:parent_id)
```

### Stopping Components

```elixir
# Stop single component
ComponentSupervisor.stop_component(:my_counter)

# Stop with cascade (stops children too)
ComponentSupervisor.stop_component(:parent, cascade: true)
```

## Fault Tolerance

### Restart Strategies

Components can specify restart behavior:

```elixir
# Restart on crash (default)
ComponentSupervisor.start_component(Module, props,
  id: :id, restart: :transient)

# Always restart
ComponentSupervisor.start_component(Module, props,
  id: :id, restart: :permanent)

# Never restart
ComponentSupervisor.start_component(Module, props,
  id: :id, restart: :temporary)
```

### State Recovery

Persist state for recovery after crash:

```elixir
ComponentSupervisor.start_component(Module, props,
  id: :id,
  restart: :transient,
  recovery: :last_state  # Recover previous state
)
```

Recovery options:
- `:reset` - Start fresh (default)
- `:last_state` - Recover previous state
- `:last_props` - Restart with same props

### Supervision Introspection

Monitor the component tree:

```elixir
# Get tree structure
tree = ComponentSupervisor.get_tree()

# Get component info
info = ComponentSupervisor.get_component_info(:my_counter)
# => %{pid: #PID<...>, restart_count: 0, uptime: 12345}

# Count children
count = ComponentSupervisor.count_children()
```

## Best Practices

### 1. Keep Components Focused

Each component should do one thing well:

```elixir
# Good - focused component
defmodule MyApp.EmailInput do
  # Only handles email input
end

# Bad - doing too much
defmodule MyApp.UserForm do
  # Handles multiple inputs, validation, submission...
end
```

### 2. Initialize Fast

Defer expensive operations to `mount/1`:

```elixir
def init(props) do
  # Fast - just set up state
  {:ok, %{data: nil, loading: true}}
end

def mount(state) do
  # Slow operations here
  data = fetch_data()
  {:ok, %{state | data: data, loading: false}}
end
```

### 3. Handle All Events

Always have a catch-all clause:

```elixir
def handle_event(%Event.Key{key: :enter}, state) do
  {:ok, handle_submit(state)}
end

def handle_event(_event, state) do
  # Important! Don't crash on unexpected events
  {:ok, state}
end
```

### 4. Clean Up Resources

Use `unmount/1` for cleanup:

```elixir
def mount(state) do
  timer_ref = :timer.send_interval(1000, self(), :tick)
  {:ok, %{state | timer: timer_ref}}
end

def unmount(state) do
  if state.timer, do: :timer.cancel(state.timer)
  :ok
end
```

### 5. Use Commands for Side Effects

Don't perform side effects directly - return commands:

```elixir
def handle_event(%Event.Key{key: :enter}, state) do
  # Don't do this:
  # send(parent, {:submitted, state.value})

  # Do this:
  {:ok, state, [{:send, parent, {:submitted, state.value}}]}
end
```

### 6. Leverage Supervision

Structure your app for fault isolation:

```elixir
# Critical components
ComponentSupervisor.start_component(Core, props,
  restart: :permanent)

# User components that can fail
ComponentSupervisor.start_component(UserWidget, props,
  restart: :transient, recovery: :last_state)
```

## Essential Widgets Reference

TermUI provides these built-in widgets:

| Widget | Purpose | Key Props |
|--------|---------|-----------|
| `Block` | Container with border | `border`, `title`, `padding` |
| `Label` | Text display | `text`, `align`, `wrap` |
| `Button` | Clickable action | `label`, `on_click`, `disabled` |
| `TextInput` | Text entry | `value`, `on_change`, `on_submit` |
| `List` | Selectable items | `items`, `selected`, `on_select` |
| `Progress` | Progress indicator | `value`, `mode`, `show_percent` |

See individual widget documentation for full details.

## Next Steps

- Explore the widget source code in `lib/term_ui/widget/`
- Check integration tests in `test/term_ui/integration/` for examples
- Read module documentation with `mix docs`
