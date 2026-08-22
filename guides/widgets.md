# Pure widgets

Every TermUI widget is plain data. The parent application owns its state and
passes normalized events to it.

```elixir
state = TermUI.Widget.Table.init(columns: columns, rows: rows)
{state, messages} = TermUI.Widget.Table.update(event, state)
child = TermUI.Widget.Table.view(state, {60, 12})
frame = TermUI.Frame.overlay(frame, child, 1, 3)
```

`update/2` does not perform effects. It returns messages for the parent. The
parent can convert those messages to application updates or `TermUI.Command`
values.

Use `TermUI.Widget.mouse/4` after the parent routes a mouse event to local
widget coordinates. A widget can implement the optional `mouse/3` callback.
The helper uses `update/2` as the fallback.

Text input selection emits `{:copy, text}` for copy and cut actions. Convert
that message to `TermUI.Clipboard.copy/2` in the parent application. See the
[interaction guide](interaction.md).

## Text and content

- `TermUI.Widget.Label`
- `TermUI.Widget.TextInput`
- `TermUI.Widget.LineInput`
- `TermUI.Widget.TextArea`
- `TermUI.Widget.MarkdownViewer`
- `TermUI.Widget.LogViewer`
- `TermUI.Widget.Stream`
- `TermUI.Widget.DiffViewer`

## Selection and data entry

- `TermUI.Widget.Button`
- `TermUI.Widget.List`
- `TermUI.Widget.PickList`
- `TermUI.Widget.Menu`
- `TermUI.Widget.ContextMenu`
- `TermUI.Widget.CommandPalette`
- `TermUI.Widget.Tabs`
- `TermUI.Widget.Table`
- `TermUI.Widget.TreeView`
- `TermUI.Widget.FormBuilder`

## Layout and feedback

- `TermUI.Widget.Block`
- `TermUI.Widget.Dialog`
- `TermUI.Widget.AlertDialog`
- `TermUI.Widget.SplitPane`
- `TermUI.Widget.Viewport`
- `TermUI.Widget.ScrollBar`
- `TermUI.Widget.Toast`

## Visualization and snapshots

- `TermUI.Widget.Progress`
- `TermUI.Widget.Gauge`
- `TermUI.Widget.Sparkline`
- `TermUI.Widget.BarChart`
- `TermUI.Widget.LineChart`
- `TermUI.Widget.Canvas`
- `TermUI.Widget.ProcessMonitor`
- `TermUI.Widget.SupervisionTree`
- `TermUI.Widget.ClusterDashboard`

Snapshot widgets do not call `Process.list/0`, monitor nodes, perform RPC, or
subscribe to streams. The parent performs those effects and supplies bounded
data with each widget's setter function.

## Bounded streams

The pure stream supports batches, counters, clear, and three overflow modes:

```elixir
stream = TermUI.Widget.Stream.init(limit: 1_000, overflow: :drop_oldest)
stream = TermUI.Widget.Stream.push_many(stream, token_batch)
stats = TermUI.Widget.Stream.stats(stream)
```

Use `TermUI.Stream.ProducerAdapter` when an external producer needs a bounded
process boundary. The adapter sends only one unacknowledged batch:

```elixir
{:ok, adapter} =
  TermUI.Stream.ProducerAdapter.start_link(consumer: self(), batch_size: 25)

:ok = TermUI.Stream.ProducerAdapter.push(adapter, token)

# In the application process:
receive do
  {:term_ui_stream, ^adapter, reference, items} ->
    stream = TermUI.Widget.Stream.push_many(stream, items)
    :ok = TermUI.Stream.ProducerAdapter.ack(adapter, reference)
end
```

## Viewport and panes

Set `scrollbars: :both` on a viewport to reserve local scrollbar tracks.
`geometry/2` returns content size, viewport size, maximum offsets, and visible
ranges. `scroll_into_view/3` reveals a zero-based content position.

`SplitPane.init/1` still accepts `:first`, `:second`, and `:ratio`. For a
multi-pane layout, use named panes and weights:

```elixir
panes =
  TermUI.Widget.SplitPane.init(
    panes: [nav: nav, main: main, inspector: inspector],
    ratios: [1, 3, 1],
    collapsed: [:inspector]
  )

panes = TermUI.Widget.SplitPane.expand(panes, :inspector)
layout = TermUI.Widget.SplitPane.layout(panes, dimensions)
```

## Theme, focus, and shortcuts

`TermUI.Theme` stores named styles, style variants, and non-style values. Use
`Theme.for_capabilities/2` to create a color-limited copy. `TermUI.Focus`
routes traversal events through an application-owned order. `TermUI.Shortcut`
routes chords and timestamp-bounded sequences to application messages. These
modules do not use registries or services.
