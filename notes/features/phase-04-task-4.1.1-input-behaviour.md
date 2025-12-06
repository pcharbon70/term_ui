# Feature: Phase 4 Task 4.1.1 - Create Input Behaviour Module

**Branch:** `feature/phase-04-task-4.1.1-input-behaviour`
**Base:** `multi-renderer`
**Date:** 2025-12-06
**Status:** Complete

## Overview

Create the `TermUI.Input` behaviour module that establishes the contract for input reading. This provides a unified interface regardless of which backend is active.

## Scope

### Task 4.1.1: Create Input Behaviour Module

- [x] 4.1.1.1 Create `lib/term_ui/input.ex` with `@moduledoc` explaining the abstraction
- [x] 4.1.1.2 Document that both raw and TTY modes use character-by-character input
- [x] 4.1.1.3 Document that `LineReader` is only needed for TextInput.Line

### Unit Tests - Section 4.1 (partial)

- [x] Test behaviour module compiles with all callbacks defined
- [x] Test type specifications are valid
- [x] Test behaviour_info returns expected callbacks

---

## Implementation Plan

### Phase 1: Create Input Behaviour Module

**File:** `lib/term_ui/input.ex`

1. Create module with comprehensive `@moduledoc`:
   - Explain the input abstraction layer purpose
   - Document that both raw and TTY modes use `IO.getn/2` for character input
   - Document that `LineReader` module is only for `TextInput.Line` widget
   - Explain the difference between character mode and line mode

2. Define input result types (preparing for Task 4.1.2):
   - Reference `TermUI.Event.Key.t()` for key events
   - Define `input_result` type

3. Define callback signatures (preparing for Tasks 4.1.3-4.1.4):
   - `poll/2` callback for input polling
   - `mode/1` callback for querying input mode

### Phase 2: Unit Tests

**File:** `test/term_ui/input_test.exs`

1. Test that the behaviour module compiles
2. Test that `behaviour_info(:callbacks)` returns expected callbacks
3. Test that a mock module can implement the behaviour
4. Verify type specifications with dialyzer-friendly patterns

---

## Technical Details

### Key Insight from Plan

The key insight is that `IO.getn/2` works in both raw and TTY modes. The shell doesn't buffer single characters—it only provides line editing for `IO.gets/1`. This means most widgets work identically in both modes.

### Input Modes

- **Character mode**: `IO.getn/2` - immediate character input (most widgets)
- **Line mode**: `IO.gets/1` - shell line editing with Enter to submit (TextInput.Line only)

### Dependencies

- `TermUI.Event.Key` - Key event struct (already exists)
- `TermUI.Terminal.EscapeParser` - Escape sequence parsing (already exists)

---

## Success Criteria

- [x] `TermUI.Input` behaviour module compiles without warnings
- [x] Module has comprehensive documentation explaining the abstraction
- [x] Callback definitions are complete and well-typed
- [x] All unit tests pass (16 tests)
- [x] No new compilation warnings

---

## Files to Create

| File | Purpose |
|------|---------|
| `lib/term_ui/input.ex` | Input behaviour definition |
| `test/term_ui/input_test.exs` | Unit tests for input behaviour |

---

## Notes

### Design Decisions

1. **Behaviour over Protocol**: Using a behaviour because input handlers are module-based, not data-based. The handler module is selected once based on backend mode, not dispatched per-event.

2. **State Parameter**: The `poll/2` callback accepts state to allow handlers to maintain internal state (e.g., escape sequence buffer for TTY input).

3. **Timeout Semantics**: The timeout parameter is best-effort. TTY mode with `IO.getn` is blocking and cannot honor timeouts. Documentation will make this clear.
