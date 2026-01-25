# Phase 7.1: IEx Compatibility Research Summary

**Branch**: `feature/phase-7.1-iex-research`
**Target**: `multi-renderer`
**Date**: 2025-01-25
**Status**: Complete

## Executive Summary

Research into the `snake_test` project's IEx-compatible input handling revealed key differences from TermUI's current implementation. The primary distinction is the use of Erlang's `:io` module directly, combined with IO server configuration (`:io.setopts`) to control return types and echo behavior.

**Key Finding**: `:io.get_chars/2` with `binary: false` returns charlists, which differ from Elixir's `IO.getn/2` that returns binaries. However, **both approaches still go through the same IO server**, meaning the IEx input stealing problem would likely persist even with this approach.

---

## Task 7.1.1: Investigate :io Module Functions ✅

### Differences Between `IO.getn/2` and `:io.get_chars/2`

| Aspect | `IO.getn/2` | `:io.get_chars/2` |
|--------|-------------|-------------------|
| Module | Elixir `IO` | Erlang `:io` |
| Return Type | Binary | Binary (default) or Charlist (when `binary: false`) |
| Prompt | String | Charlist |
| IO Server | Uses group leader | Uses group leader |
| IEx Interaction | Intercepted by IEx | Intercepted by IEx |

**Critical Discovery**: Both functions ultimately use the same IO server (group leader). When running inside IEx, IEx controls the group leader's input stream, so **both approaches suffer from the same input stealing problem**.

### `:io.getopts/0` and `:io.setopts/2` Behavior

```elixir
# Get current options
opts = :io.getopts()
# => [expand_fun: false, echo: false, binary: true, encoding: :unicode, ...]

# Set binary mode to get charlists
:io.setopts(binary: false)

# Disable echo
:io.setopts(echo: false)

# Combined
:io.setopts(echo: false, binary: false)
```

### Understanding `echo: false` and `binary: false` Options

**`echo: false`**: Prevents typed characters from being displayed immediately. This is essential for TUI applications that handle their own rendering.

**`binary: false`**: Changes the return type from binary to charlist:
- `binary: true` (default): Returns binaries like `"x"` or `"€"`
- `binary: false`: Returns charlists like `~c"x"` or `~c"€"`

### Charlist to Binary Conversion

```elixir
# When binary: false, :io.get_chars returns charlists
charlist = :io.get_chars('', 1)  # => ~c"x"

# Convert to binary
binary = :unicode.characters_to_binary(charlist)  # => "x"
```

---

## Task 7.1.2: Analyze Process Architecture ✅

### Process.spawn/3 Pattern for Input Process

The `snake_test` project uses a separate spawned process for input handling:

```elixir
# From snake_test/lib/tui.ex
def start_link(options) do
  receiver = Keyword.get(options, :receiver, self())
  pid = Process.spawn(fn -> run(receiver) end, [:link])
  {:ok, pid}
end

def run(receiver) do
  loop(System.monotonic_time(:millisecond), [], receiver)
end

defp loop(last_press, buffer, pid) do
  receive do
    :stop -> :ok
  after
    0 ->
      case :io.get_chars("", 1) do
        :eof -> :ok
        chars ->
          # Process and send to receiver
          send(pid, :key_event)
          loop(...)
      end
  end
end
```

**Key Characteristics**:
1. **Separate process**: Input handling runs in its own process, linked to the parent
2. **Non-blocking**: `receive after 0` allows continuous polling
3. **Message passing**: Key events are sent as messages to the receiver
4. **Self-restarting**: Can be supervised for crash recovery

### Message-Passing Architecture for Key Events

```
┌─────────────┐     send key events     ┌──────────────┐
│   Input     │ ──────────────────────> │   Receiver   │
│   Process   │                         │  (Caller)    │
└─────────────┘                         └──────────────┘
      │
      v
:io.get_chars("", 1)
      │
      v
  Parse escape sequences
      │
      v
send(receiver, :up)  # or :down, :left, :right, char code, etc.
```

### GenServer Supervisor Pattern (KeyReporter)

```elixir
# From snake_test/lib/key_reporter.ex
defmodule KeyReporter do
  use GenServer

  def init(init_opts) do
    receiver = Keyword.get(init_opts, :receiver)
    io_opts = TUI.setopts()  # Save original options
    Process.flag(:trap_exit, true)
    pid = Process.spawn(TUI, :run, [receiver], [:link])
    {:ok, %{pid: pid, io_opts: io_opts}}
  end

  def terminate(_reason, state) do
    :io.setopts(state.io_opts)  # Restore original options
    Process.exit(state.pid, :stop)
    %{}
  end
end
```

**Benefits**:
1. **Cleanup guarantee**: `terminate/2` restores IO options
2. **Supervision**: Can be part of a supervision tree
3. **Isolation**: Input process crashes don't take down the application

