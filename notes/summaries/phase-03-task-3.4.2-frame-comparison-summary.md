# Summary: Phase 3 Task 3.4.2 - Frame Comparison

**Branch:** `feature/phase-03-task-3.4.2-frame-comparison`
**Date:** 2025-12-06

## Overview

Task 3.4.2 implements the core diffing algorithm for incremental rendering. The `compare_frames/2` function compares current and previous frames to identify which cells need to be updated.

## Changes Made

### New Function: `compare_frames/2`

Added a public function to compare frames and identify changes:

```elixir
@spec compare_frames(
        map(),
        [{TermUI.Backend.position(), TermUI.Backend.cell()}]
      ) :: {[{TermUI.Backend.position(), TermUI.Backend.cell()}], [TermUI.Backend.position()]}
def compare_frames(last_frame, current_cells)
```

**Algorithm:**
1. Convert current cells to position-keyed map for efficient lookup
2. Filter current cells to find new/changed ones:
   - Not in last_frame → new (changed)
   - In last_frame but different → changed
   - Identical to last_frame → skip
3. Filter last_frame positions to find removed ones:
   - Not in current frame → removed

**Returns:**
- `changed` - List of `{position, cell}` tuples to render
- `removed` - List of positions to clear (render space with default style)

### Implementation Details

The function uses Elixir's pattern matching for efficient cell comparison:

```elixir
case Map.get(last_frame, pos) do
  nil -> true           # New cell
  ^cell -> false        # Unchanged (pin operator)
  _different -> true    # Changed
end
```

This catches all types of changes:
- Character changes
- Foreground color changes (named, RGB, palette)
- Background color changes
- Attribute changes (bold, underline, etc.)

## New Tests (+14)

| Test | Description |
|------|-------------|
| empty last frame and empty current | Edge case - no changes |
| new cell is detected | Single new cell |
| multiple new cells | Multiple new cells |
| removed cell is detected | Single removed cell |
| multiple removed cells | Multiple removed cells |
| unchanged cell not in output | Identical cell skipped |
| changed character detected | Character change |
| changed foreground color | FG color change |
| changed background color | BG color change |
| changed attributes | Attribute change |
| added attribute | Attribute addition |
| mixed scenario | Combined new/changed/removed/unchanged |
| position order preserved | Order matches input |
| RGB color change detected | RGB tuple comparison |

## Test Results

```
Before: 120 tests, 0 failures
After: 134 tests, 0 failures (+14 tests)
```

## Files Changed

- `lib/term_ui/backend/tty.ex` - Added compare_frames/2 function (~70 lines)
- `test/term_ui/backend/tty_test.exs` - Added 14 frame comparison tests
- `notes/planning/multi-renderer/phase-03-tty-backend.md` - Marked task complete
- `notes/features/phase-03-task-3.4.2-frame-comparison.md` - Feature plan

## Task Completion Status

- [x] 3.4.2.1 Convert current cells list to position-keyed map
- [x] 3.4.2.2 Compare each position in current frame to last_frame
- [x] 3.4.2.3 Identify changed cells (different content or style)
- [x] 3.4.2.4 Identify removed cells (in last_frame but not current)
- [x] 3.4.2.5 Return list of cells to update

## Integration Point

The `compare_frames/2` function is ready to be integrated into `draw_cells/2` in Task 3.4.3:

```elixir
# In draw_cells/2 when line_mode == :incremental and last_frame != nil
{changed, removed} = compare_frames(state.last_frame, cells)
# Render only changed cells
# Clear removed positions with spaces
```

## Foundation for Next Tasks

This provides the diffing infrastructure needed for:
- **3.4.3** Incremental draw_cells - Use compare_frames to render only changes
- **3.4.4** Cursor movement optimization - Optimize cursor positioning for sparse updates
