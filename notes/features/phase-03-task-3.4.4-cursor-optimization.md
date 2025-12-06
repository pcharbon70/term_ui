# Feature: Phase 3 Task 3.4.4 - Cursor Movement Optimization

**Branch:** `feature/phase-03-task-3.4.4-cursor-optimization`
**Base:** `multi-renderer`
**Date:** 2025-12-06
**Status:** In Progress

## Overview

Task 3.4.4 optimizes cursor movement for incremental rendering. Instead of using absolute positioning for every cell, we sort cells by position, track cursor location, and use relative moves or grouping when more efficient.

## Planning Document Requirements

From `notes/planning/multi-renderer/phase-03-tty-backend.md`:

### 3.4.4 Implement Cursor Movement Optimization

- [ ] 3.4.4.1 Sort changed cells by position (row, then col)
- [ ] 3.4.4.2 Track current cursor position
- [ ] 3.4.4.3 Use relative moves when cheaper than absolute positioning
- [ ] 3.4.4.4 Group adjacent cells to minimize cursor operations

## Implementation Design

### Cursor Movement Cost Analysis

| Move Type | Escape Sequence | Length | When Cheaper |
|-----------|-----------------|--------|--------------|
| Absolute | `\e[row;colH` | 6-10 chars | Always works |
| Right 1 | `\e[C` | 3 chars | Same row, next col |
| Right N | `\e[nC` | 4-5 chars | Same row, 2-9 cols right |
| Down 1 | `\e[B` | 3 chars | Next row, same col |
| Down N | `\e[nB` | 4-5 chars | 2-9 rows down |
| Newline | `\n` | 1 char | Next row, col 1 |
| No move | (none) | 0 chars | Cursor already there |

### Optimization Strategy

1. **Sort cells** by position (row-major order)
2. **Group adjacent cells** on same row for batch rendering
3. **Track cursor position** after each operation
4. **Choose cheapest move** based on current vs target position

### Key Insight: Row Grouping

The biggest optimization is grouping adjacent cells on the same row:
- Instead of: `\e[1;1HA\e[1;2HB\e[1;3HC` (27 chars)
- Use: `\e[1;1HABC` (10 chars)

This already exists in `render_rows/2` for full redraw. We can reuse it for incremental mode when multiple changed cells are on the same row.

## Implementation Approach

Rather than complex relative move calculations, focus on the highest-impact optimization: **grouping adjacent changed cells by row**.

1. Sort changed cells by position
2. Group by row
3. For each row, render cells in sequence (reusing row rendering logic)
4. Handle removed cells with simple absolute positioning

## Files to Modify

| File | Type | Description |
|------|------|-------------|
| `lib/term_ui/backend/tty.ex` | Modified | Optimize do_incremental_render |
| `test/term_ui/backend/tty_test.exs` | Modified | Add optimization tests |
| `notes/planning/multi-renderer/phase-03-tty-backend.md` | Modified | Mark task complete |

## Success Criteria

- Changed cells are sorted by position before rendering
- Adjacent cells on same row are rendered together (fewer cursor moves)
- Removed cells are handled efficiently
- All existing tests pass
- New optimization tests pass
