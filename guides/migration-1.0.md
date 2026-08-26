# Migration to TermUI 1.0.0-rc.1

TermUI 1.0.0-rc.1 is a breaking redesign of the published 1.0.0-rc package.
It removes the earlier release candidate's component and render systems. It
does not provide compatibility aliases for systems that no longer match the
runtime design.

## Public replacements

| 1.0.0-rc and earlier | 1.0.0-rc.1 |
| --- | --- |
| `TermUI.App` | `TermUI.run/2`, `TermUI.start_link/2`, or `TermUI.Runtime` |
| `TermUI.Component` and `TermUI.StatefulComponent` | One `TermUI.Elm` application or a pure `TermUI.Widget` |
| Component servers, registry, and supervisor | Parent-owned state in the root application |
| `TermUI.Component.RenderNode` | `TermUI.Frame` |
| Renderer buffers and tuple nodes | `TermUI.Frame` |
| `TermUI.Renderer.Cell` | `TermUI.Cell` |
| `TermUI.Renderer.Style` | `TermUI.Style` |
| `TermUI.Input.*` and terminal input readers | The `TermUI.Backend` input callback |
| Printable `Event.Key.char` input | `TermUI.Event.Text` |
| Component command tuples | `TermUI.Command` constructors |
| `TermUI.Widgets.*` | The matching parent-owned module under `TermUI.Widget.*` |

The widget feature set is available under the singular namespace. For example,
`TermUI.Widgets.Table` becomes `TermUI.Widget.Table`, and
`TermUI.Widgets.MarkdownViewer` becomes `TermUI.Widget.MarkdownViewer`.
Widgets now return `TermUI.Frame` and never require a component PID.

Public boundary structs derive their fields and defaults from Zoi schemas.
Private runtime and widget state uses plain structs. Direct struct update
syntax still works. Use the public `schema/0` functions when untrusted data
enters TermUI from an external source.

## Required application changes

1. Select one root module and use `TermUI.Elm`.
2. Move child process state into the root state or a normal domain process.
3. Convert terminal events in `event_to_msg/2`.
4. Return command structs from `update/2`.
5. Replace render nodes and buffers with `TermUI.Frame.from_rows/4` or cell writes.
6. Handle `Event.Resize` and store the new `{columns, rows}`.
7. Start with `TermUI.run(MyApp)` or `TermUI.start_link(MyApp)`.

## Backend changes

Replace cursor, clear, and cell-list render callbacks with `draw/2`. The value
passed to `draw/2` is the complete frame. Keep terminal input, output, size,
cursor, capability detection, setup, and cleanup inside the backend.

The old SSH backend is removed. Add a new SSH backend only when it can own the
complete input and terminal lifecycle for its session.
