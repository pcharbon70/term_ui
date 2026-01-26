# Section 4.2 (Raw Input Handler) - Comprehensive Review

**Date:** 2025-12-06
**Files Reviewed:**
- `lib/term_ui/input/raw.ex`
- `test/term_ui/input/raw_test.exs`

**Reviewers:** Factual, QA, Architecture, Security, Consistency, Redundancy, Elixir

---

## Summary

The `TermUI.Input.Raw` module is a well-designed, production-quality implementation of the Input behaviour. The code demonstrates excellent Elixir practices with comprehensive documentation and testing. However, there are **security concerns** around unbounded buffer growth and some **code quality issues** that should be addressed.

---

## 🚨 Blockers (Must Fix)

### B1. Unbounded Buffer Growth - Memory Exhaustion Risk
**Source:** Security Review
**Location:** `lib/term_ui/input/raw.ex:53-54, 254`
**Severity:** HIGH

The `buffer` field has no size limits. A malicious actor could send continuous incomplete escape sequences, causing unbounded memory growth until OOM crash.

**Evidence:** The codebase already has `TermUI.Backend.InputBuffer` with 64KB limits and rate-limited logging for this exact scenario, but `Input.Raw` doesn't use it.

**Fix:** Apply buffer size limit:
```elixir
@max_buffer_size 65_536  # 64KB, matching InputBuffer

# In do_read_with_timeout after line 254:
new_buffer = state.buffer <> data
{new_buffer, _truncated} = InputBuffer.apply_limit(new_buffer, max_size: @max_buffer_size)
```

### B2. Unused `reader_task` Field - Dead Code
**Source:** Architecture, Consistency, Elixir Reviews
**Location:** `lib/term_ui/input/raw.ex:55, 62, 82`

The state struct defines `reader_task` field but it's never used - always `nil`. Tasks are created inline in `do_read_with_timeout/2` and never stored.

**Fix:** Remove the field or document why it exists:
```elixir
defstruct buffer: <<>>,
          event_queue: []
          # Remove reader_task
```

### B3. Dead Code in `try_parse_buffer/1`
**Source:** Architecture, Elixir Reviews
**Location:** `lib/term_ui/input/raw.ex:161-169`

Both branches return `:need_more`, making the conditional pointless:
```elixir
{[], remaining} ->
  if EscapeParser.partial_sequence?(remaining) do
    :need_more  # Same as else branch
  else
    :need_more
  end
```

**Fix:** Simplify to `{[], _remaining} -> :need_more`

---

## ⚠️ Concerns (Should Address)

### C1. Missing Test Coverage for Critical Paths
**Source:** QA Review
**Priority:** Medium-High

Untested code paths:
1. `handle_escape_timeout/2` (lines 177-201) - Core escape timeout logic
2. `emit_partial_escape/2` (lines 204-243) - All four branches
3. EOF handling path (line 275)
4. IO error handling (line 275-276)
5. Task timeout behavior

**Fix:** Add tests for these paths (may require dependency injection for IO mocking)

### C2. Architectural Deviation from Plan
**Source:** Factual Review
**Priority:** Medium

Plan Task 4.2.2.2 says "Delegate to InputReader's polling mechanism", but implementation uses direct `IO.getn/2` with Tasks instead.

**Justification:** This is correct - InputReader is async GenServer, incompatible with sync polling. The deviation is an improvement.

**Fix:** Update planning document to reflect actual (superior) implementation.

### C3. Code Duplication with Backend.Raw
**Source:** Redundancy Review
**Priority:** Medium

Three areas of significant duplication:
1. `read_char/0` vs `Backend.Raw.read_one_byte/0` vs `Backend.TTY.read_input_char/0`
2. Task-based timeout pattern in both modules
3. Escape timeout handling in 3 modules

**Suggestion:** Consider extracting to shared modules:
- `TermUI.Terminal.IO.read_byte/0`
- `TermUI.Terminal.IO.read_with_timeout/1`
- `TermUI.Terminal.EscapeSequence.emit_partial/1`

### C4. Silent Error Swallowing
**Source:** Security, Elixir Reviews
**Location:** `lib/term_ui/input/raw.ex:275`

IO errors are silently converted to EOF:
```elixir
{:ok, {:error, _reason}} -> {:eof, state}
```

**Suggestion:** Add debug logging:
```elixir
{:ok, {:error, reason}} ->
  Logger.debug("Input read error: #{inspect(reason)}")
  {:eof, state}
```

### C5. Return Format Inconsistency
**Source:** Consistency Review

