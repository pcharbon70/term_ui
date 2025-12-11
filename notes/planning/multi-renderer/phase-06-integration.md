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

- [ ] **Section 6.1 Complete**

Update `TermUI.Runtime` to use the backend selector for initialization.

### 6.1.1 Integrate Backend Selector

- [ ] **Task 6.1.1 Complete**

Modify runtime startup to use the backend selector.

- [ ] 6.1.1.1 Modify `lib/term_ui/runtime.ex` init sequence
- [ ] 6.1.1.2 Call `Backend.Selector.select/1` with configuration options
- [ ] 6.1.1.3 Store selected backend module in runtime state
- [ ] 6.1.1.4 Store backend state in runtime state
- [ ] 6.1.1.5 Log which backend was selected

### 6.1.2 Handle Backend Selection Options

- [ ] **Task 6.1.2 Complete**

Support configuration options for backend selection.

- [ ] 6.1.2.1 Accept `:backend` option: `:auto` (default), `:raw`, `:tty`
- [ ] 6.1.2.2 `:auto` uses selector's try-raw-first strategy
- [ ] 6.1.2.3 `:raw` forces raw backend (error if unavailable)
- [ ] 6.1.2.4 `:tty` forces TTY backend (skips raw mode attempt)
- [ ] 6.1.2.5 Document options in runtime moduledoc

### 6.1.3 Store Backend Context

- [ ] **Task 6.1.3 Complete**

Make backend information available to components.

- [ ] 6.1.3.1 Store backend mode (`:raw` or `:tty`) in persistent_term
- [ ] 6.1.3.2 Store capabilities map in persistent_term
- [ ] 6.1.3.3 Implement `TermUI.Runtime.backend_mode/0` query function
- [ ] 6.1.3.4 Implement `TermUI.Runtime.capabilities/0` query function

### Unit Tests - Section 6.1

- [ ] **Unit Tests 6.1 Complete**
- [ ] Test runtime initializes with auto backend selection
- [ ] Test runtime respects `:backend` option
- [ ] Test `backend_mode/0` returns correct mode
- [ ] Test `capabilities/0` returns capabilities map
- [ ] Test forced `:raw` fails gracefully when unavailable

---

## 6.2 Update Event Loop

- [ ] **Section 6.2 Complete**

Update the runtime event loop to use the selected input handler.

### 6.2.1 Integrate Input Handler

- [ ] **Task 6.2.1 Complete**

Use the appropriate input handler based on backend mode.

- [ ] 6.2.1.1 Modify event loop to call `Input.Selector.select/0`
- [ ] 6.2.1.2 Use selected handler's `poll/2` for input reading
- [ ] 6.2.1.3 Handle input results consistently from both handlers

### 6.2.2 Unify Event Handling

- [ ] **Task 6.2.2 Complete**

Ensure events from both backends are handled identically.

- [ ] 6.2.2.1 Both backends produce `TermUI.Event.Key` structs
- [ ] 6.2.2.2 Arrow keys, Tab, Enter work identically
- [ ] 6.2.2.3 Escape sequences parsed by both handlers

### 6.2.3 Handle Backend-Specific Events

- [ ] **Task 6.2.3 Complete**

Handle events that only exist in one mode.

- [ ] 6.2.3.1 Mouse events only from raw backend (when enabled)
- [ ] 6.2.3.2 Resize events from both backends (different detection)
- [ ] 6.2.3.3 Focus events only from raw backend (when supported)

### Unit Tests - Section 6.2

- [ ] **Unit Tests 6.2 Complete**
- [ ] Test event loop reads from correct input handler
- [ ] Test key events are identical format from both backends
- [ ] Test mouse events only appear in raw mode
- [ ] Test resize events work in both modes

---

## 6.3 Update Rendering Pipeline

- [ ] **Section 6.3 Complete**

Connect the rendering pipeline to the selected backend.

### 6.3.1 Delegate Rendering to Backend

- [ ] **Task 6.3.1 Complete**

Route render calls through the backend.

- [ ] 6.3.1.1 Modify renderer to use `state.backend` module
- [ ] 6.3.1.2 Call `backend.draw_cells/2` for frame rendering
- [ ] 6.3.1.3 Call `backend.flush/1` after drawing
- [ ] 6.3.1.4 Pass backend state through render cycle

### 6.3.2 Handle Render Mode Differences

- [ ] **Task 6.3.2 Complete**

Handle differences between raw and TTY rendering.

