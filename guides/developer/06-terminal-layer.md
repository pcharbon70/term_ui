# Terminal Layer

The backend behaviour separates rendering from terminal ownership. TermUI 1.0
ships Raw, TTY, and SSH implementations.

## Selection

`TermUI.Backend.Selector.select/0` attempts native Raw mode only where
`TermUI.Platform` reports support. Success returns `{:raw, state}`; unavailable
or already-owned terminals return `{:tty, capabilities}`. OTP releases before
28 fall back to TTY.

`select(module)` and `select({module, opts})` return
`{:explicit, module, opts}`; they do not initialize that backend. Runtime atoms
`:raw` and `:tty` are convenient explicit modes handled by `TermUI.Runtime`.

In IEx, automatic runtime selection resolves directly to TTY without attempting
to replace the active shell.

## Raw backend

Raw mode is a local Unix terminal path requiring OTP 28's interactive shell API.
`TermUI.Terminal` owns raw/cooked transitions, alternate screen, cursor,
terminal size, mouse tracking, resize callbacks, and defensive restoration.
The runtime enables the alternate screen, hides the cursor, and requests all
mouse events before initializing `TermUI.Backend.Raw` without duplicating those
steps.

Raw rendering uses a BufferManager and sends only changed cells. Raw input is
character-at-a-time. WSL/ConPTY deliberately disables mouse tracking because
cleanup sequences are unreliable there.

## TTY backend

TTY leaves the local terminal in cooked mode and reads through its IO server.
The runtime initializes it with `alternate_screen: true`, even though the
backend's standalone default is false. Input can be buffered until Enter. The
input reader is separate, so rendering and shutdown remain responsive.

TTY does not receive a runtime BufferManager. It receives a full set of
displayable frame cells and defaults to `line_mode: :full_redraw`.

## SSH backend

`TermUI.Backend.SSH` is an explicit custom backend initialized with a channel
device and size. Each connection has independent backend and buffer state. The
host sends `{:ssh_input, event}` and `{:ssh_resize, rows, cols}` to that session's
runtime. SSH is not selected as the TTY fallback and does not use local stdin.

## Terminal reporting features

The escape parser understands SGR mouse, focus, and bracketed paste sequences.
Runtime Raw setup enables mouse reporting, except on WSL/ConPTY. The runtime
does not automatically enable focus reporting or bracketed paste mode; direct
integrations can use `TermUI.Focus` and `TermUI.Clipboard` sequences and must
disable them during cleanup.

## Platform matrix

- Linux/macOS Unix terminals: local Raw and TTY target platforms.
- OTP 26+: TTY and size queries; automatic SIGWINCH resize needs a newer OTP.
- OTP 28+: native Raw mode.
- WSL: Unix paths, with mouse tracking disabled.
- Native Windows: ANSI output may work when the host enabled VT processing,
  but TermUI does not configure console modes or provide native Raw input/resize.

## Cleanup

Runtime shutdown stops input before backend cleanup, restores backend and
terminal state, makes the cursor visible, restores logger output, and uses
direct-to-TTY/stty safety nets for local terminals. Custom backends clean up
their own device and do not trigger local terminal recovery.

Next: [Elm Implementation](07-elm-implementation.md).
