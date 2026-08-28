# macOS Manual Testing Checklist

> **1.0.0 status:** Interactive macOS verification was waived on 2026-08-27
> because no macOS system was available. This checklist is retained for future
> validation; the waiver is not a successful test result.

Hosted macOS CI validates compilation and the automated suite, but it cannot
verify the bytes emitted by a real keyboard, live window resizing, or terminal
restoration. Complete this checklist in an interactive macOS terminal against
the exact release commit.

## Test record

- Tester:
- Date:
- macOS version:
- Terminal and version:
- Elixir/OTP versions:
- Commit (must match the intended release head):

## Release-critical smoke test

From the repository root:

```bash
git switch release/1.0.0
git pull --ff-only origin release/1.0.0
git status --porcelain
git rev-parse HEAD
mix deps.get
mix compile --warnings-as-errors
```

`git status --porcelain` must print nothing. Record the commit above before
testing.

Capture the terminal mode, run the basic example, and compare the mode after a
normal exit:

```bash
before_stty=$(stty -g)
mix run -e 'Code.require_file("examples/multi_renderer/basic.ex"); Basic.run()'
after_stty=$(stty -g)
test "$before_stty" = "$after_stty"
```

- [ ] Initial content renders in the alternate screen without scrolling.
- [ ] Arrow keys and `j`/`k` move the selection; Enter toggles details.
- [ ] Shrinking and expanding the window redraws without stale rows or cursor
      overflow.
- [ ] `q` returns to a usable prompt with input echo and a visible cursor.
- [ ] The before/after `stty` values match.
- [ ] Repeating the run and interrupting it with Control+C restores the prompt.

Verify the macOS Option+Delete path with the real TextInput example:

```bash
cd examples/text_input
mix deps.get
mix termui.run
```

- [ ] Typing `alpha beta` and pressing Option+Delete removes `beta` without
      stalling later keyboard input.
- [ ] Backspace, Delete, arrows, Home/End, Tab, and Enter behave as documented.
- [ ] Empty the focused input and press `q` to exit cleanly.

Verify IEx compatibility:

```bash
cd examples/iex_counter
iex -S mix
```

Then run `IExCounter.App.run()`.

- [ ] Arrow keys update the counter and `q` returns to the same IEx prompt.
- [ ] The prompt remains usable and terminal echo/cursor state is restored.

Run the release-critical checks in Terminal.app. Repeat them in iTerm2 if the
release is being signed off for the guide's stated iTerm2 support. Terminal.app
mouse limitations documented in `guides/user/08-terminal.md` are accepted and
do not fail this gate.

## Extended example matrix

The following matrix records broader example coverage when time permits; it is
not a substitute for the release-critical lifecycle checks above.

| Example | Tested | Description |
|---------|:------:|-------------|
| alert_dialog | [ ] | Standardized message dialogs and confirmations with predefined button configurations |
| bar_chart | [ ] | Comparative values displayed as horizontal or vertical bars |
| canvas | [ ] | Direct character buffer for custom drawing with primitives |
| cluster_dashboard | [ ] | Visualization and monitoring of distributed Erlang/BEAM clusters |
| command_palette | [ ] | Command dropdown for filtering and selecting commands with keyboard |
| context_menu | [ ] | Floating menus at cursor position, triggered by right-click or keyboard |
| dashboard | [ ] | System monitoring dashboard with multiple widgets and real-time updates |
| dialog | [ ] | Modal dialogs with customizable buttons and content |
| form_builder | [ ] | Structured forms with multiple field types and validation |
| gauge | [ ] | Numeric values within a range using visual bars or arcs |
| iex_counter | [ ] | Simple counter demonstrating TermUI's IEx compatibility |
| line_chart | [ ] | Time series visualization using Braille patterns |
| log_viewer | [ ] | Display and analyze log data with virtual scrolling |
| markdown_viewer | [ ] | Render and display markdown content |
| menu | [ ] | Hierarchical menus with various item types |
| multi_renderer | [ ] | Multi-renderer capabilities with automatic backend selection |
| pick_list | [ ] | Modal selection dialogs with filtering support |
| process_monitor | [ ] | Live BEAM process inspection and management |
| sparkline | [ ] | Compact inline trend visualization using vertical bars |
| split_pane | [ ] | Resizable multi-pane layouts similar to IDE editors |
| stream_widget | [ ] | Backpressure-aware streaming data with GenStage |
| supervision_tree_viewer | [ ] | Visualize OTP supervision hierarchies in real-time |
| table | [ ] | Tabular data with selection, sorting, and scrolling |
| tabs | [ ] | Organize content into switchable panels |
| text_input | [ ] | Single-line and multi-line text input |
| toast | [ ] | Auto-dismissing notifications |
| tree_view | [ ] | Hierarchical data with expand/collapse functionality |
| viewport | [ ] | Scrollable content areas with keyboard/mouse support |
