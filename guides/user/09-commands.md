# Commands

Commands represent side effects in TermUI applications. They're returned from `update/2` and executed asynchronously by the runtime.

## Why Commands?

The Elm Architecture keeps `update/2` pure - it only transforms state based on messages. Side effects like timers, file I/O, and HTTP requests are described as commands and executed by the runtime.

Benefits:
- **Testable** - Test state logic without mocking side effects
- **Predictable** - State changes are synchronous and traceable
- **Composable** - Combine multiple commands easily

## Command Basics

Return commands from `update/2`:

```elixir
def update(:start_timer, state) do
  # Return new state AND a list of commands
  {state, [Command.timer(1000, :timer_done)]}
end

def update(:timer_done, state) do
  # Handle the result
  {%{state | timer_fired: true}, []}
end
```

## Available Commands

### Timer

Execute a message after a delay:

```elixir
# Fire :timeout message after 5 seconds
Command.timer(5000, :timeout)

# With data in the message
Command.timer(1000, {:delayed_action, some_data})
```

### Quit

Request application shutdown:

```elixir
def update(:quit, state) do
  {state, [:quit]}
end

# Or using Command module
def update(:quit, state) do
  {state, [Command.quit()]}
end
```

The runtime will:
1. Stop accepting new events
2. Clean up resources
3. Restore terminal state
4. Exit the process

### None

Explicit no-op (useful for conditional commands):

```elixir
def update(:maybe_save, state) do
  cmd = if state.dirty do
    Command.timer(0, :do_save)
  else
    Command.none()
  end
  {state, [cmd]}
end
```

## Command Patterns

### Debouncing

Delay action until input stops:

```elixir
def init(_opts) do
  %{search: "", debounce_ref: nil}
end

def update({:search_input, text}, state) do
  # Cancel previous timer if any
  commands = if state.debounce_ref do
    []  # Previous timer will be ignored
  else
    []
  end

  # Start new debounce timer
  ref = make_ref()
  commands = commands ++ [Command.timer(300, {:do_search, ref})]

  {%{state | search: text, debounce_ref: ref}, commands}
end

def update({:do_search, ref}, %{debounce_ref: ref} = state) do
  # Ref matches - this is the latest search
  # Perform search...
  {%{state | results: search(state.search)}, []}
end

def update({:do_search, _old_ref}, state) do
  # Ref doesn't match - ignore stale search
  {state, []}
end
```

### Chained Operations

Sequence multiple async operations:

```elixir
def update(:start_workflow, state) do
  {%{state | step: :loading}, [Command.timer(0, :step_1)]}
end

def update(:step_1, state) do
  # Do step 1...
  {%{state | step: :step_1_done}, [Command.timer(100, :step_2)]}
end

def update(:step_2, state) do
  # Do step 2...
  {%{state | step: :step_2_done}, [Command.timer(100, :step_3)]}
end

def update(:step_3, state) do
  {%{state | step: :complete}, []}
end
```

### Polling

Periodic updates:

```elixir
def init(_opts) do
  # Start polling immediately
  %{data: nil}
end

def update(:init, state) do
  {state, [Command.timer(0, :poll)]}
end

def update(:poll, state) do
  # Fetch new data
  new_data = fetch_data()

  # Schedule next poll
  {%{state | data: new_data}, [Command.timer(5000, :poll)]}
end
```

### Conditional Commands

Build command list based on state:

```elixir
def update(:save, state) do
  commands = []

  # Always show saving indicator
  commands = commands ++ [Command.timer(0, :show_saving)]

  # Maybe backup first
  commands = if state.backup_enabled do
    commands ++ [Command.timer(0, :backup)]
  else
    commands
  end

  # Do the save
  commands = commands ++ [Command.timer(100, :do_save)]

  {state, commands}
end
```

### Error Handling

Handle command failures:

