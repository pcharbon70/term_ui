# TextInput.Line Widget - Feature Plan

## Overview

Complete Section 5.1 of the multi-renderer plan by adding comprehensive unit tests for the `TextInput.Line` widget.

**Branch**: `feature/text-input-line-tests`
**Base Branch**: `multi-renderer`
**Plan Reference**: `notes/planning/multi-renderer/phase-05-widget-adaptation.md` (Section 5.1)

## Problem Statement

The `TextInput.Line` widget implementation is complete, but the unit test section (5.1 Unit Tests) in the Phase 5 plan is marked incomplete. We need to:
1. Verify existing tests cover all requirements
2. Add missing tests for EOF/cancellation behavior
3. Add edge case tests
4. Mark Phase 5.1 as complete in the planning document

## Current Status

### Implementation (COMPLETE)
- **File**: `lib/term_ui/widgets/text_input/line.ex` (661 lines)
- All tasks 5.1.1 through 5.1.5 are complete

### Existing Tests (NEEDS REVIEW)
- **File**: `test/term_ui/widgets/text_input/line_test.exs` (530 lines)
- 50 tests, 0 failures
- Tests cover: initialization, rendering, input reading, validation, focus behavior

## Implementation Plan

### Step 1: Review Existing Tests
Verify that existing tests cover all Phase 5.1 requirements:
- [ ] Test TextInput.Line initializes with default state
- [ ] Test rendering includes label and prompt
- [ ] Test `read/1` returns entered value (mock LineReader)
- [ ] Test validator is applied to input
- [ ] Test invalid input returns error with message

### Step 2: Add Missing Tests

#### 2.1 EOF and Cancellation Tests
```elixir
describe "EOF and cancellation" do
  test "read/1 returns :eof when stream ends"
  test "handle_focus/1 returns :cancelled on EOF"
  test "cancelled state is tracked properly"
  test "on_blur is called even when cancelled"
end
```

#### 2.2 Edge Case Tests
```elixir
describe "edge cases" do
  test "handles empty string validator"
  test "handles validator that returns {:ok, transformed}"
  test "handles very long input lines"
  test "handles unicode characters"
  test "handles special characters"
end
```

### Step 3: Update Planning Document
Mark section 5.1 unit tests as complete in `notes/planning/multi-renderer/phase-05-widget-adaptation.md`

### Step 4: Create Summary Document
Write summary to `notes/summaries/phase-05-task-5.1-unit-tests.md`

## Testing Strategy

### Current Test Structure
```
- new/1 (3 tests)
- init/1 (2 tests)
- get_value/1 (2 tests)
- set_value/2 (2 tests)
- clear/1 (2 tests)
- error handling (5 tests)
- accessors (4 tests)
- read/1 without validator (3 tests)
- read/1 with validator (3 tests)
- type specifications (2 tests)
- documentation (4 tests)
- render/1 (8 tests)
- focus behavior (10 tests)
```

### Mocking Approach
Use `ExUnit.CaptureIO` to mock stdin:
```elixir
capture_io([input: "test\n", capture_prompt: false], fn ->
  Line.read(state)
end)
```

## Success Criteria

1. All tests pass: `mix test test/term_ui/widgets/text_input/line_test.exs`
2. Coverage > 90% for TextInput.Line module
3. Phase 5.1 marked complete in planning document
4. Summary document created

## Critical Files

- `lib/term_ui/widgets/text_input/line.ex` - Widget implementation
- `test/term_ui/widgets/text_input/line_test.exs` - Tests to modify
- `lib/term_ui/input/line_reader.ex` - Input backend (reference)
- `notes/planning/multi-renderer/phase-05-widget-adaptation.md` - Update completion status

## Progress

- [x] Create feature branch
- [x] Step 1: Review existing tests
- [x] Step 2: Add missing tests
- [x] Step 3: Update planning document
- [x] Step 4: Create summary document