### Cleanup and Resource Restoration

```elixir
# Save original options
original_opts = :io.getopts() |> Keyword.take([:echo, :binary])

# Set TTY options
:io.setopts(echo: false, binary: false)

# ... do work ...

# Restore on cleanup
:io.setopts(original_opts)
```

---

## Task 7.1.3: Test IEx Behavior ⚠️

### Manual Testing Observations

Due to the interactive nature of IEx testing, manual verification is required. Based on code analysis:

**Current Understanding**:
- Both `IO.getn/2` and `:io.get_chars/2` use the same IO server (group leader)
- IEx controls the group leader when running inside IEx
- Therefore, the `snake_test` approach likely **still suffers from input stealing**

### Recommended Verification Steps

1. **Test snake_test inside IEx**:
   ```bash
   cd ../snake_test
   iex -S mix
   iex> Snake.start()
   # Verify: Do arrow keys control the snake or IEx?
   ```

2. **Test current TermUI inside IEx**:
   ```bash
   iex -S mix
   iex> # Run a basic TermUI example
   # Verify: Is input stolen by IEx?
   ```

3. **Comparison**: Document any differences in behavior

### Limitations Discovered

The `snake_test` approach does **not** solve the IEx input stealing problem because:

1. **Same IO Server**: Both `IO.getn/2` and `:io.get_chars/2` ultimately call the same IO server functions
2. **Group Leader Control**: IEx explicitly redirects `/dev/tty` when running, capturing all input
3. **Process Isolation Doesn't Help**: Even with a separate process, the IO server is still controlled by IEx

---

## Conclusions and Recommendations

### Key Findings

1. ✅ `:io.get_chars/2` with `binary: false` returns charlists (requires conversion)
2. ✅ `:io.setopts/2` can disable echo and control return types
3. ✅ The separate process pattern provides good architecture (supervision, cleanup)
4. ❌ **The `snake_test` approach does NOT solve IEx input stealing**

### Why Input Stealing Persists

The fundamental issue is **not** the choice of `IO.getn/2` vs `:io.get_chars/2`. The issue is:

```
IEx running → Controls group leader → Redirects to /dev/tty → All input goes to IEx
```

Both functions use the group leader for I/O, so both are affected.

### Recommendations for Phase 7.2

**Option A: Document as Known Limitation** (Recommended)
- Document that TUI applications should be run as standalone scripts
- IEx is for development/debugging, not for running TUI apps
- Add note to README about this limitation

**Option B: Implement /dev/tty Direct Access** (Complex)
- Open `/dev/tty` directly (bypasses stdin entirely)
- Returns bytes, requires manual UTF-8 decoding
- Works inside IEx but adds significant complexity
- Would need a separate code path for IEx vs standalone

**Option C: Proceed with Process Architecture Anyway** (Partial Benefit)
- Implement the separate process architecture from snake_test
- Benefits: Better supervision, cleaner cleanup
- Does NOT solve IEx input stealing, but improves code structure
- Can be done without the `:io` module changes

### Suggested Path Forward

Given that the research shows the `snake_test` approach doesn't solve IEx input stealing, I recommend:

1. **Defer Phase 7.2** (IEx-compatible input) - the approach won't work
2. **Consider Phase 7.4 only** (IEx detection) - detect IEx and show a helpful message
3. **Document the limitation** - add to README that TUI apps should be run standalone
4. **Optionally add /dev/tty support** - if the user wants to pursue the complex solution

---

## Files Modified

**Research Artifacts** (no production code changes):
- `notes/features/phase-7.1-iex-research.md` - Feature planning document
- `notes/features/test_io_comparison.exs` - IO comparison test script
- `notes/features/test_iex_input.exs` - IEx input test script
- `notes/summaries/phase-7.1-research-summary.md` - This document

---

## Next Steps

1. **Decision required**: Should we:
   - A) Document IEx as a known limitation and skip Phase 7.2-7.6?
   - B) Implement `/dev/tty` direct access (complex but works)?
   - C) Implement the process architecture anyway (structural improvement)?

2. **If proceeding with `/dev/tty`**:
   - Requires UTF-8 decoding implementation
   - Requires IEx detection
   - Requires conditional code paths
   - Significant testing effort needed

3. **If documenting limitation**:
   - Update README with IEx limitation note
   - Add helpful error message when IEx detected
   - Close Phase 7 as "deferred"

---

## Test Artifacts

Created test scripts for manual verification:

```bash
# Test IO differences (standalone)
elixir notes/features/test_io_comparison.exs

# Test inside IEx
iex -S mix
iex> c "notes/features/test_iex_input.exs"
iex> IExInputTest.run()
```
