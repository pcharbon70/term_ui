# Runtime Backend Integration - Section 6.1

## Overview

Complete Section 6.1 of the multi-renderer plan by integrating the Backend.Selector into TermUI.Runtime initialization.

**Branch**: `feature/runtime-backend-integration`
**Base Branch**: `multi-renderer`
**Plan Reference**: `notes/planning/multi-renderer/phase-06-integration.md` (Section 6.1)

## Problem Statement

Currently, `TermUI.Runtime` directly initializes raw mode using `Terminal.start_link()` and `InputReader`. This needs to be refactored to:

1. Use `Backend.Selector.select/1` to detect the appropriate backend
2. Support configuration options for backend selection (`:auto`, `:raw`, `:tty`)
3. Store backend mode and capabilities in runtime state and persistent_term
4. Provide query functions for applications to detect backend capabilities

## Current State Analysis

### Existing Implementation

**Runtime.init/1** (`lib/term_ui/runtime.ex:173-223`):
- Directly calls `Terminal.start_link()` to enable raw mode
- Uses `InputReader` for all input (raw mode only)
- Stores `input_reader: pid()` in state
- No backend selection logic

**Backend.Selector** (`lib/term_ui/backend/selector.ex`):
- `select/0` - Auto-detects backend (try raw first)
- `select/1` - Accepts `:auto`, module, or `{module, opts}`
- Returns `{:raw, state}` or `{:tty, capabilities}`
- Fully implemented

**Runtime.State** (`lib/term_ui/runtime/state.ex`):
- Needs new fields: `backend_mode`, `capabilities`, `backend`

## Implementation Plan

### Task 6.1.1: Integrate Backend Selector

**Modify `lib/term_ui/runtime.ex`**:

1. Add new option type: `{:backend, :auto | :raw | :tty}` (default `:auto`)
2. Call `Backend.Selector.select/1` with backend option
3. Store selection result in runtime state

**Changes to init/1**:
```elixir
# Before:
{terminal_started, buffer_manager, dimensions} =
  if skip_terminal do
    {false, nil, nil}
  else
    initialize_terminal()
  end

# After:
backend_selection =
  if skip_terminal do
    {:skip, nil}
  else
    backend = Keyword.get(opts, :backend, :auto)
    Backend.Selector.select(backend)
  end

{backend_mode, backend_state, terminal_started, buffer_manager, dimensions} =
  process_backend_selection(backend_selection)
```

### Task 6.1.2: Handle Backend Selection Options

The `:backend` option controls backend selection:

| Value | Behavior |
|-------|----------|
| `:auto` (default) | Try raw mode first, fall back to TTY |
| `:raw` | Force raw mode, error if unavailable |
| `:tty` | Force TTY mode, skip raw mode attempt |

**Forced :raw behavior**:
```elixir
defp process_backend_selection({:raw, state}) do
  # Raw mode succeeded
  {:raw, state, true, buffer_manager, dimensions}
end

defp process_backend_selection({:tty, capabilities}) do
  # Raw mode failed or :tty forced
  {:tty, capabilities, false, nil, nil}  # No buffer_manager for TTY
end

defp process_backend_selection({:explicit, module, opts}) do
  # Explicit backend selection (for testing)
  # module is TermUI.Backend.Raw or TermUI.Backend.TTY
  case module do
    TermUI.Backend.Raw -> attempt_raw_or_error()
    TermUI.Backend.TTY -> {:tty, detect_capabilities(), false, nil, nil}
  end
end
```

### Task 6.1.3: Store Backend Context

Add to Runtime.State struct:
- `backend_mode: :raw | :tty | nil`
- `capabilities: map() | nil`
- `backend: module() | nil` (backend module being used)

Store in persistent_term:
- `:term_ui_backend_mode` - `:raw` or `:tty`
- `:term_ui_capabilities` - capabilities map

Add query functions:
- `TermUI.Runtime.backend_mode/0` - returns `:raw` or `:tty`
- `TermUI.Runtime.capabilities/0` - returns capabilities map

### Task 6.1.4: Update Documentation

