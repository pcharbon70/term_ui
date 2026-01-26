# Summary: Phase 3 Task 3.7.1 - Cursor Operations

**Date:** 2025-12-06
**Branch:** `feature/phase-03-task-3.7.1-cursor-operations`

## What Was Done

Implemented the cursor operation callbacks in the TTY backend to actually output ANSI escape sequences:

1. **move_cursor/2**: Now outputs `\e[row;colH` sequence and clamps position to terminal bounds
2. **hide_cursor/1**: Now outputs `\e[?25l` sequence to hide cursor
3. **show_cursor/1**: Now outputs `\e[?25h` sequence to show cursor

Previously these were stub implementations that only updated state without terminal output.

## Changes

### `lib/term_ui/backend/tty.ex`
- `move_cursor/2`: Added position clamping and ANSI sequence output
- `hide_cursor/1`: Added `safe_write(@cursor_hide)` call
- `show_cursor/1`: Added `safe_write(@cursor_show)` call

### `test/term_ui/backend/tty_test.exs`
Added 7 new tests:
- `move_cursor/2` outputs cursor positioning sequence
- `move_cursor/2` updates cursor_position in state
- `move_cursor/2` clamps row to terminal bounds
- `move_cursor/2` clamps column to terminal bounds
- `move_cursor/2` clamps minimum position to 1,1
- `hide_cursor/1` outputs hide cursor sequence
- `show_cursor/1` outputs show cursor sequence

## Test Results

All 179 TTY backend tests pass.

## Next Task

According to the Phase 3 plan, the next task is **3.7.2 - Implement size/1 Callback**:
- Implement `@impl true` `size/1` returning `{:ok, state.size}`
- Size is determined at init from capabilities
- Provide `refresh_size/1` for manual size update
