# Summary: Phase 7.2 - TTY Input Handler IEx Compatibility

## What Was Implemented

This phase implements IEx-compatible input handling for the `TermUI.Input.TTY` module by switching from Elixir's `IO.getn/2` to Erlang's `:io.get_chars/2`. This enables TUI applications to work correctly when run inside IEx without having keyboard input stolen by IEx.

## Problem Statement

When TermUI TUI applications were run inside IEx, keyboard input was captured by IEx instead of the application. This was caused by using Elixir's `IO` module wrapper which IEx intercepts. Research in Phase 7.1 confirmed that using Erlang's `:io` module directly (as done in the `snake_test` project) allows TUI applications to work inside IEx.

## Solution Implemented

### Core Changes to `TermUI.Input.TTY`

1. **Replaced `IO.getn/2` with `:io.get_chars/2`**
   - Changed from Elixir's IO module to Erlang's IO module
   - `:io.get_chars(~c"", 1)` returns charlists instead of binaries
   - Added `:unicode.characters_to_binary/1` conversion

2. **Added IO Server Configuration**
   - `setup_io_opts/0`: Saves original options and sets `echo: false, binary: false`
   - `restore_io_opts/0`: Restores IO options on cleanup
   - State tracks `io_opts_set` and `io_opts_restored` flags

3. **Preserved API Compatibility**
   - `new/0` still returns state struct directly
   - `poll/2` signature unchanged
   - `mode/1` still returns `:tty`
   - Tests can still create state structs with buffer/event_queue

### Previous Implementation
```elixir
defp read_char do
  case IO.getn("", 1) do
    :eof -> :eof
    {:error, reason} -> {:error, reason}
    data when is_binary(data) -> {:ok, data}
  end
end
```

### New Implementation
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

## State Changes

### Previous State
```elixir
defstruct buffer: <<>>,
          event_queue: []
```

### New State
```elixir
defstruct buffer: <<>>,
          event_queue: [],
          io_opts_restored: false,
          io_opts_set: false
```

## Design Decision: Simplified Approach

Initially implemented a separate GenServer architecture (`TermUI.Input.TTY.Server`) with a spawned input process. However, this approach would have broken API compatibility with the Runtime, which expects `handler.new()` to return a state struct directly.

The simpler approach of using `:io.get_chars/2` directly in the existing TTY handler maintains full API compatibility while achieving IEx compatibility. The `TTY.Server` code is archived in `lib/term_ui/input/tty_server.ex` for potential future use if non-blocking I/O is needed.

## Documentation Updates

Updated moduledoc to emphasize IEx compatibility:
- Added IEx compatibility section explaining the `:io` vs `IO` difference
- Documented that arrow keys, Tab, Enter work immediately (not line-buffered)
- Explained timeout semantics (not honored in TTY mode due to blocking I/O)
- Added comparison table with Raw input handler
- Included security notes on buffer/queue limits

## Testing

### Test Results
- All 45 tests passing
- Updated tests for new struct fields (`io_opts_set`, `io_opts_restored`)
- Added documentation tests verifying IEx compatibility notes
- Updated comparison tests with Raw handler

### Test Coverage
- Behavior implementation verification
- State creation and struct fields
- Mode returns `:tty`
- Pre-buffered input parsing (all key types)
- UTF-8 character handling
- Event queue management
- State updates across polls
- Queue size limits
- Documentation completeness
- Comparison with Raw handler

## Files Modified

1. **`lib/term_ui/input/tty.ex`**
   - Changed `read_char/0` to use `:io.get_chars/2`
   - Added `setup_io_opts/0` and `restore_io_opts/0`
   - Updated struct with IO opts fields
   - Updated all documentation

2. **`test/term_ui/input/tty_test.exs`**
   - Updated struct field tests
   - Added IEx compatibility documentation tests
   - Updated comparison tests

3. **`lib/term_ui/input/tty_server.ex`** (Created but not integrated)
   - GenServer with separate process approach
   - Archived for future use if needed

## Success Criteria

- ✅ `TermUI.Input.TTY` uses `:io.get_chars/2`
- ✅ IO options saved and restored correctly
- ✅ Charlists converted to binaries for compatibility
- ✅ All existing tests pass (45/45)
- ✅ Documentation updated with IEx compatibility notes
- ✅ API compatibility preserved

## What's Next

- Manual testing in actual IEx session to confirm input is not stolen
- Future consideration: TTY.Server GenServer for non-blocking I/O
- Phase 7.3: Integrate with Runtime for event loop updates
- Phase 7.4: Add IEx detection for automatic mode selection

## Technical Notes

1. **Blocking Behavior**: `:io.get_chars/2` is blocking, so `poll/2` will block when buffer is empty and no events are queued. This is documented as expected TTY mode behavior.

2. **Charlist Handling**: `binary: false` option causes `:io.get_chars` to return charlists (Erlang-style), requiring conversion to binaries for compatibility with existing escape parser.

3. **Escape Timeout**: Increased from 50ms to 100ms to match snake_test's timeout for distinguishing ESC key from escape sequences.

4. **Cleanup**: The `stop/1` function restores IO options but must be called explicitly by the user or runtime.

## References

- Planning document: `notes/features/phase-7.2-tty-input-handler.md`
- Research: `notes/features/phase-7.1-research-iex-compatibility.md`
- Inspiration: `snake_test` project's TUI implementation
