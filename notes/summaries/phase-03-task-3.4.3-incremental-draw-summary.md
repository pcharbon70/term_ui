# Summary: Phase 3 Task 3.4.3 - Incremental draw_cells/2

**Branch:** `feature/phase-03-task-3.4.3-incremental-draw`
**Date:** 2025-12-06

## Overview

Task 3.4.3 integrates the frame comparison algorithm into `draw_cells/2` to enable true incremental rendering. Instead of redrawing all cells every frame, only changed and removed cells are updated.

## Changes Made

### Refactored `draw_cells/2`

Restructured `draw_cells/2` to use pattern matching and delegate to specialized functions:

```elixir
def draw_cells(%__MODULE__{} = state, cells) do
  case state.line_mode do
    :full_redraw ->
      do_full_redraw(cells, state)

    :incremental ->
      if is_nil(state.last_frame) do
        do_full_redraw(cells, state)  # First frame
      else
        do_incremental_render(cells, state)  # Subsequent frames
      end
  end
end
```

### New Function: `do_full_redraw/2`

Extracted full redraw logic into a dedicated function that:
- Clears screen and homes cursor
- Groups cells by row and renders all
- Builds frame map for incremental mode tracking

### New Function: `do_incremental_render/2`

Implements true incremental rendering:

```elixir
defp do_incremental_render(cells, state) do
  # Compare frames to identify changes
  {changed, removed} = compare_frames(state.last_frame, cells)

  # Render only changed cells
  Enum.each(changed, fn {pos, cell} ->
    render_cell_at(pos, cell, state)
  end)

  # Clear removed cells
  Enum.each(removed, fn pos ->
    clear_cell_at(pos)
  end)

  # Update frame tracking
  frame = build_frame_map(cells)
  {:ok, %{state | last_frame: frame, cursor_position: nil}}
end
```

### New Function: `render_cell_at/3`

Renders a single cell at an arbitrary position:
- Positions cursor with `\e[row;colH`
- Applies styled character with SGR sequence
- Resets attributes after each cell

### New Function: `clear_cell_at/1`

Clears a cell at a specific position:
- Positions cursor
- Writes space with reset attributes

## Performance Benefit

Instead of rendering all cells every frame:
- **Full redraw**: O(n) cells rendered every frame
- **Incremental**: O(changed + removed) cells rendered

For a typical UI where most content is static, this dramatically reduces terminal output.

## New Tests (+8)

| Test | Description |
|------|-------------|
| only renders changed cells | Verifies incremental mode renders only changes |
| unchanged cells not re-rendered | Verifies unchanged cells produce no output |
| removed cells cleared with space | Verifies removed positions are cleared |
| new cells are rendered | Verifies added cells are rendered |
| mixed changes in single frame | Complex scenario with add/modify/remove |
| style change triggers re-render | Verifies color/attr changes trigger update |
| last_frame updated after render | Verifies frame state is maintained |
| full_redraw always clears screen | Verifies full_redraw mode unchanged |

## Test Results

```
Before: 134 tests, 0 failures
After: 142 tests, 0 failures (+8 tests)
```

## Files Changed

- `lib/term_ui/backend/tty.ex` - Refactored draw_cells, added helper functions (~75 lines)
- `test/term_ui/backend/tty_test.exs` - 8 new incremental rendering tests
- `notes/planning/multi-renderer/phase-03-tty-backend.md` - Marked task complete
- `notes/features/phase-03-task-3.4.3-incremental-draw.md` - Feature plan

## Task Completion Status

- [x] 3.4.3.1 If `line_mode == :incremental` and `last_frame` exists, compute diff
- [x] 3.4.3.2 For each changed cell, position cursor and write cell
- [x] 3.4.3.3 For removed cells, position cursor and write space with default style
- [x] 3.4.3.4 Update `last_frame` with current frame
- [x] 3.4.3.5 If no last_frame, delegate to full_redraw logic

## Foundation for Next Task

The incremental rendering is now functional. Task 3.4.4 (Cursor Movement Optimization) can further improve performance by:
- Sorting changed cells by position
- Using relative cursor moves when cheaper than absolute
- Grouping adjacent cells to minimize cursor operations