```elixir
def update(:load_data, state) do
  {%{state | loading: true}, [Command.timer(0, :do_load)]}
end

def update(:do_load, state) do
  case fetch_data() do
    {:ok, data} ->
      {%{state | loading: false, data: data, error: nil}, []}

    {:error, reason} ->
      {%{state | loading: false, error: reason}, []}
  end
end

def view(state) do
  cond do
    state.loading -> text("Loading...")
    state.error -> text("Error: #{state.error}", Style.new(fg: :red))
    true -> render_data(state.data)
  end
end
```

### Animation

Frame-based animation:

```elixir
@frame_interval 50  # ~20 FPS

def init(_opts) do
  %{frame: 0, animating: false}
end

def update(:start_animation, state) do
  {%{state | animating: true, frame: 0}, [Command.timer(@frame_interval, :animate)]}
end

def update(:animate, %{animating: true} = state) do
  next_frame = state.frame + 1

  if next_frame >= 60 do
    # Animation complete
    {%{state | animating: false}, []}
  else
    # Continue animation
    {%{state | frame: next_frame}, [Command.timer(@frame_interval, :animate)]}
  end
end

def update(:animate, state) do
  # Animation was stopped
  {state, []}
end

def update(:stop_animation, state) do
  {%{state | animating: false}, []}
end
```

### Spinner

Indeterminate progress indicator:

```elixir
@spinner_frames ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"]
@spinner_interval 80

def init(_opts) do
  %{loading: false, spinner_frame: 0}
end

def update(:start_loading, state) do
  {%{state | loading: true}, [Command.timer(@spinner_interval, :spin)]}
end

def update(:spin, %{loading: true} = state) do
  next_frame = rem(state.spinner_frame + 1, length(@spinner_frames))
  {%{state | spinner_frame: next_frame}, [Command.timer(@spinner_interval, :spin)]}
end

def update(:spin, state) do
  {state, []}
end

def update(:stop_loading, state) do
  {%{state | loading: false}, []}
end

def view(state) do
  if state.loading do
    frame = Enum.at(@spinner_frames, state.spinner_frame)
    text("#{frame} Loading...")
  else
    text("Ready")
  end
end
```

## Multiple Commands

Return multiple commands at once:

```elixir
def update(:initialize, state) do
  commands = [
    Command.timer(0, :load_config),
    Command.timer(0, :load_data),
    Command.timer(0, :start_heartbeat)
  ]
  {state, commands}
end
```

Commands execute concurrently. Results arrive as separate messages.

## Testing Commands

Test that correct commands are returned:

```elixir
defmodule MyApp.ComponentTest do
  use ExUnit.Case
  alias TermUI.Command

  test "quit returns quit command" do
    state = %{count: 0}
    {_new_state, commands} = MyApp.Component.update(:quit, state)

    assert :quit in commands
  end

  test "start timer returns timer command" do
    state = %{}
    {_new_state, commands} = MyApp.Component.update(:start, state)

    assert [Command.timer(1000, :tick)] == commands
  end
end
```

## Custom Commands

For operations not covered by built-in commands, use timer with immediate execution:

```elixir
def update(:custom_operation, state) do
  # Timer with 0 delay executes on next message loop
  {state, [Command.timer(0, :do_custom)]}
end

def update(:do_custom, state) do
  # Perform the operation synchronously
  result = perform_custom_operation()
  {%{state | result: result}, []}
end
```

For truly async operations (HTTP, file I/O), spawn a task:

```elixir
def update(:fetch_data, state) do
  # Start async task
  Task.start(fn ->
    result = HTTPClient.get(url)
    # Send result back to runtime
    send(self(), {:data_loaded, result})
  end)

  {%{state | loading: true}, []}
end

# In event_to_msg or handle_info
def event_to_msg({:data_loaded, result}, _state) do
  {:msg, {:data_loaded, result}}
end
```

## Next Steps

- [Elm Architecture](03-elm-architecture.md) - How commands fit in
- [Events](04-events.md) - Handle command results
- [Widgets](07-widgets.md) - Animated widgets
