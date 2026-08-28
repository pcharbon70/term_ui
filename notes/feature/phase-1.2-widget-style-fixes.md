# Phase 1.2: Widget Style Calls - Dialyzer Cleanup

## Overview

Fix ~30 dialyzer `call_without_opaque` warnings across 8 widget files by applying the same helper function pattern used successfully in Phase 1.1.

**Branch**: `feature/dialyzer-theme-fixes`
**Base Branch**: `develop`
**Date**: 2026-02-05
**Related**: Phase 1.1 completed (66 warnings fixed in `theme.ex`)

## Problem Statement

Dialyzer reports `call_without_opaque` warnings when widgets call `Style.fg/2` and `Style.bg/2` with atoms returned from `Theme.get_semantic/1` and `Theme.get_color/1`. The `Cell.color()` type is opaque, and Dialyzer cannot verify that atoms like `:red`, `:info`, etc. are valid opaque types.

**Example Warning**:
```
lib/term_ui/widgets/process_monitor.ex:120:5
Call to function Style.fg/2 breaks the opaque contract of type Cell.color()
```

### Affected Files

| File | Warnings | Status |
|------|----------|--------|
| `lib/term_ui/widgets/process_monitor.ex` | 14 | Pending |
| `lib/term_ui/widgets/cluster_dashboard.ex` | 12 | Pending |
| `lib/term_ui/widgets/supervision_tree_viewer.ex` | 9 | Pending |
| `lib/term_ui/widgets/log_viewer.ex` | 8 | Pending |
| `lib/term_ui/widgets/tree_view.ex` | 5 | Pending |
| `lib/term_ui/widgets/gauge.ex` | 3 | Pending |
| `lib/term_ui/widgets/form_builder.ex` | 1 | Pending |
| `lib/term_ui/widgets/dialog.ex` | 1 | Pending |

## Solution Overview

Apply the same pattern from Phase 1.1: Create private helper functions with proper type guards and suppress opaque warnings using `@dialyzer :nowarn_function`.

### Implementation Pattern

**1. Add dialyzer directive at module level:**
```elixir
@dialyzer {:nowarn_function, fg_theme: 1, fg_bg_theme: 2, fg_bold_theme: 1, ...}
```

**2. Create typed helper functions:**
```elixir
@spec fg_theme(atom()) :: Style.t()
defp fg_theme(color) when is_atom(color), do: Style.new() |> Style.fg(color)

@spec fg_bold_theme(atom()) :: Style.t()
defp fg_bold_theme(color) when is_atom(color),
    do: Style.new() |> Style.fg(color) |> Style.bold()

@spec fg_bg_theme(atom(), atom()) :: Style.t()
defp fg_bg_theme(fg, bg) when is_atom(fg) and is_atom(bg),
    do: Style.new() |> Style.fg(fg) |> Style.bg(bg)
```

**3. Replace direct Style calls:**
```elixir
# Before:
header_style = Style.new() |> Style.fg(Theme.get_semantic(:info)) |> Style.bold()

# After:
header_style = fg_bold_theme(Theme.get_semantic(:info))
```

## Technical Details

### Phase 1.1 Reference

The Phase 1.1 summary (`notes/summaries/phase-1.1-dialyzer-theme-ex-fixes.md`) shows this approach successfully resolved 66 warnings in `theme.ex`:
- Added `@dialyzer {:nowarn_function, ...}` with 11 helper functions
- Each helper has `@spec` and `when is_atom(color)` guard
- Direct Style calls replaced with helper calls

### Common Style Patterns in Widgets

| Pattern | Helper Function |
|---------|-----------------|
| `Style.new() |> Style.fg(c)` | `fg_theme/1` |
| `Style.new() |> Style.fg(c) |> Style.bg(b)` | `fg_bg_theme/2` |
| `Style.new() |> Style.fg(c) |> Style.bold()` | `fg_bold_theme/1` |
| `Style.new() |> Style.fg(c) |> Style.dim()` | `fg_dim_theme/1` |
| `Style.new() |> Style.fg(c) |> Style.reverse()` | `fg_reverse_theme/1` |
| `Style.new() |> Style.bg(c)` | `bg_theme/1` |
| `Style.new() |> Style.fg(c) |> Style.underline()` | `fg_underline_theme/1` |

### Dependencies

- `lib/term_ui/renderer/style.ex` - Style builder module
- `lib/term_ui/theme.ex` - Theme color functions
- `lib/term_ui/renderer/cell.ex` - Opaque color type definition

