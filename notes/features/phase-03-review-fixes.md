# Feature: Phase 3 Review Fixes

**Branch:** `feature/phase-03-review-fixes`
**Base:** `multi-renderer`
**Date:** 2025-12-06
**Status:** Complete

## Overview

Address all blockers, concerns, and implement suggested improvements from the Phase 3 TTY Backend comprehensive review.

## Scope

### Blockers (Must Fix)
- [x] B1. Section 3.8 marked complete (already fixed)
- [x] B2. Redundant conditional in `named_color_to_sgr/1` (already fixed)
- [x] B3. Align `refresh_size/1` return signatures between backends
- [x] B4. Document non-callback public functions (`set_size/2`, `refresh_size/1`)
- [x] B5. Extract color conversion to shared module (`TermUI.Color.Converter`)
- [x] B6. Extract input buffer management to shared module (`TermUI.Backend.InputBuffer`)

### Security Concerns
- [x] S1. Add rate limiting for buffer overflow warnings (max 1 per 5 seconds)
- [x] S2. Sanitize logger output (via InputBuffer module with rate limiting)
- [x] S3. Add counter for dropped events in Raw backend

### Code Quality Concerns
- [x] C1. Handle `read_input_char/0` catch-all properly (return error tuple)
- [x] C2. Document `compare_frames/2` as testing helper

### Testing Concerns
- [x] T1. Tests added via InputBuffer module tests
- [x] T2. Tests added via InputBuffer module tests
- [x] T3. Update planning doc about test file location

### Suggested Improvements
- [x] I1. Add security documentation section to InputBuffer moduledoc
- [x] I2. Extract magic numbers to module attributes (buffer keep size)
- [x] I3. Add `@tag :integration` to integration test describe blocks

---

## Implementation Plan

### Phase 1: Extract Shared Modules

#### Task 1.1: Create TermUI.Color.Converter module
**Files:**
- Create: `lib/term_ui/color/converter.ex`
- Modify: `lib/term_ui/backend/tty.ex`

**Implementation:**
1. Create new module with color conversion functions
2. Move from tty.ex:
   - `rgb_to_256/3`
   - `rgb_to_16_fg/3`
   - `rgb_to_16_bg/3`
   - `rgb_to_16_base/3`
   - Related color palettes
3. Update TTY backend to use new module
4. Add tests for color converter

#### Task 1.2: Create TermUI.Backend.InputBuffer module
**Files:**
- Create: `lib/term_ui/backend/input_buffer.ex`
- Modify: `lib/term_ui/backend/tty.ex`
- Modify: `lib/term_ui/backend/raw.ex`

**Implementation:**
1. Create shared input buffer management module
2. Include:
   - `@max_size` constant (1024)
   - `@keep_size` constant (256)
   - `append/2` function
   - `apply_limit/1` function with rate-limited logging
3. Update both backends to use shared module

### Phase 2: Fix API Consistency

#### Task 2.1: Align refresh_size/1 signatures
**Files:**
- Modify: `lib/term_ui/backend/tty.ex`
- Modify: `test/term_ui/backend/tty_test.exs`

**Implementation:**
1. Change TTY `refresh_size/1` to return `{:ok, size, state}`
2. Update tests to match new signature

#### Task 2.2: Document non-callback functions
**Files:**
- Modify: `lib/term_ui/backend/tty.ex`

**Implementation:**
1. Add clear documentation for `set_size/2` and `refresh_size/1`
2. Mark as "Additional Functions" in moduledoc
3. Add @doc explaining these are TTY-specific extensions

### Phase 3: Security Improvements

#### Task 3.1: Rate-limited logging in InputBuffer
**Already handled in Task 1.2**

#### Task 3.2: Sanitize logger output
**Files:**
- Modify: `lib/term_ui/backend/raw.ex`

**Implementation:**
1. Truncate inspected values to max 50 characters
2. Add helper function for safe logging

#### Task 3.3: Add dropped event counter
**Files:**
- Modify: `lib/term_ui/backend/raw.ex`

