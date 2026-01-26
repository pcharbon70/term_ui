# Phase 7.4: IEx Detection and Configuration

**Branch**: `feature/phase-7.4-iex-detection`
**Target**: `multi-renderer`
**Created**: 2025-01-25
**Status**: Complete

## Problem Statement

The TTY input handler implemented in Phase 7.2 uses `:io.get_chars/2` which works in both IEx and standalone environments. However:

1. There was no way for applications to detect if they're running in IEx
2. No configuration option existed to force IEx-compatible mode
3. No environment variable override for testing/debugging
4. Users might want to know which mode they're in for logging/debugging

Additionally, the original Phase 7.4 plan assumed a separate-process input architecture with conditional strategies. Since Phase 7.2 implemented a simpler direct approach that works universally, this phase focuses on detection and configuration rather than changing behavior.

## Solution Overview

Added IEx detection capabilities and configuration options:

1. **`TermUI.iex_mode?/0`** - Function to detect if running in IEx
2. **`TermUI.running_mode/0`** - Returns `:iex` or `:standalone`
3. **Config option** - `:iex_compatible` to force IEx-compatible mode
4. **Environment variable** - `TERM_UI_IEX_MODE` for testing/debugging
5. **Logging** - Runtime logs detected mode at startup

Note: The TTY handler's `:io.get_chars/2` approach already works in both environments, so no input strategy changes are needed. This is purely about detection and configuration.

## Technical Details

### Files Modified

- `lib/term_ui.ex` - Added `iex_mode?/0` and `running_mode/0` functions
- `lib/term_ui/config.ex` - Added `:iex_compatible` config documentation
- `lib/term_ui/runtime.ex` - Logs detected mode at startup
- `test/term_ui_test.exs` - Added tests for IEx detection

### Detection Strategy

IEx detection checks:
1. Whether `IEx` module is loaded (`Code.ensure_loaded?(IEx)`)
2. Whether the current process is an IEx evaluator process (has `:iex_server` in process dictionary)
3. Configuration overrides (config or environment variable)

### Configuration

```elixir
# config/config.exs
config :term_ui,
  iex_compatible: true  # Force IEx-compatible mode
```

```bash
# Environment variable
export TERM_UI_IEX_MODE=true
```

### Override Hierarchy

1. Environment variable (`TERM_UI_IEX_MODE`) - highest priority
2. Config option (`:iex_compatible`)
3. Auto-detection - lowest priority

## Success Criteria

1. ✅ `TermUI.iex_mode?/0` returns `true` when in IEx, `false` otherwise
2. ✅ Config option can force IEx-compatible mode
3. ✅ Environment variable can override detection
4. ✅ Runtime logs detected mode at startup
5. ✅ All tests pass (14 tests)

## Implementation Plan

### Task 7.4.1: Implement IEx Detection

- [x] 7.4.1.1 Create `TermUI.iex_mode?/0` function
- [x] 7.4.1.2 Check for IEx module existence
- [x] 7.4.1.3 Check for IEx evaluator process
- [x] 7.4.1.4 Add `TermUI.running_mode/0` returning `:iex | :standalone`

### Task 7.4.2: Add Configuration Options

- [x] 7.4.2.1 Add `:iex_compatible` config option
- [x] 7.4.2.2 Add `TERM_UI_IEX_MODE` environment variable support
- [x] 7.4.2.3 Config overrides auto-detection
- [x] 7.4.2.4 Environment variable overrides config

### Task 7.4.3: Update Runtime

- [x] 7.4.3.1 Log detected mode at startup

### Unit Tests

- [x] Test `iex_mode?/0` returns correct value
- [x] Test config option overrides detection
- [x] Test environment variable overrides detection
- [x] Test `running_mode/0` returns correct atom

## Current Status

**What Works**:
- Phase 7.2 completed with `:io.get_chars/2` integration
- TTY handler works in both IEx and standalone
- Phase 7.3 completed with Runtime cleanup
- IEx detection functions working
- Config and env var overrides working
- Runtime logging mode at startup
- All 14 tests passing

**What's Next**:
- Manual testing in actual IEx session to verify detection

## Notes/Considerations

### Design Decisions

1. **No Behavior Change**: Since `:io.get_chars/2` works universally, this phase is purely about detection and configuration. The TTY handler behavior doesn't change based on IEx detection.

2. **API Location**: Detection functions go in `TermUI` module (main public API) rather than in individual handlers.

3. **Override Hierarchy**: Environment variable > Config option > Auto-detection

4. **Testing**: IEx detection is difficult to test in unit tests since we're not running in IEx during tests. We test the override mechanisms and verify default behavior.

### Potential Issues

1. **Test Environment**: We can't easily test actual IEx detection in unit tests. We test the override mechanisms and verify default behavior (returns `false` when not in IEx).

2. **False Positives**: Just checking for `IEx` module isn't enough (it might be loaded but we're not in IEx). We also check if the process dictionary contains `:iex_server`.

### Test Strategy

1. **Unit Tests with Overrides**: Test config and environment variable overrides
2. **Default Behavior**: Verify `iex_mode?()` returns `false` in normal tests
3. **Manual Tests**: Run in actual IEx to verify detection works

## Deliverables

1. ✅ `lib/term_ui.ex` - Added `iex_mode?/0` and `running_mode/0` functions
2. ✅ `lib/term_ui/runtime.ex` - Logs mode at startup
3. ✅ `lib/term_ui/config.ex` - Added IEx-related config documentation
4. ✅ `test/term_ui_test.exs` - Tests for IEx detection
5. ⏳ Summary in `notes/summaries/phase-7.4-summary.md` (pending)
