# The Elm Architecture

The Elm Architecture (TEA) is the core pattern used by TermUI for building interactive applications. It provides predictable state management and a clear separation of concerns.

## Overview

The architecture consists of three parts:

1. **Model** - The state of your application
2. **Update** - How state changes in response to messages
3. **View** - How state is rendered to the screen

```
    ┌─────────────────────────────────────────┐
    │                                         │
    │  ┌─────────┐   message   ┌──────────┐  │
    │  │  View   │ ◄────────── │  Update  │  │
    │  └────┬────┘             └────▲─────┘  │
    │       │                       │        │
    │       │ render tree           │ msg    │
    │       ▼                       │        │
    │  ┌─────────┐   event    ┌────┴─────┐  │
    │  │ Runtime │ ──────────►│event_to_ │  │
    │  │         │            │   msg    │  │
    │  └─────────┘            └──────────┘  │
    │                                         │
    └─────────────────────────────────────────┘
```

## The Four Callbacks

### `init/1` - Initialize State

Called once when your component starts. Receives options and returns initial state.

```elixir
def init(opts) do
  name = Keyword.get(opts, :name, "World")
  %{
    name: name,
    count: 0,
    items: []
  }
end
```

State is typically a map, but can be any Elixir term.

### `event_to_msg/2` - Convert Events to Messages

Transforms terminal events into application-specific messages.

```elixir
def event_to_msg(%Event.Key{key: :enter}, state) do
  {:msg, {:submit, state.input}}
end

def event_to_msg(%Event.Key{key: :escape}, _state) do
  {:msg, :cancel}
end

def event_to_msg(%Event.Mouse{action: :click, x: x, y: y}, _state) do
  {:msg, {:clicked, x, y}}
end

def event_to_msg(_event, _state) do
  :ignore
end
```

**Return values:**

| Return | Effect |
|--------|--------|
| `{:msg, message}` | Send message to `update/2` |
| `:ignore` | Discard the event |
| `:propagate` | Pass to parent component |

### `update/2` - Handle Messages

Receives a message and current state, returns new state and commands.

```elixir
def update(:increment, state) do
  {%{state | count: state.count + 1}, []}
end

def update({:set_name, name}, state) do
  {%{state | name: name}, []}
end

def update(:save, state) do
  # Return a command to perform side effect
  {state, [Command.file_write("data.txt", state.data, :save_complete)]}
end

def update({:save_complete, :ok}, state) do
  {%{state | saved: true}, []}
end
```

**Return format:** `{new_state, commands}`

- `new_state` - The updated state
- `commands` - List of side effects to execute (can be empty `[]`)

### `view/1` - Render State

Transforms state into a render tree describing what to display.

```elixir
def view(state) do
  stack(:vertical, [
    text("Hello, #{state.name}!", Style.new(fg: :cyan)),
    text(""),
    text("Count: #{state.count}"),
    render_items(state.items)
  ])
end

defp render_items([]), do: text("No items")
defp render_items(items) do
  stack(:vertical, Enum.map(items, fn item ->
    text("• #{item}")
  end))
end
```

The view function should be **pure** - given the same state, it always returns the same render tree.

## Message Flow

Here's the complete flow when a user presses a key:

1. **Input** - User presses `↑` key
2. **Event** - Runtime creates `%Event.Key{key: :up}`
3. **Routing** - Event sent to focused component
4. **Transform** - `event_to_msg(%Event.Key{key: :up}, state)` returns `{:msg, :increment}`
5. **Update** - `update(:increment, state)` returns `{new_state, []}`
6. **Dirty** - Component marked for re-render
7. **Render** - On next frame, `view(new_state)` called
8. **Diff** - Render tree compared to previous
9. **Output** - Only changes sent to terminal

## Commands

Commands represent side effects that happen outside the pure update cycle.

```elixir
def update(:start_timer, state) do
  {state, [Command.timer(1000, :timer_tick)]}
end

def update(:timer_tick, state) do
  {%{state | ticks: state.ticks + 1}, []}
end
```

