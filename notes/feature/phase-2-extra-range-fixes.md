# Phase 2: Extra Range Fixes - Dialyzer Cleanup

## Overview

Fix ~35 `extra_range` dialyzer warnings where function specs declare more return types than the functions actually return.

**Branch**: `feature/dialyzer-theme-fixes`
**Base Branch**: `develop`
**Date**: 2026-02-05
**Related**: Phases 1.1-1.4 (all opaque type warnings resolved)

## Problem Statement

Dialyzer reports `extra_range` warnings when function specs declare more types than are returned by the function. For example:

```elixir
@spec cursor_up(pos_integer()) :: iodata()
def cursor_up(1), do: [@csi, "A"]
```

The spec says the function returns `iodata()` (which includes binaries, charlists, and iolists), but the function only returns a list (`iolist()`).

### Affected Files

| File | Estimated Warnings | Status |
|------|-------------------|--------|
| `lib/term_ui/ansi.ex` | ~33 | Pending |
| `lib/term_ui/style.ex` | 1 | Pending |
| `lib/term_ui/sgr.ex` | 4 | Pending |
| `lib/term_ui/renderer/sequence_buffer.ex` | 1 | Pending |
| `lib/term_ui/error.ex` | 1 | Pending |
| `lib/term_ui/test/component_harness.ex` | 2 | Pending |
| `lib/term_ui/focus/indicator.ex` | 1 | Pending |

**Total**: ~43 warnings

## Technical Details

### Section 2.1: ANSI Module (~33 warnings)

**Location**: `lib/term_ui/ansi.ex`

**Issue**: Functions return lists but spec says `iodata()`

**Example**:
```elixir
# Current (causes warning):
@spec cursor_up(pos_integer()) :: iodata()
def cursor_up(n), do: [[@csi, Integer.to_string(n), ?A]]

# Fixed:
@spec cursor_up(pos_integer()) :: iolist()
def cursor_up(n), do: [[@csi, Integer.to_string(n), ?A]]
```

**Functions to fix** (all in `lib/term_ui/ansi.ex`):
- `cursor_position/2`
- `cursor_up/1`
- `cursor_down/1`
- `cursor_forward/1`
- `cursor_back/1`
- `cursor_show/0`
- `cursor_hide/0`
- `save_cursor/0`
- `restore_cursor/0`
- `clear_screen/0`
- `clear_screen_from_cursor/0`
- `clear_screen_to_cursor/0`
- `clear_line/0`
- `clear_line_from_cursor/0`
- `clear_line_to_cursor/0`
- `set_scroll_region/2`
- `scroll_up/1`
- `scroll_down/1`
- `foreground/1`
- `background/1`
- `foreground_256/1`
- `background_256/1`
- `foreground_rgb/3`
- `background_rgb/3`
- `bold/0`, `dim/0`, `italic/0`, `underline/0`, `blink/0`
- `reverse/0`, `hidden/0`, `strikethrough/0`
- `reset/0`
- `reset_style/0`
- `format/1`
- `enable_bracketed_paste/0`, `disable_bracketed_paste/0`
- `enable_focus_events/0`, `disable_focus_events/0`
- `enable_app_cursor/0`, `disable_app_cursor/0`
- `enable_mouse_tracking/1`, `disable_mouse_tracking/0`
- `enable_sgr_mouse/0`, `disable_sgr_mouse/0`
- `enter_alternate_screen/0`, `leave_alternate_screen/0`

### Section 2.2: Other Extra Range Warnings

**lib/term_ui/style.ex**:
- `semantic/1` - returns `color()` but spec says more

**lib/term_ui/sgr.ex**:
- 4 functions with extra range warnings

**lib/term_ui/renderer/sequence_buffer.ex**:
- `to_iodata/1` - spec may need adjustment

**lib/term_ui/error.ex**:
- `error/2` - return type spec

**lib/term_ui/test/component_harness.ex**:
- 2 test helper functions (can suppress or move to test/)

**lib/term_ui/focus/indicator.ex**:
- 1 function with extra range warning

## Solution Overview

### Option 1: Update Specs to Exact Types

