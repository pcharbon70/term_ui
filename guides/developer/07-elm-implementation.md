# Elm Architecture Implementation

An application root uses `TermUI.Elm` and implements four callbacks:

```elixir
defmodule Counter do
  use TermUI.Elm

  alias TermUI.Command
  alias TermUI.Event

  def init(_opts), do: %{count: 0}

  def event_to_msg(%Event.Key{key: :up}, _state), do: {:msg, :increment}
  def event_to_msg(%Event.Key{key: "q"}, _state), do: {:msg, :quit}
  def event_to_msg(_event, _state), do: :ignore

  def update(:increment, state), do: {%{state | count: state.count + 1}, []}
  def update(:quit, state), do: {state, [Command.quit()]}

  def view(state), do: text("Count: #{state.count}")
end
```

## Callback contracts

`init/1` receives the merged runtime option list after the GenServer-only
`:name` option has been removed. It may return plain state, `{state, commands}`,
`{:ok, state}`, or `{:ok, state, commands}`.

`event_to_msg/2` returns `{:msg, message}`, `:ignore`, or `:propagate`.
The primary runtime has no parent component, so `:propagate` is currently
ignored.

`update/2` returns `{state, commands}`, `{state}`, or `:noreply`. Commands must
be a list. The runtime compares old/new state to set its dirty flag.

`view/1` returns any tree accepted by `TermUI.Runtime.NodeRenderer`. Both
`TermUI.Component.Helpers` render-node structs and non-conflicting tuple helpers
from `TermUI.Elm.Helpers` are imported by `use TermUI.Elm`.

## Message queue

`TermUI.MessageQueue` is a standalone queue module used directly by
`TermUI.Runtime`; there is no `TermUI.Runtime.MessageQueue` module or process.
Events become messages, command results become messages, and public
`send_message(runtime, :root, message)` can enqueue a message directly.

## Commands

The supported command constructors are:

- `TermUI.Command.timer/2`
- `TermUI.Command.interval/2`
- `TermUI.Command.file_read/2`
- `TermUI.Command.send_after/3`
- `TermUI.Command.quit/1`
- `TermUI.Command.none/0`
- `TermUI.Command.with_timeout/2`

Timers deliver the configured message. File reads deliver
`{on_result, {:ok, contents}}` or `{on_result, {:error, reason}}`. A command
timeout delivers `{:error, :timeout}` for file reads and one-shot timers;
intervals and delayed sends do not enforce `with_timeout/2` in 1.0. The public
runtime does not expose an interval cancellation handle; intervals end when
root commands are cancelled during shutdown.

There is no generic function-command constructor in 1.0. For arbitrary HTTP or
other effects, use an application-owned process/Task and send the result to the
runtime with `TermUI.Runtime.send_message(runtime, :root, result)` or arrange a
root `handle_info/2` message. Avoid doing blocking I/O inside `update/2`.

## Stateful widgets

Stateful widgets do not become Elm runtime children. Initialize them into root
state, forward relevant events, and render their resulting state:

```elixir
props = TermUI.Widgets.TextInput.new(placeholder: "Name")
{:ok, input} = TermUI.Widgets.TextInput.init(props)

{:ok, input} = TermUI.Widgets.TextInput.handle_event(event, input)
node = TermUI.Widgets.TextInput.render(input, %{x: 0, y: 0, width: 40, height: 1})
```

The root owns focus decisions and widget state composition.

## Optional root messages

If a root module exports `handle_info/2`, the runtime forwards unknown process
messages to it. Return a new state or `{new_state, commands}`. This callback is
an extension implemented by the runtime, not a required `TermUI.Elm` callback.

Next: [Creating Widgets](08-creating-widgets.md).
