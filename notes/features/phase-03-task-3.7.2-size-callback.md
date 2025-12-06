# Feature: Phase 3 Task 3.7.2 - Size Callback

**Branch:** `feature/phase-03-task-3.7.2-size-callback`
**Base:** `multi-renderer`
**Date:** 2025-12-06
**Status:** Complete

## Overview

Verify and complete the size/1 callback implementation and add refresh_size/1 for dynamic terminal size queries.

## Implementation Summary

### 3.7.2.1 Verify size/1 Callback
- [x] `size/1` already implemented correctly
- [x] Returns `{:ok, {rows, cols}}`
- [x] Tests exist and pass

### 3.7.2.2 Size Determined at Init
- [x] Already implemented in `determine_size/2`
- [x] Tests verify size from capabilities and explicit options

### 3.7.2.3 Implement refresh_size/1
- [x] Query terminal using `:io.rows/0` and `:io.columns/0`
- [x] Update state.size with new dimensions
- [x] Clear last_frame to force full redraw
- [x] Return `{:ok, updated_state}`
- [x] Handle errors gracefully (keep current size if query fails)

## Files Modified

| File | Changes |
|------|---------|
| `lib/term_ui/backend/tty.ex` | Added `refresh_size/1` and `query_terminal_size/1` |
| `test/term_ui/backend/tty_test.exs` | Added 5 new tests for `refresh_size/1` |

## Success Criteria

- [x] `size/1` returns current size
- [x] `refresh_size/1` queries terminal and updates state
- [x] Graceful fallback when terminal query fails
- [x] All 184 tests pass