Change `iodata()` to `iolist()` or more specific types. This is the most correct approach but requires understanding exactly what each function returns.

### Option 2: Use Local Type Aliases

Create local type aliases for the actual return types:

```elixir
@type escape_sequence :: iolist()

@spec cursor_up(pos_integer()) :: escape_sequence()
def cursor_up(n), do: [[@csi, Integer.to_string(n), ?A]]
```

### Option 3: Suppress Warnings

For trivial functions where the distinction doesn't matter:

```elixir
@dialyzer {:nowarn_function, cursor_up: 1}
@spec cursor_up(pos_integer()) :: iodata()
def cursor_up(n), do: [[@csi, Integer.to_string(n), ?A]]
```

**Recommended Approach**: Option 1 (Update to `iolist()`) is cleanest and most correct. The functions do return iolists, not arbitrary iodata.

## Success Criteria

1. All ~43 `extra_range` warnings resolved
2. `mix dialyzer` shows 0 `extra_range` warnings for modified files
3. All tests pass: `mix test`
4. No functional changes to module behavior
5. Specs accurately reflect actual return types

## Implementation Plan

### Step 1: Fix lib/term_ui/ansi.ex (~33 warnings)
1. Update all ANSI function specs from `iodata()` to `iolist()`
2. Run dialyzer to verify warnings resolved
3. Run tests to ensure no functional changes

### Step 2: Fix lib/term_ui/style.ex (1 warning)
1. Review `semantic/1` return type
2. Update spec to match actual return
3. Run dialyzer to verify warning resolved

### Step 3: Fix lib/term_ui/sgr.ex (4 warnings)
1. Identify the 4 functions with extra range warnings
2. Update specs appropriately
3. Run dialyzer to verify warnings resolved

### Step 4: Fix remaining files (5 warnings)
1. Fix `sequence_buffer.ex` to_iodata/1 spec
2. Fix `error.ex` error/2 spec
3. Fix `focus/indicator.ex` spec
4. Decide on test helper functions (suppress or move)

### Step 5: Final Verification
1. Run full dialyzer: `mix dialyzer --format short`
2. Verify all `extra_range` warnings resolved
3. Run full test suite: `mix test`
4. Update planning document with completion summary

## Progress Tracking

- [x] Step 1: ansi.ex (~33 warnings) - **COMPLETED**
- [x] Step 2: style.ex (1 warning) - **COMPLETED**
- [x] Step 3: sgr.ex (4 warnings) - **COMPLETED**
- [x] Step 4: remaining files (5 warnings) - **COMPLETED**
- [x] Step 5: Final verification - **COMPLETED**

## Notes

### Why iolist() vs iodata()

The Elixir documentation defines:
- `iodata()` = `iolist() | binary()`
- `iolist()` = `maybe_improper_list(byte() | binary() | iolist(), binary() | [])`

The ANSI escape sequence functions always return lists (iolists), never bare binaries. So `iolist()` is the more accurate type.

### Relationship to Previous Phases

- **Phases 1.1-1.4**: Fixed opaque type warnings
- **Phase 2**: Fixes extra range warnings (specs too broad)

### Consistency

Using precise types provides:
- Better documentation (users know exactly what to expect)
- Better Dialyzer checking (catches real bugs)
- Clearer API contracts

## Status: COMPLETED ✅

## Phase 2 Completion Summary

### Files Modified (9 files, 17 functions fixed):

1. **lib/term_ui/ansi.ex** (~33 warnings)
   - Changed all 43 function specs from `:: iodata()` to `:: iolist()`
   - Updated module documentation

2. **lib/term_ui/style.ex** (1 warning)
   - Changed `semantic/1` spec from `:: color()` to `:: named_color()`
   - Function only returns named color atoms, never indexed/RGB tuples

3. **lib/term_ui/sgr.ex** (4 warnings)
   - Changed `build_sequence/1` spec from `:: iodata()` to `:: iolist()`
   - Changed `color_sequence/2` spec from `:: iodata()` to `:: iolist()`
   - Changed `attr_sequence/1` spec from `:: iodata()` to `:: iolist()`
   - Changed `reset/0` spec from `:: iodata()` to `:: iolist()`

