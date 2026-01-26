# Feature: Section 4.2 Review Fixes

**Branch:** `feature/section-4.2-review-fixes`
**Base:** `multi-renderer`
**Date:** 2025-12-06
**Status:** Complete

## Overview

Address all blockers, concerns, and implement suggested improvements from the Section 4.2 (Raw Input Handler) comprehensive review.

## Scope

### Blockers (Must Fix)

- [x] B1. Add buffer size limit using InputBuffer pattern
- [x] B2. Remove unused `reader_task` field from struct
- [x] B3. Fix dead code in `try_parse_buffer/1`

### Concerns (Should Address)

- [x] C1. Add tests for escape timeout and error paths
- [x] C2. Update planning doc Task 4.2.2.2 to reflect implementation
- [x] C4. Add debug logging for IO errors

### Suggestions (Nice to Have)

- [x] S1. Add event queue size limit
- [x] S2. Document escape timeout constant (why 50ms)
- [x] S3. Extract magic numbers to module attributes
- [x] S4. Use `with` for nested case in handle_escape_timeout
- [x] S5. Add integration tests tagged `:requires_terminal`
- [x] S6. Make Task.shutdown explicit

---

## Implementation Plan

### Phase 1: Fix Blockers

#### Task 1.1: Add Buffer Size Limit (B1)
**File:** `lib/term_ui/input/raw.ex`

1. Add module attribute for max buffer size (64KB matching InputBuffer)
2. Import or use InputBuffer.apply_limit/2 in do_read_with_timeout
3. Add rate-limited logging for buffer overflow

#### Task 1.2: Remove Unused Field (B2)
**File:** `lib/term_ui/input/raw.ex`

1. Remove `reader_task` from defstruct
2. Remove from @type definition
3. Remove from @typedoc
4. Update new/0 function
5. Update tests that reference the field

#### Task 1.3: Fix Dead Code (B3)
**File:** `lib/term_ui/input/raw.ex`

1. Simplify try_parse_buffer/1 to remove redundant conditional

### Phase 2: Address Concerns

#### Task 2.1: Add Missing Tests (C1)
**File:** `test/term_ui/input/raw_test.exs`

1. Add tests for emit_partial_escape/2 branches
2. Add tests for handle_escape_timeout/2
3. Add tests for EOF handling
4. Add tests for IO error handling

#### Task 2.2: Update Planning Doc (C2)
**File:** `notes/planning/multi-renderer/phase-04-input-abstraction.md`

1. Update Task 4.2.2.2 description to reflect actual implementation

#### Task 2.3: Add Debug Logging (C4)
**File:** `lib/term_ui/input/raw.ex`

1. Add Logger require
2. Add debug logging for IO errors

### Phase 3: Implement Suggestions

#### Task 3.1: Event Queue Limit (S1)
1. Add @max_queue_size constant
2. Truncate queue in try_parse_buffer/1

#### Task 3.2: Document Escape Timeout (S2)
1. Add comment explaining 50ms timeout

#### Task 3.3: Module Attributes for Magic Numbers (S3)
1. Define @esc, @left_bracket, @letter_o constants
2. Use in emit_partial_escape/2

#### Task 3.4: Refactor with `with` (S4)
1. Refactor handle_escape_timeout/2 to use `with`

#### Task 3.5: Integration Tests (S5)
1. Add integration test for actual timeout behavior

#### Task 3.6: Explicit Task.shutdown (S6)
1. Refactor do_read_with_timeout to make shutdown explicit

---

## Success Criteria

- [x] All blockers fixed
- [x] All concerns addressed
- [x] All suggestions implemented
- [x] All existing tests pass
- [x] New tests pass (45 tests, 0 failures)
- [x] No compilation warnings

---

## Files to Modify

| File | Changes |
|------|---------|
| `lib/term_ui/input/raw.ex` | Buffer limit, remove field, fix dead code, logging, suggestions |
| `test/term_ui/input/raw_test.exs` | Add missing tests, update for removed field |
| `notes/planning/multi-renderer/phase-04-input-abstraction.md` | Update Task 4.2.2.2 |
