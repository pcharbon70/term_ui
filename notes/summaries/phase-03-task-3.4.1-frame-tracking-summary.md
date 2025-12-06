# Summary: Phase 3 Task 3.4.1 - Frame Tracking

**Branch:** `feature/phase-03-task-3.4.1-frame-tracking`
**Date:** 2025-12-06

## Overview

Task 3.4.1 implements frame state tracking for the incremental rendering mode in the TTY backend. This allows comparing frames to enable differential updates in subsequent tasks.

## Changes Made

### 1. First Frame Fallback (3.4.1.2)

Modified `draw_cells/2` to detect first frame in incremental mode:

```elixir
needs_full_redraw =
  state.line_mode == :full_redraw or
    (state.line_mode == :incremental and is_nil(state.last_frame))

if needs_full_redraw do
  safe_write(@clear_screen <> @cursor_home)
end
```

When `line_mode == :incremental` but `last_frame == nil`, the backend now performs a full redraw to ensure clean initial state.

### 2. Resize Handling (3.4.1.3)

Added `set_size/2` function to handle terminal resize events:

```elixir
def set_size(%__MODULE__{} = state, {rows, cols} = new_size)
    when is_integer(rows) and rows > 0 and is_integer(cols) and cols > 0 do
  {:ok, %{state | size: new_size, last_frame: nil}}
end
```

This updates the terminal size and clears `last_frame` to force a full redraw on the next render (resize invalidates all previous frame positions).

### 3. Updated Existing Test

Fixed the existing test "in incremental mode, does not output clear screen sequence" to properly test subsequent frame behavior (not first frame which now correctly does full redraw).

## New Tests (+6)

| Test | Description |
|------|-------------|
| incremental mode first frame triggers full redraw | Verifies first frame (nil last_frame) clears screen |
| incremental mode subsequent frame does not clear | Verifies second+ frames skip clear screen |
| clear/1 clears last_frame | Verifies explicit clear resets frame state |
| set_size/2 clears last_frame | Verifies resize resets frame state |
| set_size/2 updates size correctly | Verifies size is updated |
| after resize, next draw triggers full redraw | Integration test for resize → redraw flow |

## Test Results

```
Before: 114 tests, 0 failures
After: 120 tests, 0 failures (+6 tests)
```

## Files Changed

- `lib/term_ui/backend/tty.ex` - Added first frame logic, set_size/2
- `test/term_ui/backend/tty_test.exs` - 6 new tests, 1 updated test
- `notes/planning/multi-renderer/phase-03-tty-backend.md` - Marked task complete
- `notes/features/phase-03-task-3.4.1-frame-tracking.md` - Feature plan

## Task Completion Status

- [x] 3.4.1.1 Store `last_frame` as map after render (already done in 3.3)
- [x] 3.4.1.2 On first frame (nil last_frame), fall back to full redraw
- [x] 3.4.1.3 Clear last_frame on resize or explicit clear

## Foundation for Next Tasks

This task provides the frame tracking infrastructure needed for:
- **3.4.2** Frame Comparison - Compare current vs last frame to find changed cells
- **3.4.3** Incremental draw_cells - Only render changed/removed cells
- **3.4.4** Cursor Movement Optimization - Minimize cursor operations