- [ ] 6.3.2.1 Raw backend uses differential rendering
- [ ] 6.3.2.2 TTY backend uses full_redraw by default
- [ ] 6.3.2.3 Both support same cell format
- [ ] 6.3.2.4 Color degradation handled by backend

### 6.3.3 Integrate CharacterSet

- [ ] **Task 6.3.3 Complete**

Ensure character set is available during rendering.

- [ ] 6.3.3.1 Set `CharacterSet.current/0` based on capabilities
- [ ] 6.3.3.2 Widgets use `CharacterSet.current/0` for box drawing
- [ ] 6.3.3.3 Backend applies character mapping if needed

### Unit Tests - Section 6.3

- [ ] **Unit Tests 6.3 Complete**
- [ ] Test render pipeline uses correct backend
- [ ] Test cells are rendered correctly in both modes
- [ ] Test character set is applied during rendering

---

## 6.4 Create Application API

- [ ] **Section 6.4 Complete**

Create a clean API for applications to start and run with the multi-renderer system.

### 6.4.1 Create TermUI.App Module

- [ ] **Task 6.4.1 Complete**

Create the application entry point module.

- [ ] 6.4.1.1 Create `lib/term_ui/app.ex` with `@moduledoc`
- [ ] 6.4.1.2 Document application lifecycle
- [ ] 6.4.1.3 Document configuration options

### 6.4.2 Implement start/2

- [ ] **Task 6.4.2 Complete**

Implement application start function.

- [ ] 6.4.2.1 Implement `start/2` accepting model module and options
- [ ] 6.4.2.2 Initialize backend via selector
- [ ] 6.4.2.3 Start runtime with selected backend
- [ ] 6.4.2.4 Return `{:ok, pid}` or `{:error, reason}`

### 6.4.3 Implement run/2

- [ ] **Task 6.4.3 Complete**

Implement blocking run function.

- [ ] 6.4.3.1 Implement `run/2` that starts and waits for completion
- [ ] 6.4.3.2 Block until application exits
- [ ] 6.4.3.3 Clean up terminal state on exit
- [ ] 6.4.3.4 Return final model state

### 6.4.4 Implement Convenience Functions

- [ ] **Task 6.4.4 Complete**

Add convenience functions for common operations.

- [ ] 6.4.4.1 Implement `backend_mode/0` returning current mode
- [ ] 6.4.4.2 Implement `supports?/1` for capability queries
- [ ] 6.4.4.3 Implement `shutdown/0` for clean shutdown

### Unit Tests - Section 6.4

- [ ] **Unit Tests 6.4 Complete**
- [ ] Test `start/2` returns `{:ok, pid}`
- [ ] Test `run/2` blocks until completion
- [ ] Test `backend_mode/0` returns correct mode
- [ ] Test `supports?/1` queries capabilities
- [ ] Test cleanup happens on exit

---

## 6.5 Add Configuration System

- [ ] **Section 6.5 Complete**

Add application configuration for backend preferences.

### 6.5.1 Define Configuration Options

- [ ] **Task 6.5.1 Complete**

Define configurable options.

- [ ] 6.5.1.1 `config :term_ui, :backend` - `:auto`, `:raw`, or `:tty`
- [ ] 6.5.1.2 `config :term_ui, :tty_render_mode` - `:full_redraw` or `:incremental`
- [ ] 6.5.1.3 `config :term_ui, :character_set` - `:auto`, `:unicode`, or `:ascii`
- [ ] 6.5.1.4 `config :term_ui, :color_mode` - `:auto`, `:true_color`, `:color_256`, `:color_16`, `:monochrome`

### 6.5.2 Implement Configuration Reading

- [ ] **Task 6.5.2 Complete**

Read configuration during initialization.

- [ ] 6.5.2.1 Create `TermUI.Config` module
- [ ] 6.5.2.2 Implement `get/2` with defaults
- [ ] 6.5.2.3 Merge application config with runtime options
- [ ] 6.5.2.4 Runtime options override application config

### 6.5.3 Document Configuration

- [ ] **Task 6.5.3 Complete**

Document all configuration options.

- [ ] 6.5.3.1 Add configuration section to README
- [ ] 6.5.3.2 Document each option with examples
- [ ] 6.5.3.3 Provide common configuration recipes

### Unit Tests - Section 6.5

- [ ] **Unit Tests 6.5 Complete**
- [ ] Test configuration defaults are applied
- [ ] Test runtime options override config
- [ ] Test invalid config raises helpful error

---

## 6.6 Add Graceful Degradation Logging

