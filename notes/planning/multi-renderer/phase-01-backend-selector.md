# Phase 1: Backend Selector and Behaviour Definition

## Overview

Phase 1 establishes the foundational backend abstraction layer for TermUI's multi-renderer architecture. This phase introduces the `TermUI.Backend` behaviour that defines the contract all backends must implement, and the `TermUI.Backend.Selector` module that determines which backend to use at runtime.

The selector module encapsulates the "try raw mode first" strategy, providing a single point of decision for backend selection. This approach eliminates the need for environment heuristics, as attempting raw mode is the **only reliable method** to determine availability. When raw mode succeeds, the selector returns initialization state for the Raw backend. When it fails with `{:error, :already_started}`, it triggers capability detection and returns context for the TTY backend.

The behaviour definition draws from Ratatui's proven pattern, defining minimal callback functions that map to terminal primitives. This keeps the interface focused while enabling different implementation strategies. The callbacks cover initialization/shutdown lifecycle, terminal size queries, cursor operations, cell drawing, and input polling.

This phase creates no modifications to existing code—all deliverables are new modules that will be integrated in Phase 6.

---

## 1.1 Define Backend Behaviour Module

- [x] **Section 1.1 Complete**

The `TermUI.Backend` behaviour establishes the contract for all terminal backends. This module defines callback specifications using Elixir's behaviour mechanism, ensuring type safety and compile-time verification of backend implementations. The behaviour is intentionally minimal, covering only the essential terminal operations required for rendering and input.

### 1.1.1 Create Backend Behaviour Module Structure

- [x] **Task 1.1.1 Complete**

Create the `TermUI.Backend` module with proper documentation and type specifications. The module serves as the single source of truth for backend capabilities.

- [x] 1.1.1.1 Create `lib/term_ui/backend.ex` with `@moduledoc` describing the behaviour purpose and usage patterns
- [x] 1.1.1.2 Define `@type position :: {row :: non_neg_integer(), col :: non_neg_integer()}` for cursor positioning (1-indexed)
- [x] 1.1.1.3 Define `@type size :: {rows :: non_neg_integer(), cols :: non_neg_integer()}` for terminal dimensions
- [x] 1.1.1.4 Define `@type cell :: {char :: String.t(), fg :: color(), bg :: color(), attrs :: [atom()]}` referencing `TermUI.Renderer.Cell` semantics
- [x] 1.1.1.5 Define `@type color :: :default | atom() | 0..255 | {r :: 0..255, g :: 0..255, b :: 0..255}` for color specification
- [x] 1.1.1.6 Define `@type event :: TermUI.Event.t()` aliasing the existing event type

### 1.1.2 Define Lifecycle Callbacks

- [x] **Task 1.1.2 Complete**

Define the initialization and shutdown callbacks that manage backend lifecycle. These callbacks handle terminal setup and cleanup, ensuring proper resource management.

- [x] 1.1.2.1 Define `@callback init(opts :: keyword()) :: {:ok, state :: term()} | {:error, reason :: term()}` for backend initialization
- [x] 1.1.2.2 Define `@callback shutdown(state :: term()) :: :ok` for clean shutdown and terminal restoration
- [x] 1.1.2.3 Document that `init/1` receives options from selector including capabilities map for TTY mode
- [x] 1.1.2.4 Document that `shutdown/1` must be idempotent and handle errors gracefully

### 1.1.3 Define Query Callbacks

- [x] **Task 1.1.3 Complete**

Define callbacks for querying terminal state. These provide information about the terminal that widgets and the renderer need.

- [x] 1.1.3.1 Define `@callback size(state :: term()) :: {:ok, size()} | {:error, :enotsup}` for dimension queries
- [x] 1.1.3.2 Document that size may be cached and require explicit refresh after resize events

### 1.1.4 Define Cursor Operation Callbacks

- [x] **Task 1.1.4 Complete**

Define callbacks for cursor manipulation. Cursor operations are fundamental to efficient terminal rendering.

- [x] 1.1.4.1 Define `@callback move_cursor(state :: term(), position()) :: {:ok, state :: term()}` for absolute positioning
- [x] 1.1.4.2 Define `@callback hide_cursor(state :: term()) :: {:ok, state :: term()}` for cursor hiding
- [x] 1.1.4.3 Define `@callback show_cursor(state :: term()) :: {:ok, state :: term()}` for cursor display
- [x] 1.1.4.4 Document 1-indexed row/column convention matching terminal standards

### 1.1.5 Define Rendering Callbacks

- [x] **Task 1.1.5 Complete**

