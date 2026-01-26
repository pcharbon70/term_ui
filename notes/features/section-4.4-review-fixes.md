# Feature: Section 4.4 LineReader Review Fixes

**Branch:** `feature/section-4.4-review-fixes`
**Base:** `multi-renderer`
**Date:** 2025-12-06
**Status:** Complete

## Overview

Address all concerns and implement suggested improvements from the Section 4.4 (LineReader) review.

## Review Findings to Address

### Concerns (Must Fix)

- [x] **C1**: Missing EOF test coverage - No tests for `:eof` return path
- [x] **C2**: Error-to-EOF conversion loses information - `{:error, reason}` silently becomes `:eof`
- [x] **C3**: No input length limits documented (low priority)

### Suggestions (Should Implement)

- [x] **S1**: Add security documentation section to moduledoc
- [x] **S2**: Add prominent non-behaviour documentation
- [x] **S3**: Extract test helper for capture_io pattern

---

## Implementation Plan

### Step 1: Extract Test Helper (S3)

Create a helper function to reduce the repeated capture_io pattern:

```elixir
defp capture_line_input(input, fun) do
  ExUnit.CaptureIO.capture_io([input: input], fn ->
    result = fun.()
    send(self(), {:result, result})
  end)
  assert_receive {:result, result}
  result
end
```

### Step 2: Add EOF Tests (C1)

Add test coverage for EOF scenarios:
- Test `read_line/1` returns `:eof` when IO.gets returns `:eof`
- Test `read_line/2` returns `:eof` bypassing validation
- Test error scenarios that convert to `:eof`

### Step 3: Document Error-to-EOF Conversion (C2)

Update moduledoc and function docs to explain:
- `{:error, reason}` from `IO.gets` is converted to `:eof`
- This is intentional for simplified error handling
- The distinction rarely matters in practice

### Step 4: Add Security Documentation (S1)

Add a "Security Considerations" section to moduledoc:
- Input length: limited by shell/system, not this module
- Input sanitization: application's responsibility
- No special character filtering

### Step 5: Add Non-Behaviour Documentation (S2)

Add explicit note near top of moduledoc explaining:
- This is NOT a behaviour implementation
- Contrast with Input.Raw and Input.TTY
- Standalone utility for line-based input

### Step 6: Document Input Length Limitation (C3)

Add note in "Important Notes" section about:
- No input length limits enforced
- Relies on shell/terminal limits
- Application should validate if needed

---

## Success Criteria

- [x] All tests pass (30 tests, 0 failures)
- [x] EOF scenarios have test coverage
- [x] Documentation clearly explains error handling
- [x] Security considerations documented
- [x] Non-behaviour nature clearly explained
- [x] Test helper reduces code duplication

---

## Files to Modify

| File | Changes |
|------|---------|
| `lib/term_ui/input/line_reader.ex` | Documentation updates (C2, C3, S1, S2) |
| `test/term_ui/input/line_reader_test.exs` | Add EOF tests (C1), extract helper (S3) |
