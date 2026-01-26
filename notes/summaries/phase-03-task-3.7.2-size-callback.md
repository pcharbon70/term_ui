# Summary: Phase 3 Task 3.7.2 - Size Callback

**Date:** 2025-12-06
**Branch:** `feature/phase-03-task-3.7.2-size-callback`

## What Was Done

1. **Verified existing `size/1` callback** - Already correctly implemented, returns `{:ok, state.size}`

2. **Implemented `refresh_size/1`** - New function that:
   - Queries terminal using `:io.rows/0` and `:io.columns/0`
   - Updates `state.size` with new dimensions
   - Clears `last_frame` to force full redraw (terminal may have changed)
   - Falls back to current size if terminal query fails

3. **Added helper `query_terminal_size/1`** - Private function that safely queries terminal dimensions with fallback

## Changes

### `lib/term_ui/backend/tty.ex`
- Added `refresh_size/1` public function with full documentation
- Added `query_terminal_size/1` private helper

### `test/term_ui/backend/tty_test.exs`
Added 5 new tests:
- `refresh_size/1 returns {:ok, state}`
- `refresh_size/1 clears last_frame to force full redraw`
- `refresh_size/1 preserves state structure`
- `refresh_size/1 queries terminal and updates size`
- `refresh_size/1 falls back to current size if terminal query fails`

## Test Results

All 184 TTY backend tests pass.

## Next Task

According to the Phase 3 plan, the next task is **3.7.3 - Implement flush/1 Callback**:
- Implement `@impl true` `flush/1` returning `{:ok, state}`
- TTY output is synchronous, so flush is largely a no-op
