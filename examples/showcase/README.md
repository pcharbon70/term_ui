# Interactive showcase

This application is an executable catalog of TermUI widgets and architecture.
It uses only the public Elm application, widget, frame, event, command, and
clipboard contracts.

## Run it

Use a terminal of at least 80 columns by 24 rows when possible.

```sh
cd examples/showcase
mix deps.get
mix run run.exs
```

The application also works from IEx:

```elixir
Showcase.App.run()
```

## Controls

- F1 through F5 select the main pages.
- F9 changes the showcase theme.
- F10 or Escape stops the application and restores the terminal.
- Ctrl+N and Ctrl+P select the next or previous page.
- Ctrl+T changes the showcase theme.
- Ctrl+Q stops the application and restores the terminal.
- Tab changes focus on pages with multiple controls.
- The footer and page status show local controls.

## Pages

### Overview

Shows live gauges, progress, sparklines, bars, and a selectable table. A
deterministic timer changes application state. Rendering does not collect data
or perform effects.

### Inputs

Shows single-line and multiline text input, multiple selection, keyboard focus,
button output, and copy messages. The parent routes each event to one focused
widget.

### Content

Shows Markdown, diff, and bounded stream widgets. Use `[` and `]` to change the
active widget. The Markdown sample includes a copyable code block. The parent
converts its copy message to serialized clipboard command data.

### BEAM

Shows process, supervision-tree, and cluster widgets. All values are fixed
snapshots supplied by the parent. The widgets do not inspect processes, monitor
nodes, or perform RPC.

### Architecture

Explains the application, widget, frame, and backend ownership seams inside the
running TermUI application.

## Structure

`Showcase.App` is the only Elm application. It owns global state, every page
state, timers, clipboard commands, terminal dimensions, and final frame
composition.

Each module in `Showcase.Pages` is a pure page adapter:

```elixir
{page_state, messages} = Page.update(event, page_state)
frame = Page.view(page_state, dimensions, theme)
```

A page does not start a process or a nested runtime. `Showcase.Layout` contains
only frame composition helpers.

## Tests

```sh
mix test
```

The tests render every page at normal and compact terminal sizes. They also
check state ownership, input routing, timers, and clipboard command output. CI
compiles and tests this standalone Mix application so the documentation cannot
silently drift from the public API.
