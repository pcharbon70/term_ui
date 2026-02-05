# Dialyzer Cleanup - Feature Plan

## Overview

Fix all 491 dialyzer warnings in the term_ui codebase to enable static type checking with Dialyzer. Dialyxir has been added to the project, and warnings need to be resolved in batches by category.

**Branch**: `cleanup/dialyzer`
**Base Branch**: `develop`
**Date**: 2026-02-05

## Problem Statement

Running `mix dialyzer --format short` produces 491 warnings across multiple categories:

| Category | Count | Description |
|----------|-------|-------------|
| `extra_range` | ~35 | Specs declare more types than returned |
| `contract_supertype` | ~400 | Specs are too general (supertype of actual typing) |
| `call_without_opaque` | ~130 | Opaque type mismatches (fg/bg calls, positioned_cell, etc.) |
| `unmatched_return` | ~30 | Return values not matched |
| `callback_type_mismatch` | ~3 | Callback spec mismatches |
| `pattern_match` | ~8 | Pattern can never match the type |
| `pattern_match_cov` | ~5 | Pattern variable covered by previous clauses |
| `guard_fail` | ~3 | Guard clause can never succeed |
| `no_return` | ~3 | Function has no local return |
| `call` | ~8 | Function call will not succeed |
| `unused_fun` | ~1 | Function will never be called |
| `contract_with_opaque` | ~8 | Spec has opaque subtype violation |
| `invalid_contract` | ~1 | Invalid type specification |
| `unknown_type` | ~7 | Unknown type (Tick.t, Resize.t, etc.) |

## Technical Context

### Opaque Type Issues

The `Cell.color()` type is defined as:
```elixir
@type color :: :default | atom() | 0..255 | {0..255, 0..255, 0..255}
```

When `Style.fg/2` or `Style.bg/2` are called with a bare atom (e.g., `:red`), Dialyzer sees this as a mismatch because the spec uses `Cell.color()` but the call passes an atom that could be anything. The 66 warnings in `theme.ex` are all from calls like `Style.fg(:red)`.

### Extra Range Issues

Functions in `ansi.ex` have specs like `@spec cursor_up(pos_integer()) :: iodata()` but only return `[...]` (list), not the full `iodata()` range (which includes charlists, binaries, and iolists).

### Contract Supertype Issues

Most `new/1` and update functions have specs that are too general. For example:
```elixir
@spec new(keyword()) :: t()
```
But the function only accepts specific keys, not any keyword list.

## Implementation Plan

### Phase 1: Opaque Type Fixes (~130 warnings)

**Goal**: Fix `call_without_opaque` and `contract_with_opaque` warnings

#### Section 1.1: Fix Theme.ex Style Calls (66 warnings)

**Location**: `lib/term_ui/theme.ex`

**Issue**: Calling `Style.fg(:red)` where `:red` is an atom but spec expects `Cell.color()`

**Solution**: Create local helper functions that wrap Style calls with proper type constraints

```elixir
# Instead of:
Style.new() |> Style.fg(:red)

# Use typed helpers:
defp fg_style(color) when is_atom(color), do: Style.new() |> Style.fg(color)
```

**Tasks**:
1. Add private helper functions for common style patterns
2. Update `dark_theme/0` to use helpers
3. Update `light_theme/0` to use helpers
4. Update `high_contrast_theme/0` to use helpers
5. Verify 66 warnings resolved

#### Section 1.2: Fix Widget Style Calls (~30 warnings)

**Locations**:
- `lib/term_ui/widgets/process_monitor.ex` (14 warnings)
- `lib/term_ui/widgets/cluster_dashboard.ex` (12 warnings)
- `lib/term_ui/widgets/supervision_tree_viewer.ex` (9 warnings)
- `lib/term_ui/widgets/log_viewer.ex` (8 warnings)
- `lib/term_ui/widgets/tree_view.ex` (5 warnings)
- `lib/term_ui/widgets/gauge.ex` (3 warnings)
- `lib/term_ui/widgets/form_builder.ex` (1 warning)
- `lib/term_ui/widgets/dialog.ex` (1 warning)