Define callbacks for screen manipulation and cell rendering. These form the core rendering interface.

- [x] 1.1.5.1 Define `@callback clear(state :: term()) :: {:ok, state :: term()}` for screen clearing
- [x] 1.1.5.2 Define `@callback draw_cells(state :: term(), [{position(), cell()}]) :: {:ok, state :: term()}` for batch cell rendering
- [x] 1.1.5.3 Define `@callback flush(state :: term()) :: {:ok, state :: term()}` for ensuring output is sent
- [x] 1.1.5.4 Document that `draw_cells/2` receives cells sorted by position for efficient output

### 1.1.6 Define Input Callback

- [x] **Task 1.1.6 Complete**

Define the input polling callback. This callback has different behaviour between raw and TTY backends.

- [x] 1.1.6.1 Define `@callback poll_event(state :: term(), timeout :: non_neg_integer()) :: {:ok, event()} | :timeout | {:error, :line_mode_only}`
- [x] 1.1.6.2 Document that TTY backends return `{:error, :line_mode_only}` since they cannot provide immediate input
- [x] 1.1.6.3 Document timeout semantics (milliseconds, 0 for non-blocking)

### Unit Tests - Section 1.1

- [x] **Unit Tests 1.1 Complete**
- [x] Test behaviour module compiles successfully
- [x] Test `behaviour_info(:callbacks)` returns expected callback list
- [x] Test all type specifications are valid (Dialyzer check)
- [x] Test module documentation is present and complete

---

## 1.2 Implement Backend Selector Module

- [x] **Section 1.2 Complete**

The `TermUI.Backend.Selector` module determines which backend to use by attempting raw mode initialization. This is the **only reliable method** for detection—environment variables and `io:getopts/0` cannot detect all cases where a shell is already running (Nerves, remote IEx sessions, etc.).

### 1.2.1 Create Selector Module Structure

- [x] **Task 1.2.1 Complete**

Create the selector module with proper structure and documentation explaining the "try raw mode first" strategy.

- [x] 1.2.1.1 Create `lib/term_ui/backend/selector.ex` with comprehensive `@moduledoc`
- [x] 1.2.1.2 Document why heuristics are insufficient (Nerves erlinit, SSH sessions, remote IEx)
- [x] 1.2.1.3 Document the two possible return values: `{:raw, state}` and `{:tty, capabilities}`

### 1.2.2 Implement Core Selection Logic

- [x] **Task 1.2.2 Complete**

Implement the `select/0` function that attempts raw mode and returns appropriate backend context.

- [x] 1.2.2.1 Implement `select/0` function calling `:shell.start_interactive({:noshell, :raw})`
- [x] 1.2.2.2 Handle `:ok` return by returning `{:raw, %{raw_mode_started: true}}`
- [x] 1.2.2.3 Handle `{:error, :already_started}` return by calling `detect_tty_capabilities/0` and returning `{:tty, capabilities}`
- [x] 1.2.2.4 Wrap call in try/rescue to handle `UndefinedFunctionError` on pre-OTP 28 systems (fall back to TTY)

### 1.2.3 Implement TTY Capability Detection

- [x] **Task 1.2.3 Complete**

Implement capability detection for TTY mode. This only runs when raw mode is unavailable.

- [x] 1.2.3.1 Implement private `detect_capabilities/0` returning capabilities map
- [x] 1.2.3.2 Detect color depth via `$COLORTERM` ("truecolor"/"24bit") and `$TERM` patterns ("256color", "color")
- [x] 1.2.3.3 Detect Unicode support via `$LANG` environment variable (contains "utf" case-insensitive)
- [x] 1.2.3.4 Detect terminal dimensions via `:io.columns/0`, `:io.rows/0`
- [x] 1.2.3.5 Detect terminal presence via `:io.getopts/0` `:terminal` key
- [x] 1.2.3.6 Return map with keys: `:colors`, `:unicode`, `:dimensions`, `:terminal`

### 1.2.4 Implement Explicit Selection

- [x] **Task 1.2.4 Complete**

Implement `select/1` for explicit backend selection, useful for testing and configuration override.

- [x] 1.2.4.1 Implement `select(:auto)` delegating to `select/0`
- [x] 1.2.4.2 Implement `select(module)` when `is_atom(module)` returning `{:explicit, module, []}`
- [x] 1.2.4.3 Implement `select({module, opts})` returning `{:explicit, module, opts}`
- [x] 1.2.4.4 Document explicit selection bypass of auto-detection

### Unit Tests - Section 1.2

