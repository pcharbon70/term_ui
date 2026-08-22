# Advanced feature parity

This comparison uses the source archive published to Hex as `term_ui
1.0.0-rc` for the before state. A feature in that archive is not proof that the
feature was correct in a real terminal. The rewrite removed shared processes
and global services that could break state ownership and terminal cleanup.

The after state is `1.0.0-rc.1` on the rewrite branch. `Retained` means that the
user capability remains. `Replaced` means that the capability has a new API.
`Partial` means that useful behavior remains, but an advanced function is
missing. `Deferred` means that the old form is not safe to restore.

## Before and after

| Feature | Before: published `1.0.0-rc` | After: rewrite `1.0.0-rc.1` | Status and gap |
| --- | --- | --- | --- |
| Runtime and widget ownership | Component servers, registries, queues, routers, and process-owned widgets | One Elm runtime with parent-owned pure widgets and command data | Replaced. Do not restore the old ownership model. |
| Streaming input | `StreamWidget` accepted messages through a GenStage consumer and tracked demand | `TermUI.Widget.Stream.push/2` appends parent-supplied items to a bounded pure state value | Partial. Add an optional producer adapter outside the widget. It must send bounded messages through the parent update loop. |
| Stream buffer controls | Four overflow modes, pause, clear, rate display, callbacks, and a render-rate setting | Fixed drop-oldest bound, pause, follow mode, scroll, page navigation, and a formatter | Partial. Add batch push, clear, counters, and configurable drop policies as pure functions. Do not add a widget process. |
| Streaming Markdown | The viewer replaced its full content through a GenServer call | `MarkdownViewer.append/2` appends a bounded fragment and preserves pure ownership | Improved, with a gap. Each view parses the bounded document again. Add an incremental document model before use with very long token streams. |
| Markdown grammar | MDEx headings, emphasis, links, quotes, lists, code blocks, and rules | MDEx plus strike-through, task lists, autolinks, images, tables, and terminal-safe raw HTML | Improved and retained. |
| Code syntax highlighting | Makeup highlighted Elixir and Erlang fenced code | Fenced code keeps language labels and code-block focus, but uses one code style | Partial. Restore optional lexer-based highlighting without making Makeup a required runtime service. |
| Code block copy | The widget callback wrote through caller code from a component process | The pure widget returns `{:copy, code}` and the parent can issue a bounded clipboard command | Replaced with safer effect ownership. |
| Diff viewing | No dedicated diff viewer | Unified and side-by-side views, Myers line comparison, input bounds, and mode switching | Added in the rewrite. |
| Tables | Sorting, single or multi-selection, callbacks, and constraint widths | Column widths, vertical scrolling, mouse or keyboard row selection, and row replacement | Partial. Add pure sort state and optional multi-selection. Keep data sorting outside render code. |
| Menus | Actions, checkboxes, separators, and nested submenus | Flat actions, separators, disabled items, keyboard and mouse control, and context positions | Partial. Add nested menu data and pure open-path state. Do not restore submenu processes. |
| Forms | Six field types, custom validators, groups, visibility rules, reset, and submit callbacks | Text, checkbox, select, required checks, paste cleaning, mouse focus, and submit messages | Partial. Add validator functions and richer field data in small steps. |
| Viewports | Scroll bars, drag control, `scroll_into_view/3`, content dimensions, and visible fractions | Pure horizontal and vertical scrolling, page movement, mouse wheel, content replacement, and position query | Partial. Restore geometry queries and local scrollbar drag as pure state. |
| Split panes | Multiple panes, collapse, keyboard resize, persistence, and mouse drag | Two pure panes with horizontal or vertical ratio and local mouse drag | Partial. Add multi-pane data only after the two-pane sizing rules are stable. |
| Toasts | Timed toast collection with callback-style control | Pure bounded manager with explicit `tick/2`, expiry, dismiss messages, and four types | Retained through a pure replacement. |
| Process and cluster views | Widgets performed process inspection, polling, node monitoring, and distributed RPC | Widgets render parent-supplied snapshots and return refresh requests | Replaced. Keep polling and RPC in application commands or a separate adapter. |
| Themes and capability fallback | Global theme registry and semantic component styles | Explicit `TermUI.Style` values plus backend color and character capability handling | Partial. A pure theme value and capability transform can return later. Do not use a global registry. |
| Focus and shortcuts | Global focus manager, traversal groups, and shortcut sequence service | The Elm application routes focus and shortcuts; widgets expose local event updates | Deferred as global services. Reusable pure routing helpers are a valid future feature. |
| Layout solver | Constraint solver, alignment values, and a layout cache | Direct frame composition, overlay, widgets, and explicit dimensions | Deferred. Add only pure layout functions with bounded cost and no global cache. |
| Developer tools | Hot reload, UI and state inspectors, and a performance monitor | Deterministic backend tests and runtime instrumentation through normal application state | Partial. Add optional inspection data APIs before any live tool. |
| Test toolkit | Component harness, event simulator, and test renderer shipped in `lib/` | Public backend behaviour and deterministic test backend in test support | Replaced for internal tests. A separate public test package is better than shipping test code in the runtime package. |
| Platform and SSH adapters | Unix and Windows adapter modules; the published Hex archive did not contain an SSH backend | Raw and TTY backends own complete sessions; SSH is explicitly deferred | Retained for local terminals. SSH needs a full backend lifecycle contract before it can return. |

## Recommended order

1. Add a pure stream batch API, drop counters, and configurable bounded overflow.
2. Define an optional producer adapter contract and test it with slow parent
   updates, pause, shutdown, and producer failure.
3. Add an incremental Markdown state value for partial tokens, incomplete
   fences, and bounded reparsing.
4. Add optional Elixir and Erlang code highlighting with terminal capability
   fallback.
5. Add pure table sorting and nested menu state.
6. Add form validators, viewport geometry, and multi-pane layout only when a
   Jido Console use case needs them.

The first four items are the main gap for streaming assistant output and rich
Markdown. They can be added without changing the runtime contract.
