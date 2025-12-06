# Feature: Phase 3 Task 3.7.1 - Cursor Operations

**Branch:** `feature/phase-03-task-3.7.1-cursor-operations`
**Base:** `multi-renderer`
**Date:** 2025-12-06
**Status:** Complete

## Overview

Implement the cursor operation callbacks in the TTY backend. These callbacks now output ANSI escape sequences to control cursor position and visibility.

## Implementation Summary

### 3.7.1.1 Implement move_cursor/2 Callback
- [x] Write `\e[row;colH` sequence to position cursor
- [x] Update `cursor_position` in state
- [x] Clamp position to terminal bounds (state.size)

### 3.7.1.2 Implement hide_cursor/1 Callback
- [x] Write `\e[?25l` sequence to hide cursor
- [x] Keep existing state update (`cursor_visible: false`)

### 3.7.1.3 Implement show_cursor/1 Callback
- [x] Write `\e[?25h` sequence to show cursor
- [x] Keep existing state update (`cursor_visible: true`)

### Unit Tests Added
- [x] Test `move_cursor/2` outputs cursor positioning sequence
- [x] Test `move_cursor/2` updates cursor_position in state
- [x] Test `move_cursor/2` clamps row to terminal bounds
- [x] Test `move_cursor/2` clamps column to terminal bounds
- [x] Test `move_cursor/2` clamps minimum position to 1,1
- [x] Test `hide_cursor/1` outputs hide cursor sequence
- [x] Test `show_cursor/1` outputs show cursor sequence

## Files Modified

| File | Changes |
|------|---------|
| `lib/term_ui/backend/tty.ex` | Updated `move_cursor/2`, `hide_cursor/1`, `show_cursor/1` to write ANSI sequences |
| `test/term_ui/backend/tty_test.exs` | Added 7 new tests for cursor operations |

## Success Criteria

- [x] All three cursor callbacks write appropriate ANSI sequences
- [x] State is correctly updated
- [x] Position clamping prevents out-of-bounds cursor positioning
- [x] All 179 TTY tests pass