See [Commands](09-commands.md) for full documentation.

## State Design

### Keep State Minimal

Only store what you need to render and respond to events:

```elixir
# Good - minimal state
%{
  selected_index: 0,
  items: ["a", "b", "c"]
}

# Avoid - derived data in state
%{
  selected_index: 0,
  items: ["a", "b", "c"],
  selected_item: "a",      # Can be derived
  item_count: 3            # Can be derived
}
```

### Derive Values in View

Compute derived values when rendering:

```elixir
def view(state) do
  selected_item = Enum.at(state.items, state.selected_index)
  item_count = length(state.items)

  stack(:vertical, [
    text("Selected: #{selected_item}"),
    text("Total: #{item_count} items")
  ])
end
```

### Normalize State Updates

Use helper functions for complex state changes:

```elixir
def update(:next_item, state) do
  {select_next(state), []}
end

def update(:prev_item, state) do
  {select_prev(state), []}
end

defp select_next(state) do
  max_index = length(state.items) - 1
  new_index = min(state.selected_index + 1, max_index)
  %{state | selected_index: new_index}
end

defp select_prev(state) do
  new_index = max(state.selected_index - 1, 0)
  %{state | selected_index: new_index}
end
```

## Patterns

### Loading States

```elixir
def init(_opts) do
  %{status: :loading, data: nil, error: nil}
end

def update(:load, state) do
  {%{state | status: :loading}, [Command.http_get(url, :data_loaded)]}
end

def update({:data_loaded, {:ok, data}}, state) do
  {%{state | status: :ready, data: data}, []}
end

def update({:data_loaded, {:error, reason}}, state) do
  {%{state | status: :error, error: reason}, []}
end

def view(state) do
  case state.status do
    :loading -> text("Loading...")
    :error -> text("Error: #{state.error}", Style.new(fg: :red))
    :ready -> render_data(state.data)
  end
end
```

### Form Input

```elixir
def init(_opts) do
  %{name: "", email: "", focused: :name}
end

def event_to_msg(%Event.Key{key: :tab}, _state), do: {:msg, :next_field}
def event_to_msg(%Event.Key{char: char}, state) when is_binary(char) do
  {:msg, {:input, state.focused, char}}
end

def update(:next_field, state) do
  next = case state.focused do
    :name -> :email
    :email -> :name
  end
  {%{state | focused: next}, []}
end

def update({:input, field, char}, state) do
  current = Map.get(state, field)
  {Map.put(state, field, current <> char), []}
end
```

### Confirmation Dialogs

```elixir
def init(_opts) do
  %{items: [...], confirm_delete: nil}
end

def update({:request_delete, item}, state) do
  {%{state | confirm_delete: item}, []}
end

def update(:confirm_delete, state) do
  items = List.delete(state.items, state.confirm_delete)
  {%{state | items: items, confirm_delete: nil}, []}
end

def update(:cancel_delete, state) do
  {%{state | confirm_delete: nil}, []}
end

def view(state) do
  if state.confirm_delete do
    render_confirm_dialog(state.confirm_delete)
  else
    render_items(state.items)
  end
end
```

## Testing

The Elm Architecture makes testing straightforward:

```elixir
defmodule MyApp.CounterTest do
  use ExUnit.Case

  alias MyApp.Counter

  test "init returns zero count" do
    state = Counter.init([])
    assert state.count == 0
  end

  test "increment increases count" do
    state = %{count: 5}
    {new_state, []} = Counter.update(:increment, state)
    assert new_state.count == 6
  end

  test "up key sends increment message" do
    event = %Event.Key{key: :up}
    assert {:msg, :increment} = Counter.event_to_msg(event, %{})
  end

  test "view renders count" do
    state = %{count: 42}
    tree = Counter.view(state)
    # Assert on render tree structure
  end
end
```

## Next Steps

- [Events](04-events.md) - All event types and handling
- [Commands](09-commands.md) - Side effects in detail
- [Widgets](07-widgets.md) - Pre-built components
