# Widget Compatibility Guide

This guide describes the code-level differences that affect widgets in Raw,
TTY, and explicit SSH/custom operation.

## Read the matrix in two layers

Most widgets are backend-independent state machines: given the same
`TermUI.Event`, their `handle_event/2` behavior is the same. Input delivery is
not identical, however:

- Raw input is character-at-a-time and runtime setup enables mouse reporting
  except on WSL/ConPTY.
- TTY remains cooked. `IO.getn/2` requests one character, but the shell or
  terminal driver may buffer input until Enter. The runtime does not enable TTY
  mouse reporting.
- SSH/custom hosts are responsible for parsing and forwarding normalized events
  to each session runtime.

“Keyboard” below means the widget works once normalized key events are
delivered; it does not promise immediate cooked-terminal delivery.

## Compatibility matrix

| Widget family | Raw | TTY | Notes |
|---|---|---|---|
| Menu, Tabs, Table, TreeView, PickList | Keyboard + mouse where implemented | Keyboard | Root must forward events and retain state |
| TextInput | Immediate event-driven editing | Event-driven, possibly line-buffered | Use `TextInput.Line` for intentional blocking line reads |
| FormBuilder, CommandPalette | Immediate keyboard | Keyboard, possibly line-buffered | Same widget state machine |
| Dialog, AlertDialog | Keyboard + mouse buttons | Keyboard; their code ignores TTY mouse events | Update area before Raw mouse hit-testing |
| Toast | Render/timer driven | Render/timer driven | Root must call update/tick helpers |
| Viewport, ScrollBar | Keyboard + mouse | Keyboard | TTY mouse reporting is not enabled |
| SplitPane | Keyboard + Raw mouse drag | Keyboard | Ctrl+arrow resizing is the fallback |
| ContextMenu | Positioned keyboard/mouse overlay | Keyboard works, but opening position needs a host | Prefer Inline when no pointer position exists |
| ContextMenu.Inline | Keyboard/mouse events | Keyboard/numbers | No absolute pointer position required |
| Charts, Gauge, Sparkline, Canvas | Render | Render | Some Braille/Markdown-style visuals intentionally require Unicode; see below |
| LogViewer, StreamWidget | Keyboard + supplied data | Keyboard + supplied data | Producers are independent of terminal backend |
| BEAM introspection widgets | Keyboard + refresh messages | Keyboard + refresh messages | Root owns refresh scheduling |

## Stateful widget integration

The 1.0 runtime has a single Elm root. It does not mount widget processes or
route focus automatically. Follow the state-machine lifecycle:

```elixir
props = TermUI.Widgets.Table.new(columns: columns, data: rows)
{:ok, table} = TermUI.Widgets.Table.init(props)

{:ok, table} = TermUI.Widgets.Table.handle_event(event, table)
node = TermUI.Widgets.Table.render(table, %{x: 0, y: 0, width: 80, height: 20})
```

Keep `table` in root state and decide when to forward each event. Stateless
widgets such as Gauge and Sparkline render directly in `view/1`.

## Text input choices

| Feature | `TermUI.Widgets.TextInput` | `TermUI.Widgets.TextInput.Line` |
|---|---|---|
| API style | Stateful event handler | Explicit line read |
| Blocking | No inside widget; delivery depends on backend | Yes until Enter |
| Cursor/editing | Widget-managed | Shell-managed |
| Validation | Per delivered event | On submitted line |
| Use case | Forms, search, live editing | Shell-like prompt in cooked I/O |

`TextInput.Line` is not selected automatically by TTY mode.

## Context menu choices

Use the positioned `ContextMenu` when the application has an `{x, y}` opening
position. Use `ContextMenu.Inline` for a menu rendered in normal layout with
number-key selection. `TermUI.Widgets.ContextMenu.Factory` can choose a variant
from its options and capability queries.

Callbacks execute synchronously. Context-menu callback exceptions are rescued
and logged by the shared behavior; long work should still be dispatched to
another process so it does not block the runtime callback.

## Keyboard alternatives

Every pointer action should have a keyboard path. Existing examples include:

- SplitPane: Ctrl+arrow resizing
- Viewport/Table/TreeView: arrows, Page Up/Down, Home/End
- Dialogs: Tab/Shift+Tab and Enter/Space
- ContextMenu.Inline: number keys and arrows
- ScrollBar consumers: arrow/page navigation in the owning widget

## Character compatibility

Use `TermUI.CharacterSet.current_charset/0` instead of hard-coded box drawing,
arrows, chart blocks, or indicators:

```elixir
chars = TermUI.CharacterSet.current_charset()
border = chars.tl <> String.duplicate(chars.h_line, width) <> chars.tr
```

When a local runtime starts, `TermUI.PersistentTerms` selects Unicode or ASCII
from detected terminal capabilities. `config :term_ui, character_set: ...` is
only the fallback when no runtime-managed value exists in 1.0; it is not a
force override after runtime startup. A custom widget can explicitly call
`TermUI.CharacterSet.get(:ascii)` when it must force ASCII.

Most core borders, navigation indicators, gauges, sparklines, and bar charts
use the selected character set. The following 1.0 implementations need special
attention:

- `LineChart` and Braille-mode `Canvas` output use Unicode Braille cells; there
  is no equivalent sub-character ASCII representation.
- `Markdown`/`MarkdownViewer` and the legacy `PickList` contain hard-coded
  Unicode drawing characters. The TTY backend maps the known glyphs to ASCII
  while writing cells; Raw/custom output does not add that final mapping, so a
  custom ASCII-only backend must translate them or avoid those renderers.

Use a different presentation or validate Unicode support before relying on
those visuals in an ASCII-only environment.

## Color compatibility

Use semantic theme styles where possible and provide attribute/character cues
that survive monochrome output. The TTY backend degrades RGB/256/named colors
to its detected color mode. Raw emits the requested ANSI style.

Capability queries:

```elixir
case TermUI.Runtime.backend_mode() do
  :raw -> :immediate_local_input
  :tty -> :cooked_local_input
  :custom -> :host_managed_input
  :skip -> :no_terminal_backend
  nil -> :no_local_runtime_context
end

unicode? = TermUI.App.supports?(:unicode)
true_color? = TermUI.App.supports?(:true_color)
color_256_or_better? = TermUI.App.supports?(:color_256)
```

These values describe detected output capabilities. They do not indicate that
focus, paste, or mouse reporting was enabled.

## Compatibility checklist

1. Keep widget state in the Elm root and forward events explicitly.
2. Provide keyboard access for every mouse action.
3. Expect TTY input to be buffered until Enter.
4. Use `CharacterSet` for UI glyphs.
5. Use semantic styles plus non-color cues.
6. Test widget state transitions independently of the terminal.
7. Test Raw, TTY, SSH/custom, WSL, and cleanup paths on the platforms you claim.
