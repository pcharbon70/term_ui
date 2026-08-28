# WSL Manual Testing Checklist

> **1.0.0 status:** Interactive WSL/ConPTY verification was waived on
> 2026-08-28 because no representative system was available. This checklist is
> retained for future validation; the waiver is not a successful test result.

This gate must run inside WSL from a Windows Terminal profile so the Unix
backend is exercised through ConPTY. Native PowerShell or Command Prompt does
not satisfy this gate.

## Test record

- Tester:
- Date:
- Windows version:
- Windows Terminal version:
- WSL version and distribution:
- Elixir/OTP versions:
- Commit (must match the intended release head):

## Windows preflight

In PowerShell, record the WSL installation and confirm the distribution uses
WSL 2:

```powershell
wsl --version
wsl --status
wsl --list --verbose
```

Open the distribution from Windows Terminal. In the WSL shell, run:

```bash
test -n "$WSL_DISTRO_NAME"
test -n "$WSL_INTEROP"
test -n "$WT_SESSION"
tty
printf 'TERM=%s\n' "$TERM"
stty size
```

All three environment checks must succeed, `tty` must identify a terminal, and
`stty size` must report non-zero rows and columns.

## Repository preflight

From the repository root inside WSL:

```bash
git switch release/1.0.0
git pull --ff-only origin release/1.0.0
git status --porcelain
git rev-parse HEAD
mix deps.get
mix compile --warnings-as-errors
mix test test/term_ui/platform_test.exs test/integration/cross_platform_test.exs
mix run -e 'IO.inspect(%{wsl: TermUI.Platform.wsl?(), conpty: TermUI.TerminalOutput.needs_hard_reset?()})'
```

`git status --porcelain` must print nothing. Both values in the final command
must be `true`.

## Raw backend

Raw mode requires OTP 28 or later. Capture and compare the terminal mode around
the basic example:

```bash
before_stty=$(stty -g)
mix run -e 'Code.require_file("examples/multi_renderer/basic.ex"); Basic.run(backend: :raw)'
after_stty=$(stty -g)
test "$before_stty" = "$after_stty"
```

- [ ] The initial alternate-screen render is clean and does not scroll.
- [ ] Arrow keys and `j`/`k` move the selection; Enter toggles details.
- [ ] Shrinking and expanding the Windows Terminal window redraws without
      stale rows, wrapping artifacts, or a stuck cursor.
- [ ] Resize followed immediately by `q` restores the prompt.
- [ ] A normal `q` exit restores input echo, cursor visibility, colors, and the
      exact `stty` value.
- [ ] Repeating the run and interrupting with Control+C restores the prompt.

## TTY and IEx paths

Force the TTY backend from the repository root:

```bash
before_stty=$(stty -g)
mix run -e 'Code.require_file("examples/multi_renderer/basic.ex"); Basic.run(backend: :tty)'
after_stty=$(stty -g)
test "$before_stty" = "$after_stty"
```

TTY input may be line-buffered; use `q` followed by Enter when necessary.

- [ ] Navigation and quit input work without freezing the runtime.
- [ ] The terminal mode matches after exit.

Then verify return to IEx:

```bash
cd examples/iex_counter
iex -S mix
```

Run `IExCounter.App.run()`, exercise arrows and reset, then quit.

- [ ] The application returns to the same usable IEx prompt.
- [ ] Echo, cursor visibility, and line editing remain correct.

## Paste and ConPTY-specific behavior

Run the real text-input example:

```bash
cd examples/text_input
mix deps.get
mix termui.run
```

- [ ] Single-line paste arrives once and contains no bracket markers.
- [ ] Multiline paste into the multiline field preserves its line breaks.
- [ ] Shift+Tab and modified navigation keys do not leak escape text.
- [ ] Clicking or dragging does not print raw mouse escape sequences. Mouse
      tracking is intentionally disabled under WSL/ConPTY in `1.0.0`.
- [ ] Empty the focused input and press `q` to exit cleanly.

## Gate result

- [ ] Raw backend checks passed on OTP 28 or later.
- [ ] TTY and IEx checks passed.
- [ ] Resize, paste, and cleanup checks passed.
- [ ] Any limitation or failure is recorded below and in the release notes.

Notes:

## Extended example matrix

The matrix below records broader coverage when time permits. It is not a
substitute for the release-critical lifecycle checks above.

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
