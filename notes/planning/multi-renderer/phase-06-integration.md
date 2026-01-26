# Phase 6: Integration

## Overview

Phase 6 integrates all the multi-renderer components into the existing TermUI runtime. This phase connects the backend selector, input handlers, and widget adaptations into a cohesive system that transparently handles both raw and TTY modes.

The key integration points are:

1. **Runtime initialization**: The `TermUI.Runtime` starts the backend selector, which determines raw vs TTY mode and initializes the appropriate backend
2. **Event loop**: The runtime event loop uses the selected input handler for keyboard input
3. **Application API**: The `TermUI.App` module provides a clean API for applications to start and run regardless of backend
4. **Configuration**: Users can force a specific backend or let the system auto-detect

After this phase, applications written for TermUI will automatically work in both raw and TTY modes with no code changes. The system will try raw mode first (OTP 28+ with `:shell.start_interactive`), and gracefully fall back to TTY mode when raw mode is unavailable.

---

## 6.1 Update Runtime Initialization

- [x] **Section 6.1 Complete**

Update `TermUI.Runtime` to use the backend selector for initialization.

### 6.1.1 Integrate Backend Selector

- [x] **Task 6.1.1 Complete**

Modify runtime startup to use the backend selector.

- [x] 6.1.1.1 Modify `lib/term_ui/runtime.ex` init sequence
- [x] 6.1.1.2 Call `Backend.Selector.select/1` with configuration options
- [x] 6.1.1.3 Store selected backend module in runtime state
- [x] 6.1.1.4 Store backend state in runtime state
- [x] 6.1.1.5 Log which backend was selected

### 6.1.2 Handle Backend Selection Options

- [x] **Task 6.1.2 Complete**

Support configuration options for backend selection.

- [x] 6.1.2.1 Accept `:backend` option: `:auto` (default), `:raw`, `:tty`
- [x] 6.1.2.2 `:auto` uses selector's try-raw-first strategy
- [x] 6.1.2.3 `:raw` forces raw backend (error if unavailable)
- [x] 6.1.2.4 `:tty` forces TTY backend (skips raw mode attempt)
- [x] 6.1.2.5 Document options in runtime moduledoc

### 6.1.3 Store Backend Context

- [x] **Task 6.1.3 Complete**

Make backend information available to components.

- [x] 6.1.3.1 Store backend mode (`:raw` or `:tty`) in persistent_term
- [x] 6.1.3.2 Store capabilities map in persistent_term
- [x] 6.1.3.3 Implement `TermUI.Runtime.backend_mode/0` query function
- [x] 6.1.3.4 Implement `TermUI.Runtime.capabilities/0` query function

### Unit Tests - Section 6.1

- [x] **Unit Tests 6.1 Complete**
- [x] Test runtime initializes with auto backend selection
- [x] Test runtime respects `:backend` option
- [x] Test `backend_mode/0` returns correct mode
- [x] Test `capabilities/0` returns capabilities map
- [x] Test forced `:raw` fails gracefully when unavailable

---

## 6.2 Update Event Loop

- [x] **Section 6.2 Complete**

Update the runtime event loop to use the selected input handler.

### 6.2.1 Integrate Input Handler

- [x] **Task 6.2.1 Complete**

Use the appropriate input handler based on backend mode.

- [x] 6.2.1.1 Modify event loop to call `Input.Selector.select/0`
- [x] 6.2.1.2 Use selected handler's `poll/2` for input reading
- [x] 6.2.1.3 Handle input results consistently from both handlers

### 6.2.2 Unify Event Handling

- [x] **Task 6.2.2 Complete**

Ensure events from both backends are handled identically.

- [x] 6.2.2.1 Both backends produce `TermUI.Event.Key` structs
- [x] 6.2.2.2 Arrow keys, Tab, Enter work identically
- [x] 6.2.2.3 Escape sequences parsed by both handlers

### 6.2.3 Handle Backend-Specific Events

- [x] **Task 6.2.3 Complete**

Handle events that only exist in one mode.

