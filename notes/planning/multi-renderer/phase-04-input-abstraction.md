# Phase 4: Input Abstraction

## Overview

Phase 4 provides a thin input abstraction layer that normalizes the minor differences between raw mode and TTY mode input. **Both modes use character-by-character input** via `IO.getn/2`, so keyboard navigation, arrow keys, Tab, and Enter work identically in both modes.

The input abstraction serves two purposes:

1. **Unified interface**: A common `TermUI.Input` behaviour that both backends can implement, allowing the runtime to read input without knowing which backend is active.

2. **Line-based input for TextInput**: The `TermUI.Input.LineReader` module provides `IO.gets/1`-based input specifically for the `TextInput.Line` widget, which needs free-form text entry with shell line editing.

The key insight is that `IO.getn/2` works in both raw and TTY modes. The shell doesn't buffer single characters—it only provides line editing for `IO.gets/1`. This means most widgets work identically in both modes. Only widgets that need free-form text entry (like TextInput) need to choose between:
- **Character mode**: `IO.getn/2` - immediate character input (TextInput standard)
- **Line mode**: `IO.gets/1` - shell line editing with Enter to submit (TextInput.Line)

---

## 4.1 Define Input Behaviour

- [ ] **Section 4.1 Complete**

Define the `TermUI.Input` behaviour that establishes the contract for input reading. This provides a unified interface regardless of which backend is active.

### 4.1.1 Create Input Behaviour Module

- [x] **Task 4.1.1 Complete**

Create the input behaviour module with callback definitions.

- [x] 4.1.1.1 Create `lib/term_ui/input.ex` with `@moduledoc` explaining the abstraction
- [x] 4.1.1.2 Document that both raw and TTY modes use character-by-character input
- [x] 4.1.1.3 Document that `LineReader` is only needed for TextInput.Line

### 4.1.2 Define Input Result Types

- [ ] **Task 4.1.2 Complete**

Define the types returned by input operations.

- [ ] 4.1.2.1 Define `@type key_event :: TermUI.Event.Key.t()` for keyboard events
- [ ] 4.1.2.2 Define `@type input_result :: {:ok, key_event()} | :timeout | :eof`
- [ ] 4.1.2.3 Document that both backends return the same result types

### 4.1.3 Define Poll Callback

- [ ] **Task 4.1.3 Complete**

Define the main input polling callback.

- [ ] 4.1.3.1 Define `@callback poll(state :: term(), timeout :: non_neg_integer()) :: {input_result(), state()}`
- [ ] 4.1.3.2 Document timeout semantics (milliseconds, 0 for non-blocking in raw mode)
- [ ] 4.1.3.3 Document that TTY mode may not honor timeout (blocking `IO.getn`)

### 4.1.4 Define Mode Query Callback

- [ ] **Task 4.1.4 Complete**

Define callback for querying input mode.

- [ ] 4.1.4.1 Define `@callback mode(state :: term()) :: :raw | :tty`
- [ ] 4.1.4.2 Document that this helps components know their environment
- [ ] 4.1.4.3 Note: most widgets don't need to check this—input works the same

### Unit Tests - Section 4.1

- [ ] **Unit Tests 4.1 Complete**
- [ ] Test behaviour module compiles with all callbacks defined
- [ ] Test type specifications are valid
- [ ] Test behaviour_info returns expected callbacks

---

## 4.2 Implement Raw Input Handler

- [x] **Section 4.2 Complete**

The `TermUI.Input.Raw` module provides synchronous input polling through the Input behaviour interface using Task-based timeouts. This is used when the raw backend is active.

**Note:** The original plan called for wrapping `InputReader`, but that's an async GenServer incompatible with the synchronous `poll/2` contract. The implementation uses direct `IO.getn/2` wrapped in Tasks for timeout support instead.

### 4.2.1 Create Raw Input Module

- [x] **Task 4.2.1 Complete**

Create the raw input handler module implementing the Input behaviour.

- [x] 4.2.1.1 Create `lib/term_ui/input/raw.ex` with `@behaviour TermUI.Input`
- [x] 4.2.1.2 Add `@moduledoc` explaining synchronous polling with Tasks
- [x] 4.2.1.3 Document that it supports non-blocking input with timeout

### 4.2.2 Implement poll/2

- [x] **Task 4.2.2 Complete**

Implement the main input polling function.

- [x] 4.2.2.1 Implement `@impl true` `poll/2` accepting state and timeout
- [x] 4.2.2.2 Use Task.async + Task.yield for synchronous polling (not InputReader - incompatible async GenServer)
- [x] 4.2.2.3 Parse escape sequences using `TermUI.Terminal.EscapeParser`
- [x] 4.2.2.4 Return `{:ok, event}` for keyboard input
- [x] 4.2.2.5 Return `:timeout` when no input within timeout

