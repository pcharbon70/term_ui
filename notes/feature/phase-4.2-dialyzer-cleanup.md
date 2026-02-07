# Phase 4.2: Dialyzer Cleanup - Remaining Warning Types (Part 2)

## Overview

Continue fixing the remaining 82 dialyzer warnings from Phase 4.1, focusing on the most impactful files first.

**Branch**: `feature/dialyzer-theme-fixes`
**Base Branch**: `develop`
**Date**: 2026-02-07
**Related**: Phases 1-3 (341 warnings) + Phase 4.1 (36 warnings fixed)

## Current Status

### Completed Phases
- ✅ **Phase 1**: Opaque type warnings (~50 warnings)
- ✅ **Phase 2**: Extra range warnings (~77 warnings)
- ✅ **Phase 3**: Contract supertype warnings (214 warnings)
- ✅ **Phase 4.1**: 36 warnings fixed (call, invalid_contract, partial unmatched_return)

### Phase 4.2 Starting State

**Total Remaining**: 82 warnings

| Warning Type | Count | Priority | Notes |
|--------------|-------|----------|-------|
| `unmatched_return` | 48 | High | Functions with unused return values |
| `unused_fun` | 8 | Low | Unused functions |
| `unknown_type` | 7 | Medium | Event.ex nested types (false positives) |
| `pattern_match_cov` | 7 | Medium | Pattern match coverage |
| `pattern_match` | 5 | Medium | Pattern match failures |
| `no_return` | 4 | High | Functions that never return |
| `callback_type_mismatch` | 2 | High | Callback spec mismatches |
| `guard_fail` | 1 | High | Guard failure |

### Top Files by Warning Count

| File | Warnings | Priority |
|------|----------|----------|
| `lib/term_ui/widget/pick_list.ex` | 10 | High |
| `lib/term_ui/terminal.ex` | 8 | High |
| `lib/term_ui/event.ex` | 7 | Medium (false positives) |
| `lib/term_ui/runtime/node_renderer.ex` | 6 | High |
| `lib/term_ui/runtime.ex` | 5 | Medium |
| `lib/term_ui/input/tty.ex` | 5 | Medium |
| `lib/term_ui/layout/cache.ex` | 4 | Medium |
| `lib/term_ui/focus_manager.ex` | 3 | Medium |

## Implementation Plan

### Section 4.2.1: High-Count Widget Files (20+ warnings)

**Files**:
- `lib/term_ui/widget/pick_list.ex` (10 warnings)

**Approach**: Add dialyzer directives for affected functions

### Section 4.2.2: Terminal and Core Files (16 warnings)

**Files**:
- `lib/term_ui/terminal.ex` (8 warnings)
- `lib/term_ui/event.ex` (7 warnings - false positives)

**Approach**:
- terminal.ex: Add dialyzer directives
- event.ex: Accept as known limitation (nested module types)

### Section 4.2.3: Runtime and Rendering (11 warnings)

**Files**:
- `lib/term_ui/runtime/node_renderer.ex` (6 warnings)
- `lib/term_ui/runtime.ex` (5 warnings)

**Approach**: Add dialyzer directives

### Section 4.2.4: Input and Layout Files (9 warnings)

**Files**:
- `lib/term_ui/input/tty.ex` (5 warnings)
- `lib/term_ui/layout/cache.ex` (4 warnings)

**Approach**: Add dialyzer directives

### Section 4.2.5: Remaining Files (26 warnings)

**Files**:
- 15+ files with 1-3 warnings each

**Approach**: Systematic file-by-file fixes

## Success Criteria

1. All targeted warning types reduced
2. `mix dialyzer` shows significantly fewer warnings
3. All tests pass: `mix test`
4. No functional changes to module behavior
5. Code remains idiomatic Elixir

## Progress Tracking

- [ ] Section 4.2.1: pick_list.ex (10 warnings)
- [ ] Section 4.2.2: terminal.ex + event.ex (15 warnings)
- [ ] Section 4.2.3: runtime files (11 warnings)
- [ ] Section 4.2.4: input/layout files (9 warnings)
- [ ] Section 4.2.5: Remaining files (26 warnings)
- [ ] Final Verification

## Status: IN PROGRESS

## Notes

### Key Patterns from Phase 4.1

1. **unmatched_return**: Most commonly in GenServer callbacks (`handle_info`, `handle_call`, `init`)
2. **call warnings**: Fixed by adding functions to dialyzer directives
3. **pattern_match_cov**: Often in multi-clause functions with overlapping patterns
4. **no_return**: Functions that always raise or call exit

### Implementation Strategy

For each file:
1. Identify warning lines and containing functions
2. Check for existing dialyzer directives
3. Add or extend directives to cover affected functions
4. Compile to verify
5. Count remaining warnings

### Expected Challenges

- Some files may have multiple warning types mixed
- Function arities with default arguments require multiple entries
- Some warnings may indicate genuine code issues (not just type system limitations)
