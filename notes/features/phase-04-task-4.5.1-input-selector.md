# Feature: Phase 4 Task 4.5.1 - Create Input Selector Module

**Branch:** `feature/phase-04-task-4.5.1-input-selector`
**Base:** `multi-renderer`
**Date:** 2025-12-06
**Status:** Complete

## Overview

Create the `TermUI.Input.Selector` module that chooses the appropriate input handler based on the active backend mode. This module bridges the gap between backend selection and input handling.

## Scope

### Task 4.5.1: Create Input Selector Module

- [x] 4.5.1.1 Create `lib/term_ui/input/selector.ex` with `@moduledoc`
- [x] 4.5.1.2 Document automatic selection based on backend mode

### Task 4.5.2: Implement Selection Functions

- [x] 4.5.2.1 Implement `select/0` that queries current backend mode
- [x] 4.5.2.2 Return `TermUI.Input.Raw` for `:raw` mode
- [x] 4.5.2.3 Return `TermUI.Input.TTY` for `:tty` mode
- [x] 4.5.2.4 Implement `select/1` for explicit mode selection

### Unit Tests

- [x] Test `select/0` returns Raw for raw backend mode
- [x] Test `select/0` returns TTY for tty backend mode
- [x] Test `select(:raw)` returns Raw
- [x] Test `select(:tty)` returns TTY

---

## Implementation Plan

### Step 1: Create Module Structure

Create `lib/term_ui/input/selector.ex` with:
- Comprehensive `@moduledoc` explaining the purpose
- Document the relationship with `Backend.Selector`
- Type definitions for return values

### Step 2: Implement select/1 (Explicit Selection)

Simple function that maps mode atoms to modules:
- `:raw` -> `TermUI.Input.Raw`
- `:tty` -> `TermUI.Input.TTY`
- Invalid mode -> raise `ArgumentError`

### Step 3: Implement select/0 (Auto Selection)

Query the current backend mode:
- Option A: Use Application environment (if runtime stores mode there)
- Option B: Use a registry or process dictionary
- Option C: Accept a state parameter that contains mode info

Need to check how Runtime tracks the current backend mode.

### Step 4: Write Unit Tests

Create `test/term_ui/input/selector_test.exs`:
- Test `select/1` with `:raw` and `:tty`
- Test `select/1` with invalid mode
- Test `select/0` (may need mocking for backend state)
- Documentation tests

---

## Key Design Decision

### How to Query Backend Mode

The `select/0` function needs to know which backend is active. Options:

1. **Query TermUI.Runtime** - The runtime process likely knows the backend mode
2. **Application env** - Store mode in application config at startup
3. **Accept parameter** - Make it `select/1` only, caller provides mode

Looking at the existing code, I need to find how the runtime tracks backend mode.

---

## Success Criteria

- [x] Module compiles without warnings
- [x] `select(:raw)` returns `TermUI.Input.Raw`
- [x] `select(:tty)` returns `TermUI.Input.TTY`
- [x] `select/0` returns appropriate handler based on backend
- [x] All unit tests pass (30 new tests, 150 total input tests)
- [x] Documentation is comprehensive

---

## Files to Create/Modify

| File | Action |
|------|--------|
| `lib/term_ui/input/selector.ex` | Create |
| `test/term_ui/input/selector_test.exs` | Create |
| `notes/planning/multi-renderer/phase-04-input-abstraction.md` | Update task status |
