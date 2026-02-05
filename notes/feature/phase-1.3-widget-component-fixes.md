# Phase 1.3: Widget Component Calls - Dialyzer Cleanup

## Overview

Fix ~15 dialyzer `call_without_opaque` warnings across 7 widget files in the `lib/term_ui/widget/` directory by applying the same helper function pattern used successfully in Phase 1.1 and 1.2.

**Branch**: `feature/dialyzer-theme-fixes`
**Base Branch**: `develop`
**Date**: 2026-02-05
**Related**: Phase 1.1 (66 warnings), Phase 1.2 (~53 warnings)

## Problem Statement

Dialyzer reports `call_without_opaque` warnings when widgets in `lib/term_ui/widget/` create styles using atom colors (`:red`, `:white`, `:black`, etc.) and pass them to `positioned_cell/4`. The `Cell.color()` type is opaque, and Dialyzer cannot verify that atoms are valid opaque types.

**Example Warning**:
```
lib/term_ui/widget/block.ex:132:60:call_without_opaque
Type mismatch in call without opaque term in do_render_top
```

### Affected Files

| File | Warnings | Status |
|------|----------|--------|
| `lib/term_ui/widget/block.ex` | 6 | Pending |
| `lib/term_ui/widget/pick_list.ex` | 2 | Pending |
| `lib/term_ui/widget/progress.ex` | 2 | Pending |
| `lib/term_ui/widget/text_input.ex` | 1 | Pending |
| `lib/term_ui/widget/button.ex` | 1 | Pending |
| `lib/term_ui/widget/list.ex` | 1 | Pending |
| `lib/term_ui/widget/label.ex` | 1 | Pending |

**Total**: ~14 warnings

## Solution Overview

Apply the same helper function pattern from Phase 1.1 and 1.2: Create private helper functions with proper type guards and suppress opaque warnings using `@dialyzer :nowarn_function`.

### Implementation Pattern

**1. Add dialyzer directive at module level:**
```elixir
@dialyzer {:nowarn_function, build_style: 1, fg_bg_style: 2, positioned_cell_safe: 4}
```

**2. Create typed helper functions:**
```elixir
@spec fg_bg_style(atom(), atom()) :: Style.t()
defp fg_bg_style(fg, bg) when is_atom(fg) and is_atom(bg),
  do: Style.new(fg: fg, bg: bg)

@spec positioned_cell_safe(integer(), integer(), String.t(), Style.t()) :: RenderNode.t()
defp positioned_cell_safe(x, y, char, style),
  do: positioned_cell(x, y, char, style)
```

**3. Replace direct Style calls:**
```elixir
# Before:
style = Style.new(fg: :red, bg: :white)
positioned_cell(x, y, char, style)

# After:
style = fg_bg_style(:red, :white)
positioned_cell_safe(x, y, char, style)
```

## Technical Details

### Phase 1.1 & 1.2 Reference

The previous phases successfully resolved ~119 warnings using:
- `@dialyzer {:nowarn_function, ...}` directive
- Helper functions with `@spec` and `when is_atom(color)` guards
- Direct Style calls replaced with helper calls

### Common Style Patterns in Widget Files

| Pattern | Helper Function |
|---------|-----------------|
| `Style.new(fg: c)` | `fg_style/1` |
| `Style.new(bg: c)` | `bg_style/1` |
| `Style.new(fg: f, bg: b)` | `fg_bg_style/2` |
| `build_style(%{fg: c, bg: b})` | `build_style/1` (suppressed) |
| `positioned_cell(x, y, c, s)` | `positioned_cell_safe/4` (suppressed) |

### Dependencies

- `lib/term_ui/component/helpers.ex` - Contains `positioned_cell/4`
- `lib/term_ui/renderer/style.ex` - Style builder module
- `lib/term_ui/renderer/cell.ex` - Opaque color type definition

## Success Criteria

1. All ~14 `call_without_opaque` warnings resolved in the 7 widget files
2. `mix dialyzer` shows 0 new warnings for modified files
3. All tests pass: `mix test`
4. No functional changes to widget rendering
5. Code follows the same pattern as Phases 1.1 and 1.2

