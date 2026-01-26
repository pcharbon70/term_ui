# Summary: Phase 7.4 - IEx Detection and Configuration

## What Was Implemented

This phase adds IEx detection capabilities and configuration options to TermUI, allowing applications to detect their execution environment and override detection for testing purposes.

### Problem Statement

The TTY input handler implemented in Phase 7.2 uses `:io.get_chars/2` which works in both IEx and standalone environments. However:

1. There was no way for applications to detect if they're running in IEx
2. No configuration option existed to force IEx-compatible mode
3. No environment variable override for testing/debugging
4. Users might want to know which mode they're in for logging/debugging

### Solution Implemented

1. **`TermUI.iex_mode?/0`** - Returns `true` if running in IEx, `false` otherwise
2. **`TermUI.running_mode/0`** - Returns `:iex` or `:standalone` atom
3. **Config option** - `:iex_compatible` to force IEx-compatible mode
4. **Environment variable** - `TERM_UI_IEX_MODE` for testing/debugging
5. **Runtime logging** - Logs detected mode at startup

### Files Modified

1. **`lib/term_ui.ex`**
   - Added `iex_mode?/0` function
   - Added `running_mode/0` function
   - Private `iex_running?/0` and `iex_evaluator_process?/0` helpers

2. **`lib/term_ui/config.ex`**
   - Added documentation for `:iex_compatible` config option

3. **`lib/term_ui/runtime.ex`**
   - Updated startup logging to include execution mode

4. **`test/term_ui_test.exs`**
   - Added 9 tests for `iex_mode?/0` covering all override scenarios
   - Added 3 tests for `running_mode/0`

## Code Changes

### TermUI.iex_mode?/0

```elixir
@spec iex_mode?() :: boolean()
def iex_mode? do
  cond do
    # Environment variable override takes precedence
    env_var = System.get_env("TERM_UI_IEX_MODE") ->
      env_var in ["true", "1", "yes"]

    # Config override
    config = Application.get_env(:term_ui, :iex_compatible) ->
      config == true

    # Auto-detection
    true ->
      iex_running?()
  end
end
```

### TermUI.running_mode/0

```elixir
@spec running_mode() :: :iex | :standalone
def running_mode do
  if iex_mode?(), do: :iex, else: :standalone
end
```

### IEx Detection

```elixir
defp iex_running? do
  # Check if IEx module is available and loaded
  Code.ensure_loaded?(IEx) and
    # Check if we're in an IEx evaluator process
    iex_evaluator_process?()
end

defp iex_evaluator_process? do
  # IEx evaluator processes have the :iex_server key in their dictionary
  Process.info(self(), :dictionary)
  |> case do
    {:dictionary, dictionary} ->
      Enum.any?(dictionary, fn
        {:iex_server, _} -> true
        _ -> false
      end)

    _ ->
      false
  end
end
```

### Runtime Logging

```elixir
# Log backend selection and execution mode
if backend_mode && backend_mode != :skip do
  require Logger
  mode_str = if TermUI.iex_mode?(), do: "IEx", else: "standalone"
  Logger.info("TermUI.Runtime started with #{backend_mode} backend (#{mode_str} mode)")
end
```

## Configuration

### Config Option

```elixir
# config/config.exs
config :term_ui,
  iex_compatible: true  # Force IEx-compatible mode
```

### Environment Variable

```bash
# Force IEx mode
export TERM_UI_IEX_MODE=true

# Force standalone mode
export TERM_UI_IEX_MODE=false
```

### Override Hierarchy

1. Environment variable (`TERM_UI_IEX_MODE`) - highest priority
2. Config option (`:iex_compatible`)
3. Auto-detection - lowest priority

## Test Results

- 14 tests passing
- Tests cover:
  - Default behavior (returns `false` when not in IEx)
  - Config override (both `true` and `false`)
  - Environment variable override (multiple values: `true`, `1`, `yes`, `false`)
  - Precedence (env var > config)

## Design Decisions

1. **No Behavior Change**: Since `:io.get_chars/2` works universally, this phase is purely about detection and configuration. The TTY handler behavior doesn't change based on IEx detection.

2. **API Location**: Detection functions go in `TermUI` module (main public API) rather than in individual handlers.

3. **Override Hierarchy**: Environment variable > Config option > Auto-detection for maximum flexibility.

4. **Detection Strategy**: Combines module check (`Code.ensure_loaded?(IEx)`) with process dictionary check (`:iex_server` key) to avoid false positives.

## What's Next

- Manual testing in actual IEx session to verify detection works correctly
- Consider adding IEx-specific optimizations if needed in the future

## Files Changed

- Modified: `lib/term_ui.ex`
- Modified: `lib/term_ui/config.ex`
- Modified: `lib/term_ui/runtime.ex`
- Modified: `test/term_ui_test.exs`
- Created: `notes/features/phase-7.4-iex-detection.md`
- Updated: `notes/planning/multi-renderer/phase-06-integration.md` (Section 7.4)
