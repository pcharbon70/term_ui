# Phase 7.6: Integration Tests for IEx Compatibility

**Feature Branch:** `feature/phase-7.6-integration-tests`
**Base Branch:** `multi-renderer`
**Status:** In Progress

## Overview

This phase implements comprehensive integration tests for IEx compatibility, ensuring that TermUI applications work correctly both in IEx sessions and in standalone mode.

## Requirements from Planning Document

### Section 7.6.1: IEx Lifecycle Tests

- **7.6.1.1**: Test start → render → input → update → render → shutdown in IEx
- **7.6.1.2**: Test keyboard input works correctly in IEx
- **7.6.1.3**: Test cleanup on crash in IEx
- **7.6.1.4**: Test multiple start/stop cycles in IEx session

### Section 7.6.2: Cross-Mode Tests

- **7.6.2.1**: Test same app works identically in IEx and standalone
- **7.6.2.2**: Test Raw backend still works when not in IEx
- **7.6.2.3**: Test switching between IEx and standalone modes

## Key Technical Context

### IEx Detection Mechanism

- `TermUI.iex_mode?/0` - Checks if running in IEx
- `TermUI.running_mode/0` - Returns `:iex` or `:standalone`
- Detection via `Process.info(self(), :dictionary)` checking for `:iex_server` key
- Configuration overrides via `Application.get_env(:term_ui, :iex_compatible)` and `TERM_UI_IEX_MODE` env var

### TTY Backend for IEx Compatibility

- `TermUI.Backend.TTY` - Provides IEx-compatible terminal I/O
- Uses `IO.getn/2` for character-by-character input
- Parses escape sequences via `TermUI.Terminal.EscapeParser`
- Handles partial escape sequences via `input_buffer` field

### Runtime Integration

- `TermUI.Runtime` - Central orchestrator for application lifecycle
- `TermUI.App.run/2` - Blocking run for applications
- `TermUI.App.start/2` - Non-blocking start for supervision
- `TermUI.App.shutdown/0-1` - Graceful shutdown with terminal cleanup

## Test Implementation Plan

### 1. IEx Lifecycle Integration Test (`test/term_ui/integration/iex_lifecycle_test.exs`)

Test the complete application lifecycle when running in IEx mode:

```elixir
defmodule TermUI.Integration.IExLifecycleTest do
  use ExUnit.Case, async: false

  # Tests will simulate IEx environment by:
  # 1. Setting process dictionary with :iex_server key
  # 2. Forcing iex_compatible config
  # 3. Starting/stopping applications
  # 4. Verifying cleanup
end
```

### 2. Cross-Mode Integration Test (`test/term_ui/integration/cross_mode_test.exs`)

Test consistency between IEx and standalone modes:

```elixir
defmodule TermUI.Integration.CrossModeTest do
  use ExUnit.Case, async: false

  # Tests will:
  # 1. Run same app in both modes
  # 2. Verify behavior consistency
  # 3. Test backend selection
end
```

## Test Components

### Test Application

A simple test component implementing the Elm Architecture:

```elixir
defmodule TermUI.TestComponents.Counter do
  @moduledoc """
  Simple counter component for integration testing.
  """

  defstruct count: 0

  def init(_opts), do: {:ok, %__MODULE__{}}

  def view(%__MODULE__{count: count}) do
    [
      {:text, "Count: #{count}"},
      {:text, "\nPress + to increment, - to decrement, q to quit"}
    ]
  end

  def update({:key, ?+}, %__MODULE__{} = model), do: {:ok, %{model | count: model.count + 1}}
  def update({:key, ?-}, %__MODULE__{} = model), do: {:ok, %{model | count: model.count - 1}}
  def update({:key, ?q}, model), do: {:quit, model}
  def update(_msg, model), do: {:ok, model}
end
```

## Implementation Status

- [ ] Create test helper module for IEx environment simulation
- [ ] Implement IExLifecycleTest (7.6.1.1-7.6.1.4)
- [ ] Implement CrossModeTest (7.6.2.1-7.6.2.3)
- [ ] Add test component modules
- [ ] Run full test suite to verify no regressions

## Notes

- Tests use `async: false` because they manipulate process state and global configuration
- IEx environment simulation is done via process dictionary manipulation
- Tests skip actual terminal I/O to avoid blocking in CI
- Focus is on lifecycle and state management, not terminal interaction
