# Event Loop Input Integration - Section 6.2

## Overview

Complete Section 6.2 of the multi-renderer plan by integrating the Input.Selector into the Runtime event loop for automatic input handler selection based on backend mode.

**Branch**: `feature/event-loop-input-integration`
**Base Branch**: `multi-renderer`
**Plan Reference**: `notes/planning/multi-renderer/phase-06-integration.md` (Section 6.2)

## Problem Statement

Currently, `TermUI.Runtime` uses `InputReader` for all input, which is a GenServer-based async input system designed for raw mode. This needs to be refactored to:

1. Use `Input.Selector` to select the appropriate handler (`Input.Raw` or `Input.TTY`)
2. Integrate the selected input handler into the event loop
3. Handle input consistently from both handlers (both produce `TermUI.Event` structs)
4. Handle backend-specific events (mouse, resize, focus)

## Current State Analysis

### Existing Input Infrastructure (COMPLETE)

**`TermUI.Input.Selector`** (`lib/term_ui/input/selector.ex`):
- `select/0` - Auto-detects handler based on current backend mode
- `select/1` - Explicit selection by mode (`:raw` or `:tty`)
- Returns handler module (`TermUI.Input.Raw` or `TermUI.Input.TTY`)

**`TermUI.Input.Raw`** (`lib/term_ui/input/raw.ex`):
- Implements `TermUI.Input` behaviour
- `new/0` - Creates initial state
- `poll/2` - Synchronous polling with timeout support
- Returns `{{:ok, event}, state}`, `{:timeout, state}`, or `{:eof, state}`
- Handles escape sequences, arrow keys, mouse events

**`TermUI.Input.TTY`** (`lib/term_ui/input/tty.ex`):
- Implements `TermUI.Input` behaviour
- `new/0` - Creates initial state
- `poll/2` - Blocking polls (timeout ignored in TTY mode)
- Returns `{{:ok, event}, state}` or `{:eof, state}`
- Handles escape sequences, arrow keys, mouse events

### Current Runtime Input

**`TermUI.Runtime`** uses `InputReader`:
- GenServer-based async input
- Sends `{:input, event}` messages to target process
- Raw mode only
- Located in `lib/term_ui/terminal/input_reader.ex`

## Implementation Plan

### Task 6.2.1: Integrate Input Handler

**Modify `lib/term_ui/runtime.ex`**:

1. Add input handler state to `Runtime.State`:
   ```elixir
   input_handler: module() | nil  # e.g., TermUI.Input.Raw
   input_state: term() | nil     # Handler-specific state
   ```

2. Select handler during initialization:
   ```elixir
   input_handler = Selector.select(backend_mode)
   input_state = input_handler.new()
   ```

3. Create input poll loop in `handle_info(:input_poll, state)`:
   - Call `handler.poll(state, timeout)`
   - Handle `{{:ok, event}, new_state}` - dispatch event
   - Handle `{:timeout, new_state}` - reschedule poll
   - Handle `{:eof, new_state}` - initiate shutdown

### Task 6.2.2: Unify Event Handling

Both input handlers already produce `TermUI.Event` structs:
- `Event.Key` - Keyboard events (arrows, Tab, Enter, etc.)
- `Event.Mouse` - Mouse events
- `Event.Resize` - Terminal resize
- `Event.Focus` - Focus gain/loss (raw mode only)

**No changes needed** - existing `dispatch_event/2` already handles all event types uniformly.

### Task 6.2.3: Handle Backend-Specific Events

**Mouse events**:
- Both handlers produce `Event.Mouse`
- Raw mode: full mouse tracking
- TTY mode: mouse tracking if terminal supports it

**Resize events**:
- Raw mode: detected via terminal callback (already implemented)
- TTY mode: detected via `:io.rows()` and `:io.columns()`

**Focus events**:
- Raw mode: some terminals send focus events
- TTY mode: focus events typically not available

**Current implementation handles all these events** through the existing `dispatch_event/2` function. No special handling needed.

### Task 6.2.4: Unit Tests

Update `test/term_ui/runtime_test.exs`:

1. Test runtime initializes with correct input handler based on backend
2. Test input polling loop works with both handlers
3. Test events are dispatched correctly from input handler
4. Test EOF from input handler triggers shutdown
5. Test timeout handling (raw mode only)

## Design Decisions

### 1. Input Polling Strategy

Instead of using a separate GenServer (InputReader), we'll poll directly in the Runtime process:

