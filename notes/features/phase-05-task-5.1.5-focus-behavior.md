# Feature: Phase 5 Task 5.1.5 - Implement Focus Behavior

**Branch:** `feature/phase-05-task-5.1.5-focus-behavior`
**Base:** `multi-renderer`
**Date:** 2025-12-06
**Status:** In Progress

## Overview

Implement focus handling for the `TextInput.Line` widget. This allows the widget to integrate with the framework's focus management system.

## Task Requirements

| Subtask | Requirement | Description |
|---------|-------------|-------------|
| 5.1.5.1 | When focused, initiate line read | Handle Focus.gained event |
| 5.1.5.2 | Block until Enter pressed | Shell handles editing via IO.gets |
| 5.1.5.3 | Return focus to parent after complete | Signal focus should move away |
| 5.1.5.4 | Handle Ctrl+C to cancel input | Return cancelled state |

## Design Decisions

### Focus State Tracking

Add a `focused` field to the struct to track focus state, similar to standard TextInput.

### Blocking Read Behavior

The `read/1` function already blocks until Enter is pressed (via `IO.gets/1`). The focus behavior adds:
- `handle_focus/1` - Called when focus is gained, initiates read
- Focus state tracking

### Focus Callback

Add an optional `on_blur` callback to notify when the widget loses focus or completes input.

### Ctrl+C Handling

`IO.gets/1` returns `:eof` when interrupted with Ctrl+C (or when input stream closes). We'll return `{:cancelled, state}` in this case.

## Implementation Plan

### Step 1: Add Focus State to Struct

Add `focused: false` to the defstruct.

### Step 2: Add Handle Focus Function

Create `handle_focus/1` that:
- Sets focused to true
- Initiates line read
- Returns result with updated state

### Step 3: Add Blur/Cancel Handling

- Track when input is cancelled (Ctrl+C / EOF)
- Add `on_blur` callback support
- Return appropriate result tuples

### Step 4: Add Tests

- Test focus gained initiates read
- Test Ctrl+C returns cancelled
- Test focus state tracking
- Test on_blur callback

---

## Implementation Details

### New Fields

```elixir
defstruct prompt: "",
          value: "",
          label: nil,
          validator: nil,
          placeholder: "",
          error: nil,
          focused: false,        # NEW
          on_blur: nil           # NEW (optional callback)
```

### New Functions

```elixir
@spec handle_focus(t()) :: {:ok, term(), t()} | {:error, term(), t()} | {:cancelled, t()}
def handle_focus(%__MODULE__{} = state)

@spec is_focused?(t()) :: boolean()
def is_focused?(%__MODULE__{focused: focused}), do: focused
```

### Result Types Update

```elixir
@type read_result ::
        {:ok, term(), t()}
        | {:error, term(), t()}
        | {:cancelled, t()}      # NEW - for Ctrl+C
        | {:eof, t()}
```

---

## Success Criteria

- [x] Focus state tracked in struct
- [x] handle_focus/1 initiates read and returns result
- [x] Ctrl+C (EOF) returns {:cancelled, state}
- [x] on_blur callback supported
- [x] Unit tests pass (50 tests, 0 failures)
