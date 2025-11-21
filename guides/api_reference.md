# Phase 3 API Reference

Quick reference for the TermUI component system API.

## Component Behaviours

### TermUI.Component

Base behaviour for stateless components.

```elixir
use TermUI.Component

# Required
@callback render(props :: map(), area :: rect()) :: render_tree()

# Optional
@callback describe() :: component_info()
@callback default_props() :: map()
```

### TermUI.StatefulComponent

Behaviour for stateful, interactive components.

```elixir
use TermUI.StatefulComponent

# Required
@callback init(props :: map()) :: {:ok, state()}
@callback handle_event(event :: term(), state()) :: event_result()
@callback render(state(), area :: rect()) :: render_tree()

# Optional
@callback mount(state()) :: {:ok, state()} | {:ok, state(), [command()]}
@callback unmount(state()) :: :ok
@callback handle_info(msg :: term(), state()) :: {:noreply, state()}
@callback handle_call(request :: term(), from :: GenServer.from(), state()) :: {:reply, reply, state()}
@callback terminate(reason :: term(), state()) :: term()
```

### TermUI.Container

Behaviour for components that manage children.

```elixir
use TermUI.Container

# Required (in addition to StatefulComponent)
@callback children(state()) :: [child_spec()]
@callback layout(children :: [component_ref()], area :: rect(), state()) :: [{component_ref(), rect()}]

# Optional
@callback handle_child_message(child_id :: term(), msg :: term(), state()) :: {:ok, state()}
@callback route_event(event :: term(), state()) :: {:route, component_id()} | :self
```

## ComponentServer

Manages individual component lifecycle.

```elixir
# Start and mount
{:ok, pid} = ComponentSupervisor.start_component(Module, props, id: :id)
:ok = ComponentServer.mount(pid)

# Query state
state = ComponentServer.get_state(pid)

# Send events
:ok = ComponentServer.send_event(pid, event)

# Update props
:ok = ComponentServer.update_props(pid, new_props)

# Request render
render_tree = ComponentServer.render(pid, area)
```

## ComponentSupervisor

Supervises all component processes.

```elixir
# Start component
{:ok, pid} = ComponentSupervisor.start_component(Module, props, opts)

# Options
opts = [
  id: :component_id,           # Required
  restart: :transient,         # :transient | :permanent | :temporary
  recovery: :reset,            # :reset | :last_state | :last_props
  max_restarts: 3,             # Restart limit
  max_seconds: 5               # Time window for restarts
]

# Stop component
:ok = ComponentSupervisor.stop_component(:id)
:ok = ComponentSupervisor.stop_component(:id, cascade: true)

# Query
count = ComponentSupervisor.count_children()
tree = ComponentSupervisor.get_tree()
{:ok, info} = ComponentSupervisor.get_component_info(:id)
tree_text = ComponentSupervisor.format_tree()
```

## ComponentRegistry

Tracks components and their relationships.

```elixir
# Lookup
{:ok, pid} = ComponentRegistry.lookup(:id)

# Relationships
:ok = ComponentRegistry.set_parent(:child, :parent)
{:ok, parent_id} = ComponentRegistry.get_parent(:id)
children = ComponentRegistry.get_children(:id)

# All components
components = ComponentRegistry.list_all()
```

## EventRouter

Routes events to components.

```elixir
# Route event to appropriate target
:handled | :unhandled = EventRouter.route(event)

# Route to specific component
:handled | :unhandled = EventRouter.route_to(:id, event)

# Broadcast to all
{:ok, count} = EventRouter.broadcast(event)

# Focus management
:ok = EventRouter.set_focus(:id)
{:ok, id} = EventRouter.get_focus()
:ok = EventRouter.clear_focus()

# Fallback handler
:ok = EventRouter.set_fallback_handler(fn event -> :ok end)
:ok = EventRouter.clear_fallback_handler()
```

## FocusManager

Manages focus state and traversal.

```elixir
# Current focus
{:ok, id | nil} = FocusManager.get_focused()
:ok = FocusManager.set_focused(:id)
:ok = FocusManager.clear_focus()

# Traversal
:ok = FocusManager.focus_next()
:ok = FocusManager.focus_prev()

# Focus stack (for modals)
:ok = FocusManager.push_focus(:modal_component)
:ok = FocusManager.pop_focus()

# Focus groups and trapping
:ok = FocusManager.register_group(:group, [:id1, :id2, :id3])
:ok = FocusManager.trap_focus(:group)
:ok = FocusManager.release_focus()
:ok = FocusManager.unregister_group(:group)
```