- [x] 6.2.3.1 Mouse events only from raw backend (when enabled)
- [x] 6.2.3.2 Resize events from both backends (different detection)
- [x] 6.2.3.3 Focus events only from raw backend (when supported)

### Unit Tests - Section 6.2

- [x] **Unit Tests 6.2 Complete**
- [x] Test event loop reads from correct input handler
- [x] Test key events are identical format from both backends
- [x] Test mouse events only appear in raw mode
- [x] Test resize events work in both modes

---

## 6.3 Update Rendering Pipeline

- [x] **Section 6.3 Complete**

Connect the rendering pipeline to the selected backend.

### 6.3.1 Delegate Rendering to Backend

- [x] **Task 6.3.1 Complete**

Route render calls through the backend.

- [x] 6.3.1.1 Modify renderer to use `state.backend` module
- [x] 6.3.1.2 Call `backend.draw_cells/2` for frame rendering
- [x] 6.3.1.3 Call `backend.flush/1` after drawing
- [x] 6.3.1.4 Pass backend state through render cycle

### 6.3.2 Handle Render Mode Differences

- [x] **Task 6.3.2 Complete**

Handle differences between raw and TTY rendering.

- [x] 6.3.2.1 Raw backend uses differential rendering
- [x] 6.3.2.2 TTY backend uses full_redraw by default
- [x] 6.3.2.3 Both support same cell format
- [x] 6.3.2.4 Color degradation handled by backend

### 6.3.3 Integrate CharacterSet

- [x] **Task 6.3.3 Complete**

Ensure character set is available during rendering.

- [x] 6.3.3.1 Set `CharacterSet.current/0` based on capabilities
- [x] 6.3.3.2 Widgets use `CharacterSet.current/0` for box drawing
- [x] 6.3.3.3 Backend applies character mapping if needed

### Unit Tests - Section 6.3

- [x] **Unit Tests 6.3 Complete**
- [x] Test render pipeline uses correct backend
- [x] Test cells are rendered correctly in both modes
- [x] Test character set is applied during rendering

---

## 6.4 Create Application API

- [x] **Section 6.4 Complete**

Create a clean API for applications to start and run with the multi-renderer system.

### 6.4.1 Create TermUI.App Module

- [x] **Task 6.4.1 Complete**

Create the application entry point module.

- [x] 6.4.1.1 Create `lib/term_ui/app.ex` with `@moduledoc`
- [x] 6.4.1.2 Document application lifecycle
- [x] 6.4.1.3 Document configuration options

### 6.4.2 Implement start/2

- [x] **Task 6.4.2 Complete**

Implement application start function.

- [x] 6.4.2.1 Implement `start/2` accepting model module and options
- [x] 6.4.2.2 Initialize backend via selector
- [x] 6.4.2.3 Start runtime with selected backend
- [x] 6.4.2.4 Return `{:ok, pid}` or `{:error, reason}`

### 6.4.3 Implement run/2

- [x] **Task 6.4.3 Complete**

Implement blocking run function.

- [x] 6.4.3.1 Implement `run/2` that starts and waits for completion
- [x] 6.4.3.2 Block until application exits
- [x] 6.4.3.3 Clean up terminal state on exit
- [x] 6.4.3.4 Return final model state

### 6.4.4 Implement Convenience Functions

- [x] **Task 6.4.4 Complete**

Add convenience functions for common operations.

- [x] 6.4.4.1 Implement `backend_mode/0` returning current mode
- [x] 6.4.4.2 Implement `supports?/1` for capability queries
- [x] 6.4.4.3 Implement `shutdown/0` for clean shutdown

### Unit Tests - Section 6.4

- [x] **Unit Tests 6.4 Complete**
- [x] Test `start/2` returns `{:ok, pid}`
- [x] Test `run/2` blocks until completion
- [x] Test `backend_mode/0` returns correct mode
- [x] Test `supports?/1` queries capabilities
- [x] Test cleanup happens on exit

---

## 6.5 Add Configuration System

- [x] **Section 6.5 Complete**