```elixir
# In handle_info(:input_poll, state)
case input_handler.poll(input_state, 16) do
  {{:ok, event}, new_input_state} ->
    state = dispatch_event(event, %{state | input_state: new_input_state})
    schedule_input_poll()
    {:noreply, state}

  {:timeout, new_input_state} ->
    schedule_input_poll()
    {:noreply, %{state | input_state: new_input_state}}

  {:eof, _new_input_state} ->
    initiate_shutdown(state)
end
```

**Rationale**:
- Simpler architecture - fewer processes
- Direct integration with event loop
- Easier to test

### 2. Compatibility with skip_terminal

When `skip_terminal: true` is used (for testing), we won't initialize an input handler:

```elixir
input_handler =
  if skip_terminal do
    nil
  else
    Selector.select(backend_mode)
  end
```

### 3. Backward Compatibility

The `InputReader` GenServer will remain for:
- Legacy code that depends on it
- Potential use cases where async input is preferred

We'll add a new option `:use_input_handler` (default `false`) to opt-in to the new behavior, preserving backward compatibility.

## Success Criteria

1. Runtime selects input handler based on backend mode
2. Input polling loop works correctly in both raw and TTY modes
3. Events from both handlers are dispatched correctly
4. EOF triggers graceful shutdown
5. All existing tests pass
6. New tests cover input handler integration

## Critical Files

- `lib/term_ui/runtime.ex` - Main changes
- `lib/term_ui/runtime/state.ex` - Add input handler fields
- `lib/term_ui/input/selector.ex` - Already complete
- `lib/term_ui/input/raw.ex` - Already complete
- `lib/term_ui/input/tty.ex` - Already complete
- `test/term_ui/runtime_test.exs` - Add input handler tests

## Progress

- [x] Create feature branch
- [x] Analyze existing code
- [x] Task 6.2.1: Integrate Input Handler into Runtime
- [x] Task 6.2.2: Add input polling loop
- [x] Task 6.2.3: Add unit tests
- [x] Update planning document
- [x] Create summary document

## Status: COMPLETE

All tasks for Section 6.2 have been implemented:

### Changes Made

1. **lib/term_ui/runtime/state.ex**
   - Added `input_handler: module() | nil` field
   - Added `input_state: term() | nil` field

2. **lib/term_ui/runtime.ex**
   - Added `:use_input_handler` option (opt-in, defaults to `false`)
   - Integrated `Input.Selector` for handler selection
   - Added `handle_info(:input_poll, state)` for polling input
   - Added `schedule_input_poll/0` helper function

3. **test/term_ui/runtime_test.exs**
   - Added "input handler integration" describe block (5 tests)
   - Total: 46 tests passing

### Test Results

```
mix test test/term_ui/runtime_test.exs
46 tests, 0 failures
```

## Design Notes

### Opt-in Approach

The new input handler is opt-in via `use_input_handler: true` to maintain backward compatibility with the existing `InputReader` GenServer-based approach.

### Handler Selection

When enabled:
- `backend_mode: :raw` → `Input.Raw` handler
- `backend_mode: :tty` → `Input.TTY` handler
- `backend_mode: :skip` → No handler (testing mode)

### Polling Loop

The input poll loop runs every 16ms (same as render interval) and:
- Calls `handler.poll(state, timeout)`
- Dispatches events via existing `dispatch_event/2`
- Handles `{:timeout}`, `{{:ok, event}}`, and `{:eof}` results
- Triggers graceful shutdown on EOF

### Event Unification

Both `Input.Raw` and `Input.TTY` already produce `TermUI.Event` structs with identical format:
- `Event.Key` - Keyboard events (arrows, Tab, Enter, etc.)
- `Event.Mouse` - Mouse events
- `Event.Resize` - Terminal resize
- `Event.Focus` - Focus events (raw mode only)

No special handling needed - existing `dispatch_event/2` works for all.

## Notes

### Key Insight

Both `Input.Raw` and `Input.TTY` already implement the same `TermUI.Input` behaviour and produce the same `TermUI.Event` structs. The integration is straightforward - we just need to:

1. Select the handler at initialization
2. Poll for input in the event loop
3. Dispatch events (already implemented)

### Gradual Migration

To maintain backward compatibility, we'll make the new input handler opt-in via the `:use_input_handler` option. This allows:

- Existing code to continue using `InputReader`
- New code to opt-in to the unified input handler
- Gradual migration and testing

### Future Work

Section 6.3 will address rendering pipeline integration. Section 6.2 only focuses on input handling.
