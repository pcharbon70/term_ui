# Feature: Phase 3 Section 3.7 Review Fixes

**Branch:** `feature/phase-03-section-3.7-review-fixes`
**Base:** `multi-renderer`
**Date:** 2025-12-06
**Status:** Complete

## Overview

Address all findings from the Section 3.7 code review:
1. Security vulnerability (HIGH): Unbounded input buffer
2. Missing tests: poll_event timeout/error paths
3. Quality improvement: Cursor idempotency checks
4. Missing tests: Cursor idempotency

## Implementation Plan

### 1. Security Fix: Input Buffer Size Limit (HIGH Priority)

**Problem:** The `input_buffer` field has no size limit, allowing unbounded memory growth.

**Solution:** Copy the pattern from Raw backend:
- [x] Add `@max_input_buffer_size 1024` constant
- [x] Create `append_to_input_buffer/2` helper function
- [x] Create `apply_buffer_limit/1` helper function
- [x] Update `poll_event/2` to use the helper
- [x] Add tests for buffer overflow handling

**Files:**
- `lib/term_ui/backend/tty.ex`
- `test/term_ui/backend/tty_test.exs`

### 2. Missing Tests: poll_event Paths

**Problem:** No tests for `{:timeout, state}` and `{:error, reason, state}` return paths.

**Solution:** Add tests using buffer manipulation:
- [x] Test timeout return when input is incomplete escape sequence
- [x] Test that partial sequences are preserved in buffer

**Files:**
- `test/term_ui/backend/tty_test.exs`

### 3. Quality Improvement: Cursor Idempotency

**Problem:** TTY backend always writes cursor sequences, unlike Raw backend which checks state first.

**Solution:** Add idempotency checks to `hide_cursor/1` and `show_cursor/1`:
- [x] Add pattern match for already-hidden state in `hide_cursor/1`
- [x] Add pattern match for already-shown state in `show_cursor/1`
- [x] Add tests for idempotent behavior
- [x] Update existing test to work with idempotency

**Files:**
- `lib/term_ui/backend/tty.ex`
- `test/term_ui/backend/tty_test.exs`

## Success Criteria

- [x] All 200 tests pass (was 194, added 6 new tests)
- [x] Input buffer size is bounded to 1024 bytes
- [x] Buffer overflow logs warning and truncates gracefully
- [x] poll_event timeout/error paths have test coverage
- [x] Cursor operations are idempotent
- [x] Idempotency tests verify no output on repeated calls

## Changes Log

| File | Changes |
|------|---------|
| `lib/term_ui/backend/tty.ex` | Buffer limit constant, helper functions, cursor idempotency |
| `test/term_ui/backend/tty_test.exs` | 6 new tests, 1 test updated |
