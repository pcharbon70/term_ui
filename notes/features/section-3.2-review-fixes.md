# Feature: Section 3.2 Review Fixes

**Branch:** `feature/section-3.2-review-fixes`
**Base:** `multi-renderer`
**Date:** 2025-12-06
**Status:** Complete

## Overview

This feature addresses all concerns and implements all suggestions from the Section 3.2 review.

## Source

Review document: `notes/reviews/section-3.2-initialization-shutdown-review.md`

## Concerns to Fix

### Concern #1: Missing Defensive Error Handling in shutdown/1
**Severity:** Medium
**Location:** `lib/term_ui/backend/tty.ex:225-239`

The shutdown function uses bare `IO.write/1` calls without error handling. The Raw backend uses `safe_write/1` with try/rescue to prevent cleanup failures from cascading.

**Tasks:**
- [x] 1.1 Add `safe_write/1` private function with try/rescue
- [x] 1.2 Refactor `shutdown/1` to use `safe_write/1`

### Concern #2: Hardcoded Escape Sequences vs ANSI Module
**Severity:** Low-Medium
**Location:** Lines 227-234, 406-413

TTY backend uses raw escape sequence strings while Raw backend uses `TermUI.ANSI` module. This creates maintenance burden and potential inconsistency.

**Tasks:**
- [x] 2.1 Add module constants for all escape sequences
- [x] 2.2 Update `shutdown/1` to use constants
- [x] 2.3 Update `setup_terminal/1` to use constants

## Suggestions to Implement

### Suggestion #1: Add Module Constants for Escape Sequences
Already covered by Concern #2.

### Suggestion #3: Add State Validation in shutdown/1
**Tasks:**
- [x] 3.1 Add pattern match for struct type in `shutdown/1`

### Suggestion #4: Document Error Safety Guarantees
**Tasks:**
- [x] 4.1 Expand `shutdown/1` documentation to explain:
  - Idempotent behavior
  - Error handling strategy
  - Why TTY doesn't need cooked mode restoration

### Suggestion #5: Test Edge Cases for Invalid Inputs
**Tasks:**
- [x] 5.1 Add test for invalid size values: `{0, 80}`, `{24, -1}`
- [x] 5.2 Add test for malformed capabilities: `%{colors: :unknown_mode}`
- [x] 5.3 Add test for shutdown state parameter verification

## Files Modified

| File | Type | Description |
|------|------|-------------|
| `lib/term_ui/backend/tty.ex` | Modified | Add constants, safe_write, improve docs |
| `test/term_ui/backend/tty_test.exs` | Modified | Add edge case tests |

## Test Results

```
66 tests, 0 failures
```

Added 13 new tests:
- 1 test for shutdown struct validation
- 6 tests for invalid size values
- 6 tests for malformed capabilities