Add application configuration for backend preferences.

### 6.5.1 Define Configuration Options

- [x] **Task 6.5.1 Complete**

Define configurable options.

- [x] 6.5.1.1 `config :term_ui, :backend` - `:auto`, `:raw`, or `:tty`
- [x] 6.5.1.2 `config :term_ui, :character_set` - `:auto`, `:unicode`, or `:ascii`
- [x] 6.5.1.3 `config :term_ui, :color_mode` - `:auto`, `:true_color`, `:color_256`, `:color_16`, `:monochrome`
- [x] 6.5.1.4 `config :term_ui, :render_interval` - Milliseconds between renders

### 6.5.2 Implement Configuration Reading

- [x] **Task 6.5.2 Complete**

Read configuration during initialization.

- [x] 6.5.2.1 Create `TermUI.Config` module
- [x] 6.5.2.2 Implement `get/2` with defaults
- [x] 6.5.2.3 Implement `merge_options/2` for merging config and runtime options
- [x] 6.5.2.4 Runtime options override application config
- [x] 6.5.2.5 Runtime initialization uses Config for defaults

### 6.5.3 Document Configuration

- [x] **Task 6.5.3 Complete**

Document all configuration options.

- [ ] 6.5.3.1 Add configuration section to README (deferred)
- [x] 6.5.3.2 Document each option with examples in Config module
- [ ] 6.5.3.3 Provide common configuration recipes (deferred)

### Unit Tests - Section 6.5

- [x] **Unit Tests 6.5 Complete**
- [x] Test configuration defaults are applied (26 tests pass)
- [x] Test runtime options override config
- [x] Test merge_options/2 combines correctly

---

## 6.6 Add Graceful Degradation Logging

- [x] **Section 6.6 Complete**

Add logging to help developers understand what capabilities are available.

### 6.6.1 Log Backend Selection

- [x] **Task 6.6.1 Complete**

Log which backend was selected and why.

- [x] 6.6.1.1 Log when raw mode succeeds
- [x] 6.6.1.2 Log when falling back to TTY mode
- [x] 6.6.1.3 Include reason for fallback
- [x] 6.6.1.4 Use Logger with `:info` level

### 6.6.2 Log Capability Detection

- [x] **Task 6.6.2 Complete**

Log detected capabilities.

- [x] 6.6.2.1 Log color mode detected
- [x] 6.6.2.2 Log character set detected
- [x] 6.6.2.3 Log terminal size
- [x] 6.6.2.4 Use Logger with `:debug` level

### 6.6.3 Log Degradation Events

- [x] **Task 6.6.3 Complete**

Degradation is implicit in capability detection - logged as part of capabilities.

- [x] 6.6.3.1 Colors are logged in capability detection
- [x] 6.6.3.2 Character set is logged in capability detection

### Unit Tests - Section 6.6

- [x] **Unit Tests 6.6 Complete**
- [x] Test backend selection is logged (3 tests)
- [x] Test capabilities are logged at debug level (1 test)

---

## 6.7 Create Example Applications

- [x] **Section 6.7 Complete**

Create example applications demonstrating both modes.

### 6.7.1 Create Basic Example

- [x] **Task 6.7.1 Complete**

Create a basic example showing auto-detection.

- [x] 6.7.1.1 Create `examples/multi_renderer/basic.ex`
- [x] 6.7.1.2 Simple list navigation application
- [x] 6.7.1.3 Works identically in both modes
- [x] 6.7.1.4 Add README explaining how to test both modes

### 6.7.2 Create TextInput Example

- [x] **Task 6.7.2 Complete**

Create example showing TextInput variants.

- [x] 6.7.2.1 Create `examples/multi_renderer/text_input.ex`
- [x] 6.7.2.2 Show TextInput (character mode) and TextInput.Line (line mode)
- [x] 6.7.2.3 Demonstrate when to use each

### 6.7.3 Create Feature Detection Example

- [x] **Task 6.7.3 Complete**

Create example showing capability queries.

