# Feature: Phase 3 Task 3.4.3 - Incremental draw_cells/2

**Branch:** `feature/phase-03-task-3.4.3-incremental-draw`
**Base:** `multi-renderer`
**Date:** 2025-12-06
**Status:** Complete

## Overview

Task 3.4.3 integrates the frame comparison algorithm into `draw_cells/2` to enable true incremental rendering. Instead of rendering all cells every frame, only changed and removed cells are updated.

## Planning Document Requirements

From `notes/planning/multi-renderer/phase-03-tty-backend.md`:

### 3.4.3 Implement draw_cells/2 for Incremental Mode

- [ ] 3.4.3.1 If `line_mode == :incremental` and `last_frame` exists, compute diff
- [ ] 3.4.3.2 For each changed cell, position cursor and write cell
- [ ] 3.4.3.3 For removed cells, position cursor and write space with default style
- [ ] 3.4.3.4 Update `last_frame` with current frame
- [ ] 3.4.3.5 If no last_frame, delegate to full_redraw logic

## Implementation Design

### Modified `draw_cells/2` Flow

```
draw_cells(state, cells)
  │
  ├─ line_mode == :full_redraw?
  │   └─ Yes → do_full_redraw(cells, state)
  │
  └─ line_mode == :incremental
      │
      ├─ last_frame == nil?
      │   └─ Yes → do_full_redraw(cells, state) [first frame]
      │
      └─ last_frame exists
          └─ do_incremental_render(cells, state)
              ├─ compare_frames(last_frame, cells)
              ├─ render changed cells (cursor + styled char)
              ├─ clear removed positions (cursor + space)
              └─ update last_frame
```

### New Function: `render_cell_at/3`

For incremental mode, we need to render individual cells at arbitrary positions:

```elixir
defp render_cell_at({row, col}, {char, fg, bg, attrs}, state) do
  # Position cursor
  cursor = "\e[#{row};#{col}H"
  # Build styled character
  sgr = build_sgr_sequence(fg, bg, attrs, state.color_mode)
  mapped_char = map_character(char, state.character_set)
  sanitized_char = sanitize_char(mapped_char)
  # Write
  safe_write([cursor, sgr, sanitized_char, @reset_attrs])
end
```

### New Function: `clear_cell_at/2`

For clearing removed cells:

```elixir
defp clear_cell_at({row, col}, state) do
  cursor = "\e[#{row};#{col}H"
  safe_write([cursor, @reset_attrs, " "])
end
```

## Files to Modify

| File | Type | Description |
|------|------|-------------|
| `lib/term_ui/backend/tty.ex` | Modified | Refactor draw_cells/2 for incremental mode |
| `test/term_ui/backend/tty_test.exs` | Modified | Add incremental rendering tests |
| `notes/planning/multi-renderer/phase-03-tty-backend.md` | Modified | Mark task complete |

## Success Criteria

- Incremental mode only renders changed cells (not full screen)
- Removed cells are cleared with spaces
- First frame still does full redraw
- Full redraw mode unchanged
- All existing tests pass
- New incremental rendering tests pass
