# Feature: Phase 3 Task 3.4.2 - Frame Comparison

**Branch:** `feature/phase-03-task-3.4.2-frame-comparison`
**Base:** `multi-renderer`
**Date:** 2025-12-06
**Status:** Complete

## Overview

Task 3.4.2 implements comparison between current and previous frames to identify which cells need to be updated. This is the core diffing algorithm for incremental rendering.

## Planning Document Requirements

From `notes/planning/multi-renderer/phase-03-tty-backend.md`:

### 3.4.2 Implement Frame Comparison

- [ ] 3.4.2.1 Convert current cells list to position-keyed map
- [ ] 3.4.2.2 Compare each position in current frame to last_frame
- [ ] 3.4.2.3 Identify changed cells (different content or style)
- [ ] 3.4.2.4 Identify removed cells (in last_frame but not current)
- [ ] 3.4.2.5 Return list of cells to update

## Implementation Design

### Function: `compare_frames/2`

```elixir
@spec compare_frames(map(), [{position(), cell()}]) ::
  {changed :: [{position(), cell()}], removed :: [position()]}
```

**Parameters:**
- `last_frame` - Previous frame as position-keyed map
- `current_cells` - Current frame as list of `{position, cell}` tuples

**Returns:**
- `changed` - Cells that are new or different from last frame
- `removed` - Positions that were in last frame but not in current

### Algorithm

1. Convert current cells to position-keyed map (3.4.2.1)
2. For each position in current frame:
   - If not in last_frame → changed (new cell)
   - If in last_frame but different → changed
   - If identical → skip (no update needed)
3. For each position in last_frame:
   - If not in current frame → removed

### Integration Point

The `compare_frames/2` function will be called from `draw_cells/2` when:
- `line_mode == :incremental`
- `last_frame != nil`

This will be integrated in Task 3.4.3.

## Files to Modify

| File | Type | Description |
|------|------|-------------|
| `lib/term_ui/backend/tty.ex` | Modified | Add compare_frames/2 function |
| `test/term_ui/backend/tty_test.exs` | Modified | Add frame comparison tests |
| `notes/planning/multi-renderer/phase-03-tty-backend.md` | Modified | Mark task complete |

## Success Criteria

- compare_frames/2 correctly identifies changed cells
- compare_frames/2 correctly identifies removed cells
- compare_frames/2 correctly identifies unchanged cells (not in output)
- All existing tests pass
- New frame comparison tests pass