**Solution**: Same approach as Theme.ex - create typed wrapper functions

**Tasks**:
1. For each widget file, add private style helper functions
2. Replace direct `Style.fg/2` and `Style.bg/2` calls with helpers
3. Verify warnings resolved

#### Section 1.3: Fix RenderNode Calls (~20 warnings)

**Locations**:
- `lib/term_ui/widget/block.ex` (6 warnings)
- `lib/term_ui/widget/progress.ex` (2 warnings)
- `lib/term_ui/widget/text_input.ex` (1 warning)
- `lib/term_ui/widget/pick_list.ex` (2 warnings)
- `lib/term_ui/widget/list.ex` (1 warning)
- `lib/term_ui/widget/label.ex` (1 warning)
- `lib/term_ui/widget/button.ex` (1 warning)

**Issue**: `positioned_cell/3` and other RenderNode functions with opaque types

**Solution**: Add proper type specs or pattern match to destructure opaque types

**Tasks**:
1. Review RenderNode type definitions
2. Add proper type constraints
3. Verify warnings resolved

#### Section 1.4: Fix Style and Cell Module Opaque Violations (8 warnings)

**Locations**:
- `lib/term_ui/renderer/style.ex` (3 warnings)
- `lib/term_ui/renderer/cell.ex` (5 warnings)

**Issue**: Specs use opaque types but success typing is more general

**Solution**: Update specs to match actual success typing

**Tasks**:
1. Review `Style.new/1`, `Style.reset/1`, `Style.clear_attrs/1` specs
2. Review `Cell.empty/0`, `Cell.valid_attributes/0`, `Cell.named_colors/0` specs
3. Update specs to match actual behavior
4. Verify warnings resolved

---

### Phase 2: Extra Range Fixes (~35 warnings)

**Goal**: Fix `extra_range` warnings where specs declare more types than returned

#### Section 2.1: Fix ANSI Module Specs (~33 warnings)

**Location**: `lib/term_ui/ansi.ex`

**Issue**: Functions return lists but spec says `iodata()`

**Current**:
```elixir
@spec cursor_up(pos_integer()) :: iodata()
def cursor_up(1), do: [@csi, "A"]
```

**Solution**: Change return type from `iodata()` to proper list type

**Tasks**:
1. Update all ANSI function specs to return `iolist()` instead of `iodata()`
2. Or create a local type alias for the actual return type
3. Verify ~33 warnings resolved

#### Section 2.2: Fix Other Extra Range Warnings (~5 warnings)

**Locations**:
- `lib/term_ui/style.ex` (1 warning)
- `lib/term_ui/sgr.ex` (4 warnings)
- `lib/term_ui/renderer/sequence_buffer.ex` (1 warning)
- `lib/term_ui/error.ex` (1 warning)
- `lib/term_ui/test/component_harness.ex` (2 warnings)
- `lib/term_ui/focus/indicator.ex` (1 warning)

**Tasks**:
1. Fix `Style.semantic/2` spec
2. Fix `SGR` module specs
3. Fix `SequenceBuffer.to_iodata/1` spec
4. Fix `Error.error/2` spec
5. Fix test helper specs (or add @dialyzer :nowarn_function)
6. Verify warnings resolved

---

### Phase 3: Contract Supertype Fixes (~400 warnings)

**Goal**: Fix `contract_supertype` warnings where specs are too general

#### Section 3.1: Widget new/1 and Update Functions (~200 warnings)

**Locations**: All widget files

**Issue**: Functions like `new(keyword())` have specs that accept any keyword list, but actual behavior requires specific keys

**Solution Options**:
1. Use `t()` as return type (current - too general)
2. Create more specific types for options
3. Use `@dialyzer :nowarn_function` for pure data functions

**Recommended Approach**: For simple data struct functions, suppress warnings:

