# Feature: Phase 4 Task 4.3.1 - Create TTY Input Module

**Branch:** `feature/phase-04-task-4.3.1-tty-input`
**Base:** `multi-renderer`
**Date:** 2025-12-06
**Status:** Complete

## Overview

Create the `TermUI.Input.TTY` module implementing the `TermUI.Input` behaviour for TTY mode input. This module provides character-by-character input using `IO.getn/2` for applications running with the TTY backend.

## Scope

### Task 4.3.1: Create TTY Input Module

- [x] 4.3.1.1 Create `lib/term_ui/input/tty.ex` with `@behaviour TermUI.Input`
- [x] 4.3.1.2 Add `@moduledoc` explaining `IO.getn/2` character input
- [x] 4.3.1.3 Document that arrow keys, Tab, etc. work normally

## Implementation Plan

### Step 1: Create Module Structure

1. Create `lib/term_ui/input/tty.ex`
2. Add `@behaviour TermUI.Input`
3. Define struct with `buffer` and `event_queue` fields (similar to Raw)
4. Add type definitions

### Step 2: Add Documentation

1. Add comprehensive `@moduledoc` explaining:
   - TTY mode character input using `IO.getn/2`
   - That single character reads work immediately (no Enter required)
   - Arrow keys, Tab, function keys work normally
   - Comparison with Raw input (blocking vs timeout support)
   - Usage examples

### Step 3: Implement Stub Functions

For Task 4.3.1, implement minimal stubs:
1. `new/0` - Create initial state
2. `poll/2` - Stub returning `:timeout` (full implementation in 4.3.2)
3. `mode/1` - Return `:tty`

### Step 4: Write Unit Tests

Test file: `test/term_ui/input/tty_test.exs`
1. Behaviour implementation tests
2. State initialization tests
3. Mode query tests
4. Documentation presence tests

---

## Key Design Decisions

### Similarity to Raw Input Handler

The TTY input handler will share significant structure with `Input.Raw`:
- Same struct fields: `buffer`, `event_queue`
- Same escape sequence parsing via `EscapeParser`
- Same event queue management

### Differences from Raw Input Handler

1. **Blocking I/O**: TTY mode uses blocking `IO.getn/2` without Task wrapping
2. **No timeout support**: The `timeout` parameter is noted but not honored
3. **Simpler implementation**: No Task spawning/yielding required

### Why Not Share Code?

While both handlers are similar, keeping them separate:
- Allows TTY-specific optimizations
- Keeps each implementation focused
- Avoids complex conditional logic
- Future C3 (shared utilities) can extract common patterns

---

## Success Criteria

- [x] Module compiles with `@behaviour TermUI.Input`
- [x] `new/0` creates valid initial state
- [x] `mode/1` returns `:tty`
- [x] Documentation explains TTY input approach
- [x] All unit tests pass (42 tests, 0 failures)
- [x] No compilation warnings

---

## Files to Create/Modify

| File | Action |
|------|--------|
| `lib/term_ui/input/tty.ex` | Create |
| `test/term_ui/input/tty_test.exs` | Create |
| `notes/planning/multi-renderer/phase-04-input-abstraction.md` | Update task status |
