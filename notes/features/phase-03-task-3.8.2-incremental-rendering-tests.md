# Feature: Phase 3 Task 3.8.2 - Incremental Rendering Tests

**Branch:** `feature/phase-03-task-3.8.2-incremental-rendering-tests`
**Base:** `multi-renderer`
**Date:** 2025-12-06
**Status:** Complete

## Overview

Implement integration tests for incremental rendering mode functionality. These tests verify that the TTY backend correctly handles:
1. First frame fallback to full redraw (when last_frame is nil)
2. Subsequent frames only updating changed cells
3. Resize operations triggering full redraw

## Implementation Plan

### 3.8.2.1 Test first frame falls back to full redraw
- [x] Test that incremental mode with nil last_frame does full redraw
- [x] Verify clear screen sequence (`\e[2J`) is output
- [x] Verify last_frame is populated after first frame
- [x] Test state transitions correctly from nil to populated frame

### 3.8.2.2 Test subsequent frames only update changes
- [x] Test unchanged cells are not re-rendered
- [x] Test changed cells are rendered with cursor positioning
- [x] Test new cells are added correctly
- [x] Test removed cells are cleared (space written at position)
- [x] Verify no clear screen sequence on incremental updates

### 3.8.2.3 Test resize triggers full redraw
- [x] Test set_size/2 clears last_frame
- [x] Test refresh_size/1 clears last_frame
- [x] Test next draw_cells after set_size does full redraw
- [x] Verify clear screen sequence after resize

## Tests Added (16 total)

### 3.8.2.1 - First frame fallback (4 tests)
1. `first frame in incremental mode triggers full redraw`
2. `first frame in incremental mode populates last_frame`
3. `first frame with nil last_frame outputs clear screen and content`
4. `state transitions from nil to populated last_frame correctly`

### 3.8.2.2 - Subsequent frames (8 tests)
5. `subsequent frames do not clear screen`
6. `unchanged cells are not re-rendered in subsequent frames`
7. `changed cells are rendered with cursor positioning`
8. `new cells are added in subsequent frames`
9. `removed cells are cleared in subsequent frames`
10. `multiple changed cells render efficiently in batches`
11. `style changes trigger cell update`

### 3.8.2.3 - Resize triggers full redraw (5 tests)
12. `set_size/2 clears last_frame`
13. `refresh_size/1 clears last_frame`
14. `draw_cells after set_size triggers full redraw`
15. `clear/1 also clears last_frame for incremental mode`
16. `full resize cycle: populate -> set_size -> redraw`

## Test Location

Tests added to: `test/term_ui/backend/tty_test.exs`

In describe block: `describe "integration - incremental rendering (Section 3.8.2)"`

## Success Criteria

- [x] All integration tests pass
- [x] Tests verify first frame triggers full redraw
- [x] Tests verify subsequent frames only update changes
- [x] Tests verify resize triggers full redraw
- [x] Tests verify state tracking (last_frame population and clearing)
- [x] Total TTY backend tests: 228 (was 212, added 16)

## Files Modified

| File | Changes |
|------|---------|
| `test/term_ui/backend/tty_test.exs` | Add 16 integration tests for incremental rendering |
| `notes/planning/multi-renderer/phase-03-tty-backend.md` | Mark task 3.8.2 complete |
