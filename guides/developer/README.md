# Developer Guides

Technical documentation for TermUI internals and architecture.

## Guides

| Guide | Description |
|-------|-------------|
| [01-architecture-overview.md](01-architecture-overview.md) | System layers, process hierarchy, data flow |
| [02-runtime-internals.md](02-runtime-internals.md) | GenServer event loop, state management, lifecycle |
| [03-rendering-pipeline.md](03-rendering-pipeline.md) | View → Buffer → Diff → Output stages |
| [04-event-system.md](04-event-system.md) | Input parsing, escape sequences, dispatch |
| [05-buffer-management.md](05-buffer-management.md) | ETS double buffering, cell storage |
| [06-terminal-layer.md](06-terminal-layer.md) | Raw mode, ANSI sequences, platform handling |
| [07-elm-implementation.md](07-elm-implementation.md) | The Elm Architecture adapted for OTP |

## Reading Order

For new contributors:

1. **Architecture Overview** - Understand the layers
2. **Elm Implementation** - Learn the component model
3. **Runtime Internals** - See how components are orchestrated
4. **Event System** - Follow input from terminal to component
5. **Rendering Pipeline** - Follow output from component to terminal
6. **Buffer Management** - Understand the ETS buffer system
7. **Terminal Layer** - Low-level terminal details

## Key Concepts

### Three-Layer Architecture

```
┌─────────────────────────────────────┐
│          Widget Layer               │  ← Components (Elm Architecture)
├─────────────────────────────────────┤
│         Renderer Layer              │  ← Buffers, Diff, Output
├─────────────────────────────────────┤
│          Port Layer                 │  ← Terminal I/O
└─────────────────────────────────────┘
```

### Data Flow

```
Event → event_to_msg → Message → update → State → view → Render Tree → Buffer → Diff → Terminal
```

### Key Files

| File | Purpose |
|------|---------|
| `lib/term_ui/runtime.ex` | Central GenServer orchestrating everything |
| `lib/term_ui/renderer/buffer.ex` | ETS-backed screen buffer |
| `lib/term_ui/renderer/diff.ex` | Differential rendering algorithm |
| `lib/term_ui/renderer/sequence_buffer.ex` | ANSI sequence batching |
| `lib/term_ui/terminal.ex` | Raw mode and terminal control |
| `lib/term_ui/terminal/input_reader.ex` | Stdin reading and event parsing |
| `lib/term_ui/terminal/escape_parser.ex` | Escape sequence parsing |

## Diagrams

All guides include Mermaid diagrams. To view them:

- GitHub renders Mermaid automatically
- VS Code with Markdown Preview Mermaid extension
- [Mermaid Live Editor](https://mermaid.live/)