### 4.2.3 Implement mode/1

- [x] **Task 4.2.3 Complete**

Implement the mode query function.

- [x] 4.2.3.1 Implement `@impl true` `mode/1` returning `:raw`

### Unit Tests - Section 4.2

- [x] **Unit Tests 4.2 Complete**
- [x] Test `poll/2` returns `{:ok, event}` format (mock input)
- [x] Test `poll/2` returns `:timeout` when no input
- [x] Test `mode/1` returns `:raw`
- [x] Test escape sequences parse to correct key events

---

## 4.3 Implement TTY Input Handler

- [x] **Section 4.3 Complete**

The `TermUI.Input.TTY` module provides character-by-character input using `IO.getn/2`. Despite running in TTY mode (with a shell present), single character reads work immediately without waiting for Enter.

**Note:** Tasks 4.3.2, 4.3.3, and 4.3.4 were implemented together as part of Task 4.3.1 to maintain implementation coherence. All requirements from these tasks are present in the code.

### 4.3.1 Create TTY Input Module

- [x] **Task 4.3.1 Complete**

Create the TTY input handler module implementing the Input behaviour.

- [x] 4.3.1.1 Create `lib/term_ui/input/tty.ex` with `@behaviour TermUI.Input`
- [x] 4.3.1.2 Add `@moduledoc` explaining `IO.getn/2` character input
- [x] 4.3.1.3 Document that arrow keys, Tab, etc. work normally

### 4.3.2 Implement poll/2

- [x] **Task 4.3.2 Complete** (implemented as part of 4.3.1)

Implement the main input polling function using `IO.getn/2`.

- [x] 4.3.2.1 Implement `@impl true` `poll/2` accepting state and timeout
- [x] 4.3.2.2 Use `IO.getn("", 1)` to read single character
- [x] 4.3.2.3 Note: timeout is ignored (`IO.getn` is blocking)
- [x] 4.3.2.4 Parse escape sequences using `TermUI.Terminal.EscapeParser`
- [x] 4.3.2.5 Return `{:ok, event}` for keyboard input
- [x] 4.3.2.6 Return `:eof` if `IO.getn` returns `:eof`

### 4.3.3 Implement Escape Sequence Buffering

- [x] **Task 4.3.3 Complete** (implemented as part of 4.3.1)

Handle multi-byte escape sequences that arrive as separate characters.

- [x] 4.3.3.1 Detect escape character (27/0x1B) as start of sequence
- [x] 4.3.3.2 Continue reading characters to complete the sequence
- [x] 4.3.3.3 Use `EscapeParser` to decode complete sequence
- [x] 4.3.3.4 Handle incomplete sequences with timeout fallback

### 4.3.4 Implement mode/1

- [x] **Task 4.3.4 Complete** (implemented as part of 4.3.1)

Implement the mode query function.

- [x] 4.3.4.1 Implement `@impl true` `mode/1` returning `:tty`

### Unit Tests - Section 4.3

- [x] **Unit Tests 4.3 Complete**
- [x] Test `poll/2` returns `{:ok, event}` for single characters (mock IO.getn)
- [x] Test `poll/2` handles escape sequences correctly
- [x] Test `poll/2` returns `:eof` on EOF
- [x] Test `mode/1` returns `:tty`

---

## 4.4 Implement Line Reader

- [x] **Section 4.4 Complete**

The `TermUI.Input.LineReader` module provides line-based input using `IO.gets/1`. This is **only** used by `TextInput.Line` for free-form text entry where shell line editing (backspace, cursor movement) is desirable.

### 4.4.1 Create Line Reader Module

- [x] **Task 4.4.1 Complete**

Create the line reader module for TextInput.Line.

- [x] 4.4.1.1 Create `lib/term_ui/input/line_reader.ex` with `@moduledoc`
- [x] 4.4.1.2 Document that this is for TextInput.Line only
- [x] 4.4.1.3 Document that it uses shell line editing

### 4.4.2 Implement read_line/1

- [x] **Task 4.4.2 Complete**

Implement the line reading function.

- [x] 4.4.2.1 Implement `read_line/1` accepting optional prompt
- [x] 4.4.2.2 Call `IO.gets(prompt)` for line input
- [x] 4.4.2.3 Trim trailing newline from result
- [x] 4.4.2.4 Return `{:ok, line}` or `:eof`

### 4.4.3 Implement read_line/2 with Validation

- [x] **Task 4.4.3 Complete**