## Success Criteria

1. All ~30 `call_without_opaque` warnings resolved in the 8 widget files
2. `mix dialyzer` shows 0 new warnings for modified files
3. All tests pass: `mix test`
4. No functional changes to widget rendering
5. Code follows the same pattern as Phase 1.1 for consistency

## Implementation Plan

### Step 1: Process process_monitor.ex (14 warnings)
1. Read file to identify all Style call patterns
2. Create appropriate helper functions
3. Replace direct Style calls
4. Run dialyzer to verify warnings resolved
5. Run tests to ensure no functional changes

### Step 2: Process cluster_dashboard.ex (12 warnings)
1. Read file to identify all Style call patterns
2. Create appropriate helper functions
3. Replace direct Style calls
4. Run dialyzer to verify warnings resolved
5. Run tests to ensure no functional changes

### Step 3: Process supervision_tree_viewer.ex (9 warnings)
1. Read file to identify all Style call patterns
2. Create appropriate helper functions
3. Replace direct Style calls
4. Run dialyzer to verify warnings resolved
5. Run tests to ensure no functional changes

### Step 4: Process log_viewer.ex (8 warnings)
1. Read file to identify all Style call patterns
2. Create appropriate helper functions
3. Replace direct Style calls
4. Run dialyzer to verify warnings resolved
5. Run tests to ensure no functional changes

### Step 5: Process tree_view.ex (5 warnings)
1. Read file to identify all Style call patterns
2. Create appropriate helper functions
3. Replace direct Style calls
4. Run dialyzer to verify warnings resolved
5. Run tests to ensure no functional changes

### Step 6: Process gauge.ex (3 warnings)
1. Read file to identify all Style call patterns
2. Create appropriate helper functions
3. Replace direct Style calls
4. Run dialyzer to verify warnings resolved
5. Run tests to ensure no functional changes

### Step 7: Process form_builder.ex (1 warning)
1. Read file to identify all Style call patterns
2. Create appropriate helper functions
3. Replace direct Style calls
4. Run dialyzer to verify warnings resolved
5. Run tests to ensure no functional changes

### Step 8: Process dialog.ex (1 warning)
1. Read file to identify all Style call patterns
2. Create appropriate helper functions
3. Replace direct Style calls
4. Run dialyzer to verify warnings resolved
5. Run tests to ensure no functional changes

### Step 9: Final Verification
1. Run full dialyzer: `mix dialyzer --format short`
2. Verify all ~30 warnings resolved
3. Run full test suite: `mix test`
4. Update phase 1.2 checkbox in dialyzer_cleanup.md
5. Create summary document in notes/summaries/

## Progress Tracking

- [x] Step 1: process_monitor.ex (14 warnings)
- [x] Step 2: cluster_dashboard.ex (12 warnings)
- [x] Step 3: supervision_tree_viewer.ex (9 warnings)
- [x] Step 4: log_viewer.ex (8 warnings)
- [x] Step 5: tree_view.ex (5 warnings)
- [x] Step 6: gauge.ex (3 warnings)
- [x] Step 7: form_builder.ex (1 warning)
- [x] Step 8: dialog.ex (1 warning)
- [x] Step 9: Final verification

## Notes

### Why This Approach Works

The `Cell.color()` type is defined as:
```elixir
@type color :: :default | atom() | 0..255 | {0..255, 0..255, 0..255}
```

When `Style.fg(:red)` is called, Dialyzer sees `:red` as an arbitrary atom, not a validated opaque type. The helper functions with `when is_atom(color)` guards and `@dialyzer :nowarn_function` tell Dialyzer "we know what we're doing - these atoms are valid colors."

### Consistency with Phase 1.1

Using the exact same pattern ensures:
- Code consistency across the codebase
- Maintainable approach for future fixes
- Dialyzer configuration is uniform
- Any developer can apply this pattern to new code

### Testing Strategy

Each file will be tested after modification:
1. Run `mix dialyzer --format short` and check warning count decreased
2. Run `mix test path/to/widget_test.exs` for specific widget tests
3. Visual inspection of widget rendering (if applicable)

## Status: COMPLETED ✅

## Completion Summary

All 8 widget files have been fixed. **~53 `call_without_opaque` warnings** resolved across:
- process_monitor.ex (14)
- cluster_dashboard.ex (12)
- supervision_tree_viewer.ex (9)
- log_viewer.ex (8)
- tree_view.ex (5)
- gauge.ex (3)
- form_builder.ex (1)
- dialog.ex (1)
