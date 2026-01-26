# Phase 7.1: IEx Compatibility Research Summary

**Branch**: `feature/phase-7.1-iex-research`
**Target**: `multi-renderer`
**Date**: 2025-01-25
**Status**: Complete

## Executive Summary

Research into the `snake_test` project's IEx-compatible input handling revealed key differences from TermUI's current implementation. The primary distinction is the use of Erlang's `:io` module directly, combined with IO server configuration (`:io.setopts`) to control return types and echo behavior.

**Key Finding**: The `:io.get_chars/2` approach with a separate spawned process **DOES work inside IEx**. Testing confirms that snake_test's Snake.start() works perfectly when run from IEx - arrow keys control the snake and input is NOT stolen by IEx.

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

## Task 7.1.3: Test IEx Behavior ✅

### Manual Testing Results

User confirmed testing inside IEx with `iex -S mix` followed by `Snake.start()`:

**Result**: **Snake works perfectly** - arrow keys control the snake, input is NOT stolen by IEx.

**Why This Works** (Corrected Analysis):

The key is the combination of:
1. **Separate spawned process** - Input handling runs in its own process
2. **`:io.get_chars/2`** - Direct Erlang IO function (vs Elixir's `IO.getn/2` wrapper)
3. **`receive after 0` loop** - Continuous non-blocking polling
4. **`:io.setopts(echo: false, binary: false)`** - Configures IO server directly

While both approaches use the same IO server (group leader), the direct Erlang `:io` call with a separate process appears to bypass IEx's input interception. The exact mechanism may be related to how IEx hooks into Elixir's IO layer versus the underlying Erlang IO functions.

### Comparison with TermUI Current Behavior

| Aspect | snake_test | TermUI Current |
|--------|-----------|----------------|
| Function | `:io.get_chars/2` | `IO.getn/2` |
| Process | Separate spawned process | Direct in poll/2 |
| Loop | `receive after 0` | Blocking read |
| IEx Behavior | **Works correctly** | Input stolen by IEx |

### Why The Previous Analysis Was Wrong

Initial analysis incorrectly concluded that both approaches would fail because they use the same IO server. However, practical testing shows that:

1. The direct Erlang `:io.get_chars/2` call behaves differently than Elixir's `IO.getn/2` wrapper
2. The separate process pattern with `receive after 0` creates a polling loop that successfully captures input
3. This is a working solution that can be adopted by TermUI

---

## Conclusions and Recommendations

### Key Findings

1. ✅ `:io.get_chars/2` with `binary: false` returns charlists (requires conversion)
2. ✅ `:io.setopts/2` can disable echo and control return types
3. ✅ The separate process pattern provides good architecture (supervision, cleanup)
4. ✅ **The `snake_test` approach DOES solve IEx input stealing**

### Why This Works

The key difference is that the direct Erlang `:io.get_chars/2` call, when made from a separate spawned process with a `receive after 0` loop, successfully captures keyboard input even when running inside IEx. This is likely because:

1. **Elixir's `IO` module wrapper** may have additional hooks that IEx intercepts
2. **Direct Erlang `:io` calls** may bypass some of these hooks
3. **Separate process** creates isolation from IEx's input handling
4. **Continuous polling** with `receive after 0` ensures the process is always ready to receive input

### Recommendations for Phase 7.2

**Proceed with implementing the snake_test approach** in TermUI.

The implementation should:
1. Replace `IO.getn/2` with `:io.get_chars/2` in the TTY input handler
2. Add `:io.setopts(echo: false, binary: false)` configuration
3. Implement the separate process pattern with `receive after 0` loop
4. Add charlist to binary conversion for compatibility
5. Create a GenServer wrapper for proper supervision and cleanup

### Suggested Path Forward

1. **Proceed with Phase 7.2** - Implement the working solution
2. **Create `TermUI.Input.TTY.Server`** - GenServer for input process
3. **Update `TermUI.Input.TTY`** - Use `:io.get_chars/2` with new process
4. **Integrate with Runtime** - Update event loop to receive messages
5. **Add IEx detection** - Optionally enable only when IEx is detected

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
