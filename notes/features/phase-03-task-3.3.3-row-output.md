# Feature: Phase 3 Task 3.3.3 - Implement Row-by-Row Output

**Branch:** `feature/phase-03-task-3.3.3-row-output`
**Base:** `multi-renderer`
**Date:** 2025-12-06
**Status:** Complete

## Overview

Task 3.3.3 implements efficient row-by-row output for full redraw. Most was already implemented in Task 3.3.2. This task adds style delta tracking to optimize SGR output.

## Tasks

### 3.3.3 Implement Row-by-Row Output

- [x] 3.3.3.1 Group cells by row number (done in 3.3.2)
- [x] 3.3.3.2 Sort rows by row number for sequential output (done in 3.3.2)
- [x] 3.3.3.3 For each row, position cursor at start with `\e[row;1H` (done in 3.3.2)
- [x] 3.3.3.4 Output cells left-to-right, tracking style changes (NEW)
- [x] 3.3.3.5 Fill gaps with spaces if cells are non-contiguous (done in 3.3.2)

## Implementation Details

### Style Delta Tracking

Added `render_cell_with_delta/3` which:
1. Tracks current style (fg, bg, attrs) as a tuple
2. Only outputs SGR sequences when style differs from previous cell
3. Returns new style for tracking

Updated `render_row/3` to:
1. Track both column position AND current style in reduce accumulator
2. Use `render_cell_with_delta/3` instead of `render_cell/2`
3. Still reset attributes at end of each row for clean state

### Benefits

- Reduces redundant SGR escape sequences
- Adjacent cells with same style only output style once
- Less terminal output = faster rendering

### Example

Before (3.3.2):
```
\e[0m\e[31mA\e[0m\e[31mB\e[0m\e[31mC\e[0m
```

After (3.3.3):
```
\e[0m\e[31mABC\e[0m
```

## Files Modified

| File | Type | Description |
|------|------|-------------|
| `lib/term_ui/backend/tty.ex` | Modified | Added style delta tracking |
| `test/term_ui/backend/tty_test.exs` | Modified | Added 7 new tests |
| `notes/planning/multi-renderer/phase-03-tty-backend.md` | Modified | Marked Section 3.3 complete |

## Test Results

```
97 tests, 0 failures
```

Added 7 new tests:
- Consecutive cells with same style only output style once
- Cells with different styles output style for each change
- Style change in attributes triggers new SGR
- Gap filling preserves style tracking
- Outputs cells left-to-right
- Multiple rows maintain correct ordering
- Each row ends with attribute reset
