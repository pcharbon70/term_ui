# Feature: Phase 4 Section 4.6 - Integration Tests

**Branch:** `feature/phase-04-section-4.6-integration-tests`
**Base:** `multi-renderer`
**Date:** 2025-12-06
**Status:** Complete

## Overview

Create integration tests that verify the input abstraction layer works correctly with both backends. These tests ensure the Input.Selector, Input.Raw, Input.TTY, and LineReader modules work together as a cohesive system.

## Scope

### Task 4.6.1: Input Mode Selection Tests

Test input handler selection based on backend mode.

- [x] 4.6.1.1 Test Raw handler selected when backend is raw
- [x] 4.6.1.2 Test TTY handler selected when backend is tty

### Task 4.6.2: Input Equivalence Tests

Test that both input handlers produce equivalent results.

- [x] 4.6.2.1 Test arrow key produces same event in both modes
- [x] 4.6.2.2 Test Enter key produces same event in both modes
- [x] 4.6.2.3 Test Tab key produces same event in both modes
- [x] 4.6.2.4 Test printable characters produce same events

### Task 4.6.3: Line Reader Tests

Test line reader for TextInput.Line usage.

- [x] 4.6.3.1 Test line input with shell editing
- [x] 4.6.3.2 Test validation callback works
- [x] 4.6.3.3 Test EOF handling

---

## Implementation Plan

### Step 1: Create Integration Test File

Create `test/integration/input_abstraction_test.exs` following the pattern of existing integration tests:
- Use `async: false` since we're testing global state
- Set up proper cleanup in `on_exit` callback
- Group tests by task number

### Step 2: Implement Mode Selection Tests (4.6.1)

Test that Input.Selector correctly maps backend modes to input handlers:
- `select(:raw)` returns `TermUI.Input.Raw`
- `select(:tty)` returns `TermUI.Input.TTY`
- `select/0` auto-detects based on Backend.Selector

### Step 3: Implement Equivalence Tests (4.6.2)

Test that both handlers produce identical Event structs for the same input:
- Parse escape sequences in both Raw and TTY states
- Compare resulting Event structs for equality
- Test arrow keys, Enter, Tab, and printable characters

### Step 4: Implement LineReader Integration Tests (4.6.3)

Test LineReader works correctly with mocked IO:
- Use CaptureIO to test line input
- Verify validation callbacks work
- Test EOF handling

---

## Test Strategy

### Mode Selection Tests

These are straightforward unit-like integration tests that verify the Selector module works with the Input handlers:

```elixir
test "selector returns Raw for :raw mode" do
  handler = Input.Selector.select(:raw)
  assert handler == TermUI.Input.Raw
  state = handler.new()
  assert handler.mode(state) == :raw
end
```

### Equivalence Tests

These tests verify both handlers produce identical events. Since we can't easily mock IO.getn for both, we'll:
1. Create handler states
2. Manually populate buffers with escape sequences
3. Parse and compare results

```elixir
test "arrow up produces same event in both modes" do
  raw_state = %Raw{buffer: "\e[A"}
  tty_state = %TTY{buffer: "\e[A"}

  {{:ok, raw_event}, _} = Raw.poll(raw_state, 0)
  {{:ok, tty_event}, _} = TTY.poll(tty_state, 0)

  assert raw_event == tty_event
end
```

### LineReader Tests

Use ExUnit.CaptureIO to test line reading:

```elixir
test "read_line returns input" do
  result = capture_io([input: "test input\n"], fn ->
    result = LineReader.read_line("prompt: ")
    send(self(), {:result, result})
  end)

  assert_receive {:result, {:ok, "test input"}}
end
```

---

## Success Criteria

- [x] All integration tests pass (27 new tests, 177 total integration tests)
- [x] Mode selection tests verify Selector works with handlers
- [x] Equivalence tests prove Raw and TTY produce same events
- [x] LineReader tests verify line input functionality
- [x] Tests follow existing integration test patterns

---

## Files to Create/Modify

| File | Action |
|------|--------|
| `test/integration/input_abstraction_test.exs` | Create |
| `notes/planning/multi-renderer/phase-04-input-abstraction.md` | Update task status |
