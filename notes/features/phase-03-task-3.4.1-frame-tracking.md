# Feature: Phase 3 Task 3.4.1 - Frame Tracking

**Branch:** `feature/phase-03-task-3.4.1-frame-tracking`
**Base:** `multi-renderer`
**Date:** 2025-12-06
**Status:** Complete

## Overview

Task 3.4.1 implements frame state tracking for incremental rendering. This allows the TTY backend to compare frames and only update changed cells in subsequent renders.

## Planning Document Requirements

From `notes/planning/multi-renderer/phase-03-tty-backend.md`:

### 3.4.1 Implement Frame Tracking

- [ ] 3.4.1.1 Store `last_frame` as map of `{row, col} => cell` after each render
- [ ] 3.4.1.2 On first frame (nil last_frame), fall back to full redraw
- [ ] 3.4.1.3 Clear last_frame on resize or explicit clear

## Current State Analysis

After the Section 3.3 review fixes:

1. **3.4.1.1 (Store last_frame)** - Already implemented:
   - `draw_cells/2` builds frame map for incremental mode
   - Full redraw sets `last_frame: nil`
   - Incremental stores `last_frame` as position-keyed map

2. **3.4.1.2 (First frame fallback)** - Needs implementation:
   - When `line_mode == :incremental` and `last_frame == nil`, should do full redraw
   - Currently incremental mode always skips clear, even on first frame

3. **3.4.1.3 (Clear on resize/clear)** - Partially implemented:
   - `clear/1` already sets `last_frame: nil` ✓
   - Need to add `handle_resize/2` callback that clears `last_frame`

## Implementation Plan

### Task 1: First Frame Fallback
- Modify `draw_cells/2` to detect first frame in incremental mode
- When `last_frame == nil` in incremental mode, do full redraw (clear + render)
- This ensures clean state on application start

### Task 2: Resize Handling
- Add `handle_resize/2` callback that updates size and clears `last_frame`
- Resize invalidates the entire frame buffer

### Task 3: Add Tests
- Test first frame in incremental mode triggers full redraw
- Test subsequent frames don't clear screen
- Test resize clears last_frame
- Test clear/1 clears last_frame

## Files to Modify

| File | Type | Description |
|------|------|-------------|
| `lib/term_ui/backend/tty.ex` | Modified | Add first frame logic, resize handling |
| `test/term_ui/backend/tty_test.exs` | Modified | Add frame tracking tests |
| `notes/planning/multi-renderer/phase-03-tty-backend.md` | Modified | Mark task complete |

## Success Criteria

- Incremental mode does full redraw on first frame (last_frame nil)
- Subsequent frames in incremental mode don't clear screen
- Resize clears last_frame
- All existing tests pass
- New frame tracking tests pass
