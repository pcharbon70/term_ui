# Feature: Phase 4 Task 4.4.1 - Create Line Reader Module

**Branch:** `feature/phase-04-task-4.4.1-line-reader`
**Base:** `multi-renderer`
**Date:** 2025-12-06
**Status:** Complete

## Overview

Create the `TermUI.Input.LineReader` module for line-based input using `IO.gets/1`. This module is specifically designed for the `TextInput.Line` widget, which benefits from shell line editing features.

## Scope

### Task 4.4.1: Create Line Reader Module

- [x] 4.4.1.1 Create `lib/term_ui/input/line_reader.ex` with `@moduledoc`
- [x] 4.4.1.2 Document that this is for TextInput.Line only
- [x] 4.4.1.3 Document that it uses shell line editing

### Additional Tasks (implementing full Section 4.4)

Since this is a small module, implementing Tasks 4.4.2 and 4.4.3 together:

- [x] 4.4.2 Implement `read_line/1` with prompt
- [x] 4.4.3 Implement `read_line/2` with validation

## Implementation Plan

### Step 1: Create Module Structure

1. Create `lib/term_ui/input/line_reader.ex`
2. Add comprehensive `@moduledoc` explaining:
   - Purpose: line-based input for TextInput.Line widget
   - Uses `IO.gets/1` for shell line editing
   - Features: backspace, cursor movement, history (if shell supports)
   - When to use vs character mode

### Step 2: Implement read_line/1

1. Accept optional prompt string
2. Call `IO.gets(prompt)`
3. Trim trailing newline
4. Return `{:ok, line}` or `:eof`

### Step 3: Implement read_line/2 with Validation

1. Accept prompt and validator function
2. Read line using `IO.gets/1`
3. Apply validator: `validator.(input)`
4. Return `{:ok, line}` if valid, `{:error, reason}` if invalid

### Step 4: Write Unit Tests

Test file: `test/term_ui/input/line_reader_test.exs`
1. Test `read_line/1` returns trimmed input
2. Test `read_line/1` returns `:eof` on EOF
3. Test `read_line/2` applies validator
4. Test `read_line/2` returns error on validation failure
5. Documentation presence tests

---

## Key Design Decisions

### Not a Behaviour Implementation

Unlike `Input.Raw` and `Input.TTY`, LineReader does NOT implement the `TermUI.Input` behaviour. It's a standalone utility module for line-based input, not character-based polling.

### Simple API

- `read_line/1` - Basic line reading with optional prompt
- `read_line/2` - Line reading with validation function

### Validation Function Contract

The validator function should:
- Accept a string (the trimmed input)
- Return `:ok` or `{:ok, transformed_value}` for valid input
- Return `{:error, reason}` for invalid input

---

## Success Criteria

- [x] Module compiles without warnings
- [x] `read_line/1` reads line and trims newline
- [x] `read_line/2` validates input correctly
- [x] Documentation explains TextInput.Line usage
- [x] All unit tests pass (27 tests, 0 failures)
- [x] No compilation warnings

---

## Files to Create/Modify

| File | Action |
|------|--------|
| `lib/term_ui/input/line_reader.ex` | Create |
| `test/term_ui/input/line_reader_test.exs` | Create |
| `notes/planning/multi-renderer/phase-04-input-abstraction.md` | Update task status |
