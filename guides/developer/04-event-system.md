# Event System

TermUI normalizes terminal input into structs under `TermUI.Event`:
`Key`, `Mouse`, `Resize`, `Focus`, `Paste`, `Tick`, and `Custom`.

## Local input paths

Raw mode has two implementations:

- By default `TermUI.Terminal.InputReader` reads asynchronously and sends
  `{:input, event}` to the runtime.
- With `use_input_handler: true`, the runtime selects `TermUI.Input.Raw` and
  polls it from a linked reader process.

TTY always selects `TermUI.Input.TTY` and polls it from a linked reader process.
TTY requests characters through the current IO server while leaving the
terminal cooked. Its timeout argument is not honored and delivery may be
line-buffered; the separate reader prevents that blocking call from stopping
the runtime's render loop.

Both input paths use `TermUI.Terminal.EscapeParser`. The older modules under
`TermUI.Parser` are separate parser utilities and are not used by the runtime.

## Parsing

The escape parser handles ordinary keys, control keys, CSI/SS3 navigation and
function keys, SGR mouse sequences, focus sequences, and bracketed paste
payloads. Partial escape sequences remain buffered until complete; a short
timeout distinguishes a lone Escape key in Raw input.

Parsing support does not mean the runtime enables every terminal reporting
mode. Raw startup enables mouse tracking. Focus reporting and bracketed paste
helpers exist (`TermUI.Focus` and `TermUI.Clipboard`), but the 1.0 runtime does
not enable those modes automatically.

## Runtime dispatch

The runtime puts events in a bounded `TermUI.EventQueue` and processes one per
pass. All supported event types reach the single root Elm module. Mouse input
does not query `TermUI.SpatialIndex`; resize/focus/tick broadcasts currently
still target only `:root`.

The root returns:

- `{:msg, message}` to enqueue a message for `update/2`
- `:ignore` to discard the event
- `:propagate` to leave it unhandled; there is no runtime parent in 1.0, so it
  is also discarded

Exceptions in `event_to_msg/2` are logged and do not replace root state.

## SSH input

The SSH host owns channel input parsing and sends normalized events to the
session runtime as `{:ssh_input, event}`. Window changes arrive as
`{:ssh_resize, rows, cols}`. A custom/SSH runtime does not create a local stdin
reader.

## Resize limits

Size queries work in minimum-version TTY operation. Automatic local resize
notifications depend on OTP exposing `SIGWINCH` to handlers; OTP 26 does not.
Native Windows raw input and resize handling are not implemented.

## Tests

Use constructors such as `TermUI.Event.key/2`, `mouse/5`, `resize/3`, and
`paste/2`, or `TermUI.Test.EventSimulator`. Feed integration events through
`TermUI.Runtime.send_event/2`, then call `TermUI.Runtime.sync/2` before reading
runtime state.

Next: [Buffer Management](05-buffer-management.md).