**Implementation:**
1. Add `events_dropped` field to state
2. Increment when events are dropped
3. Log warning when dropping first event of a batch

### Phase 4: Code Quality Fixes

#### Task 4.1: Fix read_input_char catch-all
**Files:**
- Modify: `lib/term_ui/backend/tty.ex`

**Implementation:**
1. Add Logger.warning for unexpected return values
2. Return error tuple instead of coercing to string

#### Task 4.2: Document compare_frames/2
**Files:**
- Modify: `lib/term_ui/backend/tty.ex`

**Implementation:**
1. Add @doc explaining it's a public testing helper
2. Explain purpose and usage

### Phase 5: Testing Improvements

#### Task 5.1: Add EOF and error path tests
**Files:**
- Modify: `test/term_ui/backend/tty_test.exs`

**Implementation:**
1. Add test verifying EOF handling behavior
2. Add test verifying error propagation
3. Note: These may require mocking IO functions

#### Task 5.2: Add integration test tags
**Files:**
- Modify: `test/term_ui/backend/tty_test.exs`

**Implementation:**
1. Add `@tag :integration` to Section 3.8 describe blocks
2. Document in test file how to run integration tests only

#### Task 5.3: Update planning doc
**Files:**
- Modify: `notes/planning/multi-renderer/phase-03-tty-backend.md`

**Implementation:**
1. Update Key Outputs section to reflect actual test file location
2. Note that integration tests are in main test file with tags

### Phase 6: Documentation

#### Task 6.1: Add security documentation
**Files:**
- Modify: `lib/term_ui/backend/tty.ex`

**Implementation:**
1. Add "Security Considerations" section to moduledoc
2. Document:
   - Cell content sanitization
   - Input buffer limits
   - No external command execution
   - Defense-in-depth approach

#### Task 6.2: Extract magic numbers
**Files:**
- Modify: `lib/term_ui/backend/input_buffer.ex`

**Implementation:**
1. Define `@max_buffer_size 1024`
2. Define `@keep_size 256`
3. Document purpose of each constant

---

## Success Criteria

- [x] All extracted modules compile without errors
- [x] All existing tests pass (326 tests total: 259 TTY + 27 InputBuffer + 40 Color)
- [x] New tests added for color converter (40 tests)
- [x] New tests added for input buffer (27 tests)
- [x] API consistency verified between backends
- [x] Security documentation added
- [x] Integration tests tagged
- [x] No new compilation warnings

---

## Files to Create

| File | Purpose |
|------|---------|
| `lib/term_ui/color/converter.ex` | Shared color conversion algorithms |
| `lib/term_ui/backend/input_buffer.ex` | Shared input buffer management |
| `test/term_ui/color/converter_test.exs` | Tests for color converter |
| `test/term_ui/backend/input_buffer_test.exs` | Tests for input buffer |

## Files to Modify

| File | Changes |
|------|---------|
| `lib/term_ui/backend/tty.ex` | Use shared modules, add docs, fix catch-all |
| `lib/term_ui/backend/raw.ex` | Use input buffer module, sanitize logs, add counter |
| `test/term_ui/backend/tty_test.exs` | Add tags, add EOF/error tests |
| `notes/planning/multi-renderer/phase-03-tty-backend.md` | Update test location |

---

## Notes

### Trade-offs

1. **Color Converter Module**: Creates additional module but eliminates ~80 lines of duplication and enables reuse.

2. **Input Buffer Module**: Small overhead for import, but centralizes security-critical code.

3. **Rate-Limited Logging**: Requires timestamp tracking in module, adds minimal complexity for significant security benefit.

### Out of Scope

- ANSI sequence unification (C4, C5) - Deferred as it requires larger refactoring and current approach has performance benefits
- Telemetry events - Deferred to Phase 4 or later
- Benchmark tests - Deferred to Phase 4 or later
- Concurrent access tests - Deferred to Phase 4 or later
