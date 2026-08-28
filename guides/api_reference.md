# TermUI 1.0 API Map

This is a map of the major public APIs. HexDocs module pages remain the source
for complete types, options, and return values.

## Application runtime

The normal application path is:

```elixir
defmodule MyApp do
  use TermUI.Elm

  def init(_opts), do: %{}
  def event_to_msg(_event, _state), do: :ignore
  def update(_message, state), do: {state, []}
  def view(_state), do: text("Hello")
end

TermUI.Runtime.run(root: MyApp)
```

Important entry points:

- `TermUI.Runtime.start_link/1`, `run/1`, `shutdown/1`
- `TermUI.Runtime.send_event/2`, `send_message/3`, `sync/2`
- `TermUI.Runtime.get_state/1`, `force_render/1`
- `TermUI.Runtime.backend_mode/0`, `capabilities/0`
- `TermUI.App.start/2` and `run/2` as convenience wrappers

The runtime has one registered ID, `:root`. It does not automatically mount the
process-oriented component APIs described later in this guide.

## Elm and commands

`TermUI.Elm` defines `init/1`, `event_to_msg/2`, `update/2`, and `view/1`.
`TermUI.Command` provides:

```elixir
Command.timer(1_000, :tick)
Command.interval(1_000, :tick)
Command.file_read("data.txt", :file_loaded)
Command.send_after(:root, :wake, 1_000)
Command.quit()
Command.none()
Command.with_timeout(command, 5_000)
```

There is no generic HTTP or arbitrary-function command in 1.0.

## Rendering and layout

- `TermUI.Component.RenderNode` and `TermUI.Component.Helpers` build struct
  render nodes.
- `TermUI.Elm.Helpers` builds tuple row/column/fragment nodes.
- `TermUI.Runtime.NodeRenderer` rasterizes supported trees.
- `TermUI.Renderer.Style`, `Cell`, `Buffer`, and `BufferManager` are the
  integrated low-level rendering types.
- `TermUI.Layout.Constraint` and `TermUI.Layout.Solver` allocate constrained
  stack children.

`TermUI.Renderer.Diff`, `FramerateLimiter`, and `TermUI.ViewCache` are public
opt-in utilities; `TermUI.Runtime` does not call them.

`TermUI.Style` is a separate compatibility style representation and is not
accepted where the integrated renderer expects `TermUI.Renderer.Style`.

## Events and input

Use constructors on `TermUI.Event` or nested event modules. Local runtime input
is parsed by `TermUI.Terminal.EscapeParser` through Raw or TTY readers.

`TermUI.Parser` and `TermUI.Parser.Events` are standalone compatibility APIs.
They produce different structs and are not used by the runtime input path.

`TermUI.EventRouter`, `TermUI.FocusManager`, and `TermUI.SpatialIndex` belong to
the optional process-oriented component subsystem. They do not route events for
the default Elm runtime.

## Backends

- `TermUI.Backend` defines the custom backend contract.
- `TermUI.Backend.Selector` returns automatic Raw/TTY selections or explicit
  module selections.
- `TermUI.Backend.Raw` is the OTP 28+ local Raw implementation.
- `TermUI.Backend.TTY` is cooked local/IEx operation.
- `TermUI.Backend.SSH` renders a separate OTP SSH channel session.

Use `TermUI.Config` for application/runtime configuration. The similarly named
`TermUI.Backend.Config` and `TermUI.Backend.State` are legacy standalone helpers
and are not used by `TermUI.Runtime`.

## Widgets

Stateless widgets expose rendering functions and are called directly from
`view/1`. Stateful widgets generally follow:

```elixir
props = Widget.new(options)
{:ok, widget_state} = Widget.init(props)
{:ok, widget_state} = Widget.handle_event(event, widget_state)
node = Widget.render(widget_state, area)
```

Keep `widget_state` inside the root state. See the widget's module page for its
constructors, events, area requirements, and state helpers.

Modules under the earlier `TermUI.Widget` namespace (`Label`, `Button`, `List`,
`Block`, `Progress`, `TextInput`, and `PickList`) remain public. They accept
props maps directly rather than consistently exposing `new/1`; embed/call them
explicitly just like other widget state machines. Prefer
`TermUI.Widgets.TextInput` over the older single-line text input for new code.

## Optional component processes

These APIs are lower-level and require their own supervision/integration:

```elixir
children = [
  TermUI.ComponentRegistry,
  TermUI.Component.StatePersistence,
  TermUI.ComponentSupervisor
]

{:ok, _host} = Supervisor.start_link(children, strategy: :one_for_one)
{:ok, pid} = TermUI.ComponentSupervisor.start_component(MyWidget, props, id: :widget)
:ok = TermUI.ComponentServer.mount(pid)
:ok = TermUI.ComponentServer.send_event(pid, event)
state = TermUI.ComponentServer.get_state(pid)
:ok = TermUI.ComponentSupervisor.stop_component(pid)
```

Other services include `TermUI.ComponentRegistry`, `TermUI.EventRouter`,
`TermUI.FocusManager`, `TermUI.SpatialIndex`, and
`TermUI.Component.StatePersistence`. `ComponentServer` has no rendering API;
call the component's `render/2` yourself if you build a renderer around this
subsystem.

## Test support

- `TermUI.Test.ComponentHarness` drives its legacy `init/1`, `render/1`, and
  GenServer-style `handle_event/2` test contract. Test current
  `TermUI.StatefulComponent` callbacks directly unless an adapter is used.
- `TermUI.Test.TestRenderer` provides cell/text/style/snapshot inspection.
- `TermUI.Test.EventSimulator` creates normalized events.
- `TermUI.Test.Assertions` supplies renderer and state assertion macros.

Run the complete project checks with `mix test`, `mix format --check-formatted`,
`mix credo --strict`, `mix dialyzer`, and `mix docs`.
