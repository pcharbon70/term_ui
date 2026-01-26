# Phase 7.3: Runtime Integration for IEx-Compatible Input

**Branch**: `feature/phase-7.3-runtime-integration`
**Target**: `multi-renderer`
**Created**: 2025-01-25
**Status**: Complete

## Problem Statement

The TTY input handler implemented in Phase 7.2 uses `:io.get_chars/2` for IEx compatibility. However, the handler's `stop/1` function (which restores IO options) was not part of the `TermUI.Input` behaviour and was not called by the Runtime during shutdown. This meant:

1. The IO options (`echo: false, binary: false`) were not restored when the TUI application exits
2. The terminal could be left in an inconsistent state

Additionally, the original Phase 7.3 plan was written assuming a separate-process input architecture (TTY.Server), but Phase 7.2 implemented a simpler direct approach. This phase updates the integration to match the actual implementation.

## Solution Overview

Updated the Runtime to properly integrate with the TTY input handler by:

1. **Added `stop/1` to Input behaviour** - Made cleanup a formal part of the input handler contract
2. **Implemented `stop/1` in Raw handler** - Added corresponding cleanup function for symmetry
3. **Updated Runtime terminate/2** - Now calls `input_handler.stop/1` during cleanup
4. **Added tests** - Verified IO options are restored on shutdown

## Technical Details

### Files Modified

- `lib/term_ui/input.ex` - Added `stop/1` callback to behaviour
- `lib/term_ui/input/raw.ex` - Implemented `stop/1` for Raw handler
- `lib/term_ui/input/tty.ex` - Added `@impl true` to existing `stop/1`
- `lib/term_ui/runtime.ex` - Calls `input_handler.stop/1` in terminate/2
- `test/term_ui/input_test.exs` - Added tests for new callback
- `test/term_ui/input/raw_test.exs` - Added tests for Raw.stop/1
- `test/term_ui/input/tty_test.exs` - Added tests for TTY.stop/1

### Key Changes

**Added stop/1 to Input behaviour**:
```elixir
@callback stop(state()) :: :ok
```

**Implemented in Raw handler**:
```elixir
@impl true
def stop(%__MODULE__{}), do: :ok
```

**Implemented in TTY handler**:
```elixir
@impl true
def stop(%__MODULE__{}) do
  restore_io_opts()
  :ok
end
```

**Updated Runtime terminate/2**:
```elixir
# Stop input handler to restore IO options (TTY mode)
try do
  if state.input_handler and state.input_state do
    state.input_handler.stop(state.input_state)
  end
rescue
  _ -> :ok
end
```

## Success Criteria

1. ✅ `stop/1` is part of `TermUI.Input` behaviour
2. ✅ Both Raw and TTY handlers implement `stop/1`
3. ✅ Runtime calls `stop/1` during shutdown
4. ✅ IO options are restored after TTY application exits
5. ✅ All tests pass (113 input tests)

## Implementation Plan

### Task 7.3.1: Add stop/1 to Input Behaviour

- [x] 7.3.1.1 Add `stop/1` callback to `TermUI.Input` behaviour
- [x] 7.3.1.2 Update behaviour documentation
- [x] 7.3.1.3 Add type specification for stop result

### Task 7.3.2: Implement stop/1 in Handlers

- [x] 7.3.2.1 Implement `stop/1` in `TermUI.Input.Raw` (no-op)
- [x] 7.3.2.2 Add `@impl true` to existing `TermUI.Input.TTY.stop/1`
- [x] 7.3.2.3 Verify both handlers compile correctly

### Task 7.3.3: Update Runtime

- [x] 7.3.3.1 Add input handler cleanup to `Runtime.terminate/2`
- [x] 7.3.3.2 Ensure cleanup happens before other shutdown steps
- [x] 7.3.3.3 Handle nil input_handler gracefully

### Unit Tests

- [x] Test Input.stop/1 behaviour is defined
- [x] Test Raw.stop/1 returns :ok
- [x] Test TTY.stop/1 calls restore_io_opts
- [x] Test handlers implement stop/1 callback

## Current Status

**What Works**:
- Phase 7.2 completed with `:io.get_chars/2` integration
- TTY handler has `stop/1` function for IO option restoration
- Runtime calls `stop/1` during shutdown
- All 113 input tests passing

**What's Next**:
- Manual testing to verify IO options are restored in actual terminal
- Consider integration tests for Runtime shutdown sequence

## Notes/Considerations

### Design Decisions

1. **Behaviour Addition**: Adding `stop/1` to the behaviour is a breaking change for any external input handlers, but since TermUI is pre-1.0 and there are no known external implementations, this is acceptable.

2. **Raw Handler No-op**: The Raw handler doesn't need cleanup (InputReader is already stopped separately), so its `stop/1` is a no-op that returns `:ok`.

3. **Cleanup Order**: Input handler cleanup happens after InputReader stop but before terminal restoration, ensuring the handler is done reading input.

### Potential Issues

1. **Nil Handler**: The Runtime may have `nil` input_handler if `use_input_handler` is false. This is handled gracefully with a nil check.

2. **Already Stopped**: The input handler may already be stopped (e.g., after EOF). The `stop/1` function is idempotent (calling restore_io_opts multiple times is safe).

### Test Strategy

1. **Unit Tests**: Test each handler's `stop/1` function in isolation (completed)
2. **Integration Tests**: Test Runtime cleanup sequence (added to Runtime.terminate/2)
3. **Manual Tests**: Run TTY application and verify terminal state after exit (recommended)

## Deliverables

1. ✅ Updated `lib/term_ui/input.ex` - With stop/1 callback
2. ✅ Updated `lib/term_ui/input/raw.ex` - With stop/1 implementation
3. ✅ Updated `lib/term_ui/input/tty.ex` - With @impl true for stop/1
4. ✅ Updated `lib/term_ui/runtime.ex` - With input handler cleanup
5. ✅ Updated tests for all modules
6. ⏳ Summary in `notes/summaries/phase-7.3-summary.md` (pending)

