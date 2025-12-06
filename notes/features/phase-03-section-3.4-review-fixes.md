# Feature: Phase 3 Section 3.4 Review Fixes

**Branch:** `feature/phase-03-section-3.4-review-fixes`
**Base:** `multi-renderer`
**Date:** 2025-12-06
**Status:** In Progress

## Overview

Address all blockers, concerns, and suggestions from the Section 3.4 review (`notes/reviews/section-3.4-incremental-rendering-review.md`).

## Implementation Plan

### Blockers (Must Fix)

#### 1. RGB Color Validation
- [ ] Add guard clauses to `color_to_sgr/3` for RGB tuples
- [ ] Validate r, g, b values are in 0..255 range
- [ ] Add fallback clause for invalid RGB values

#### 2. Position Bounds Validation
- [ ] Add validation in `render_incremental_row/3`
- [ ] Add validation in `clear_cell_at/1`
- [ ] Skip rendering for out-of-bounds positions with logging

### Concerns (Should Address)

#### 3. Extract Shared Row Rendering Logic
- [ ] Create `render_row_at_column/4` shared helper
- [ ] Refactor `render_row/3` to use shared helper
- [ ] Refactor `render_incremental_row/3` to use shared helper
- [ ] Verify tests still pass

#### 4. Remove Unused `render_cell_at/3`
- [ ] Delete the function (lines 544-566)
- [ ] Verify no references exist

#### 5. Make `compare_frames/2` Private
- [ ] Change `def` to `defp`
- [ ] Remove `@doc` (or keep short comment)
- [ ] Update any tests that call it directly

#### 6. Clarify Sanitization Contract
- [ ] Add documentation noting defense-in-depth approach
- [ ] Document that cells should be pre-sanitized by Cell module
- [ ] Keep basic ESC sanitization as last line of defense

#### 7. Remove Unused `current_style` State Field
- [ ] Remove from struct definition
- [ ] Remove from @type definition
- [ ] Verify no code references it

#### 8. Optimize `compare_frames/2` Map Construction
- [ ] Use MapSet for position lookup instead of full map
- [ ] Avoid building current_frame map twice

### Suggestions (Nice to Have)

#### 9. Improve Iolist Building Pattern
- [ ] Change prepend+reverse to append pattern
- [ ] Update in shared `render_row_at_column/4`

#### 10. Add Comment to `clear_cell_at/1`
- [ ] Add descriptive comment above typespec

## Files to Modify

| File | Changes |
|------|---------|
| `lib/term_ui/backend/tty.ex` | All fixes |
| `test/term_ui/backend/tty_test.exs` | Update tests for private function |

## Success Criteria

- [ ] All 150+ tests pass
- [ ] No compiler warnings for unused functions
- [ ] All blockers addressed
- [ ] All concerns addressed
- [ ] Suggestions implemented
