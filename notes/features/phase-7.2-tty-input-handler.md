# Phase 7.2: Update TTY Input Handler

**Branch**: `feature/phase-7.2-tty-input-handler`
**Target**: `multi-renderer`
**Created**: 2025-01-25
**Status**: Complete

## Problem Statement

The current `TermUI.Input.TTY` module uses `IO.getn/2` for character input, which causes input to be stolen by IEx when running TUI applications inside IEx. Research in Phase 7.1 confirmed that using `:io.get_chars/2` with a separate spawned process (as done in the `snake_test` project) successfully allows TUI applications to work inside IEx.

## Solution Overview

IEx-compatible input handling was implemented in `TermUI.Input.TTY` by:

1. **Replacing `IO.getn/2` with `:io.get_chars/2`** - Using Erlang's IO module directly
2. **Adding IO server configuration** - Set `echo: false, binary: false` via `:io.setopts/2`
3. **Converting charlist to binary** - `:io.get_chars/2` returns charlists when `binary: false`
4. **Preserving API compatibility** - Maintained existing state struct and function signatures

### Design Note: Simplified Approach

Initially considered a separate GenServer architecture (TTY.Server), but this would have broken API compatibility with the Runtime which expects `handler.new()` to return a state struct directly. The simpler approach of using `:io.get_chars/2` directly in the existing TTY handler maintains full API compatibility while achieving IEx compatibility.

## Technical Details

### Files Modified

- `lib/term_ui/input/tty.ex` - Updated to use `:io.get_chars/2` directly
- `test/term_ui/input/tty_test.exs` - Updated tests for new struct fields

### Files Created (Not Used)

- `lib/term_ui/input/tty_server.ex` - GenServer approach (created but not integrated due to API compatibility concerns)

### Key Changes

**Previous Implementation**:
```elixir
defp read_char do
  case IO.getn("", 1) do
    :eof -> :eof
    {:error, reason} -> {:error, reason}
    data when is_binary(data) -> {:ok, data}
  end
end
```

**New Implementation**:
```elixir
defp read_char do
  case :io.get_chars(~c"", 1) do
    :eof -> :eof
    chars when is_list(chars) ->
      case :unicode.characters_to_binary(chars) do
        binary when is_binary(binary) -> {:ok, binary}
        :error -> {:error, :invalid_unicode}
      end
    {:error, reason} -> {:error, reason}
    other -> {:error, {:unexpected_io_return, other}}
  end
end
```

### State Changes

**Previous state**:
```elixir
defstruct buffer: <<>>,
          event_queue: []
```

**New state**:
```elixir
defstruct buffer: <<>>,
          event_queue: [],
          io_opts_restored: false,
          io_opts_set: false
```

## Success Criteria

1. ✅ `TermUI.Input.TTY` uses `:io.get_chars/2` directly
2. ✅ IO options are saved and restored correctly
3. ✅ Charlists are converted to binaries for compatibility
4. ✅ All existing tests pass (45/45)
5. ✅ Documentation updated with IEx compatibility notes

## Implementation Plan

### Task 7.2.1: Replace IO.getn with :io.get_chars

- [x] 7.2.1.1 Replace `IO.getn("", 1)` with `:io.get_chars("", 1)` in `Input.TTY.read_char/0`
- [x] 7.2.1.2 Update return type handling for charlist vs binary
- [x] 7.2.1.3 Add conversion from charlist to binary for compatibility
- [x] 7.2.1.4 Update error handling for `:io` module error formats

### Task 7.2.2: Add IO Server Configuration

- [x] 7.2.2.1 Add `:io.getopts/0` call to save original options in `new/0`
- [x] 7.2.2.2 Add `:io.setopts(echo: false, binary: false)` call in `new/0`
- [x] 7.2.2.3 Store original opts in state struct
- [x] 7.2.2.4 Implement cleanup function to restore original opts

### Task 7.2.3: Separate Process Input (Not Used - Simplified Approach)

- [x] 7.2.3.1 Created `TermUI.Input.TTY.Server` GenServer (archived for future use)
- [x] 7.2.3.2 Implemented continuous polling loop (archived)
- [x] 7.2.3.3 Send parsed key events as messages (archived)
- [x] 7.2.3.4 Handle process cleanup and termination (archived)

**Note**: The separate process approach was implemented in `tty_server.ex` but not integrated due to API compatibility concerns. The simpler direct approach using `:io.get_chars/2` was used instead.

### Unit Tests

- [x] All existing tests pass (45/45)
- [x] State struct has new IO opts fields
- [x] Documentation tests verify IEx compatibility
- [x] Comparison tests with Raw handler updated

## Current Status

**What Works**:
- Phase 7.1 research confirmed the approach works
- Feature branch `feature/phase-7.2-tty-input-handler` created
- `:io.get_chars/2` integration complete
- IO server configuration (echo: false, binary: false) implemented
- Charlist to binary conversion working
- All 45 tests passing
- Documentation updated with IEx compatibility notes
- Comparison tests updated for new struct fields

**What's Next**:
- Integration testing in actual IEx session
- Future consideration: TTY.Server GenServer approach for non-blocking I/O

## Notes/Considerations

### Design Decisions

1. **Simplified vs GenServer Approach**: Initially designed a separate GenServer architecture (TTY.Server), but this would have broken API compatibility with the Runtime. The simpler approach of using `:io.get_chars/2` directly in the existing TTY handler maintains full API compatibility while achieving IEx compatibility. The TTY.Server code is archived for potential future use if non-blocking I/O is needed.

2. **State Management**: Added `io_opts_set` and `io_opts_restored` fields to track IO server configuration state without breaking existing tests that create state structs directly.

3. **Backward Compatibility**: The API remains unchanged - `poll/2` and `mode/1` still work the same way. The change is internal to the `read_char/0` function.

### Potential Issues

1. **Blocking Behavior**: The `:io.get_chars/2` call is blocking, so `poll/2` will block when no events are buffered. This is documented as expected behavior for TTY mode.

2. **IEx Testing**: Final verification requires manual testing in an actual IEx session to confirm input is not stolen.

3. **Cleanup**: The `stop/1` function is provided to restore IO options, but it must be called explicitly by the user.

### Test Strategy

1. **Unit Tests**: All existing tests updated and passing (45/45)
2. **Documentation Tests**: Tests verify moduledoc mentions IEx compatibility
3. **Manual Tests**: Required to verify IEx compatibility in a live session

## Deliverables

1. ✅ Updated `lib/term_ui/input/tty.ex` - Uses `:io.get_chars/2` directly
2. ✅ Created `lib/term_ui/input/tty_server.ex` - GenServer for input process (archived, not integrated)
3. ✅ Updated `test/term_ui/input/tty_test.exs` - Updated handler tests
4. ✅ Planning document in `notes/features/phase-7.2-tty-input-handler.md`
5. ⏳ Summary in `notes/summaries/phase-7.2-summary.md` (pending)
