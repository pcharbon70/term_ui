# Runtime Internals

`TermUI.Runtime` is the integrated TermUI 1.0 application loop. It is a single
GenServer with a single Elm root.

## Initialization

`start_link/1` preserves IEx detection, removes the optional GenServer name,
and starts the process. `init/1` then:

1. Merges `TermUI.Config` values with runtime options; runtime options win.
2. Selects and initializes Raw, TTY, or an explicit custom backend.
3. Starts `TermUI.Command.Executor`.
4. Calls `root.init(opts)` with the merged option list after the GenServer-only
   `:name` option has been removed.
5. Selects the input path and registers resize handling where available.
6. Creates bounded event/message queues and the `:root` component entry.
7. Executes startup commands and schedules the first render.

`skip_terminal: true` is intended for tests. It skips backend/input/buffer
initialization while leaving the Elm loop usable through public event APIs.

## State

The fields are defined by `TermUI.Runtime.State`. Important ones include:

- `root_module` and `root_state`
- `event_queue` and `message_queue`
- `components`, currently `%{root: %{module: ..., state: ...}}`
- `dirty` and `render_interval`
- backend, backend state, capabilities, dimensions, and buffer manager
- input handler/reader processes
- command executor and pending command metadata
- shutdown and logger-restoration state

The map is not the `TermUI.ComponentRegistry`; the two APIs are independent.

## Event and message flow

Events enter through `send_event/2` or an input reader. The bounded event queue
processes one event per pass to avoid starving the GenServer mailbox. Key,
mouse, paste, resize, focus, and tick events all reach the root because it is
the only registered runtime component.

`event_to_msg/2` may return `{:msg, message}`, `:ignore`, or `:propagate`.
There is no parent in the 1.0 runtime, so `:propagate` is currently ignored.

Messages are flushed from `TermUI.MessageQueue`, passed to `root.update/2`,
normalized by `TermUI.Elm.normalize_update_result/2`, and written back to both
`root_state` and the `:root` entry. A changed state marks the runtime dirty.
`send_message(runtime, :root, message)` bypasses event conversion; other IDs
are ignored because they are not registered.

If the root exports `handle_info/2`, otherwise-unhandled process messages are
forwarded to it. It may return a new state or `{new_state, commands}`.

## Commands

The runtime accepts `TermUI.Command` structs. It also retains compatibility
with `:quit`, `{:timer, milliseconds, message}`, and
`{:send, pid, message}`. Prefer the struct constructors in new code.

`TermUI.Command.Executor` implements timers, intervals, asynchronous file
reads, delayed component messages, and timeouts. Results are enqueued as root
messages. `Command.quit/1` takes precedence over other commands in the batch.

## Rendering

A timer fires every `render_interval` milliseconds (16 by default). If `dirty`
is false, no view or output work occurs. Otherwise the runtime calls
`root.view/1`, rasterizes it, writes cells through the backend, flushes, and
clears the dirty flag.

`force_render/1` marks the state dirty and immediately invokes the same render
path. It does not use `TermUI.Renderer.FramerateLimiter`.

## Error boundaries

Exceptions from root `event_to_msg/2`, `update/2`, and `view/1` are logged and
the runtime keeps its previous usable state. The command executor isolates
asynchronous task failures and reports them as result messages.

## Shutdown

Shutdown stops accepting command results, cancels root commands, stops input,
shuts down the backend and buffer manager, removes resize callbacks, restores
terminal and logger state, and exits normally. The runtime does not call a
root `terminate/2` callback; applications needing root cleanup should arrange
it outside that callback contract.

Next: [Rendering Pipeline](03-rendering-pipeline.md).
