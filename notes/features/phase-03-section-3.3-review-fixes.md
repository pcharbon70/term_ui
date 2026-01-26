# Feature: Section 3.3 Review Fixes

**Branch:** `feature/section-3.3-review-fixes`
**Base:** `multi-renderer`
**Date:** 2025-12-06
**Status:** In Progress

## Overview

Address all concerns and implement all suggestions from the Section 3.3 review to improve code quality, test coverage, and maintainability.

## Review Findings to Address

### Concerns (5 items - 2 deferred)

| # | Concern | Severity | Action |
|---|---------|----------|--------|
| 1 | Frame map built unnecessarily in full_redraw mode | Low | Fix: Skip frame map in full_redraw |
| 2 | Character set mapping is a stub | Low | SKIP: Deferred to Section 3.6 |
| 3 | RGB to 16-color uses simplistic algorithm | Low | Fix: Improve algorithm |
| 4 | No IO output batching | Low | Fix: Add iolist batching |
| 5 | IO.write error handling inconsistency | Low | Fix: Use safe_write consistently |

### Suggestions (6 items)

| # | Suggestion | Action |
|---|------------|--------|
| 1 | Add character sanitization for escape sequences | Implement |
| 2 | Use map-based approach for named colors | Implement |
| 3 | Add tests for all attribute types | Implement |
| 4 | Add tests for default/nil color handling | Implement |
| 5 | Add tests for palette index colors | Implement |
| 6 | Extract SGR building sub-functions | Implement |

## Implementation Plan

### Phase 1: Code Improvements

- [ ] 1.1 Skip frame map in full_redraw mode (Concern 1)
  - Only build frame map when line_mode is :incremental
  - Full_redraw mode doesn't need position lookups

- [ ] 1.2 Improve RGB to 16-color mapping (Concern 3)
  - Use weighted RGB distance calculation
  - Better color matching for edge cases

- [ ] 1.3 Add IO output batching (Concern 4)
  - Build iolist per row instead of multiple IO.write calls
  - Single IO.write per row for efficiency

- [ ] 1.4 Use safe_write consistently (Concern 5)
  - Replace IO.write with safe_write in rendering functions
  - Consistent error handling strategy

- [ ] 1.5 Add character sanitization (Suggestion 1)
  - Add sanitize_char/1 to strip escape sequences from user content
  - Defensive programming practice

### Phase 2: Refactoring

- [ ] 2.1 Use map-based approach for named colors (Suggestion 2)
  - Replace 32 function clauses with @named_fg_colors and @named_bg_colors maps
  - Reduce ~50 lines of code

- [ ] 2.2 Extract SGR building sub-functions (Suggestion 6)
  - Create build_fg_sgr/2
  - Create build_bg_sgr/2
  - Create build_attrs_sgr/1
  - Improved testability and single responsibility

### Phase 3: Test Coverage

- [ ] 3.1 Add tests for all attribute types (Suggestion 3)
  - Test :dim attribute
  - Test :italic attribute
  - Test :blink attribute
  - Test :reverse attribute
  - Test :strikethrough attribute

- [ ] 3.2 Add tests for default/nil color handling (Suggestion 4)
  - Test nil foreground color
  - Test nil background color
  - Test :default named color

- [ ] 3.3 Add tests for palette index colors (Suggestion 5)
  - Test {:palette, index} colors in 256-color mode
  - Test palette colors degraded to 16-color mode

## Files Modified

| File | Type | Description |
|------|------|-------------|
| `lib/term_ui/backend/tty.ex` | Modified | All code improvements |
| `test/term_ui/backend/tty_test.exs` | Modified | Additional tests |
| `notes/planning/multi-renderer/phase-03-tty-backend.md` | Modified | Update status |

## Test Results

```
Before: 97 tests, 0 failures
After: 114 tests, 0 failures (+17 tests)
```

## Notes

- Concern 2 (character set mapping) is correctly deferred to Section 3.6
- Focus on practical improvements that benefit the codebase
- All changes maintain backward compatibility

## Completion Summary

All items completed:
- [x] 1.1 Skip frame map in full_redraw mode
- [x] 1.2 Improve RGB to 16-color mapping (perceptual weighting)
- [x] 1.3 Add IO output batching (iolist per row)
- [x] 1.4 Use safe_write consistently
- [x] 1.5 Add character sanitization
- [x] 2.1 Map-based named colors (reduced ~20 lines)
- [x] 2.2 Extract SGR building sub-functions
- [x] 3.1 Tests for all attribute types (dim, italic, blink, reverse, strikethrough)
- [x] 3.2 Tests for default/nil color handling
- [x] 3.3 Tests for palette index colors