```elixir
@dialyzer :nowarn_function
def new(opts) when is_list(opts) do
  # ...
end
```

**Tasks**:
1. Add `@dialyzer :nowarn_function` to simple `new/1` functions
2. Add to update functions that just return `t()`
3. Verify ~200 warnings resolved

#### Section 3.2: Platform and Helper Functions (~50 warnings)

**Locations**:
- `lib/term_ui/platform.ex`
- `lib/term_ui/platform/unix.ex`
- `lib/term_ui/platform/windows.ex`
- `lib/term_ui/terminal/size_detector.ex`
- `lib/term_ui/term_utils.ex`
- `lib/term_ui/sanitize.ex`

**Tasks**:
1. Add `@dialyzer :nowarn_function` to query functions
2. Update specs where appropriate
3. Verify warnings resolved

#### Section 3.3: Component and Runtime Functions (~50 warnings)

**Locations**:
- `lib/term_ui/component_registry.ex`
- `lib/term_ui/component/state_persistence.ex`
- `lib/term_ui/component_supervisor.ex`
- `lib/term_ui/component/render_node.ex`
- Various runtime files

**Tasks**:
1. Add `@dialyzer :nowarn_function` where appropriate
2. Update specs for public API functions
3. Verify warnings resolved

#### Section 3.4: Event and Input Functions (~30 warnings)

**Locations**:
- `lib/term_ui/event.ex`
- `lib/term_ui/event/transformation.ex`
- `lib/term_ui/input/selector.ex`
- `lib/term_ui/terminal/state.ex`

**Tasks**:
1. Add `@dialyzer :nowarn_function` to data constructors
2. Update event type specs
3. Verify warnings resolved

#### Section 3.5: Test Helper Functions (~20 warnings)

**Locations**:
- `lib/term_ui/test/event_simulator.ex`
- `lib/term_ui/message_queue.ex`
- `lib/term_ui/view_cache.ex`

**Tasks**:
1. Add `@dialyzer :nowarn_function` to test helpers
2. Or move to `test/support` (excluded from dialyzer)
3. Verify warnings resolved

---

### Phase 4: Unmatched Return Fixes (~30 warnings)

**Goal**: Fix `unmatched_return` warnings

#### Section 4.1: Runtime and Terminal Functions (~15 warnings)

**Locations**:
- `lib/term_ui/runtime.ex` (5 warnings)
- `lib/term_ui/terminal.ex` (5 warnings)
- `lib/term_ui/runtime/node_renderer.ex` (6 warnings)
- `lib/term_ui/renderer/buffer.ex` (1 warning)
- `lib/term_ui/renderer/framerate_limiter.ex` (1 warning)

**Issue**: Functions return multiple types but none are matched by caller

**Solution**: Either pattern match on return or add `@dialyzer :nowarn_return`

**Tasks**:
1. Identify which returns should be matched
2. Add `@dialyzer :nowarn_return` where ignore is intentional
3. Verify warnings resolved

#### Section 4.2: Component and Event Functions (~10 warnings)

**Locations**:
- `lib/term_ui/component_registry.ex` (3 warnings)
- `lib/term_ui/component/state_persistence.ex` (2 warnings)
- `lib/term_ui/component_server.ex` (2 warnings)
- `lib/term_ui/event_router.ex` (2 warnings)
- `lib/term_ui/event_queue.ex` (2 warnings)
- `lib/term_ui/spatial_index.ex` (1 warning)

**Tasks**:
1. Add `@dialyzer :nowarn_return` to async function returns
2. Verify warnings resolved

#### Section 4.3: Input and Widget Functions (~5 warnings)

**Locations**:
- `lib/term_ui/input/tty.ex` (4 warnings)
- `lib/term_ui/input/raw.ex` (1 warning)
- `lib/term_ui/widgets/process_monitor.ex` (2 warnings)
- `lib/term_ui/widgets/cluster_dashboard.ex` (2 warnings)
- `lib/term_ui/widgets/context_menu/behavior.ex` (2 warnings)
- `lib/term_ui/widgets/context_menu/inline.ex` (1 warning)

