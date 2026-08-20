# TermUI usage rules

Use one module with `use TermUI.Elm` as the root application.

- Store all durable UI state in the root application state.
- Convert `TermUI.Event` values to application messages in `event_to_msg/2`.
- Keep `update/2` pure. Return `TermUI.Command` values for effects.
- Return exactly one `TermUI.Frame` from `view/1`.
- Use `{columns, rows}` for application dimensions.
- Use `{column, row}` for a frame cursor.
- Treat backends as terminal owners. Do not parse terminal input in an application.
- Keep widget state in the parent. Do not start one process for each widget.
- Call widget `view/2` with `{columns, rows}` and compose the returned frame with
  `TermUI.Frame.overlay/4`.
- Route global mouse events with `TermUI.Mouse`. Call `TermUI.Widget.mouse/4`
  with local, zero-based coordinates.

Printable text is `TermUI.Event.Text`. Do not read printable characters from a
legacy `Key.char` field. Use `TermUI.Event.Key` for named or modified keys.

Use `TermUI.Style`, `TermUI.Cell`, and `TermUI.Frame`. The old renderer,
component, input, and `TermUI.Widgets` namespaces do not exist in 1.0.

Use `TermUI.Widget.MarkdownViewer` for MDEx Markdown. Use
`TermUI.Widget.DiffViewer` for unified or side-by-side text diffs. Supply
process, stream, supervision, and cluster snapshots from the parent application.

Use `TermUI.Selection` for Unicode grapheme ranges. Convert widget
`{:copy, text}` messages to `TermUI.Clipboard.copy/2` commands. Do not write
OSC 52 data directly from an application or widget.

TermUI production structs derive fields and defaults from Zoi schemas. Public
terminal data types expose `schema/0` for explicit validation. Do not validate
each cell or each widget update in a render loop.

For tests, inject a module that implements `TermUI.Backend`. Assert on the
`TermUI.Frame` values passed to `draw/2`.
