# TermUI

TermUI is a small terminal runtime for Elixir and the BEAM. It uses the Elm
architecture and has one render value: `TermUI.Frame`.

The runtime owns application state, command execution, frame timing, and
shutdown. A backend owns terminal setup, input, output, size, cursor state,
capabilities, and cleanup.

## Install

Add the release candidate to `mix.exs`:

```elixir
def deps do
  [
    {:term_ui, "~> 1.0.0-rc"}
  ]
end
```

TermUI uses MDEx to parse Markdown for terminal display. It uses Zoi schemas
as the source for production struct fields and defaults.

## Application contract

```elixir
defmodule Counter do
  use TermUI.Elm

  alias TermUI.{Command, Event, Frame, Style}

  def init(opts) do
    %{count: 0, dimensions: Keyword.fetch!(opts, :dimensions)}
  end

  def event_to_msg(%Event.Key{key: :up}, _state), do: {:msg, :increment}
  def event_to_msg(%Event.Key{key: :down}, _state), do: {:msg, :decrement}
  def event_to_msg(%Event.Text{text: text}, _state) when text in ["q", "Q"],
    do: {:msg, :quit}

  def event_to_msg(%Event.Resize{width: width, height: height}, _state),
    do: {:msg, {:resize, width, height}}

  def event_to_msg(_event, _state), do: :ignore

  def update(:increment, state), do: %{state | count: state.count + 1}
  def update(:decrement, state), do: %{state | count: state.count - 1}
  def update(:quit, state), do: {state, [Command.shutdown()]}
  def update({:resize, width, height}, state), do: %{state | dimensions: {width, height}}

  def view(%{count: count, dimensions: {width, height}}) do
    heading = Style.new(fg: :cyan, attrs: [:bold])

    Frame.from_rows(
      [[{"Counter", heading}], "", "Count: #{count}", "", "Up/Down: change  Q: quit"],
      width,
      height
    )
  end
end

TermUI.run(Counter)
```

`init/1` receives `:dimensions` as `{columns, rows}`. Printable input arrives
as `Event.Text`. Named and modified keys arrive as `Event.Key`. Paste, mouse,
resize, and focus input have separate event types.

`view/1` must return one complete `TermUI.Frame`. A frame contains its size,
cells, and optional cursor. The cursor is `{column, row}` and is one-based.

## Effects

`update/2` returns new state or `{new_state, commands}`. Commands are data:

- `Command.message/1` queues an application message.
- `Command.send/2` sends data to another process.
- `Command.timer/2` queues a later application message.
- `Command.async/2` runs work outside the runtime process. The function can
  return any term. The runtime wraps a normal return as `{:ok, value}` and a
  raised, thrown, or exited function as `{:error, reason}`. Its mapper always
  receives this one runtime-produced result. For example, a function return of
  `{:ok, value}` reaches the mapper as `{:ok, {:ok, value}}`.
- `TermUI.Clipboard.copy/2` and `TermUI.Clipboard.clear/1` request bounded,
  serialized OSC 52 clipboard output.
- `Command.shutdown/1` requests one final render and cleanup.

## Pure widgets

A widget is not a process. The parent application owns widget state. It sends
events to the widget and composes the returned frame into its application frame.

```elixir
list = TermUI.Widget.List.init(items: ["one", "two"])
{list, messages} = TermUI.Widget.List.update(event, list)
list_frame = TermUI.Widget.List.view(list, {30, 10})
frame = TermUI.Frame.overlay(frame, list_frame, 2, 3)
```

Use `TermUI.Mouse` to route global events to local widget coordinates. Use
`TermUI.Widget.mouse/4` to apply the local event. `TextInput` and `TextArea`
support keyboard and mouse selection. Copy and cut return `{:copy, text}` to
the parent, which can return a `TermUI.Clipboard.copy/2` command.

The supplied pure widgets include:

- Text: label, single-line input, validated line input, multiline text area,
  Markdown viewer, log viewer, stream view, and diff viewer.
- Selection: button, list, pick list, menu, context menu, command palette,
  tabs, table, tree view, and forms.
- Layout: block, dialog, alert dialog, split pane, viewport, scrollbar, and toast.
- Data views: progress, gauge, sparkline, bar chart, line chart, canvas,
  process snapshots, supervision trees, and cluster snapshots.

System views accept data snapshots from the parent. They do not start polling
processes or perform RPC.

## Markdown and diffs

`TermUI.Widget.MarkdownViewer` uses MDEx and supports CommonMark headings,
emphasis, links, quotes, lists, tasks, code blocks, rules, and tables.

`TermUI.Widget.DiffViewer` accepts `:before` and `:after` text or a
`:unified_diff`. It supports unified and side-by-side terminal views.

## Backends

Use `:auto`, `:raw`, or `:tty` with the `:backend` option. Tests can inject a
module that implements `TermUI.Backend`.

```elixir
TermUI.start_link(Counter, backend: {MyTestBackend, owner: self()})
```

Raw mode needs OTP 28 or later. TTY mode is the fallback when raw mode is not
available. The SSH backend from the pre-1.0 design is not part of this release
candidate because its input was owned outside the backend contract.

## Documents

- [Architecture](guides/architecture.md)
- [Backend contract](guides/backend.md)
- [Pure widgets](guides/widgets.md)
- [Clipboard, selection, and mouse](guides/interaction.md)
- [Markdown and diff viewers](guides/markdown-and-diffs.md)
- [Removed and deferred features](guides/removed-and-deferred.md)
- [Migration to 1.0](guides/migration-1.0.md)
- [Counter example](https://github.com/mikehostetler/term_ui/tree/main/examples/iex_counter)

## License

TermUI uses the MIT License. The repository includes the license text.