- [x] 6.7.3.1 Create `examples/multi_renderer/capabilities.ex`
- [x] 6.7.3.2 Display detected capabilities
- [x] 6.7.3.3 Show current backend mode
- [x] 6.7.3.4 Show color and character set in use

### Unit Tests - Section 6.7

- [x] **Unit Tests 6.7 Complete**
- [x] Test examples compile
- [x] Test examples run without error in test mode

---

## 6.8 Integration Tests

- [x] **Section 6.8 Complete**

Integration tests verify the complete system works end-to-end.

### 6.8.1 Full Application Lifecycle Tests

- [x] **Task 6.8.1 Complete**

Test complete application lifecycle.

- [x] 6.8.1.1 Test start → render → input → update → render → shutdown
- [x] 6.8.1.2 Test in raw mode (if available)
- [x] 6.8.1.3 Test in TTY mode (forced)
- [x] 6.8.1.4 Test cleanup on crash

### 6.8.2 Backend Switching Tests

- [x] **Task 6.8.2 Complete**

Test backend selection scenarios.

- [x] 6.8.2.1 Test auto-detection selects appropriate backend
- [x] 6.8.2.2 Test forced raw mode works when available
- [x] 6.8.2.3 Test forced TTY mode skips raw attempt
- [x] 6.8.2.4 Test error on forced raw when unavailable

### 6.8.3 Input Consistency Tests

- [x] **Task 6.8.3 Complete**

Test input works consistently.

- [x] 6.8.3.1 Test arrow keys work in both modes
- [x] 6.8.3.2 Test Enter/Tab/Escape work in both modes
- [x] 6.8.3.3 Test widgets respond identically to input

### 6.8.4 Rendering Consistency Tests

- [x] **Task 6.8.4 Complete**

Test rendering works consistently.

- [x] 6.8.4.1 Test same widget renders in both modes
- [x] 6.8.4.2 Test colors degrade correctly
- [x] 6.8.4.3 Test characters degrade correctly

---

## Success Criteria

1. **Runtime Integration**: Backend selector integrated into runtime startup
2. **Event Loop**: Input handler selected and used based on backend
3. **Rendering**: Backend handles all rendering operations
4. **Application API**: Clean `TermUI.App` API for applications
5. **Configuration**: Backend and features configurable via config
6. **Logging**: Helpful logging for debugging backend selection
7. **Examples**: Working examples demonstrating both modes
8. **Test Coverage**: All unit and integration tests pass

---

## Provides Foundation

This phase completes the multi-renderer architecture:
- Applications automatically work in both raw and TTY modes
- No code changes required for existing applications
- Clear API for capability queries when needed

---

## Key Outputs

- `lib/term_ui/app.ex` - Application entry point
- `lib/term_ui/config.ex` - Configuration module
- Updated `lib/term_ui/runtime.ex` - Backend integration
- `examples/multi_renderer/` - Example applications
- `test/integration/multi_renderer_test.exs` - Integration tests

---

## Critical Files to Modify

- `lib/term_ui/runtime.ex` - Backend and input integration
- `lib/term_ui/renderer.ex` - Delegate to backend
- `mix.exs` - Add examples to project

---

## Migration Guide

For existing TermUI applications:

1. **No changes required** - Applications will automatically use the appropriate backend
2. **Optional**: Use `TermUI.App.backend_mode/0` to check current mode
3. **Optional**: Use `TextInput.Line` for shell line editing in TTY mode
4. **Optional**: Configure preferred backend in `config/config.exs`

```elixir
# Force TTY mode for testing
config :term_ui, :backend, :tty

# Force specific render mode
config :term_ui, :tty_render_mode, :full_redraw
```

---

# Phase 7: IEx Compatibility

## Overview

Phase 7 implements IEx-compatible input handling for TUI applications. Currently, when TermUI applications run inside IEx, keyboard input is captured by IEx instead of the application. This phase implements an alternative input strategy inspired by the `snake_test` project that uses direct Erlang IO functions and a separate input process.

The key changes are:

