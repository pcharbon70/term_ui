# Feature: Phase 3 Task 3.3.2 - Implement draw_cells/2 for Full Redraw Mode

**Branch:** `feature/phase-03-task-3.3.2-draw-cells`
**Base:** `multi-renderer`
**Date:** 2025-12-06
**Status:** Complete

## Overview

Task 3.3.2 implements the `draw_cells/2` callback for the TTY backend in full redraw mode. This is the core rendering function that outputs styled cells to the terminal.

## Cell Format

From `TermUI.Backend`:
```elixir
@type cell :: {char :: String.t(), fg :: color(), bg :: color(), attrs :: [atom()]}
@type position :: {row :: pos_integer(), col :: pos_integer()}
```

## Tasks

### 3.3.2 Implement draw_cells/2 for Full Redraw Mode

- [x] 3.3.2.1 Implement `@impl true` `draw_cells/2` accepting state and cells list
- [x] 3.3.2.2 If `line_mode == :full_redraw`, start with screen clear
- [x] 3.3.2.3 Build frame buffer from cells list, organized by row
- [x] 3.3.2.4 For each row, position cursor and write styled cell content
- [x] 3.3.2.5 Apply color degradation based on `color_mode`
- [x] 3.3.2.6 Use character set mapping for box-drawing characters
- [x] 3.3.2.7 Return `{:ok, updated_state}`

## Implementation Details

### Main Function
- `draw_cells/2`: Clears screen in full_redraw mode, groups cells by row, renders each row

### Helper Functions Added
- `group_cells_by_row/1`: Groups and sorts cells by row, then column
- `render_rows/2`: Iterates over rows and renders each
- `render_row/3`: Positions cursor, fills gaps, renders cells, resets attributes
- `render_cell/2`: Builds SGR sequence and outputs character
- `build_sgr_sequence/4`: Constructs SGR sequence from colors and attributes
- `attr_to_sgr/1`: Converts attribute atoms to SGR sequences
- `color_to_sgr/3`: Converts colors to SGR based on color_mode
- `named_color_to_sgr/2`: Handles named colors (red, blue, etc.)
- `rgb_to_256/3`: Converts RGB to 256-color palette index
- `rgb_to_16_fg/3`, `rgb_to_16_bg/3`: Convert RGB to 16-color codes
- `map_character/2`: Character set mapping (placeholder for Section 3.6)
- `build_frame_map/1`: Builds frame map for incremental mode tracking

### Color Degradation
- True color: Direct RGB output (`\e[38;2;r;g;bm`)
- 256 color: 6x6x6 color cube + grayscale (`\e[38;5;nm`)
- 16 color: Basic ANSI colors (30-37, 90-97)
- Monochrome: Colors omitted, attributes preserved

## Files Modified

| File | Type | Description |
|------|------|-------------|
| `lib/term_ui/backend/tty.ex` | Modified | Implemented draw_cells/2 with all helpers |
| `test/term_ui/backend/tty_test.exs` | Modified | Added 18 new tests |
| `notes/planning/multi-renderer/phase-03-tty-backend.md` | Modified | Marked task 3.3.2 complete |

## Test Results

```
90 tests, 0 failures
```

Added 18 new tests:
- Full redraw mode clear screen output
- Incremental mode no clear screen
- Cursor positioning
- Cell character output
- Row ordering
- Named foreground/background colors
- RGB colors in true_color mode
- Bold and underline attributes
- Attribute reset at end of row
- last_frame state update
- Empty cells list handling
- Color degradation (256-color, 16-color, monochrome)
