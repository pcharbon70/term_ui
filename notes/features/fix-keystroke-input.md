# Fix Keystroke Input Not Being Captured

## Problem Statement

The dashboard example displays correctly but keyboard input (Q, R, T, arrows) is not captured by the application. Instead, characters echo to the terminal without triggering any application behavior.

### Root Cause Analysis

The issue stems from multiple problems:

1. **Terminal detection failure**: The `terminal?()` check only looked at `:io.getopts(:standard_io)` which returns `terminal: false` in SSH sessions
2. **Port-based input**: `InputReader` used `Port.open({:spawn, "cat"})` which connects to a pipe, not the terminal
3. **Non-blocking start**: `Dashboard.start()` returned immediately, letting IEx compete for input

### Why characters echo

Without raw mode enabled (because terminal detection failed), the terminal driver operates in "cooked" mode - echoing characters and line-buffering input.

## Solution Overview

**Chosen approach**: Multiple fixes working together:

1. Improve terminal detection to work in SSH sessions
2. Use Erlang's IO system (`IO.getn`) instead of external `cat` process
3. Add blocking `Runtime.run/1` for standalone TUI apps

## Implementation Plan

### Step 1: Fix terminal detection ✅
- [x] Add `/dev/tty` existence check as fallback
- [x] Add `test -t 0` check as secondary fallback
- [x] Restructure `terminal?()` to try multiple methods

### Step 2: Fix input reading ✅
- [x] Replace `Port.open({:spawn, "cat"})` with `IO.getn` based reader
- [x] Spawn reader process to avoid blocking GenServer
- [x] Handle `:io_data` messages in InputReader

### Step 3: Add blocking runtime mode ✅
- [x] Add `Runtime.run/1` that blocks until runtime exits
- [x] Add `Dashboard.run/0` for standalone execution
- [x] Update `run.exs` to use blocking mode

### Step 4: Test the fix ✅
- [x] Run the dashboard example
- [x] Verify T toggles theme
- [x] Verify arrow keys navigate
- [x] Verify R refreshes
- [x] Verify no character echoing

## Success Criteria

1. ✅ Dashboard starts and displays correctly
2. ⏳ Pressing Q quits the application (needs Runtime.shutdown integration)
3. ✅ Pressing R triggers refresh
4. ✅ Pressing T toggles theme
5. ✅ Arrow keys navigate the process list
6. ✅ No character echoing to terminal
7. ✅ Terminal restores to normal state after exit (Ctrl+C)

## Files Changed

1. `lib/term_ui/terminal.ex` - Improved `terminal?()` detection
2. `lib/term_ui/terminal/input_reader.ex` - IO-based input reading
3. `lib/term_ui/runtime.ex` - Added `run/1` blocking function
4. `examples/dashboard/lib/dashboard.ex` - Added `run/0` function
5. `examples/dashboard/run.exs` - Use `Dashboard.run()`

## Notes

- Works over SSH sessions where `:io.getopts` reports `terminal: false`
- The `/dev/tty` device check is Unix-specific but provides good SSH compatibility
- Q key exit functionality requires additional `Runtime.shutdown` integration (future work)