1. Use `:io.get_chars/2` instead of `IO.getn/2` for TTY backend input
2. Configure the IO server directly with `:io.setopts/2`
3. Input handling runs in a separate spawned process
4. Non-blocking poll pattern with `receive after 0`

After this phase, TermUI applications will work correctly when run from within IEx, enabling interactive development and testing.

---

## 7.1 Research snake_test Input Approach

- [x] **Section 7.1 Complete** ✅ **Research Confirmed - Approach Works!**

Analyze the snake_test project's input handling implementation to understand the key differences from current TermUI approach.

**Research Summary**: The `snake_test` approach **DOES work** inside IEx. Testing confirmed that `Snake.start()` runs correctly from IEx with `iex -S mix` - arrow keys control the snake and input is NOT stolen. See `notes/summaries/phase-7.1-research-summary.md` for details.

### 7.1.1 Investigate :io Module Functions

- [x] **Task 7.1.1 Complete**

Research the differences between Elixir's `IO` module and Erlang's `:io` module.

- [x] 7.1.1.1 Document differences between `IO.getn/2` and `:io.get_chars/2`
- [x] 7.1.1.2 Research `:io.getopts/0` and `:io.setopts/2` behavior
- [x] 7.1.1.3 Understand `echo: false` and `binary: false` options
- [x] 7.1.1.4 Test behavior difference when running inside IEx

**Key Finding**: `:io.get_chars/2` with `binary: false` returns charlists; the direct Erlang call with separate process bypasses IEx's input interception.

### 7.1.2 Analyze Process Architecture

- [x] **Task 7.1.2 Complete**

Study how snake_test uses a separate process for input handling.

- [x] 7.1.2.1 Document the `Process.spawn/3` pattern for input process
- [x] 7.1.2.2 Understand the message-passing architecture for key events
- [x] 7.1.2.3 Analyze the GenServer supervisor pattern (KeyReporter)
- [x] 7.1.2.4 Document cleanup and resource restoration on termination

**Key Finding**: The separate process with `receive after 0` loop is key to making IEx input work correctly.

### 7.1.3 Test IEx Behavior

- [x] **Task 7.1.3 Complete**

Verify whether the snake_test approach actually works inside IEx.

- [x] 7.1.3.1 Run snake_test inside IEx and verify input is not stolen
- [x] 7.1.3.2 Compare with current TermUI behavior inside IEx
- [x] 7.1.3.3 Document any remaining issues or limitations

**Critical Finding**: The approach **WORKS** - testing confirmed `Snake.start()` works perfectly in IEx with `iex -S mix`.

### Unit Tests - Section 7.1

- [x] **Unit Tests 7.1 Complete**
- [x] Test scripts created for manual verification
- [x] Research documentation complete
- [x] Summary written with recommendations

**Note**: Test scripts created in `notes/features/` for manual IEx verification.

---

## 7.2 Update TTY Input Handler

- [x] **Section 7.2 Complete**

Modified `TermUI.Input.TTY` to use `:io.get_chars/2` for IEx compatibility.

### 7.2.1 Replace IO.getn with :io.get_chars

- [x] **Task 7.2.1 Complete**

Updated the character reading function to use Erlang's `:io` module.

- [x] 7.2.1.1 Replace `IO.getn("", 1)` with `:io.get_chars("", 1)` in `Input.TTY.read_char/0`
- [x] 7.2.1.2 Update return type handling for charlist vs binary
- [x] 7.2.1.3 Add conversion from charlist to binary for compatibility
- [x] 7.2.1.4 Update error handling for `:io` module error formats

### 7.2.2 Add IO Server Configuration

- [x] **Task 7.2.2 Complete**

Implemented direct IO server configuration.

- [x] 7.2.2.1 Add `:io.getopts/0` call to save original options in `new/0`
- [x] 7.2.2.2 Add `:io.setopts(echo: false, binary: false)` call in `new/0`
- [x] 7.2.2.3 Store IO opts flags in state struct
- [x] 7.2.2.4 Implement cleanup function to restore original opts

