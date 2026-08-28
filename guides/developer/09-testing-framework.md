# Testing Framework

TermUI includes test helpers for widget state machines, cell rendering, event
construction, and assertions. Root Elm modules can also be tested directly or
through a terminal-free runtime.

## ComponentHarness

`TermUI.Test.ComponentHarness` drives a small legacy test contract: `init/1`
returns state directly, `render/1` returns a render tree, and optional
`handle_event/2` returns `{:noreply, state}` or `{:reply, reply, state}`. That is
not the current `TermUI.StatefulComponent` callback shape (`{:ok, state}` and
`render/2`), so test current built-in widgets directly unless you provide an
adapter module.

```elixir
alias TermUI.Test.ComponentHarness
alias TermUI.Test.EventSimulator

{:ok, harness} = ComponentHarness.mount_test(MyHarnessComponent, initial: 0)

harness = ComponentHarness.event_cycle(harness, EventSimulator.simulate_key(:up))
state = ComponentHarness.get_state(harness)
tree = ComponentHarness.get_render(harness)
:ok = ComponentHarness.unmount(harness)
```

`mount_test/2` passes all options except `:width` and `:height` to `init/1`.
`send_event/2` only drives the event callback; `event_cycle/2` also renders.
Harness values are immutable, so keep the returned value. Other helpers inspect
history, area, state paths, and allow controlled state replacement/reset.

The harness does not exercise `TermUI.Runtime` routing or terminal output.

## TestRenderer

The renderer module is `TermUI.Test.TestRenderer`:

```elixir
alias TermUI.Test.TestRenderer

{:ok, renderer} = TestRenderer.new(24, 80)
TestRenderer.write_string(renderer, 1, 1, "Hello")
assert TestRenderer.get_text_at(renderer, 1, 1, 5) == "Hello"
snapshot = TestRenderer.snapshot(renderer)
:ok = TestRenderer.destroy(renderer)
```

It wraps an ETS buffer and supports cell/string writes, text/style inspection,
search, dimensions, printable output, and in-memory snapshot comparison. Its
snapshot API does not read or write snapshot files.

## EventSimulator

`TermUI.Test.EventSimulator` creates key, click/double-click/move/drag/scroll,
typing, sequence, focus, resize, paste, shortcut, function-key, and navigation
events. These are regular `TermUI.Event` structs.

```elixir
event = TermUI.Test.EventSimulator.simulate_click(10, 5, :left)
events = TermUI.Test.EventSimulator.simulate_type("hello")
```

## Assertions

`use TermUI.Test.Assertions` imports macros for text at a position, contained or
global text, styles and attributes, rows, state paths, snapshots, and empty
buffers. Pass a `TestRenderer` where renderer assertions are expected.

## Elm unit tests

Test pure root callbacks without processes:

```elixir
test "up increments" do
  state = Counter.init([])
  assert {:msg, :increment} = Counter.event_to_msg(TermUI.Event.key(:up), state)
  assert {%{count: 1}, []} = Counter.update(:increment, state)
end
```

## Runtime integration tests

Use `skip_terminal: true` and synchronize casts before inspecting state:

```elixir
{:ok, runtime} = TermUI.Runtime.start_link(root: Counter, skip_terminal: true)
TermUI.Runtime.send_event(runtime, TermUI.Event.key(:up))
:ok = TermUI.Runtime.sync(runtime)
assert TermUI.Runtime.get_state(runtime).root_state.count == 1
TermUI.Runtime.shutdown(runtime)
```

This path exercises event/message queues and commands but skips backend,
input, buffer, and terminal integration. Backend tests should use the backend
contract directly or a purpose-built test backend.

## Project checks

```bash
mix test
mix format --check-formatted
mix credo --strict
mix dialyzer
mix docs
```

Manual platform procedures live under `test/manual/` and remain necessary for
behaviour that cannot be proven by terminal-free tests.