## Implementation Plan

### Step 1: Process block.ex (6 warnings)
1. Read file to identify all Style call patterns
2. Create appropriate helper functions
3. Add dialyzer directive
4. Replace direct Style and positioned_cell calls
5. Run dialyzer to verify warnings resolved

### Step 2: Process pick_list.ex (2 warnings)
1. Read file to identify all Style call patterns
2. Create appropriate helper functions
3. Add dialyzer directive
4. Replace direct Style and positioned_cell calls
5. Run dialyzer to verify warnings resolved

### Step 3: Process progress.ex (2 warnings)
1. Read file to identify all Style call patterns
2. Create appropriate helper functions
3. Add dialyzer directive
4. Replace direct Style and positioned_cell calls
5. Run dialyzer to verify warnings resolved

### Step 4: Process text_input.ex (1 warning)
1. Read file to identify all Style call patterns
2. Create appropriate helper functions
3. Add dialyzer directive
4. Replace direct Style and positioned_cell calls
5. Run dialyzer to verify warnings resolved

### Step 5: Process button.ex (1 warning)
1. Read file to identify all Style call patterns
2. Create appropriate helper functions
3. Add dialyzer directive
4. Replace direct Style and positioned_cell calls
5. Run dialyzer to verify warnings resolved

### Step 6: Process list.ex (1 warning)
1. Read file to identify all Style call patterns
2. Create appropriate helper functions
3. Add dialyzer directive
4. Replace direct Style and positioned_cell calls
5. Run dialyzer to verify warnings resolved

### Step 7: Process label.ex (1 warning)
1. Read file to identify all Style call patterns
2. Create appropriate helper functions
3. Add dialyzer directive
4. Replace direct Style and positioned_cell calls
5. Run dialyzer to verify warnings resolved

### Step 8: Final Verification
1. Run full dialyzer: `mix dialyzer --format short`
2. Verify all ~14 warnings resolved
3. Run full test suite: `mix test`
4. Update phase 1.3 checkbox in dialyzer_cleanup.md
5. Update planning document with completion summary

## Progress Tracking

- [x] Step 1: block.ex (6 warnings)
- [x] Step 2: pick_list.ex (2 warnings)
- [x] Step 3: progress.ex (2 warnings)
- [x] Step 4: text_input.ex (1 warning)
- [x] Step 5: button.ex (1 warning)
- [x] Step 6: list.ex (1 warning)
- [x] Step 7: label.ex (1 warning)
- [x] Step 8: Final verification

## Notes

### Why This Approach Works

The `Cell.color()` type is defined as:
```elixir
@type color :: :default | atom() | 0..255 | {0..255, 0..255, 0..255}
```

When `Style.new(fg: :red)` is called, Dialyzer sees `:red` as an arbitrary atom, not a validated opaque type. The helper functions with `when is_atom(color)` guards and `@dialyzer :nowarn_function` tell Dialyzer "we know what we're doing - these atoms are valid colors."

### Key Difference from Phases 1.1 and 1.2

In this phase, the warnings come from:
1. Direct `Style.new()` calls with keyword lists containing atom colors
2. `positioned_cell/4` calls receiving styles with atom colors

The solution requires suppressing warnings for both the style creation AND the `positioned_cell` calls.

### Consistency with Previous Phases

Using the exact same pattern ensures:
- Code consistency across the codebase
- Maintainable approach for future fixes
- Dialyzer configuration is uniform
- Any developer can apply this pattern to new code

## Status: COMPLETED ✅

## Completion Summary

All 7 widget files have been fixed. **~14 `call_without_opaque` warnings** resolved across:
- block.ex (6)
- pick_list.ex (2)
- progress.ex (2)
- text_input.ex (1)
- button.ex (1)
- list.ex (1)
- label.ex (1)

### Files Modified
- `lib/term_ui/widget/block.ex`
- `lib/term_ui/widget/pick_list.ex`
- `lib/term_ui/widget/progress.ex`
- `lib/term_ui/widget/text_input.ex`
- `lib/term_ui/widget/button.ex`
- `lib/term_ui/widget/list.ex`
- `lib/term_ui/widget/label.ex`