- [x] **Unit Tests 1.2 Complete**
- [x] Test `select/0` returns `{:raw, state}` tuple format when mocking `:shell.start_interactive/1` to return `:ok`
- [x] Test `select/0` returns `{:tty, capabilities}` tuple format when mocking to return `{:error, :already_started}`
- [x] Test capability detection populates `:colors` field correctly for various `$TERM` values
- [x] Test capability detection populates `:unicode` field correctly for various `$LANG` values
- [x] Test capability detection populates `:dimensions` with fallback values when `:io.columns/0` fails
- [x] Test `select/1` with `:auto` delegates to `select/0`
- [x] Test `select/1` with module atom returns `{:explicit, module, []}`
- [x] Test `select/1` with `{module, opts}` tuple returns `{:explicit, module, opts}`
- [x] Test pre-OTP 28 fallback when `:shell.start_interactive/1` is undefined

---

## 1.3 Create Backend State Module

- [x] **Section 1.3 Complete**

The `TermUI.Backend.State` module provides a shared state structure that wraps backend-specific state with common metadata. This enables consistent state management across different backend implementations.

### 1.3.1 Define State Structure

- [x] **Task 1.3.1 Complete**

Define the state struct with fields for tracking backend information and capabilities.

- [x] 1.3.1.1 Create `lib/term_ui/backend/state.ex` with `defstruct`
- [x] 1.3.1.2 Define field `backend_module :: module()` for the active backend
- [x] 1.3.1.3 Define field `backend_state :: term()` for backend-specific state
- [x] 1.3.1.4 Define field `mode :: :raw | :tty` for current mode
- [x] 1.3.1.5 Define field `capabilities :: map()` for detected capabilities
- [x] 1.3.1.6 Define field `size :: {rows, cols} | nil` for cached dimensions
- [x] 1.3.1.7 Define field `initialized :: boolean()` for initialization status

### 1.3.2 Implement State Constructors

- [x] **Task 1.3.2 Complete**

Implement constructor functions for creating state structs.

- [x] 1.3.2.1 Implement `new/2` accepting `backend_module` and keyword options
- [x] 1.3.2.2 Implement `new_raw/1` convenience function for raw mode state
- [x] 1.3.2.3 Implement `new_tty/2` convenience function for TTY mode state with capabilities

### 1.3.3 Implement State Update Functions

- [x] **Task 1.3.3 Complete**

Implement immutable update functions for state manipulation.

- [x] 1.3.3.1 Implement `put_backend_state/2` for updating inner backend state
- [x] 1.3.3.2 Implement `put_size/2` for updating cached dimensions
- [x] 1.3.3.3 Implement `put_capabilities/2` for updating capabilities map
- [x] 1.3.3.4 Implement `mark_initialized/1` for setting initialized flag

### Unit Tests - Section 1.3

- [x] **Unit Tests 1.3 Complete**
- [x] Test `new/2` creates state with correct backend module
- [x] Test `new_raw/1` sets mode to `:raw`
- [x] Test `new_tty/2` sets mode to `:tty` and stores capabilities
- [x] Test `put_backend_state/2` returns new state with updated backend_state
- [x] Test `put_size/2` returns new state with updated size
- [x] Test state struct enforces required fields

---

## 1.4 Create Configuration Module

- [x] **Section 1.4 Complete**

The `TermUI.Backend.Config` module handles backend configuration from the application environment. It provides a clean interface for reading and validating configuration options.

### 1.4.1 Implement Configuration Reading

- [x] **Task 1.4.1 Complete**

Implement functions for reading backend configuration from application environment.

- [x] 1.4.1.1 Create `lib/term_ui/backend/config.ex` module
- [x] 1.4.1.2 Implement `get_backend/0` reading `:term_ui, :backend` config, defaulting to `:auto`
- [x] 1.4.1.3 Implement `get_character_set/0` reading `:term_ui, :character_set` config, defaulting to `:unicode`
- [x] 1.4.1.4 Implement `get_fallback_character_set/0` reading `:term_ui, :fallback_character_set`, defaulting to `:ascii`
- [x] 1.4.1.5 Implement `get_tty_opts/0` reading `:term_ui, :tty_opts`, defaulting to `[line_mode: :full_redraw]`
- [x] 1.4.1.6 Implement `get_raw_opts/0` reading `:term_ui, :raw_opts`, defaulting to `[alternate_screen: true]`

### 1.4.2 Implement Configuration Validation

- [x] **Task 1.4.2 Complete**

Implement validation functions to catch configuration errors early.

