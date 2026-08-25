# Interactive showcase

The TermUI showcase is an executable catalog for the public application,
widget, frame, event, command, and clipboard contracts. It also explains the
ownership rules from inside a running terminal application.

## Run the application

Use a terminal of at least 80 columns by 24 rows when possible.

```sh
git clone https://github.com/pcharbon70/term_ui.git
cd term_ui/examples/showcase
mix deps.get
mix run run.exs
```

See the [showcase source and full control
list](https://github.com/pcharbon70/term_ui/tree/develop/examples/showcase).

## What it demonstrates

- The Overview page composes gauges, progress, a sparkline, bars, and a table.
- The Inputs page routes events to parent-owned text, list, and button state.
- The Content page shows Markdown, diff, bounded streams, and clipboard command
  output.
- The BEAM page renders parent-supplied process, supervision, and cluster
  snapshots.
- The Architecture page explains the active application, frame, and backend
  seams.

## Application structure

`Showcase.App` is the only Elm application. It owns global state, all page and
widget state, timers, clipboard commands, terminal dimensions, and final frame
composition.

Each page is a pure adapter:

```elixir
{page_state, messages} = Page.update(event, page_state)
frame = Page.view(page_state, dimensions, theme)
```

A page does not start a process or nested runtime. Sample metrics and BEAM data
are deterministic values. A real application can replace them with command or
adapter output without changing the widgets.

The showcase has its own tests. CI renders every page at normal and compact
sizes and checks input routing, timers, and clipboard command output.