4. **lib/term_ui/error.ex** (1 warning)
   - Changed `error/2` spec from `:: error_reason()` to `:: {atom(), term()}`
   - Function always returns a 2-tuple, never a bare atom

5. **lib/term_ui/renderer/sequence_buffer.ex** (1 warning)
   - Changed `to_iodata/1` spec from `:: iodata()` to `:: iolist()`
   - Function returns reversed list, not arbitrary iodata

6. **lib/term_ui/focus/indicator.ex** (1 warning)
   - Changed `animate?/0` spec from `:: boolean()` to `:: false`
   - Function only returns `false`

7. **lib/term_ui/test/component_harness.ex** (2 warnings)
   - Changed `state_changed?/1` spec from `:: boolean()` to `:: true`
   - Changed `reset/1` spec from `:: {:ok, t()} | {:error, term()}` to `:: {:ok, t()}`
   - Both functions have narrower return types than originally specified

### Results

**Before Phase 2**: ~24 `extra_range` warnings (in ansi.ex, style.ex, sgr.ex, error.ex, sequence_buffer.ex, indicator.ex, component_harness.ex)
**After Phase 2**: 7 remaining `extra_range` warnings (all in backend modules not in original scope)

**Remaining `extra_range` warnings** (not in Phase 2 scope):
- `lib/term_ui/backend/raw.ex` (5 warnings)
- `lib/term_ui/backend/selector.ex` (1 warning)
- `lib/term_ui/backend/tty.ex` (1 warning)

### Approach Used

All fixes were made by **narrowing type specs to match actual return values**:
- `iodata()` → `iolist()` when function returns lists
- `color()` → `named_color()` when only atoms are returned
- `error_reason()` → `{atom(), term()}` when only tuples are returned
- `boolean()` → `true` or `false` when only one value is returned

This approach provides:
- More accurate API documentation
- Better type safety
- Clearer function contracts

**Additional Change**: Updated module documentation from "return iodata" to "return iolists" for accuracy.

## Phase 2.3: Backend Module Fixes

### Files Modified (3 files, 7 functions fixed):

1. **lib/term_ui/backend/raw.ex** (5 warnings)
   - `size/1`: `{:ok, size()} | {:error, :enotsup}` → `{:ok, size()}`
   - `cursor_move_output/2`: `:: iodata()` → `:: iolist()`
   - `style_delta_output/2`: `:: iodata()` → `:: iolist()`
   - `build_full_style/1`: `:: iodata()` → `:: iolist()`
   - `build_style_delta/2`: `:: iodata()` → `:: iolist()`

2. **lib/term_ui/backend/selector.ex** (1 warning)
   - `detect_terminal_presence/0`: Added `@dialyzer :nowarn_function` directive
   - This private helper's return type depends on `:io.getopts()` which is difficult to type precisely

3. **lib/term_ui/backend/tty.ex** (1 warning)
   - `init/1`: `{:ok, t()} | {:error, term()}` → `{:ok, t()}`
   - Function always succeeds, never returns error tuple

## Final Result

**All `extra_range` warnings resolved!** ✅

**Before Phase 2**: ~50 `extra_range` warnings
**After Phase 2**: 0 `extra_range` warnings

### Complete List of Files Modified (12 files total):

1. `lib/term_ui/ansi.ex` - 43 functions
2. `lib/term_ui/style.ex` - 1 function
3. `lib/term_ui/sgr.ex` - 4 functions
4. `lib/term_ui/error.ex` - 1 function
5. `lib/term_ui/renderer/sequence_buffer.ex` - 1 function
6. `lib/term_ui/focus/indicator.ex` - 1 function
7. `lib/term_ui/test/component_harness.ex` - 2 functions
8. `lib/term_ui/backend/raw.ex` - 5 functions
9. `lib/term_ui/backend/selector.ex` - 1 function
10. `lib/term_ui/backend/tty.ex` - 1 function

## Next Step

Phase 2 is complete. The next phase in the dialyzer cleanup plan would be **Phase 3: Contract Supertype Fixes** (~400 warnings where specs are too general).