- [ ] **Section 6.6 Complete**

Add logging to help developers understand what capabilities are available.

### 6.6.1 Log Backend Selection

- [ ] **Task 6.6.1 Complete**

Log which backend was selected and why.

- [ ] 6.6.1.1 Log when raw mode succeeds
- [ ] 6.6.1.2 Log when falling back to TTY mode
- [ ] 6.6.1.3 Include reason for fallback
- [ ] 6.6.1.4 Use Logger with `:info` level

### 6.6.2 Log Capability Detection

- [ ] **Task 6.6.2 Complete**

Log detected capabilities.

- [ ] 6.6.2.1 Log color mode detected
- [ ] 6.6.2.2 Log character set detected
- [ ] 6.6.2.3 Log terminal size
- [ ] 6.6.2.4 Use Logger with `:debug` level

### 6.6.3 Log Degradation Events

- [ ] **Task 6.6.3 Complete**

Log when features degrade.

- [ ] 6.6.3.1 Log when colors are degraded
- [ ] 6.6.3.2 Log when Unicode falls back to ASCII
- [ ] 6.6.3.3 Log when mouse tracking unavailable
- [ ] 6.6.3.4 Use Logger with `:debug` level

### Unit Tests - Section 6.6

- [ ] **Unit Tests 6.6 Complete**
- [ ] Test backend selection is logged
- [ ] Test capabilities are logged at debug level
- [ ] Test degradation events are logged

---

## 6.7 Create Example Applications

- [ ] **Section 6.7 Complete**

Create example applications demonstrating both modes.

### 6.7.1 Create Basic Example

- [ ] **Task 6.7.1 Complete**

Create a basic example showing auto-detection.

- [ ] 6.7.1.1 Create `examples/multi_renderer/basic.ex`
- [ ] 6.7.1.2 Simple list navigation application
- [ ] 6.7.1.3 Works identically in both modes
- [ ] 6.7.1.4 Add README explaining how to test both modes

### 6.7.2 Create TextInput Example

- [ ] **Task 6.7.2 Complete**

Create example showing TextInput variants.

- [ ] 6.7.2.1 Create `examples/multi_renderer/text_input.ex`
- [ ] 6.7.2.2 Show TextInput (character mode) and TextInput.Line (line mode)
- [ ] 6.7.2.3 Demonstrate when to use each

### 6.7.3 Create Feature Detection Example

- [ ] **Task 6.7.3 Complete**

Create example showing capability queries.

- [ ] 6.7.3.1 Create `examples/multi_renderer/capabilities.ex`
- [ ] 6.7.3.2 Display detected capabilities
- [ ] 6.7.3.3 Show current backend mode
- [ ] 6.7.3.4 Show color and character set in use

### Unit Tests - Section 6.7

- [ ] **Unit Tests 6.7 Complete**
- [ ] Test examples compile
- [ ] Test examples run without error in test mode

---

## 6.8 Integration Tests

- [ ] **Section 6.8 Complete**

Integration tests verify the complete system works end-to-end.

### 6.8.1 Full Application Lifecycle Tests

- [ ] **Task 6.8.1 Complete**

Test complete application lifecycle.

- [ ] 6.8.1.1 Test start → render → input → update → render → shutdown
- [ ] 6.8.1.2 Test in raw mode (if available)
- [ ] 6.8.1.3 Test in TTY mode (forced)
- [ ] 6.8.1.4 Test cleanup on crash

### 6.8.2 Backend Switching Tests

- [ ] **Task 6.8.2 Complete**

Test backend selection scenarios.

- [ ] 6.8.2.1 Test auto-detection selects appropriate backend
- [ ] 6.8.2.2 Test forced raw mode works when available
- [ ] 6.8.2.3 Test forced TTY mode skips raw attempt
- [ ] 6.8.2.4 Test error on forced raw when unavailable

### 6.8.3 Input Consistency Tests

- [ ] **Task 6.8.3 Complete**

Test input works consistently.

- [ ] 6.8.3.1 Test arrow keys work in both modes
- [ ] 6.8.3.2 Test Enter/Tab/Escape work in both modes
- [ ] 6.8.3.3 Test widgets respond identically to input

### 6.8.4 Rendering Consistency Tests

- [ ] **Task 6.8.4 Complete**

Test rendering works consistently.

- [ ] 6.8.4.1 Test same widget renders in both modes
- [ ] 6.8.4.2 Test colors degrade correctly
- [ ] 6.8.4.3 Test characters degrade correctly

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
