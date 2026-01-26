# Feature: Phase 5 Task 5.1.1 - Create TextInput.Line Module

**Branch:** `feature/phase-05-task-5.1.1-runtime-input-integration`
**Base:** `multi-renderer`
**Date:** 2025-12-06
**Status:** Complete

## Overview

Create the `TextInput.Line` widget module, a TTY-friendly variant of TextInput that uses `IO.gets/1` for line-based input with shell line editing support.

## Scope

### Task 5.1.1: Create TextInput.Line Module

- [x] 5.1.1.1 Create `lib/term_ui/widgets/text_input/line.ex` with `@moduledoc`
- [x] 5.1.1.2 Document that this uses shell line editing via `IO.gets/1`
- [x] 5.1.1.3 Document use case: free-form text entry where shell editing is preferred
- [x] 5.1.1.4 Note: standard TextInput still works in TTY mode for character-by-character input

---

## Implementation Plan

### Step 1: Create Directory Structure

Create `lib/term_ui/widgets/text_input/` directory for TextInput variants.

### Step 2: Create TextInput.Line Module

Create the module with comprehensive `@moduledoc` explaining:
- Uses `TermUI.Input.LineReader` for shell line editing
- Useful when shell editing (backspace, cursor movement, history) is preferred
- Simpler than standard TextInput - just prompt/read/validate flow
- Standard TextInput still works in TTY mode for character-by-character input

### Step 3: Define State Structure

```elixir
defstruct [
  :prompt,      # String to display before input
  :value,       # Current/last entered value
  :label,       # Optional label shown above input
  :validator,   # Optional validation function
  :placeholder, # Text shown when value is empty
  :error        # Current validation error, if any
]
```

### Step 4: Implement Core Functions

- `new/1` - Create new widget props
- `read/1` - Trigger line read and validate
- `get_value/1` - Get current value
- `clear/1` - Clear current value

---

## Design Decisions

### Simple Widget Design

Unlike the full TextInput widget which is a StatefulComponent with complex event handling, TextInput.Line is a simple utility widget:
- Does not handle character-by-character events
- Uses `IO.gets/1` through LineReader which blocks until Enter
- Returns control after input is complete

### Integration with LineReader

Uses `TermUI.Input.LineReader` from Phase 4:
- `read_line/1` for simple input
- `read_line/2` for input with validation

---

## Success Criteria

- [x] Module compiles without warnings
- [x] Module has comprehensive documentation
- [x] Documents relationship to standard TextInput
- [x] Documents use of shell line editing
- [x] Unit tests pass (32 tests)

---

## Files to Create/Modify

| File | Action |
|------|--------|
| `lib/term_ui/widgets/text_input/line.ex` | Create |
| `test/term_ui/widgets/text_input/line_test.exs` | Create |
| `notes/planning/multi-renderer/phase-05-widget-adaptation.md` | Update task status |