Implement line reading with optional validation.

- [x] 4.4.3.1 Implement `read_line/2` accepting prompt and validator function
- [x] 4.4.3.2 Read line using `IO.gets/1`
- [x] 4.4.3.3 Apply validator function to input
- [x] 4.4.3.4 Return `{:ok, line}` if valid, `{:error, reason}` if invalid

### Unit Tests - Section 4.4

- [x] **Unit Tests 4.4 Complete**
- [x] Test `read_line/1` returns trimmed input (mock IO.gets)
- [x] Test `read_line/1` returns `:eof` on EOF
- [x] Test `read_line/2` applies validator
- [x] Test `read_line/2` returns error on validation failure

---

## 4.5 Implement Input Selector

- [ ] **Section 4.5 Complete**

The `TermUI.Input.Selector` module chooses the appropriate input handler based on backend mode.

### 4.5.1 Create Input Selector Module

- [ ] **Task 4.5.1 Complete**

Create the input selector module.

- [ ] 4.5.1.1 Create `lib/term_ui/input/selector.ex` with `@moduledoc`
- [ ] 4.5.1.2 Document automatic selection based on backend mode

### 4.5.2 Implement Selection Functions

- [ ] **Task 4.5.2 Complete**

Implement input handler selection.

- [ ] 4.5.2.1 Implement `select/0` that queries current backend mode
- [ ] 4.5.2.2 Return `TermUI.Input.Raw` for `:raw` mode
- [ ] 4.5.2.3 Return `TermUI.Input.TTY` for `:tty` mode
- [ ] 4.5.2.4 Implement `select/1` for explicit mode selection

### Unit Tests - Section 4.5

- [ ] **Unit Tests 4.5 Complete**
- [ ] Test `select/0` returns Raw for raw backend mode
- [ ] Test `select/0` returns TTY for tty backend mode
- [ ] Test `select(:raw)` returns Raw
- [ ] Test `select(:tty)` returns TTY

---

## 4.6 Integration Tests

- [ ] **Section 4.6 Complete**

Integration tests verify the input abstraction works correctly with both backends.

### 4.6.1 Input Mode Selection Tests

- [ ] **Task 4.6.1 Complete**

Test input handler selection based on backend mode.

- [ ] 4.6.1.1 Test Raw handler selected when backend is raw
- [ ] 4.6.1.2 Test TTY handler selected when backend is tty

### 4.6.2 Input Equivalence Tests

- [ ] **Task 4.6.2 Complete**

Test that both input handlers produce equivalent results.

- [ ] 4.6.2.1 Test arrow key produces same event in both modes
- [ ] 4.6.2.2 Test Enter key produces same event in both modes
- [ ] 4.6.2.3 Test Tab key produces same event in both modes
- [ ] 4.6.2.4 Test printable characters produce same events

### 4.6.3 Line Reader Tests

- [ ] **Task 4.6.3 Complete**

Test line reader for TextInput.Line usage.

- [ ] 4.6.3.1 Test line input with shell editing
- [ ] 4.6.3.2 Test validation callback works
- [ ] 4.6.3.3 Test EOF handling

---

## Success Criteria

1. **Behaviour Definition**: `TermUI.Input` behaviour is defined with poll/mode callbacks
2. **Raw Handler**: `TermUI.Input.Raw` wraps InputReader through behaviour interface
3. **TTY Handler**: `TermUI.Input.TTY` provides equivalent character input via `IO.getn/2`
4. **Line Reader**: `LineReader` provides `IO.gets`-based input for TextInput.Line
5. **Selector**: `Input.Selector` correctly chooses handler based on backend
6. **Test Coverage**: All unit and integration tests pass

---

## Provides Foundation

This phase establishes:
- **Phase 5**: Input handlers for widget event processing
- **Phase 6**: Input integration with runtime event loop

---

## Key Outputs

- `lib/term_ui/input.ex` - Input behaviour definition
- `lib/term_ui/input/raw.ex` - Raw input handler
- `lib/term_ui/input/tty.ex` - TTY input handler
- `lib/term_ui/input/line_reader.ex` - Line-based input for TextInput.Line
- `lib/term_ui/input/selector.ex` - Input handler selector
- `test/term_ui/input/` - Unit tests for all modules
- `test/integration/input_abstraction_test.exs` - Integration tests

---

## Critical Files to Reference

- `lib/term_ui/terminal/input_reader.ex` - Existing input reader to wrap
- `lib/term_ui/terminal/escape_parser.ex` - Escape sequence parsing
- `lib/term_ui/event.ex` - Event types for key construction
- `lib/term_ui/backend/selector.ex` - Backend mode detection