**Tasks**:
1. Add `@dialyzer :nowarn_return` where appropriate
2. Verify warnings resolved

---

### Phase 5: Pattern Match and Guard Fixes (~20 warnings)

**Goal**: Fix `pattern_match`, `pattern_match_cov`, and `guard_fail` warnings

#### Section 5.1: Fix Impossible Pattern Matches (~8 warnings)

**Locations**:
- `lib/term_ui/terminal.ex` (3 warnings)
- `lib/term_ui/input/tty.ex` (1 warning)
- `lib/term_ui/input/raw.ex` (1 warning)
- `lib/term_ui/focus_manager.ex` (2 warnings)
- `lib/term_ui/markdown.ex` (2 warnings)
- `lib/term_ui/platform.ex` (1 warning)
- `lib/term_ui/persistent_terms.ex` (1 warning)
- `lib/term_ui/dev/hot_reload.ex` (1 warning)

**Solution**: Remove dead code or fix patterns

**Tasks**:
1. Remove unused catch-all clauses
2. Fix patterns that can never match
3. Verify warnings resolved

#### Section 5.2: Fix Guard Failures (~3 warnings)

**Locations**:
- `lib/term_ui/widgets/supervision_tree_viewer.ex` (1 warning)
- `lib/term_ui/terminal.ex` (1 warning)
- `lib/term_ui/widgets/canvas.ex` (related to no_return)

**Tasks**:
1. Fix or remove failing guard clauses
2. Verify warnings resolved

#### Section 5.3: Fix Input TTY Server Issues (~5 warnings)

**Location**: `lib/term_ui/input/tty_server.ex`

**Issues**:
- Pattern can never match `<<>>`, `string()`, `integer()`
- Function call `++` will not succeed
- Unused function `parse_buffer/1`
- No return on `handle_escape_timeout/3`

**Tasks**:
1. Fix or remove impossible pattern match
2. Fix concatenation issue
3. Remove unused function
4. Fix no return issue
5. Verify warnings resolved

---

### Phase 6: Remaining Warnings (~30 warnings)

**Goal**: Fix all remaining warnings

#### Section 6.1: Fix Canvas No Return Issues (6 warnings)

**Location**: `lib/term_ui/widgets/canvas.ex`

**Issues**:
- `draw_vline/4`, `draw_hline/4`, `draw_line/5` have no local return
- Calls to these functions will not succeed

**Tasks**:
1. Review canvas drawing functions for infinite recursion
2. Fix or add termination conditions
3. Verify warnings resolved

#### Section 6.2: Fix Unknown Types (7 warnings)

**Location**: `lib/term_ui/event.ex`

**Issues**: Unknown types `Tick.t()`, `Resize.t()`, `Paste.t()`, `Mouse.t()`, `Key.t()`, `Focus.t()`, `Custom.t()`

**Solution**: Define opaque types for event subtypes

**Tasks**:
1. Define `@opaque` types for each event subtype
2. Update event specs
3. Verify warnings resolved

#### Section 6.3: Fix Callback Type Mismatches (3 warnings)

**Locations**:
- `lib/term_ui/widgets/viewport.ex` (1 warning)
- `lib/term_ui/widget/label.ex` (1 warning)
- `lib/term_ui/widget/text_input.ex` (related)

**Tasks**:
1. Update `@callback` specs to match implementations
2. Verify warnings resolved

#### Section 6.4: Fix Terminal Input Reader (2 warnings)

**Location**: `lib/term_ui/terminal/input_reader.ex`

**Issues**:
- Function call `key/1` will not succeed
- Unmatched return

**Tasks**:
1. Fix key function call
2. Fix unmatched return
3. Verify warnings resolved

#### Section 6.5: Fix Escape Parser Issues (6 warnings)