### 7.2.3 Separate Process Input (Simplified Approach)

- [x] **Task 7.2.3 Complete**

Evaluated separate process approach but implemented simpler direct approach for API compatibility.

- [x] 7.2.3.1 Created `TermUI.Input.TTY.Server` GenServer (archived for future use)
- [x] 7.2.3.2 Implemented continuous polling loop (archived)
- [x] 7.2.3.3 Send parsed key events as messages (archived)
- [x] 7.2.3.4 Handle process cleanup and termination (archived)

**Note**: Separate process architecture (TTY.Server) was implemented but not integrated due to API compatibility concerns. The simpler direct approach using `:io.get_chars/2` was used instead.

### Unit Tests - Section 7.2

- [x] **Unit Tests 7.2 Complete**
- [x] All 45 tests passing
- [x] State struct has new IO opts fields
- [x] Documentation tests verify IEx compatibility
- [x] Comparison tests with Raw handler updated

---

## 7.3 Integrate with Runtime

- [x] **Section 7.3 Complete**

Update the Runtime to properly integrate with the IEx-compatible TTY input handler.

**Note**: The original Phase 7.3 plan assumed a separate-process input architecture (TTY.Server), but Phase 7.2 implemented a simpler direct approach using `:io.get_chars/2`. This phase updates the integration to match the actual implementation.

### 7.3.1 Add stop/1 to Input Behaviour

- [x] **Task 7.3.1 Complete**

Add cleanup callback to the Input behaviour and implement in handlers.

- [x] 7.3.1.1 Add `stop/1` callback to `TermUI.Input` behaviour
- [x] 7.3.1.2 Update behaviour documentation
- [x] 7.3.1.3 Implement `stop/1` in `TermUI.Input.Raw`
- [x] 7.3.1.4 Add `@impl true` to `TermUI.Input.TTY.stop/1`

### 7.3.2 Update Runtime Cleanup

- [x] **Task 7.3.2 Complete**

Ensure Runtime calls input handler cleanup during shutdown.

- [x] 7.3.2.1 Add input handler cleanup to `Runtime.terminate/2`
- [x] 7.3.2.2 Handle nil input_handler gracefully
- [x] 7.3.2.3 Verify cleanup happens in correct order

### Unit Tests - Section 7.3

- [x] **Unit Tests 7.3 Complete**
- [x] Test Input.stop/1 callback is defined
- [x] Test Raw.stop/1 returns :ok
- [x] Test TTY.stop/1 returns :ok
- [x] Test Runtime calls stop on input handler during shutdown

---

## 7.4 Add IEx Detection

- [x] **Section 7.4 Complete**

Add IEx detection capabilities and configuration options for testing and debugging.

**Note**: The original Phase 7.4 plan assumed a separate-process input architecture with conditional strategies. Since Phase 7.2 implemented a simpler direct approach using `:io.get_chars/2` that works universally in both IEx and standalone, this phase focuses on detection and configuration rather than changing behavior.

### 7.4.1 Implement IEx Detection

- [x] **Task 7.4.1 Complete**

Create functions to detect when running inside IEx.

- [x] 7.4.1.1 Create `TermUI.iex_mode?/0` function
- [x] 7.4.1.2 Check for IEx module existence and evaluator process
- [x] 7.4.1.3 Create `TermUI.running_mode/0` returning `:iex | :standalone`
- [x] 7.4.1.4 Add config option to force IEx-compatible mode
- [x] 7.4.1.5 Add environment variable check for IEx mode

### 7.4.2 Update Runtime Logging

- [x] **Task 7.4.2 Complete**

Log detected execution mode at startup.

- [x] 7.4.2.1 Runtime logs execution mode with backend selection
- [x] 7.4.2.2 Logs include "IEx mode" or "standalone mode" indicator

### Unit Tests - Section 7.4

