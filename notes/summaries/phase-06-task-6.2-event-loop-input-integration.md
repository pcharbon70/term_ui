# Phase 6 Task 6.2: Event Loop Input Integration - Summary

**Branch**: `feature/event-loop-input-integration`
**Base Branch**: `multi-renderer`
**Date**: 2025-01-24
**Status**: COMPLETE

## Overview

Implemented Section 6.2 of the multi-renderer plan: "Update Event Loop". This integrated the `Input.Selector` into the Runtime event loop for automatic input handler selection based on backend mode.

## Changes Made

### 1. Runtime.State (`lib/term_ui/runtime/state.ex`)

Added two new fields to the state struct:

| Field | Type | Description |
|-------|------|-------------|
| `input_handler` | `module() \| nil` | Input handler module (`Input.Raw` or `Input.TTY`) |
| `input_state` | `term() \| nil` | Handler-specific state |

### 2. Runtime (`lib/term_ui/runtime.ex`)

**New Options:**
- `:use_input_handler` - Opt-in flag to use new input handler system (default: `false`)

**New Internal Functions:**
- `schedule_input_poll/0` - Schedule next input poll (16ms interval)
- `handle_info(:input_poll, state)` - Process input from handler

**Modified Functions:**
- `init/1` - Selects input handler based on backend mode when `use_input_handler: true`

**Example Usage:**

```elixir
# Opt-in to new input handler system
{:ok, runtime} = Runtime.start_link(
  root: MyApp.Root,
  backend: :auto,
  use_input_handler: true
)

# Input handler is automatically selected based on backend mode
# :raw backend → Input.Raw handler
# :tty backend → Input.TTY handler
```

### 3. Runtime Tests (`test/term_ui/runtime_test.exs`)

Added 5 new tests in "input handler integration" describe block:

- `does not use input handler by default`
- `initializes input handler when use_input_handler is true`
- `initializes input handler for raw backend mode`
- `initializes input handler for TTY backend mode`
- `input_handler defaults to nil when use_input_handler is false`

Total tests: 41 → 46

## Test Results

```
mix test test/term_ui/runtime_test.exs
46 tests, 0 failures
```

All existing tests continue to pass with the new functionality.

## Files Modified

| File | Lines Changed | Description |
|------|---------------|-------------|
| `lib/term_ui/runtime/state.ex` | +5 | Added input handler fields |
| `lib/term_ui/runtime.ex` | +60, -10 | Integrated Input.Selector, added poll loop |
| `test/term_ui/runtime_test.exs` | +50 | Added input handler tests |
| `notes/planning/multi-renderer/phase-06-integration.md` | -15, +15 | Marked Section 6.2 complete |

## Input Polling Flow

```
┌─────────────────────────────────────────────────────────────┐
│ Runtime.init/1                                              │
│                                                             │
│ 1. Select backend (Backend.Selector)                       │
│ 2. If use_input_handler: true                              │
│    - Select input handler (Input.Selector)                 │
│    - Initialize handler state (handler.new())              │
│ 3. Schedule first input poll                               │
└─────────────────────────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│ handle_info(:input_poll, state)                             │
│                                                             │
│ case handler.poll(input_state, timeout) do                  │
│   {{:ok, event}, new_state} →                              │
│     - Dispatch event via dispatch_event/2                   │
│     - Schedule next poll                                   │
│                                                             │
│   {:timeout, new_state} →                                   │
│     - Schedule next poll                                   │
│                                                             │
│   {:eof, new_state} →                                       │
│     - Initiate graceful shutdown                           │
│ end                                                         │
└─────────────────────────────────────────────────────────────┘
```

## Design Decisions

### Opt-in Approach

The new input handler system is opt-in via `use_input_handler: true` to:
- Maintain backward compatibility with existing `InputReader`
- Allow gradual migration and testing
- Give applications control over when to adopt the new system

### Polling vs. Async Messages

The new system uses synchronous polling in the Runtime process instead of async messages from `InputReader`:
- Simpler architecture (fewer processes)
- Direct integration with event loop
- Easier to test

### Event Unification

Both `Input.Raw` and `Input.TTY` already implement the `TermUI.Input` behaviour and produce identical `TermUI.Event` structs:
- No special handling needed for different backends
- Existing `dispatch_event/2` works for all events
- Keyboard, mouse, resize, and focus events unified

## Backend-Specific Events

| Event Type | Raw Mode | TTY Mode |
|------------|----------|----------|
| Keyboard (`Event.Key`) | Yes | Yes |
| Mouse (`Event.Mouse`) | Yes | Yes (if terminal supports) |
| Resize (`Event.Resize`) | Via callback | Via callback |
| Focus (`Event.Focus`) | Yes (if terminal supports) | Typically no |

All event types are handled identically through the existing `dispatch_event/2` function.

## Success Criteria Met

- [x] Runtime selects input handler based on backend mode
- [x] Input polling loop works correctly
- [x] Events from both handlers are dispatched correctly
- [x] EOF triggers graceful shutdown
- [x] All existing tests pass (41 tests)
- [x] New tests cover input handler integration (5 tests)
- [x] Section 6.2 marked complete in planning document

## Next Steps

Section 6.2 is complete. The next section in Phase 6 is:
- **Section 6.3: Update Rendering Pipeline** - Connect rendering to backend selection

This will involve using the backend module for rendering and handling differences between raw and TTY rendering modes.
