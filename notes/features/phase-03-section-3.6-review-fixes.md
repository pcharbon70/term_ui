# Feature: Phase 3 Section 3.6 Review Fixes

**Branch:** `feature/phase-03-section-3.6-review-fixes`
**Base:** `multi-renderer`
**Date:** 2025-12-06
**Status:** Complete

## Overview

Address all concerns and implement suggestions from the Section 3.6 review (`notes/reviews/section-3.6-character-set-handling-review.md`).

## Implementation Plan

### Concerns (Should Address)

#### 1. Bidirectional Override Characters Not Filtered
- [x] Add U+202A-U+202E filtering in Cell.sanitize_char
- [x] Add U+2066-U+2069 filtering in Cell.sanitize_char
- [x] Add tests for bidi character filtering (10 tests)

#### 2. Unicode Non-Characters Not Filtered
- [x] Add U+FFFE, U+FFFF filtering
- [x] Add U+FDD0-U+FDEF filtering
- [x] Add tests for non-character filtering (6 tests)

### Suggestions (Nice to Have)

#### 3. Simplify Character Mapping Construction
- [x] Refactor to derive mappings from CharacterSet.keys()
- [x] Reduce three-stage construction to single expression
- [x] Verify tests still pass

#### 4. Add Validation to get/1
- [x] Add catch-all clause with ArgumentError
- [x] Add tests for invalid charset argument (3 tests)

#### 5. Derive keys/0 from Actual Map
- [x] Generate keys at compile time from @unicode_charset
- [x] Remove manual key list
- [x] Verify tests still pass

#### 6. Add current_charset/0 Helper
- [x] Add convenience function
- [x] Add @doc and @spec
- [x] Add tests for helper function (4 tests)

## Files Modified

| File | Changes |
|------|---------|
| `lib/term_ui/renderer/cell.ex` | Added bidi override and non-character filtering to `safe_codepoint?/1` |
| `lib/term_ui/character_set.ex` | Refactored to use module attributes, added validation, derived keys, added `current_charset/0` |
| `lib/term_ui/backend/tty.ex` | Simplified mapping construction using `CharacterSet.keys()` |
| `test/term_ui/renderer/cell_test.exs` | Added 16 new sanitization tests |
| `test/term_ui/character_set_test.exs` | Added 7 new tests for validation and helper |

## Success Criteria

- [x] All new filtering in place
- [x] CharacterSet improvements implemented
- [x] TTY mapping simplified
- [x] All tests pass (296 tests in affected files)

## Summary

All concerns and suggestions from the Section 3.6 review have been addressed:

### Security Hardening
- **Bidirectional override filtering**: Characters U+202A-U+202E (LRE, RLE, PDF, LRO, RLO) and U+2066-U+2069 (LRI, RLI, FSI, PDI) are now blocked to prevent visual text direction confusion attacks.
- **Unicode non-character filtering**: U+FFFE, U+FFFF, and U+FDD0-U+FDEF are blocked as they should never appear in interchange per Unicode spec.

### Code Quality Improvements
- **CharacterSet.get/1 validation**: Now raises `ArgumentError` with helpful message for invalid input instead of `FunctionClauseError`.
- **Derived keys/0**: Keys are now generated at compile time from `Map.keys(@unicode_charset)`, eliminating possibility of desync.
- **current_charset/0 helper**: Convenience function that combines `current/0` and `get/1` for common use case.
- **Simplified TTY mapping**: Reduced from three module attributes to single expression using `CharacterSet.keys()` for automatic adaptation.
