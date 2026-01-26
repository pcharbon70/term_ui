# Summary: Section 4.4 LineReader Review Fixes

**Date:** 2025-12-06
**Branch:** `feature/section-4.4-review-fixes`

## What Was Done

Addressed all concerns and implemented all suggested improvements from the Section 4.4 (LineReader) code review.

## Changes Made

### Documentation Updates (`lib/term_ui/input/line_reader.ex`)

1. **Added non-behaviour callout (S2)**: Added prominent info box at top of moduledoc explaining that LineReader does NOT implement the `TermUI.Input` behaviour, unlike Input.Raw and Input.TTY.

2. **Added security documentation (S1)**: New "Security Considerations" section documenting:
   - No input length limits enforced
   - Input returned as-is without sanitization
   - No injection protection (caller's responsibility)

3. **Documented error-to-EOF conversion (C2)**: Added note in "Important Notes" explaining that IO errors from `IO.gets/1` are converted to `:eof` for simplified error handling.

4. **Documented input length limitation (C3)**: Added note that this module does not enforce length limits; applications should validate if needed.

### Test Improvements (`test/term_ui/input/line_reader_test.exs`)

1. **Extracted test helper (S3)**: Created `capture_line_input/2` helper function to reduce boilerplate in capture_io tests. Refactored 15+ test cases to use the helper.

2. **Added EOF test coverage (C1)**: New "EOF handling" describe block with 3 tests:
   - `read_line/1` handles EOF from IO.gets
   - `read_line/2` returns :eof bypassing validation
   - error-to-eof conversion is documented behavior

## Test Results

```
30 tests, 0 failures (1 excluded - requires_terminal)
```

## Lines Changed

- `lib/term_ui/input/line_reader.ex`: +30 lines (documentation)
- `test/term_ui/input/line_reader_test.exs`: Refactored + 50 lines (helper, EOF tests)

## Next Steps

The next logical task according to the Phase 4 plan is:

**Section 4.3 - Task 4.3.2: Implement poll/2 for TTY Input**
- Implement `poll/2` using `IO.getn("", 1)` for single character reads
- Note: timeout is ignored (IO.getn is blocking)
- Parse escape sequences using `TermUI.Terminal.EscapeParser`
- Return `{:ok, event}` for keyboard input
- Return `:eof` if `IO.getn` returns `:eof`
