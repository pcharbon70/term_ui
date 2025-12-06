# Feature: Phase 4 Task 4.2.1 - Create Raw Input Module

**Branch:** `feature/phase-04-task-4.2.1-raw-input`
**Base:** `multi-renderer`
**Date:** 2025-12-06
**Status:** Complete

## Overview

Create the `TermUI.Input.Raw` module that implements the `TermUI.Input` behaviour for raw mode input. This module provides a simplified interface for polling input when the Raw backend is active.

## Scope

### Task 4.2.1: Create Raw Input Module

- [x] 4.2.1.1 Create `lib/term_ui/input/raw.ex` with `@behaviour TermUI.Input`
- [x] 4.2.1.2 Add `@moduledoc` explaining this handler wraps InputReader
- [x] 4.2.1.3 Document that it supports non-blocking input with timeout

### Related from Task 4.2.2 and 4.2.3 (implementing together)

- [x] Implement `poll/2` callback accepting state and timeout
- [x] Parse escape sequences using `TermUI.Terminal.EscapeParser`
- [x] Return `{:ok, event}` for keyboard input
- [x] Return `:timeout` when no input within timeout
- [x] Implement `mode/1` returning `:raw`

### Unit Tests

- [x] Test `poll/2` returns `{{:ok, event}, state}` format
- [x] Test `poll/2` returns `{:timeout, state}` when no input
- [x] Test `mode/1` returns `:raw`
- [x] Test escape sequences parse to correct key events

---

## Implementation Plan

### Design Decision: Direct Input vs Wrapping InputReader

The existing `TermUI.Terminal.InputReader` is a GenServer that asynchronously sends events to a target process. However, the `TermUI.Input` behaviour requires synchronous `poll/2` semantics.

**Approach:** Create a new module that uses the same underlying input reading technique (spawned process with `IO.getn`) but provides synchronous polling with timeout support. This is similar to how the Raw backend's `poll_event/2` works.

### Phase 1: Create Raw Input Module

**File:** `lib/term_ui/input/raw.ex`

1. Define state struct with:
   - `buffer` - Partial escape sequence buffer
   - `reader_task` - Optional Task for async input reading

2. Implement `new/0` to create initial state

3. Implement `poll/2`:
   - First check buffer for complete events
   - If no complete event, spawn Task to read with timeout
   - Use `Task.yield/2` with timeout for non-blocking behavior
   - Parse with `EscapeParser`
   - Return appropriate result tuple

4. Implement `mode/1`:
   - Simply return `:raw`

### Phase 2: Unit Tests

**File:** `test/term_ui/input/raw_test.exs`

1. Test module implements behaviour
2. Test state initialization
3. Test `mode/1` returns `:raw`
4. Test `poll/2` return format (will need mocking for actual input)
5. Test escape sequence parsing integration

---

## Technical Details

### State Structure

```elixir
defstruct [
  :buffer,      # Binary buffer for partial escape sequences
  :reader_task  # Task.t() | nil for async input reading
]
```

### Dependencies

- `TermUI.Input` - Behaviour definition
- `TermUI.Terminal.EscapeParser` - Escape sequence parsing
- `TermUI.Event` - Event types

---

## Success Criteria

- [x] `TermUI.Input.Raw` module compiles without warnings
- [x] Module implements `TermUI.Input` behaviour
- [x] `poll/2` handles timeout correctly
- [x] `mode/1` returns `:raw`
- [x] All unit tests pass (38 tests)
- [x] No new compilation warnings

---

## Files to Create

| File | Purpose |
|------|---------|
| `lib/term_ui/input/raw.ex` | Raw input handler |
| `test/term_ui/input/raw_test.exs` | Unit tests |