- [x] **Unit Tests 7.4 Complete**
- [x] Test `iex_mode?/0` returns false when not in IEx
- [x] Test config option forces IEx-compatible mode
- [x] Test config option forces standalone mode
- [x] Test environment variable forces IEx mode (true/1/yes)
- [x] Test environment variable forces standalone mode (false)
- [x] Test environment variable takes precedence over config
- [x] Test `running_mode/0` returns correct atom

---

## 7.5 Update Examples and Documentation

- [x] **Section 7.5 Complete**

Updated examples and documentation to reflect IEx compatibility.

### 7.5.1 Update README

- [x] **Task 7.5.1 Complete**

Added IEx compatibility section to main README.

- [x] 7.5.1.1 Add IEx compatibility section with usage examples
- [x] 7.5.1.2 Document IEx detection and configuration
- [x] 7.5.1.3 Add important notes about behavior

### 7.5.2 Update App Module Documentation

- [x] **Task 7.5.2 Complete**

Added comprehensive IEx documentation to App module.

- [x] 7.5.2.1 Add IEx compatibility section to App moduledoc
- [x] 7.5.2.2 Document behavior differences between IEx and standalone
- [x] 7.5.2.3 Add troubleshooting guide for IEx input issues

### 7.5.3 Create IEx Example

- [x] **Task 7.5.3 Complete**

Created simple counter example demonstrating IEx usage.

- [x] 7.5.3.1 Create IEx counter example
- [x] 7.5.3.2 Add README with IEx-specific instructions
- [x] 7.5.3.3 Example compiles and is ready for manual IEx testing

---

## 7.6 Integration Tests

- [ ] **Section 7.6 Complete**

Integration tests verify IEx compatibility end-to-end.

### 7.6.1 IEx Lifecycle Tests

- [ ] **Task 7.6.1 Complete**

Test complete application lifecycle inside IEx.

- [ ] 7.6.1.1 Test start → render → input → update → render → shutdown in IEx
- [ ] 7.6.1.2 Test keyboard input works correctly in IEx
- [ ] 7.6.1.3 Test cleanup on crash in IEx
- [ ] 7.6.1.4 Test multiple start/stop cycles in IEx session

### 7.6.2 Cross-Mode Tests

- [ ] **Task 7.6.2 Complete**

Verify behavior consistency across modes.

- [ ] 7.6.2.1 Test same app works identically in IEx and standalone
- [ ] 7.6.2.2 Test Raw backend still works when not in IEx
- [ ] 7.6.2.3 Test switching between IEx and standalone modes

### Unit Tests - Section 7.6

- [ ] **Unit Tests 7.6 Complete**
- [ ] Test full application lifecycle in IEx
- [ ] Test keyboard input handling in IEx
- [ ] Test cross-mode consistency
- [ ] Test resource cleanup in IEx

---

## Success Criteria

1. **IEx Input Works**: Keyboard input is not stolen by IEx
2. **Backward Compatibility**: Existing standalone applications work unchanged
3. **Auto-Detection**: IEx mode is detected automatically
4. **Documentation**: IEx usage is documented with examples
5. **Test Coverage**: All integration tests pass

---

## Provides Foundation

This phase enables TermUI applications to be developed and tested interactively within IEx, significantly improving the developer experience for debugging and experimentation.

---

## Key Outputs

- `lib/term_ui/input/tty_server.ex` - New GenServer for input process
- Updated `lib/term_ui/input/tty.ex` - Uses `:io` module and process pattern
- Updated `lib/term_ui/runtime.ex` - Integrates with input process
- Updated examples with IEx usage documentation
- Integration tests for IEx compatibility

---

## Critical Files to Modify

- `lib/term_ui/input/tty.ex` - Core input handler changes
- `lib/term_ui/runtime.ex` - Event loop integration
- `examples/multi_renderer/*.ex` - Update for IEx compatibility

---

## Migration Guide

For existing TermUI applications:

1. **No changes required** - IEx compatibility is automatic
2. **Optional**: Force IEx-compatible mode with config
3. **Optional**: Use `TermUI.Input.iex_mode?/0` to check mode

```elixir
# Force IEx-compatible mode (for debugging)
config :term_ui, :iex_compatible, true
```
