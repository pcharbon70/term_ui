# Commands

Commands are data returned from `update/2`. `TermUI.Runtime` executes supported
commands and delivers their results back to the same root as messages.

```elixir
alias TermUI.Command

def update(:start, state) do
  {%{state | waiting: true}, [Command.timer(1_000, :timer_done)]}
end

def update(:timer_done, state) do
  {%{state | waiting: false}, []}
end
```

## Supported commands

### Timer

```elixir
Command.timer(5_000, :timeout)
Command.timer(1_000, {:delayed, value})
```

The configured message is delivered once after the delay.

### Interval

```elixir
Command.interval(1_000, :tick)
```

The message repeats until the runtime shuts down and cancels root commands.
The 1.0 Runtime API does not expose the generated command ID, so an interval
cannot be individually cancelled through the public runtime. For stoppable
animation, recursively schedule one-shot timers and ignore stale messages.

### File read

```elixir
def update({:load, path}, state) do
  command =
    path
    |> Command.file_read(:file_loaded)
    |> Command.with_timeout(5_000)

  {%{state | loading: true}, [command]}
end

def update({:file_loaded, {:ok, contents}}, state) do
  {%{state | loading: false, contents: contents}, []}
end

def update({:file_loaded, {:error, reason}}, state) do
  {%{state | loading: false, error: reason}, []}
end

def update({:error, :timeout}, state) do
  {%{state | loading: false, error: :timeout}, []}
end
```

`file_read/2` is the built-in asynchronous I/O command. The result message is
`{on_result, {:ok, contents}}` or `{on_result, {:error, reason}}`. A command
timeout is delivered as `{:error, :timeout}`. In 1.0, `with_timeout/2` is
enforced for file reads and one-shot timers, not intervals or delayed sends.

### Delayed root message

```elixir
Command.send_after(:root, :wake_up, 1_000)
```

`send_after/3` accepts a component ID. The default runtime only registers
`:root`; another ID has no receiver.

### Quit and no-op

```elixir
Command.quit()
Command.quit(:user_requested)
Command.none()
```

Quit initiates graceful runtime shutdown and takes precedence over other
commands returned in the same batch. `none/0` is useful in conditional lists.
The legacy atom `:quit` still works, but `Command.quit/1` is the public API.

## Startup commands

`init/1` may return state together with commands:

```elixir
def init(_opts) do
  {%{frame: 0}, [Command.timer(100, :animate)]}
end
```

The accepted init forms are plain state, `{state, commands}`, `{:ok, state}`,
and `{:ok, state, commands}`.

## Debouncing and stale timers

Timer IDs are internal, so debounce by including your own token in the message:

```elixir
def update({:search_changed, query}, state) do
  token = make_ref()
  state = %{state | query: query, search_token: token}
  {state, [Command.timer(300, {:run_search, token})]}
end

def update({:run_search, token}, %{search_token: token} = state) do
  # Compute a local/pure search result here, or ask an external worker.
  {%{state | results: search_local(state.query)}, []}
end

def update({:run_search, _stale_token}, state), do: {state, []}
```

## Animation

Recursive one-shot timers can be stopped through state:

```elixir
def update(:start_animation, state) do
  {%{state | animating: true}, [Command.timer(50, :animate)]}
end

def update(:animate, %{animating: true} = state) do
  state = %{state | frame: state.frame + 1}
  {state, [Command.timer(50, :animate)]}
end

def update(:animate, state), do: {state, []}
def update(:stop_animation, state), do: {%{state | animating: false}, []}
```

## Multiple commands

Commands in one returned list are submitted independently. Asynchronous results
may arrive in any order. A quit command short-circuits the batch.

```elixir
{state, [
  Command.file_read("one.txt", :one_loaded),
  Command.file_read("two.txt", :two_loaded)
]}
```

## Arbitrary side effects

There is no generic HTTP/function command in TermUI 1.0. Do not use a zero-delay
timer as a wrapper for blocking work: its message still runs through
`update/2`. Instead, let an application-owned process or Task perform the work
and send the result to the runtime:

```elixir
Task.Supervisor.start_child(MyApp.TaskSupervisor, fn ->
  result = MyClient.fetch()
  TermUI.Runtime.send_message(runtime, :root, {:data_loaded, result})
end)
```

Alternatively, a root module may export `handle_info/2`; the runtime forwards
otherwise-unhandled process messages to it. Take care to send to the runtime PID,
not `self()` inside the worker.

## Testing

Commands are ordinary structs, so unit tests can assert exact constructors:

```elixir
{_state, commands} = MyApp.update(:start, %{})
assert commands == [Command.timer(1_000, :tick)]
```

Use `skip_terminal: true`, `TermUI.Runtime.sync/2`, and runtime state inspection
for command integration tests.

Next: [Advanced Widgets](10-advanced-widgets.md).
