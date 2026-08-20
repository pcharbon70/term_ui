# Removed and deferred features

The 1.0 release candidate has one runtime, one input path, one frame type, and
one widget namespace. Some old features did not fit this design.

## Intentional architecture removals

These systems will not return in their old form:

| Removed system | Replacement |
| --- | --- |
| Component server, registry, supervisor, containers, and state persistence | One Elm runtime and parent-owned pure widget state |
| Event router, event queue, message queue, and global focus manager | The Elm application serializes events and owns focus |
| Legacy raw, TTY, selector, and line-reader input modules | The selected backend owns one input path |
| Render nodes, renderer buffers, buffer managers, and renderer style/cell copies | `TermUI.Frame`, `TermUI.Cell`, and backend rendering |
| `TermUI.Widgets` and process-based widgets | `TermUI.Widget` pure state transitions |
| Global spatial index and mouse tracker | Pure `TermUI.Mouse.Region` lists and application-owned `TermUI.Mouse.Tracker` data |
| Global configuration and persistent-term caches | Runtime and widget options stored by their owner |

## Deferred optional features

These features are not in the new package:

- SSH backend support.
- A high-level theme registry and automatic capability-based theme fallback.
- A constraint layout solver, layout cache, and alignment objects.
- A shared shortcut-sequence service and global focus traversal groups.
- Development hot reload, UI inspection, state inspection, and performance tools.
- The component test harness, event simulator, and test renderer.
- Dedicated Unix and Windows platform adapter modules.
- The old set of one application for each widget. The counter is the retained
  general example.

SSH can return only as a normal backend that owns its complete state. Layout
and focus helpers can return as pure functions. These forms keep the core
design unchanged.

Clipboard, selection, and mouse support have returned in refined forms.
Clipboard writes are bounded command data. Selection uses Unicode grapheme
positions. Mouse regions, hit testing, hover, and drag state are pure data.

## Widget behavior that became smaller

The widget names are present, but some old adapters and services are not:

| Widget area | Current behavior | Removed behavior |
| --- | --- | --- |
| Stream | Bounded parent-supplied items | GenStage consumer and backpressure process |
| Process, supervision, and cluster views | Parent-supplied snapshots | Process inspection, polling, distributed RPC, and monitoring processes |
| Toast | Pure state with explicit `tick/2` | Timer process and global stack service |
| Line input | Pure event-driven input | Blocking shell `IO.gets/1` adapter |
| Markdown code blocks | Emits copy data that the parent can send as a clipboard command | Direct clipboard writes |
| Menu and context menu | Flat actions, separators, keyboard and mouse control, and an overlay position | Submenu processes and inline service variants |
| Table | Scrolling, columns, and row selection | Built-in sorting service |
| Form | Text, checkbox, select, and required-field validation | General validation framework and field processes |
| Split pane and scrollbar | Pure state with local mouse drag and click behavior | Global mouse routing services |

Applications can add these effects in their Elm update function. A reusable
adapter belongs in TermUI only when it can stay pure or follow the backend and
command contracts.
