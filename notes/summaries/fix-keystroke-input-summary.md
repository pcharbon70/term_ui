# Fix Keystroke Input - Summary

## Problem

The dashboard example displayed correctly but keyboard input (Q, R, T, arrows) was not captured by the application. Characters were echoed to the terminal without triggering any application behavior.

## Root Causes Identified

### 1. Terminal Detection Failure
The `terminal?()` check in `Terminal` module only checked `:io.getopts(:standard_io)` for a `:terminal` key. This fails in SSH sessions where the Erlang VM doesn't properly detect the pseudo-terminal (PTY).

### 2. InputReader Not Receiving Data
The `InputReader` used `Port.open({:spawn, "cat"}, [:binary, :eof])` which connects the port's stdin to a pipe from the Erlang VM, not the terminal. The `cat` process never received any keyboard input.

### 3. Non-blocking Runtime Start
`Dashboard.start()` returned immediately with `{:ok, pid}`, allowing IEx to take back terminal control and compete for input.

## Solutions Implemented

### 1. Improved Terminal Detection (`lib/term_ui/terminal.ex`)
Added multiple fallback methods to detect terminal availability:
- Check `:io.getopts` for terminal key
- Check if `/dev/tty` exists (works for SSH on Unix/Linux/macOS)
- Fall back to `test -t 0` command

### 2. IO-based Input Reading (`lib/term_ui/terminal/input_reader.ex`)
Changed from port-based `cat` to Erlang's native IO system:
- Spawn a reader process that uses `IO.getn("", 1)`
- This integrates with OTP's terminal handling
- Works cross-platform when raw mode is enabled

### 3. Blocking Runtime.run Function (`lib/term_ui/runtime.ex`)
Added `Runtime.run/1` that:
- Starts the runtime with `start_link`
- Monitors the runtime process
- Blocks until the runtime exits
- Provides proper entry point for standalone TUI apps

### 4. Dashboard Updates (`examples/dashboard/`)
- Added `Dashboard.run/0` for blocking mode
- Updated `run.exs` to use blocking mode
- `Dashboard.start/0` remains for IEx development

## Files Changed

1. `lib/term_ui/terminal.ex` - Improved `terminal?()` detection
2. `lib/term_ui/terminal/input_reader.ex` - IO-based input reading
3. `lib/term_ui/runtime.ex` - Added `run/1` blocking function
4. `examples/dashboard/lib/dashboard.ex` - Added `run/0` function
5. `examples/dashboard/run.exs` - Use `Dashboard.run()`

## Testing

Run the dashboard with:
```bash
cd examples/dashboard && mix run run.exs
```

Verified working:
- T key toggles theme (dark/light)
- Arrow keys navigate process list
- R key refreshes
- Q key captured (exit not yet implemented)
- No character echoing
- Works over SSH sessions

## Notes

- The Q key sends a `:quit` message but the dashboard doesn't exit yet (needs `Runtime.shutdown` integration)
- Raw mode is enabled via `:shell.start_interactive({:noshell, :raw})` on OTP 28+
- Falls back to `stty` commands if OTP 28 shell API unavailable
