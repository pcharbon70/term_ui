# Feature: Phase 3 Task 3.3.1 - Implement clear/1 Callback

**Branch:** `feature/phase-03-task-3.3.1-clear-callback`
**Base:** `multi-renderer`
**Date:** 2025-12-06
**Status:** Complete

## Overview

Task 3.3.1 implements the `clear/1` callback for the TTY backend. This callback clears the screen and resets cursor position, which is the foundation for full redraw rendering mode.

## Tasks

### 3.3.1 Implement clear/1 Callback

- [x] 3.3.1.1 Implement `@impl true` `clear/1` accepting state
- [x] 3.3.1.2 Write `\e[2J` (clear entire screen)
- [x] 3.3.1.3 Write `\e[H` (cursor to home position)
- [x] 3.3.1.4 Clear `last_frame` in state if incremental mode
- [x] 3.3.1.5 Return `{:ok, updated_state}`

## Implementation Details

Updated `clear/1` to:
1. Output `@clear_screen` (`\e[2J`) to clear entire screen
2. Output `@cursor_home` (`\e[H`) to move cursor to home position
3. Set `last_frame: nil` to force full redraw in incremental mode
4. Set `cursor_position: {1, 1}` to track cursor state

## Files Modified

| File | Type | Description |
|------|------|-------------|
| `lib/term_ui/backend/tty.ex` | Modified | Updated clear/1 to output sequences |
| `test/term_ui/backend/tty_test.exs` | Modified | Added 6 new tests for clear/1 |
| `notes/planning/multi-renderer/phase-03-tty-backend.md` | Modified | Marked task 3.3.1 complete |

## Test Results

```
72 tests, 0 failures
```

Added 6 new tests:
- Test clear/1 outputs clear screen sequence
- Test clear/1 outputs cursor home sequence
- Test clear screen comes before cursor home
- Test clears last_frame in state
- Test sets cursor_position to {1, 1}
- Test returns {:ok, state}