Add to `@moduledoc`:
```elixir
## Options

- `:root` - The root component module (required)
- `:name` - GenServer name (optional)
- `:render_interval` - Milliseconds between renders (default: 16)
- `:backend` - Backend selection: `:auto` (default), `:raw`, `:tty`
- `:skip_terminal` - Skip terminal initialization (for testing)

## Backend Selection

The `:backend` option controls which terminal backend is used:

- `:auto` (default) - Attempts raw mode first, falls back to TTY
- `:raw` - Forces raw mode (requires OTP 28+, errors if unavailable)
- `:tty` - Forces TTY mode (line-based input, no raw mode)

## Examples

    # Auto-detect backend (default)
    Runtime.start_link(root: MyApp.Root)

    # Force TTY mode
    Runtime.start_link(root: MyApp.Root, backend: :tty)

    # Query backend mode
    mode = Runtime.backend_mode()  # => :raw or :tty

    # Query capabilities
    caps = Runtime.capabilities()  # => %{colors: :true_color, ...}
```

### Task 6.1.5: Unit Tests

Update `test/term_ui/runtime_test.exs`:

1. Test runtime initializes with auto backend selection
2. Test runtime respects `:backend => :raw` option
3. Test runtime respects `:backend => :tty` option
4. Test `backend_mode/0` returns correct mode
5. Test `capabilities/0` returns capabilities map (in TTY mode)
6. Test forced `:raw` fails gracefully when unavailable

## Success Criteria

1. Runtime calls `Backend.Selector.select/1` during initialization
2. Runtime stores backend mode and capabilities in state
3. `backend_mode/0` and `capabilities/0` query functions work
4. All existing tests pass
5. New tests cover backend selection scenarios

## Critical Files

- `lib/term_ui/runtime.ex` - Main changes
- `lib/term_ui/runtime/state.ex` - Add new fields
- `lib/term_ui/backend/selector.ex` - Already complete, used by runtime
- `test/term_ui/runtime_test.exs` - Add backend selection tests

## Progress

- [x] Create feature branch
- [x] Analyze existing code
- [x] Task 6.1.1: Integrate Backend Selector
- [x] Task 6.1.2: Handle Backend Selection Options
- [x] Task 6.1.3: Store Backend Context
- [x] Task 6.1.4: Update Documentation
- [x] Task 6.1.5: Unit Tests
- [x] Update planning document
- [x] Create summary document

## Status: COMPLETE

All tasks for Section 6.1 have been implemented:

### Changes Made

1. **lib/term_ui/runtime/state.ex**
   - Added `backend_mode: :raw | :tty | nil` field
   - Added `backend: module() | nil` field
   - Added `capabilities: map() | nil` field
   - Updated type specs

2. **lib/term_ui/runtime.ex**
   - Added `:backend` option to `start_link/1`
   - Integrated `Backend.Selector.select/1` in init sequence
   - Added `select_backend/1` helper function
   - Added `store_backend_context/2` helper function
   - Added public `backend_mode/0` query function
   - Added public `capabilities/0` query function
   - Updated moduledoc with backend selection examples

3. **test/term_ui/runtime_test.exs**
   - Added setup/1 for persistent_term cleanup
   - Added "backend selection" describe block (5 tests)
   - Added "backend option handling" describe block (3 tests)
   - Added "backend selector integration" describe block (2 tests)
   - Total: 41 tests passing

### Test Results

```
mix test test/term_ui/runtime_test.exs
41 tests, 0 failures
```

## Notes

### Compatibility Considerations

1. **Breaking change**: The `terminal_started` field semantics change slightly
   - Before: `true` if raw mode started, `false` otherwise
   - After: `true` if raw mode, `false` if TTY mode

2. **Buffer manager**: Currently only used in raw mode
   - TTY mode doesn't use differential rendering
   - `buffer_manager: nil` in TTY mode is acceptable

3. **Input reader**: Currently always uses `InputReader`
   - Section 6.2 will address input handler selection
   - For now, keep existing `InputReader` behavior in raw mode
   - TTY mode will need different input handling (future task)

### Future Work (Section 6.2)

Section 6.1 only initializes backend selection. Section 6.2 will:
- Use `Input.Selector` to choose appropriate input handler
- Unify event handling between backends
- Handle backend-specific events (mouse, resize, focus)

## Questions for Developer

1. Should `capabilities/0` return `nil` in raw mode, or return a capabilities map with raw-mode capabilities?

   **Answer**: In raw mode, we can detect capabilities similarly. Let's return capabilities in both modes for consistency.

2. Should we store backend module in state for later use in rendering (Section 6.3)?

   **Answer**: Yes, storing `backend: module()` will be useful for render backend selection.
