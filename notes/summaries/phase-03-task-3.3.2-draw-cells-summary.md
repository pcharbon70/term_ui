# Summary: Phase 3 Task 3.3.2 - Implement draw_cells/2 for Full Redraw Mode

**Branch:** `feature/phase-03-task-3.3.2-draw-cells`
**Date:** 2025-12-06

## Changes Made

This commit implements the core cell rendering functionality for the TTY backend, including color degradation across all color modes.

### Main Implementation

Updated `draw_cells/2` to:
1. Clear screen in full_redraw mode (`\e[2J\e[H`)
2. Group cells by row and sort by column
3. Position cursor at each row start (`\e[row;1H`)
4. Render styled cells with proper SGR sequences
5. Fill gaps with spaces for non-contiguous cells
6. Reset attributes at end of each row
7. Build frame map for incremental mode tracking

### Helper Functions Added (13 functions)

**Cell Rendering:**
- `group_cells_by_row/1` - Groups and sorts cells
- `render_rows/2` - Renders all rows
- `render_row/3` - Renders single row with gap filling
- `render_cell/2` - Renders single cell with style

**SGR (Style) Generation:**
- `build_sgr_sequence/4` - Builds complete SGR sequence
- `attr_to_sgr/1` - Converts attribute atoms (bold, underline, etc.)
- `color_to_sgr/3` - Converts colors based on color mode
- `named_color_to_sgr/2` - Handles named colors (32 color variants)

**Color Degradation:**
- `rgb_to_256/3` - RGB to 256-color palette (6x6x6 cube + grayscale)
- `rgb_to_16_fg/3` - RGB to 16-color foreground
- `rgb_to_16_bg/3` - RGB to 16-color background
- `rgb_to_16_base/3` - Base 16-color calculation

**Utilities:**
- `map_character/2` - Character set mapping (placeholder)
- `build_frame_map/1` - Builds frame map for incremental mode

### Tests Added (18 tests)

**draw_cells/2 Tests:**
- Full redraw mode clear screen
- Incremental mode no clear
- Cursor positioning
- Cell character output
- Row ordering
- Named foreground/background colors
- RGB colors in true_color mode
- Bold/underline attributes
- Attribute reset
- last_frame update
- Empty cells handling
- Return value verification

**Color Degradation Tests:**
- 256-color mode RGB conversion
- 16-color mode RGB conversion
- Monochrome mode color omission

## Test Results

```
90 tests, 0 failures
```

## Files Changed

- `lib/term_ui/backend/tty.ex` - Core implementation (~250 new lines)
- `test/term_ui/backend/tty_test.exs` - 18 new tests
- `notes/planning/multi-renderer/phase-03-tty-backend.md` - Marked complete
- `notes/features/phase-03-task-3.3.2-draw-cells.md` - Feature plan
