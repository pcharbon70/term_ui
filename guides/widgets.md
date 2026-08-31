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

### Table state and row identity

The table keeps sorting, filtering, cursor, and selection in its pure state.
Use a stable row identity when rows can move or change:

```elixir
table =
  TermUI.Widget.Table.init(
    columns: [{:name, "Name"}, {:score, "Score"}],
    rows: users,
    row_id: :id,
    selection_mode: :multiple
  )

table = TermUI.Widget.Table.sort_by(table, :score, :desc)
table = TermUI.Widget.Table.set_filter(table, & &1.active)
selected_users = TermUI.Widget.Table.selected_rows(table)
```

Each row ID must be unique. It must not change when other row values change.
The table stores selected IDs, so sorting and filtering do not change the
selection. `set_rows/2` removes a selected ID only when the new row list no
longer contains that ID. Without `:row_id`, the complete row value is the ID.
Use that default only for unique rows whose values do not change.

Selection mode can be `:none`, `:single`, or `:multiple`. Enter selects the
cursor row. Space toggles the cursor row in multiple mode. A left-button
release uses the same selection transition. The parent can also use
`set_selection/2` and `clear_selection/1`.

Use `TermUI.Widget.mouse/4` after the parent routes a mouse event to local
widget coordinates. A widget can implement the optional `mouse/3` callback.
The helper uses `update/2` as the fallback.

Text input selection emits `{:copy, text}` for copy and cut actions. Convert
that message to `TermUI.Clipboard.copy/2` in the parent application. See the
[interaction guide](interaction.md).

## Parent-owned child routing

`TermUI.Widget.Router` removes repeated state access and message mapping for
nested widgets. Each route has an explicit child ID and parent-state path.
The route is data. It does not own state or use a process.

```elixir
alias TermUI.Widget.{Checkbox, Router}

model = %{
  save: Checkbox.init(id: :save),
  publish: Checkbox.init(id: :publish)
}

save = Router.new(:save, Checkbox, [:save])
publish = Router.new(:publish, Checkbox, [:publish])

{model, messages} = Router.update(save, event, model)
# messages use the form {:widget, :save, child_message}

focus = TermUI.Focus.new([:save, :publish], current: :save)
true = Router.focused?(save, focus)

regions = [
  Router.region(save, 0, 0, 20, 1),
  Router.region(publish, 0, 2, 20, 1)
]

routed = TermUI.Mouse.route(regions, mouse_event)
{model, messages} = Router.mouse(save, routed, model, {20, 1})
```

Call `mouse/4` for each possible route, or select one route by the returned
ID. A route that does not own the returned ID leaves the parent unchanged.
Use `:map_message` in `new/4` when the parent needs a different message form.
Two child routes can use the same widget module because their IDs and state
paths are independent.

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
- `TermUI.Widget.Checkbox`
- `TermUI.Widget.List`
- `TermUI.Widget.PickList`
- `TermUI.Widget.Menu`
- `TermUI.Widget.ContextMenu`
- `TermUI.Widget.CommandPalette`
- `TermUI.Widget.RadioGroup`
- `TermUI.Widget.Select`
- `TermUI.Widget.Tabs`
- `TermUI.Widget.Table`
- `TermUI.Widget.Toggle`
- `TermUI.Widget.TreeView`
- `TermUI.Widget.FormBuilder`

## Layout and feedback

- `TermUI.Widget.Block`
- `TermUI.Widget.Breadcrumb`
- `TermUI.Widget.Dialog`
- `TermUI.Widget.AlertDialog`
- `TermUI.Widget.SplitPane`
- `TermUI.Widget.Viewport`
- `TermUI.Widget.ScrollBar`
- `TermUI.Widget.Spinner`
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

## Controls and messages

Checkboxes and toggles emit `{:changed, id, checked}`. Radio groups and select
controls emit `{:selected, id, value}`. Disabled options do not receive focus
and do not emit messages.

A select control renders its option list in its own frame while it is open.
Give it more than one row when the option list must be visible.

A spinner does not start a timer. The parent calls
`TermUI.Widget.Spinner.tick/1` from its timer update.

## Layout and composition

`TermUI.Layout` allocates zero-based rectangles. Fixed tracks use an integer.
Flexible tracks use `:fill` or `{:weight, value}`. Pure helpers also create
percentage, ratio, minimum, maximum, and bounded-content tracks.

```elixir
root = TermUI.Layout.new({80, 24})
[nav, main] = TermUI.Layout.row(root, [24, :fill], gap: 1)

frame =
  TermUI.Frame.new(80, 24)
  |> TermUI.Layout.place(nav_frame, nav)
  |> TermUI.Layout.place(main_frame, main)
```

Use `column/3` for vertical tracks. Use `grid/3` for equal grid cells. Set
`:column_tracks` and `:row_tracks` when grid tracks need different sizing
modes. The `:columns` and optional `:rows` values keep equal configured tracks
when the grid has fewer items.
`Block.compose/3`, `Dialog.compose/3`, and `Tabs.compose/3` can render a frame,
a `{widget_module, widget_state}` pair, or a one-argument renderer function.

Buttons accept `:prefix` and `:suffix` decorations. List items, menu actions,
tree nodes, and tabs can include icons. Lists, menus, and tabs can show
shortcuts. Menus support vertical and horizontal orientation. Tabs support
left, center, and right alignment. Tabs, menus, radio groups, selects, trees,
and dialogs skip disabled choices during keyboard navigation.

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