`Input.Raw.poll/2` returns mixed tuple formats:
- `{{:ok, event}, state}` - nested tuple for success
- `{:timeout, state}` - flat tuple for timeout
- `{:eof, state}` - flat tuple for EOF

This differs from `Backend.Raw.poll_event/2` which uses 3-element tuples consistently.

**Note:** This matches the `TermUI.Input` behaviour definition, so it's correct but worth documenting.

---

## 💡 Suggestions (Nice to Have)

### S1. Add Event Queue Size Limit
**Source:** Security Review

The `event_queue` can grow unbounded when parsing many characters at once.

```elixir
@max_queue_size 1000
queued_events = Enum.take(rest_events, @max_queue_size)
```

### S2. Document Escape Timeout Constant
**Source:** Architecture, Consistency Reviews
**Location:** Line 51

Add comment explaining why 50ms:
```elixir
# Timeout for escape sequence completion (ms).
# Matches terminal emulator behavior for distinguishing ESC key from sequences.
@escape_timeout 50
```

### S3. Extract Magic Numbers to Module Attributes
**Source:** Elixir Review

Define constants for escape bytes:
```elixir
@esc 0x1B
@left_bracket ?[
@letter_O ?O
```

### S4. Use `with` for Nested Cases
**Source:** Elixir Review
**Location:** `handle_escape_timeout/2`

Flatten nested case with `with` for readability.

### S5. Add Integration Tests (Tagged)
**Source:** Architecture Review

Add tests that actually test timeout behavior:
```elixir
@tag :requires_terminal
test "handles actual timeout with no input" do
  state = Raw.new()
  {result, _state} = Raw.poll(state, 100)
  assert result == :timeout
end
```

### S6. Improve Task Cleanup Pattern
**Source:** Elixir Review

Make Task.shutdown explicit:
```elixir
case Task.yield(task, timeout) do
  {:ok, result} -> handle_result(result, state)
  nil ->
    Task.shutdown(task)
    {:timeout, state}
end
```

---

## ✅ Good Practices Noticed

1. **Excellent Documentation** - Comprehensive moduledoc with examples, comparison section, implementation details
2. **Clean Behaviour Implementation** - Proper `@behaviour` and `@impl` usage
3. **Smart Event Queue Design** - Minimizes blocking reads through priority handling
4. **Proper EscapeParser Delegation** - Clean integration with existing module
5. **Sophisticated Escape Timeout Logic** - Correctly handles ambiguous ESC sequences
6. **Comprehensive Error Handling** - All edge cases covered in `read_char/0`
7. **Strong Test Coverage** - 38 tests covering behaviour, state, docs
8. **Type Safety** - Complete typespecs matching behaviour
9. **Zero Compilation Warnings** - Clean build
10. **Idiomatic Pattern Matching** - Excellent binary pattern matching for escape sequences

---

## Test Coverage Assessment

| Area | Coverage | Notes |
|------|----------|-------|
| Public API | 100% | All 3 functions tested |
| Happy paths | 95% | Extensive escape sequence tests |
| Edge cases | 40% | Missing timeout/error paths |
| Error handling | 0% | No error scenario tests |
| Private functions | 30% | Indirect testing only |

**Overall:** ~55% functional coverage (adequate for happy path, needs work for production)

---

## Action Items

### Before Production:
1. [ ] **B1** - Add buffer size limit using InputBuffer pattern
2. [ ] **B2** - Remove unused `reader_task` field
3. [ ] **B3** - Fix dead code in `try_parse_buffer/1`
4. [ ] **C1** - Add tests for escape timeout and error paths

### Should Address:
5. [ ] **C2** - Update planning doc Task 4.2.2.2
6. [ ] **C4** - Add debug logging for IO errors
7. [ ] **S2** - Document escape timeout constant

### Future Improvements:
8. [ ] **C3** - Extract shared IO/escape utilities
9. [ ] **S1** - Add event queue size limit
10. [ ] **S5** - Add integration tests

---

## Conclusion

The `TermUI.Input.Raw` module is **architecturally sound** and demonstrates **high code quality**. The main concerns are:

1. **Security** - Buffer overflow risk (critical)
2. **Code Quality** - Dead code/unused field (medium)
3. **Testing** - Missing error path coverage (medium)

With the blockers addressed, this code is production-ready. The architectural decisions are correct, the Elixir idioms are well-applied, and the documentation is excellent.

**Recommendation:** Address blockers B1-B3 and concern C1 before considering Phase 4 complete.
