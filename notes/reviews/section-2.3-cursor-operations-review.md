# Code Review: Section 2.3 - Cursor Operations

**Date:** 2025-12-05
**Reviewers:** Factual, QA, Senior Engineer, Security, Consistency, Redundancy, Elixir
**Files Reviewed:**
- `lib/term_ui/backend/raw.ex` (lines 370-499, 425-449)
- `lib/term_ui/renderer/cursor_optimizer.ex`
- `test/term_ui/backend/raw_test.exs` (lines 395-658)
- `notes/planning/multi-renderer/phase-02-raw-backend.md` (Section 2.3)

---

## Executive Summary

Section 2.3 implements cursor operations (`move_cursor/2`, `hide_cursor/1`, `show_cursor/1`) with cursor position optimization. The implementation is **complete and well-designed**, following established patterns from Section 2.2. All planned subtasks are implemented and tested.

**Overall Assessment:** APPROVE with minor suggestions

| Category | Status |
|----------|--------|
| Implementation vs Plan | ✅ Complete |
| Test Coverage | ✅ Strong (87/100) |
| Architecture | ✅ Well-designed |
| Security | ✅ No blockers |
| Consistency | ✅ Follows patterns |
| Code Quality | ✅ Idiomatic Elixir |

---

## Findings by Category

### 🚨 Blockers (Must Fix Before Merge)

**None identified.** All reviewers agree the implementation is ready for integration.

---

### ⚠️ Concerns (Should Address or Document)

#### 1. Missing Bounds Validation in move_cursor/2 (Security, Senior Engineer)

**Location:** `raw.ex:413-423`

The function accepts positions beyond terminal bounds without validation:

```elixir
def move_cursor(state, {row, col} = position)
    when is_integer(row) and is_integer(col) and row > 0 and col > 0 do
```

**Issue:** Positions like `{100, 200}` on a 24x80 terminal are accepted. The documentation claims clamping occurs but no clamping code exists.

**Impact:**
- State-Reality divergence: `state.cursor_position = {100, 200}` but actual cursor at `{24, 80}`
- Subsequent optimization calculations use wrong starting position

**Recommendation:** Either:
1. Add bounds validation using existing `valid_position?/2`
2. Document that bounds checking is caller's responsibility

---

#### 2. Test Coverage Gap: No Output Verification (QA)

**Location:** `raw_test.exs:395-544`

Tests verify state updates but don't verify actual ANSI sequences written to terminal.

**Impact:**
- Could hide bugs in `generate_cursor_sequence/3` or optimizer integration
- No verification that optimizer actually selects relative vs absolute moves

**Recommendation:** Consider adding tests that capture/verify output sequences for critical paths.

---

#### 3. CursorOptimizer Error Path (Senior Engineer)

**Location:** `raw.ex:427-435`

```elixir
{sequence, _cost} = CursorOptimizer.optimal_move(from_row, from_col, to_row, to_col)
```

No error handling if `CursorOptimizer.optimal_move/4` fails.

**Impact:** Low risk since CursorOptimizer is well-tested, but no recovery path exists.

**Recommendation:** Add rescue clause with fallback to absolute positioning.

---

#### 4. Idempotent Semantics Documentation (Senior Engineer, Consistency)

**Location:** `raw.ex:461-464, 486-489`

Idempotent operations return the **same state object** when already in desired state. Callers cannot distinguish no-op from actual operation.

**Recommendation:** Document this behavior in `@doc`:
```
Note: When cursor is already in the desired state, returns the input state
unchanged without emitting escape sequences (idempotent).
```

---

#### 5. Integer Overflow in CursorOptimizer (Security)

**Location:** `cursor_optimizer.ex:99-101`

```elixir
def advance(%__MODULE__{} = optimizer, cols) do
  %{optimizer | col: optimizer.col + cols}
end
```

No bounds checking on column sum. Extreme values could produce malformed sequences.

**Impact:** Low - requires malicious input at API boundary.

**Recommendation:** Add reasonable bounds constant (`@max_cursor_pos 9999`).

---

### 💡 Suggestions (Nice to Have)

#### 1. Function Clause Ordering (Elixir)

**Location:** `raw.ex:427-449`

Convention suggests ordering clauses from most specific to general. Current order works but unconventional:
- Current: `{tuple}`, `nil`, `false`
- Suggested: `nil`, `{tuple}`, `false`

---

#### 2. Consolidate generate_cursor_sequence Clauses (Redundancy)

**Location:** `raw.ex:437-449`

Clauses 2 and 3 both return `ANSI.cursor_position(row, col)`:

```elixir
# Line 437-444: cursor_position: nil
ANSI.cursor_position(row, col)

# Line 446-449: optimize_cursor: false
ANSI.cursor_position(row, col)
```

Could consolidate into single clause handling "optimization not applicable".

---

#### 3. Test Helper for State Preservation (Redundancy)

**Location:** `raw_test.exs:431-440, 578-587, 620-628`

Same "preserves other state fields" assertion pattern repeated 3+ times. Consider helper:

```elixir
defp assert_state_unchanged_except(original, updated, changed_fields) do
  # Assert all fields except changed_fields are equal
end
```

---

#### 4. Add Sequence Instrumentation (Senior Engineer)

Consider optional telemetry for optimization metrics:

```elixir
:telemetry.execute([:term_ui, :cursor, :move], %{
  from: {from_row, from_col},
  to: {to_row, to_col},
  bytes_saved: naive_cost - actual_cost
})
```

---

#### 5. Cross-Reference Documentation (Consistency)

Add "See Also" sections linking `move_cursor/2`, `hide_cursor/1`, and `show_cursor/1`.

---

#### 6. Large Distance Fallback Test (QA)

Add test verifying optimizer falls back to absolute positioning for large moves:

```elixir
test "optimizer uses absolute for long horizontal moves" do
  {:ok, state} = Raw.init(size: {24, 80}, optimize_cursor: true)
  {:ok, state2} = Raw.move_cursor(state, {10, 10})
  {:ok, state3} = Raw.move_cursor(state2, {10, 70})  # 60 columns - should use absolute
end
```

---

### ✅ Good Practices Noticed

#### 1. Idempotent Pattern Implementation (All Reviewers)

**Location:** `raw.ex:461-474, 486-499`

Gold-standard idempotent pattern using function clause matching:

```elixir
def hide_cursor(%__MODULE__{cursor_visible: false} = state) do
  {:ok, state}  # No-op if already hidden
end

def hide_cursor(state) do
  write_to_terminal(ANSI.cursor_hide())
  {:ok, %{state | cursor_visible: false}}
end
```

Prevents redundant ANSI writes while maintaining consistent state.

---

#### 2. Guard Clause Usage (Elixir, Consistency)

**Location:** `raw.ex:413-414`

Excellent guard clause placement:

```elixir
def move_cursor(state, {row, col} = position)
    when is_integer(row) and is_integer(col) and row > 0 and col > 0 do
```

- Simultaneous destructuring and binding
- Type enforcement at function head
- Fast-fail for invalid input

---

#### 3. CursorOptimizer Integration (Senior Engineer)

**Location:** `raw.ex:427-449`

Clean delegation to `CursorOptimizer` maintains separation of concerns:
- Raw backend handles I/O
- CursorOptimizer handles algorithm

---

#### 4. Comprehensive Test Coverage (QA)

- 28+ tests for cursor operations
- Idempotency tests for hide/show
- Round-trip cycle tests
- Guard clause enforcement tests
- State preservation tests
- Edge case handling (nil cursor_position)

---

#### 5. @impl true Annotations (Consistency)

All three callbacks properly marked as behaviour implementations.

---

#### 6. Error-Safe I/O Writing (Security)

**Location:** `raw.ex:687-691`

```elixir
defp write_to_terminal(data) do
  IO.write(data)
rescue
  _ -> :ok
end
```

Prevents I/O errors from crashing backend.

---

#### 7. Documentation Quality (All Reviewers)

Comprehensive `@doc` blocks with:
- Purpose and behavior
- Cursor optimization explanation
- ANSI sequence details
- Examples

---

## Implementation vs Planning Verification

| Task | Status | Evidence |
|------|--------|----------|
| 2.3.1.1 Implement move_cursor/2 | ✅ | Lines 412-423 |
| 2.3.1.2 Generate cursor sequence | ✅ | Lines 416, 427-449 |
| 2.3.1.3 Write to stdout | ✅ | Line 417 |
| 2.3.1.4 Update cursor_position | ✅ | Line 420 |
| 2.3.1.5 Return {:ok, state} | ✅ | Line 422 |
| 2.3.2.1 Implement hide_cursor | ✅ | Lines 466-473 |
| 2.3.2.2 Update cursor_visible false | ✅ | Line 471 |
| 2.3.2.3 Implement show_cursor | ✅ | Lines 491-498 |
| 2.3.2.4 Update cursor_visible true | ✅ | Line 496 |
| 2.3.2.5 Make idempotent | ✅ | Lines 461-464, 486-489 |
| 2.3.3.1-4 Cursor optimization | ✅ | Lines 427-449, CursorOptimizer integration |

**All 15 subtasks verified complete.**

---

## Test Coverage Summary

| Test Category | Count | Coverage |
|---------------|-------|----------|
| move_cursor/2 basic | 10 | ✅ Complete |
| Cursor optimization | 8 | ✅ Good |
| hide_cursor/1 | 4 | ✅ Complete |
| show_cursor/1 | 4 | ✅ Complete |
| Round-trip cycles | 2 | ✅ Complete |
| **Total** | **28** | **87/100** |

**Gap:** Output sequence verification not implemented (tests verify state, not output).

---

## Recommendations Summary

### Must Address (Before Next Section)

1. **Document bounds checking contract** - Clarify whether Raw backend or caller is responsible

### Should Address (When Convenient)

2. Add idempotent behavior note to cursor visibility docs
3. Consider error handling for CursorOptimizer integration

### Nice to Have (Future)

4. Add telemetry for optimization metrics
5. Test helper for state preservation assertions
6. Consolidate generate_cursor_sequence clauses

---

## Conclusion

Section 2.3 is **well-implemented** with strong adherence to the planning document and established codebase patterns. The cursor operations demonstrate idiomatic Elixir with excellent use of pattern matching, guard clauses, and idempotent design.

The main concern is **bounds validation** - the current implementation accepts out-of-bounds positions which could cause state divergence. This should be documented or fixed before moving to Section 2.4.

**Verdict:** Ready for integration with documentation clarification on bounds checking.