**Location**: `lib/term_ui/terminal/escape_parser.ex`

**Issue**: Function call `key/1` will not succeed

**Tasks**:
1. Review escape parser key handling
2. Fix function call
3. Verify warnings resolved

#### Section 6.6: Fix Invalid Contract (1 warning)

**Location**: `lib/term_ui/renderer/cell.ex`

**Issue**: Invalid type specification for `wide_placeholder/1`

**Tasks**:
1. Fix spec for `wide_placeholder/1`
2. Verify warning resolved

---

## Success Criteria

1. `mix dialyzer` runs with 0 warnings
2. All tests still pass: `mix test`
3. No functional changes to existing behavior
4. Code remains maintainable

## Progress Tracking

### Phase 1: Opaque Type Fixes
- [x] Section 1.1: Fix Theme.ex (66 warnings) - **COMPLETED 2026-02-05**
- [ ] Section 1.2: Fix Widget Style Calls (~30 warnings)
- [ ] Section 1.3: Fix RenderNode Calls (~20 warnings)
- [ ] Section 1.4: Fix Style/Cell Opaque Violations (8 warnings)

### Phase 2: Extra Range Fixes
- [ ] Section 2.1: Fix ANSI Module Specs (~33 warnings)
- [ ] Section 2.2: Fix Other Extra Range Warnings (~5 warnings)

### Phase 3: Contract Supertype Fixes
- [ ] Section 3.1: Widget new/1 Functions (~200 warnings)
- [ ] Section 3.2: Platform Functions (~50 warnings)
- [ ] Section 3.3: Component Functions (~50 warnings)
- [ ] Section 3.4: Event Functions (~30 warnings)
- [ ] Section 3.5: Test Helpers (~20 warnings)

### Phase 4: Unmatched Return Fixes
- [ ] Section 4.1: Runtime/Terminal Functions (~15 warnings)
- [ ] Section 4.2: Component Functions (~10 warnings)
- [ ] Section 4.3: Input/Widget Functions (~5 warnings)

### Phase 5: Pattern Match and Guard Fixes
- [ ] Section 5.1: Fix Impossible Patterns (~8 warnings)
- [ ] Section 5.2: Fix Guard Failures (~3 warnings)
- [ ] Section 5.3: Fix Input TTY Server (~5 warnings)

### Phase 6: Remaining Warnings
- [ ] Section 6.1: Fix Canvas Issues (6 warnings)
- [ ] Section 6.2: Fix Unknown Types (7 warnings)
- [ ] Section 6.3: Fix Callback Mismatches (3 warnings)
- [ ] Section 6.4: Fix Input Reader (2 warnings)
- [ ] Section 6.5: Fix Escape Parser (6 warnings)
- [ ] Section 6.6: Fix Invalid Contract (1 warning)

## Final Tasks
- [ ] Run full dialyzer: `mix dialyzer`
- [ ] Run full test suite: `mix test`
- [ ] Document approach in developer guide
- [ ] Create summary document

## Status: PLANNING

## Notes

### Strategy Decisions

1. **Suppress vs Fix**: For simple data structure functions (like `new/1`), suppressing with `@dialyzer :nowarn_function` is acceptable since the functions are trivial wrappers.

2. **Opaque Types**: The `Cell.color()` type is intentionally opaque. We work around this by creating typed helper functions.

3. **Test Files**: Test helper modules in `lib/term_ui/test/` could be moved to `test/support/` to exclude from dialyzer entirely.

4. **Incremental Approach**: We fix warnings in phases to allow testing at each checkpoint.

### Critical Files

- `mix.exs` - Dialyxir configuration
- `lib/term_ui/renderer/cell.ex` - Color type definition
- `lib/term_ui/renderer/style.ex` - Style builder
- `lib/term_ui/theme.ex` - Most opaque warnings (66)
- `lib/term_ui/ansi.ex` - Most extra range warnings (~33)
- `lib/term_ui/event.ex` - Unknown type definitions