- [x] 1.4.2.1 Define `@valid_backends [:auto, TermUI.Backend.Raw, TermUI.Backend.TTY, TermUI.Backend.Test]`
- [x] 1.4.2.2 Define `@valid_character_sets [:unicode, :ascii]`
- [x] 1.4.2.3 Define `@valid_line_modes [:full_redraw, :incremental]`
- [x] 1.4.2.4 Implement `validate!/0` that raises `ArgumentError` for invalid configuration
- [x] 1.4.2.5 Implement `valid?/0` returning boolean without raising

### 1.4.3 Implement Runtime Configuration

- [x] **Task 1.4.3 Complete**

Implement function to get complete runtime configuration as a map.

- [x] 1.4.3.1 Implement `runtime_config/0` returning map with all config values
- [x] 1.4.3.2 Include backend, character_set, fallback_character_set, tty_opts, raw_opts keys
- [x] 1.4.3.3 Document that this function validates configuration before returning

### Unit Tests - Section 1.4

- [x] **Unit Tests 1.4 Complete**
- [x] Test `get_backend/0` returns `:auto` when no config present
- [x] Test `get_backend/0` returns configured value when present
- [x] Test `get_character_set/0` returns `:unicode` by default
- [x] Test `get_tty_opts/0` returns default `[line_mode: :full_redraw]`
- [x] Test `validate!/0` raises for invalid backend value
- [x] Test `validate!/0` raises for invalid character_set value
- [x] Test `valid?/0` returns false for invalid configuration
- [x] Test `runtime_config/0` returns complete configuration map

---

## 1.5 Integration Tests

- [ ] **Section 1.5 Complete**

Integration tests verify that all Phase 1 modules work together correctly. These tests exercise the full backend selection flow from configuration through selector.

### 1.5.1 Backend Selection Flow Tests

- [ ] **Task 1.5.1 Complete**

Test the complete flow from configuration to backend selection.

- [ ] 1.5.1.1 Test configuration with `:auto` backend triggers selector
- [ ] 1.5.1.2 Test selector result provides correct backend module and init options
- [ ] 1.5.1.3 Test explicit backend configuration bypasses selector
- [ ] 1.5.1.4 Test invalid configuration is caught before selector runs

### 1.5.2 Capability Integration Tests

- [ ] **Task 1.5.2 Complete**

Test capability detection integrates with existing `TermUI.Capabilities` module where applicable.

- [ ] 1.5.2.1 Test TTY capability detection produces compatible capability format
- [ ] 1.5.2.2 Test capability map can be passed to TTY backend init
- [ ] 1.5.2.3 Test environment variable changes affect capability detection

### 1.5.3 State Management Tests

- [ ] **Task 1.5.3 Complete**

Test state management across the selection flow.

- [ ] 1.5.3.1 Test `Backend.State` correctly wraps selector results
- [ ] 1.5.3.2 Test state updates preserve backend-specific state
- [ ] 1.5.3.3 Test mode field correctly reflects selection result

---

## Success Criteria

1. **Behaviour Definition**: `TermUI.Backend` behaviour compiles with all callbacks defined and documented
2. **Selector Reliability**: `TermUI.Backend.Selector.select/0` correctly determines raw vs TTY mode using `:shell.start_interactive/1`
3. **Capability Detection**: TTY mode capability detection produces accurate results for color depth, Unicode, and dimensions
4. **Configuration Support**: All configuration options are readable and validatable
5. **Type Safety**: Dialyzer reports no type errors for Phase 1 modules
6. **Test Coverage**: All unit and integration tests pass

---

## Provides Foundation

This phase establishes the infrastructure for:
- **Phase 2**: Raw backend implementing the Backend behaviour
- **Phase 3**: TTY backend implementing the Backend behaviour with capability-aware rendering
- **Phase 4**: Input abstraction using backend mode from selector
- **Phase 5**: Widget adaptation querying backend capabilities
- **Phase 6**: Runtime integration using selector and configuration

---

## Key Outputs

- `lib/term_ui/backend.ex` - Behaviour definition with all callbacks
- `lib/term_ui/backend/selector.ex` - Backend selection with "try raw mode first" strategy
- `lib/term_ui/backend/state.ex` - Shared state structure
- `lib/term_ui/backend/config.ex` - Configuration handling and validation
- `test/term_ui/backend_test.exs` - Behaviour unit tests
- `test/term_ui/backend/selector_test.exs` - Selector unit tests
- `test/term_ui/backend/state_test.exs` - State unit tests
- `test/term_ui/backend/config_test.exs` - Configuration unit tests
- `test/integration/backend_selection_test.exs` - Integration tests
