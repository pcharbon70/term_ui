# Feature: Phase 3 Task 3.8.1 - Full Redraw Lifecycle Tests

**Branch:** `feature/phase-03-task-3.8.1-full-redraw-tests`
**Base:** `multi-renderer`
**Date:** 2025-12-06
**Status:** Complete

## Overview

Implement integration tests for the TTY backend's full redraw lifecycle. These tests verify the complete backend workflow works correctly in realistic scenarios.

## Implementation Plan

### 3.8.1.1 Test init → draw_cells → shutdown sequence
- [x] Create test that initializes backend with full_redraw mode
- [x] Draw cells to the terminal
- [x] Shutdown and verify cleanup sequences
- [x] Verify output contains expected ANSI sequences

### 3.8.1.2 Test multiple frames render correctly
- [x] Initialize backend
- [x] Render first frame with set of cells
- [x] Render second frame with different cells
- [x] Verify both frames produce clear + render sequences
- [x] Verify state is properly maintained between frames

### 3.8.1.3 Test style changes between frames
- [x] Initialize backend
- [x] Render frame with specific colors/attributes
- [x] Render second frame with different colors/attributes
- [x] Verify SGR sequences change appropriately
- [x] Test various style combinations (colors, bold, underline, etc.)

## Test Location

Tests added to: `test/term_ui/backend/tty_test.exs`

In describe block: `describe "integration - full redraw lifecycle (Section 3.8.1)"`

## Tests Added (12 total)

1. `init -> draw_cells -> shutdown sequence works correctly`
2. `init -> draw_cells -> shutdown with alternate screen`
3. `multiple frames render correctly in full_redraw mode`
4. `state is properly maintained between frames`
5. `style changes between frames render different SGR sequences`
6. `style changes with RGB colors in true_color mode`
7. `style changes with multiple attributes`
8. `combined color and attribute changes between frames`
9. `each row ends with attribute reset`
10. `cursor position is updated after draw_cells`
11. `full lifecycle with clear operation`
12. `full lifecycle maintains correct line_mode throughout`

## Success Criteria

- [x] All integration tests pass
- [x] Tests verify complete lifecycle
- [x] Tests verify multiple frame rendering
- [x] Tests verify style changes between frames
- [x] Total TTY backend tests: 212 (was 200, added 12)

## Files Modified

| File | Changes |
|------|---------|
| `test/term_ui/backend/tty_test.exs` | Add 12 integration tests for full redraw lifecycle |
| `notes/planning/multi-renderer/phase-03-tty-backend.md` | Mark task 3.8.1 complete |