## SpatialIndex

Maps screen positions to components for mouse routing.

```elixir
# Register bounds
:ok = SpatialIndex.update(:id, pid, %{x: 0, y: 0, width: 20, height: 5})
:ok = SpatialIndex.update(:id, pid, bounds, z_index: 100)

# Query
{:ok, {id, pid}} = SpatialIndex.find_at(x, y)
{:error, :not_found} = SpatialIndex.find_at(x, y)

# Remove
:ok = SpatialIndex.remove(:id)
```

## Event Types

```elixir
# Keyboard
%TermUI.Event.Key{
  key: :enter | :tab | :up | :down | :left | :right | :backspace | :delete | :escape | :home | :end | :page_up | :page_down | :f1..f12 | atom(),
  char: String.t() | nil,
  modifiers: [:ctrl | :alt | :shift],
  timestamp: integer()
}

# Mouse
%TermUI.Event.Mouse{
  action: :click | :release | :move | :scroll_up | :scroll_down,
  button: :left | :right | :middle | nil,
  x: integer(),
  y: integer(),
  modifiers: [:ctrl | :alt | :shift],
  timestamp: integer()
}

# Focus
%TermUI.Event.Focus{
  type: :gained | :lost
}

# Custom
%TermUI.Event.Custom{
  name: atom(),
  payload: term()
}
```

## StatePersistence

Persists state for crash recovery.

```elixir
# Manual persistence
:ok = StatePersistence.persist(:id, state)

# Recovery
{:ok, state} = StatePersistence.recover(:id, :last_state)
:not_found = StatePersistence.recover(:id, :reset)

# Restart tracking
count = StatePersistence.get_restart_count(:id)
:ok = StatePersistence.increment_restart_count(:id)
```

## Essential Widgets

### Block

Container with border and title.

```elixir
%{
  border: :none | :single | :double | :rounded | :thick,
  title: String.t() | nil,
  title_align: :left | :center | :right,
  padding: integer() | %{top: i, bottom: i, left: i, right: i}
}
```

### Label

Text display.

```elixir
%{
  text: String.t(),
  style: Style.t(),
  align: :left | :center | :right,
  wrap: boolean(),
  truncate: boolean()
}
```

### Button

Clickable action trigger.

```elixir
%{
  label: String.t(),
  on_click: (-> any()),
  disabled: boolean(),
  style: Style.t(),
  focus_style: Style.t()
}
```

### TextInput

Single-line text entry.

```elixir
%{
  value: String.t(),
  placeholder: String.t(),
  on_change: (String.t() -> any()),
  on_submit: (String.t() -> any()),
  password: boolean(),
  max_length: integer() | nil
}
```

### List

Selectable item list.

```elixir
%{
  items: [String.t() | {String.t(), term()}],
  selected: integer() | [integer()],
  on_select: (term() -> any()),
  multi_select: boolean(),
  highlight_style: Style.t()
}
```

### Progress

Progress indicator.

```elixir
%{
  value: float(),  # 0.0 to 1.0
  mode: :bar | :spinner,
  show_percent: boolean(),
  bar_char: String.t(),
  empty_char: String.t()
}
```

## Type Reference

```elixir
@type rect :: %{x: integer(), y: integer(), width: integer(), height: integer()}
@type render_tree :: RenderNode.t() | [render_tree()] | String.t()
@type child_spec :: {module(), props :: map()} | {module(), props :: map(), id :: term()}
@type event_result :: {:ok, state()} | {:ok, state(), [command()]} | {:stop, reason, state()}
@type command :: {:send, pid(), term()} | {:timer, ms, term()} | {:focus, term()} | term()
```

## Running Tests

```bash
# All Phase 3 tests
mix test test/term_ui/component* test/term_ui/event* test/term_ui/focus* test/term_ui/widget test/term_ui/spatial* test/term_ui/integration/

# Integration tests only
mix test test/term_ui/integration/

# Specific module
mix test test/term_ui/focus_manager_test.exs
```

## Generating Documentation

```bash
mix docs
open doc/index.html
```
