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
| Streaming input | `StreamWidget` accepted messages through a GenStage consumer and tracked demand | `ProducerAdapter` bounds queued data and sends one acknowledged batch at a time; the parent applies it to the pure widget | Replaced. Slow consumers cannot receive an unbounded series of adapter batches. |
| Stream buffer controls | Four overflow modes, pause, clear, rate display, callbacks, and a render-rate setting | Batch push, clear, lifetime counters, drop-oldest, drop-newest, whole-batch reject, pause, follow, scroll, and formatting | Replaced with pure state. Rate calculation belongs in application data. |
| Streaming Markdown | The viewer replaced its full content through a GenServer call | A bounded incremental document parses completed top-level blocks once and retains the last extensible block as a pending tail | Improved and retained without a viewer process. |
| Markdown grammar | MDEx headings, emphasis, links, quotes, lists, code blocks, and rules | MDEx plus strike-through, task lists, autolinks, images, tables, and terminal-safe raw HTML | Improved and retained. |
| Code syntax highlighting | Makeup highlighted Elixir and Erlang fenced code | Fenced code keeps language labels and code-block focus, but uses one code style | Partial. Restore optional lexer-based highlighting without making Makeup a required runtime service. |
| Code block copy | The widget callback wrote through caller code from a component process | The pure widget returns `{:copy, code}` and the parent can issue a bounded clipboard command | Replaced with safer effect ownership. |
| Diff viewing | No dedicated diff viewer | Unified and side-by-side views, Myers line comparison, input bounds, and mode switching | Added in the rewrite. |
| Tables | Sorting, single or multi-selection, callbacks, and constraint widths | Pure stable sorting and filtering, identity-based single or multiple selection, vertical scrolling, mouse or keyboard selection, and row replacement | Replaced for data interaction. Callbacks are parent messages, and v2 uses direct column widths. |
| Menus | Actions, checkboxes, separators, and nested submenus | Actions, separators, disabled items, nested submenu data, pure open-path state, keyboard and mouse control, and edge-fitted context positions | Replaced for nested navigation. Checkbox items remain reduced, and no submenu process exists. |
| Forms | Six field types, custom validators, groups, visibility rules, reset, and submit callbacks | Text, checkbox, select, pure field, group, and submit validators, field errors, first-error focus, paste cleaning, mouse focus, and submit messages | Replaced for validation flow. Some field types and conditional visibility remain reduced. |
| Viewports | Scroll bars, drag control, `scroll_into_view/3`, content dimensions, and visible fractions | Pure geometry, visible ranges, `scroll_into_view/3`, optional local scrollbars, keyboard and wheel scroll, and drag state | Retained through a pure replacement. |
| Split panes | Multiple panes, collapse, keyboard resize, persistence, and mouse drag | Named multi-pane weights, collapse state, measured layout, keyboard resize, and local separator drag; legacy two-pane fields remain | Retained except automatic persistence. The parent can persist the pure value. |
| Toasts | Timed toast collection with callback-style control | Pure bounded manager with explicit `tick/2`, expiry, dismiss messages, and four types | Retained through a pure replacement. |
| Process and cluster views | Widgets performed process inspection, polling, node monitoring, and distributed RPC | Widgets render parent-supplied snapshots and return refresh requests | Replaced. Keep polling and RPC in application commands or a separate adapter. |
| Themes and capability fallback | Global theme registry and semantic component styles | `TermUI.Theme` stores named styles, variants, values, merge data, and a capability-limited copy | Replaced. The global registry remains removed. |
| Focus and shortcuts | Global focus manager, traversal groups, and shortcut sequence service | `TermUI.Focus` routes enabled traversal order; `TermUI.Shortcut` routes chords and timestamp-bounded sequences | Replaced with application-owned pure values. |
| Layout solver | Constraint solver, alignment values, and a layout cache | Direct frame composition and pure row, column, and grid tracks for fixed, fill, percentage, ratio, bounds, and measured content | Replaced for common constraints. The general solver and global cache remain removed. |
| Developer tools | Hot reload, UI and state inspectors, and a performance monitor | Deterministic backend tests and runtime instrumentation through normal application state | Partial. Add optional inspection data APIs before any live tool. |
| Test toolkit | Component harness, event simulator, and test renderer shipped in `lib/` | Public deterministic v2 backend with event injection, complete frames, and shutdown snapshots | Replaced. Tests use the runtime, event, command, and frame contracts without component processes. |
| Platform and SSH adapters | Unix and Windows adapter modules; the published Hex archive did not contain an SSH backend | Raw, TTY, and SSH backends own complete sessions | Replaced. SSH has a direct host API and an OTP SSH channel callback with isolated runtimes and bounded frame output. |

## Recommended order

1. Add optional Elixir and Erlang code highlighting with terminal capability
   fallback.
2. Add richer form field data when a Jido Console use case needs it.
3. Add optional inspection data APIs before any live developer tool.

Bounded assistant output and rich Markdown no longer need the old component
ownership model. Syntax highlighting is the main remaining rich-Markdown gap.
