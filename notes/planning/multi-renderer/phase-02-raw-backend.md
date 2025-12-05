# Phase 2: Raw Backend Implementation

## Overview

Phase 2 implements the `TermUI.Backend.Raw` module, which provides full terminal control when raw mode is available. This backend assumes raw mode was already activated by the selector (Phase 1) and provides optimized ANSI output with true color support.

The Raw backend serves as the primary high-fidelity rendering path. It enables alternate screen buffer usage, cursor hiding, mouse tracking, and all advanced terminal features. Since raw mode is active, input arrives character-by-character, enabling real-time keyboard and mouse event handling.

The implementation wraps and extends functionality from the existing `TermUI.Terminal` module, reusing its proven raw mode handling while adapting it to the backend behaviour interface. The key architectural change is that the selector handles raw mode activation, so `init/1` only performs terminal setup (alternate screen, cursor hiding) without calling `:shell.start_interactive/1`.

This phase maintains full backward compatibility—existing applications using TermUI will continue to work identically, as the Raw backend preserves all current rendering capabilities.

---

## 2.1 Create Raw Backend Module Structure

- [x] **Section 2.1 Complete**

Set up the `TermUI.Backend.Raw` module implementing the `TermUI.Backend` behaviour. The module structure follows existing TermUI patterns while conforming to the new backend abstraction.

### 2.1.1 Define Module with Behaviour Declaration

- [x] **Task 2.1.1 Complete**

Create the module with proper structure, documentation, and behaviour declaration.

- [x] 2.1.1.1 Create `lib/term_ui/backend/raw.ex` with `@behaviour TermUI.Backend` declaration
- [x] 2.1.1.2 Add comprehensive `@moduledoc` explaining the backend's purpose, requirements (OTP 28+), and capabilities
- [x] 2.1.1.3 Document that raw mode is already active when `init/1` is called (started by Selector)
- [x] 2.1.1.4 Import or alias `TermUI.ANSI` for escape sequence generation

### 2.1.2 Define Internal State Structure

- [x] **Task 2.1.2 Complete**

Define the internal state struct for tracking terminal state within the backend.

- [x] 2.1.2.1 Define `defstruct` with field `size :: {rows :: pos_integer(), cols :: pos_integer()}`
- [x] 2.1.2.2 Define field `cursor_visible :: boolean()` defaulting to `false` (hidden during rendering)
- [x] 2.1.2.3 Define field `cursor_position :: {row :: pos_integer(), col :: pos_integer()} | nil`
- [x] 2.1.2.4 Define field `alternate_screen :: boolean()` tracking alternate screen state
- [x] 2.1.2.5 Define field `mouse_mode :: :none | :click | :drag | :all` tracking mouse tracking state
- [x] 2.1.2.6 Define field `current_style :: Style.t() | nil` for tracking current SGR state to minimize output

### Unit Tests - Section 2.1

- [x] **Unit Tests 2.1 Complete**
- [x] Test module compiles and declares `@behaviour TermUI.Backend`
- [x] Test state struct has all expected fields with correct defaults
- [x] Test state struct can be pattern matched

---

## 2.2 Implement Initialization Lifecycle

- [x] **Section 2.2 Complete**

Implement `init/1` and `shutdown/1` callbacks for terminal setup and teardown. These callbacks assume raw mode is already active from the selector.

### 2.2.1 Implement init/1 Callback

- [x] **Task 2.2.1 Complete**

Implement initialization that sets up the terminal for rendering without activating raw mode (already done by selector).

- [x] 2.2.1.1 Implement `@impl true` `init/1` accepting keyword options
- [x] 2.2.1.2 Accept `:alternate_screen` option (default: `true`) to control alternate screen usage
- [x] 2.2.1.3 Accept `:hide_cursor` option (default: `true`) to control initial cursor visibility
- [x] 2.2.1.4 Accept `:mouse_tracking` option (default: `:none`) for mouse mode
- [x] 2.2.1.5 Accept `:size` option for explicit dimensions, falling back to query

### 2.2.2 Implement Terminal Setup Sequence

- [x] **Task 2.2.2 Complete**

Implement the sequence of operations to prepare the terminal for rendering.

- [x] 2.2.2.1 Query terminal size using `:io.columns/0` and `:io.rows/0` if not provided in options
- [x] 2.2.2.2 Enter alternate screen buffer with `\e[?1049h` if `alternate_screen: true`
- [x] 2.2.2.3 Hide cursor with `\e[?25l` if `hide_cursor: true`
- [x] 2.2.2.4 Enable mouse tracking if requested using appropriate escape sequences
- [x] 2.2.2.5 Clear the screen with `\e[2J\e[1;1H` to start fresh
- [x] 2.2.2.6 Return `{:ok, state}` with initialized state struct

### 2.2.3 Implement shutdown/1 Callback

- [x] **Task 2.2.3 Complete**

Implement clean shutdown that restores terminal to pre-init state.

- [x] 2.2.3.1 Implement `@impl true` `shutdown/1` accepting state
- [x] 2.2.3.2 Disable mouse tracking if it was enabled
- [x] 2.2.3.3 Show cursor with `\e[?25h`
- [x] 2.2.3.4 Leave alternate screen with `\e[?1049l` if it was entered
- [x] 2.2.3.5 Reset all attributes with `\e[0m`
- [x] 2.2.3.6 Return to cooked mode with `:shell.start_interactive({:noshell, :cooked})`
- [x] 2.2.3.7 Return `:ok`

### 2.2.4 Implement Error-Safe Shutdown

- [x] **Task 2.2.4 Complete**

Ensure shutdown completes even if individual operations fail.

- [x] 2.2.4.1 Wrap each shutdown step in try/rescue
- [x] 2.2.4.2 Log errors but continue cleanup sequence
- [x] 2.2.4.3 Ensure cooked mode restoration happens last and is attempted even after errors
- [x] 2.2.4.4 Make shutdown idempotent (safe to call multiple times)

### Unit Tests - Section 2.2

- [x] **Unit Tests 2.2 Complete**
- [x] Test `init/1` with default options returns `{:ok, state}`
- [x] Test `init/1` with `alternate_screen: false` does not enter alternate screen
- [x] Test `init/1` with explicit size option uses provided dimensions
- [x] Test `init/1` queries terminal size when not provided
- [x] Test `shutdown/1` returns `:ok`
- [x] Test `shutdown/1` is idempotent (can be called twice safely)
- [x] Test shutdown continues after individual step failure

---

## 2.3 Implement Cursor Operations

- [x] **Section 2.3 Complete**

Implement cursor control callbacks for positioning and visibility. These operations use ANSI escape sequences from the existing `TermUI.ANSI` module.

### 2.3.1 Implement move_cursor/2 Callback

- [x] **Task 2.3.1 Complete**

Implement cursor positioning using absolute coordinates.

- [x] 2.3.1.1 Implement `@impl true` `move_cursor/2` accepting state and `{row, col}` position
- [x] 2.3.1.2 Generate `\e[row;colH` sequence using `TermUI.ANSI.cursor_position/2`
- [x] 2.3.1.3 Write sequence to stdout via `IO.write/1`
- [x] 2.3.1.4 Update `cursor_position` in state
- [x] 2.3.1.5 Return `{:ok, updated_state}`

### 2.3.2 Implement hide_cursor/1 and show_cursor/1 Callbacks

- [x] **Task 2.3.2 Complete**

Implement cursor visibility control.

- [x] 2.3.2.1 Implement `@impl true` `hide_cursor/1` writing `\e[?25l`
- [x] 2.3.2.2 Update `cursor_visible` to `false` in state
- [x] 2.3.2.3 Implement `@impl true` `show_cursor/1` writing `\e[?25h`
- [x] 2.3.2.4 Update `cursor_visible` to `true` in state
- [x] 2.3.2.5 Make operations idempotent (no-op if already in desired state)

### 2.3.3 Implement Cursor Position Optimization

- [x] **Task 2.3.3 Complete**

Implement optional cursor movement optimization comparing absolute vs relative moves.

- [x] 2.3.3.1 Calculate cost of absolute move (`\e[row;colH` = 6-10 bytes)
- [x] 2.3.3.2 Calculate cost of relative moves (up/down/forward/back sequences)
- [x] 2.3.3.3 Choose cheaper option based on distance and current position
- [x] 2.3.3.4 Reference existing `TermUI.Renderer.CursorOptimizer` for algorithm

### Unit Tests - Section 2.3

- [x] **Unit Tests 2.3 Complete**
- [x] Test `move_cursor/2` generates correct escape sequence for various positions
- [x] Test `move_cursor/2` updates state with new position
- [x] Test `hide_cursor/1` updates state to `cursor_visible: false`
- [x] Test `show_cursor/1` updates state to `cursor_visible: true`
- [x] Test cursor operations are idempotent
- [x] Test cursor optimizer chooses relative move for short distances

---

## 2.4 Implement Screen Operations

- [x] **Section 2.4 Complete**

Implement screen clearing and the size query callback. These provide essential screen management capabilities.

### 2.4.1 Implement clear/1 Callback

- [x] **Task 2.4.1 Complete**

Implement full screen clear.

- [x] 2.4.1.1 Implement `@impl true` `clear/1` accepting state
- [x] 2.4.1.2 Write `\e[2J` (clear entire screen)
- [x] 2.4.1.3 Write `\e[1;1H` (move cursor to home position)
- [x] 2.4.1.4 Reset `current_style` in state (style state unknown after clear)
- [x] 2.4.1.5 Return `{:ok, updated_state}`

### 2.4.2 Implement size/1 Callback

- [x] **Task 2.4.2 Complete**

Implement terminal size query.

- [x] 2.4.2.1 Implement `@impl true` `size/1` accepting state
- [x] 2.4.2.2 Return `{:ok, state.size}` from cached state
- [x] 2.4.2.3 Provide `refresh_size/1` function to re-query dimensions (see Task 2.4.3)
- [x] 2.4.2.4 Handle `:io.columns/0` or `:io.rows/0` failure with `{:error, :enotsup}` (see Task 2.4.3)

### 2.4.3 Implement Size Refresh

- [x] **Task 2.4.3 Complete**

Implement size refresh for handling terminal resize events.

- [x] 2.4.3.1 Implement `refresh_size/1` querying `:io.columns/0` and `:io.rows/0`
- [x] 2.4.3.2 Update `size` field in state
- [x] 2.4.3.3 Return `{:ok, new_size, updated_state}`
- [x] 2.4.3.4 Document that this should be called after SIGWINCH handling

### Unit Tests - Section 2.4

- [x] **Unit Tests 2.4 Complete**
- [x] Test `clear/1` returns `{:ok, state}`
- [x] Test `clear/1` resets current_style in state
- [x] Test `size/1` returns cached dimensions
- [x] Test `refresh_size/1` updates state with new dimensions
- [x] Test size query handles `:io.columns/0` failure gracefully

---

## 2.5 Implement Cell Drawing

- [x] **Section 2.5 Complete**

Implement the core `draw_cells/2` callback for rendering. This is the primary rendering interface, taking a list of positioned cells and outputting optimized ANSI sequences.

### 2.5.1 Implement draw_cells/2 Callback

- [x] **Task 2.5.1 Complete**

Implement the main cell drawing callback with batch optimization.

- [x] 2.5.1.1 Implement `@impl true` `draw_cells/2` accepting state and list of `{position, cell}` tuples
- [x] 2.5.1.2 Sort cells by row then column for sequential output
- [x] 2.5.1.3 Group consecutive cells on same row for efficient cursor handling
- [x] 2.5.1.4 Track current position and style to minimize escape sequences
- [x] 2.5.1.5 Build output as iolist for efficient concatenation

### 2.5.2 Implement Style Application

- [x] **Task 2.5.2 Complete**

Implement conversion of cell styles to ANSI escape sequences.

- [x] 2.5.2.1 Track `current_style` in state to emit only style changes (deltas)
- [x] 2.5.2.2 Reset style with `\e[0m` when transitioning to simpler style (fewer attributes)
- [x] 2.5.2.3 Apply foreground color using appropriate sequence based on color type
- [x] 2.5.2.4 Apply background color using appropriate sequence based on color type
- [x] 2.5.2.5 Apply text attributes (bold, italic, underline, etc.) using SGR codes

### 2.5.3 Implement True Color Output

- [x] **Task 2.5.3 Complete**

Implement true color (24-bit) output for RGB color values.

- [x] 2.5.3.1 Detect RGB tuple `{r, g, b}` color type
- [x] 2.5.3.2 Generate foreground sequence `\e[38;2;r;g;bm`
- [x] 2.5.3.3 Generate background sequence `\e[48;2;r;g;bm`
- [x] 2.5.3.4 Use existing `TermUI.ANSI.true_color_foreground/1` and `true_color_background/1`

### 2.5.4 Implement 256-Color Output

- [x] **Task 2.5.4 Complete**

Implement 256-color palette output for integer color indices.

- [x] 2.5.4.1 Detect integer color value `0..255`
- [x] 2.5.4.2 Generate foreground sequence `\e[38;5;nm`
- [x] 2.5.4.3 Generate background sequence `\e[48;5;nm`
- [x] 2.5.4.4 Use existing `TermUI.ANSI.color256_foreground/1` and `color256_background/1`

### 2.5.5 Implement Named Color Output

- [x] **Task 2.5.5 Complete**

Implement standard 16-color output for named color atoms.

- [x] 2.5.5.1 Detect atom color value (`:red`, `:green`, `:blue`, etc.)
- [x] 2.5.5.2 Map to ANSI color codes (30-37 foreground, 40-47 background, 90-97/100-107 bright)
- [x] 2.5.5.3 Handle `:default` by using default foreground `\e[39m` or background `\e[49m`
- [x] 2.5.5.4 Use existing `TermUI.ANSI.foreground/1` and `TermUI.ANSI.background/1`

### 2.5.6 Implement Attribute Handling

- [x] **Task 2.5.6 Complete**

Implement text attribute application from cell attribute list.

- [x] 2.5.6.1 Handle `:bold` attribute with `\e[1m`
- [x] 2.5.6.2 Handle `:dim` attribute with `\e[2m`
- [x] 2.5.6.3 Handle `:italic` attribute with `\e[3m`
- [x] 2.5.6.4 Handle `:underline` attribute with `\e[4m`
- [x] 2.5.6.5 Handle `:blink` attribute with `\e[5m`
- [x] 2.5.6.6 Handle `:reverse` attribute with `\e[7m`
- [x] 2.5.6.7 Handle `:hidden` attribute with `\e[8m`
- [x] 2.5.6.8 Handle `:strikethrough` attribute with `\e[9m`

### 2.5.7 Implement Output Batching

- [x] **Task 2.5.7 Complete**

Optimize output by batching all sequences into a single write.

- [x] 2.5.7.1 Accumulate all escape sequences and characters in iolist
- [x] 2.5.7.2 Perform single `IO.write/1` call with complete iolist
- [x] 2.5.7.3 Update state with final cursor position and style
- [x] 2.5.7.4 Return `{:ok, updated_state}`

### Unit Tests - Section 2.5

- [x] **Unit Tests 2.5 Complete**
- [x] Test `draw_cells/2` with single cell generates correct output
- [x] Test `draw_cells/2` with multiple cells on same row
- [x] Test `draw_cells/2` with cells on different rows
- [x] Test true color output format `\e[38;2;r;g;bm`
- [x] Test 256-color output format `\e[38;5;nm`
- [x] Test named color output maps correctly to ANSI codes
- [x] Test `:default` color uses reset sequences
- [x] Test attribute application for all supported attributes
- [x] Test style delta optimization (only changed attributes emitted)
- [x] Test output is batched into single write

---

## 2.6 Implement Flush Operation

- [x] **Section 2.6 Complete**

Implement the `flush/1` callback for ensuring output is sent to the terminal.

### 2.6.1 Implement flush/1 Callback

- [x] **Task 2.6.1 Complete**

Implement flush that ensures all pending output is written.

- [x] 2.6.1.1 Implement `@impl true` `flush/1` accepting state
- [x] 2.6.1.2 For Raw backend, `IO.write/1` is synchronous so flush is largely a no-op
- [x] 2.6.1.3 Optionally call `:erlang.port_command/3` with sync option if buffering is used (documented in code)
- [x] 2.6.1.4 Return `{:ok, state}` unchanged

### Unit Tests - Section 2.6

- [x] **Unit Tests 2.6 Complete**
- [x] Test `flush/1` returns `{:ok, state}`
- [x] Test `flush/1` is safe to call multiple times
- [x] Test `flush/1` preserves all state fields
- [x] Test `flush/1` has documentation

---

## 2.7 Implement Input Polling

- [x] **Section 2.7 Complete**

Implement the `poll_event/2` callback for reading keyboard and mouse input. In raw mode, input arrives character-by-character, enabling real-time event handling.

### 2.7.1 Implement poll_event/2 Callback

- [x] **Task 2.7.1 Complete**

Implement input polling with timeout support.

- [x] 2.7.1.1 Implement `@impl true` `poll_event/2` accepting state and timeout in milliseconds
- [x] 2.7.1.2 Use non-blocking read with timeout (Task with yield/shutdown pattern)
- [x] 2.7.1.3 Return `{:ok, event, state}` when input available
- [x] 2.7.1.4 Return `{:timeout, state}` when timeout expires with no input
- [x] 2.7.1.5 Handle read errors gracefully (returns `{:error, reason, state}`)

### 2.7.2 Implement Escape Sequence Handling

- [x] **Task 2.7.2 Complete**

Handle multi-byte escape sequences with timeout-based disambiguation.

- [x] 2.7.2.1 Detect escape character (`\e`, byte 27) as potential sequence start
- [x] 2.7.2.2 Use short timeout (50ms) to read additional sequence bytes
- [x] 2.7.2.3 Delegate parsing to `TermUI.Terminal.EscapeParser`
- [x] 2.7.2.4 Return raw Escape key event if timeout expires (single escape press)

### 2.7.3 Implement Event Construction

- [x] **Task 2.7.3 Complete**

Convert parsed input to `TermUI.Event` structs.

- [x] 2.7.3.1 Construct `Event.Key` for keyboard input with key identifier and modifiers
- [x] 2.7.3.2 Construct `Event.Mouse` for mouse input with action, button, position, modifiers
- [x] 2.7.3.3 Handle special sequences (paste, focus, resize) as appropriate event types
- [x] 2.7.3.4 Include timestamp in events

Note: Subtask 2.7.3.3 - Event types for paste/focus/resize exist; parsing deferred to Section 2.8+.

### Unit Tests - Section 2.7

- [x] **Unit Tests 2.7 Complete**
- [x] Test `poll_event/2` returns `:timeout` when no input
- [x] Test `poll_event/2` returns key event for single character
- [x] Test escape sequence parsing produces correct key events
- [x] Test arrow keys parsed from escape sequences
- [x] Test function keys parsed correctly
- [x] Test modifier detection (Ctrl, Alt, Shift)
- [ ] Test mouse event parsing when mouse tracking enabled (deferred to Section 2.8)

---

## 2.8 Implement Mouse Tracking

- [ ] **Section 2.8 Complete**

Implement optional mouse tracking for interactive applications. Mouse tracking enables click, drag, and movement detection.

### 2.8.1 Implement Mouse Tracking Enable

- [ ] **Task 2.8.1 Complete**

Implement mouse tracking activation with configurable modes.

- [ ] 2.8.1.1 Implement `enable_mouse/2` accepting state and mode (`:click`, `:drag`, `:all`)
- [ ] 2.8.1.2 Enable X10 mouse tracking with `\e[?9h` for basic click
- [ ] 2.8.1.3 Enable button event tracking with `\e[?1002h` for drag
- [ ] 2.8.1.4 Enable any event tracking with `\e[?1003h` for all movement
- [ ] 2.8.1.5 Enable SGR extended mode with `\e[?1006h` for better coordinate handling
- [ ] 2.8.1.6 Update `mouse_mode` in state

### 2.8.2 Implement Mouse Tracking Disable

- [ ] **Task 2.8.2 Complete**

Implement mouse tracking deactivation.

- [ ] 2.8.2.1 Implement `disable_mouse/1` accepting state
- [ ] 2.8.2.2 Disable SGR mode with `\e[?1006l`
- [ ] 2.8.2.3 Disable tracking mode with appropriate sequence (`\e[?1003l`, `\e[?1002l`, or `\e[?9l`)
- [ ] 2.8.2.4 Update `mouse_mode` to `:none` in state

### 2.8.3 Implement Mouse Event Parsing

- [ ] **Task 2.8.3 Complete**

Parse mouse events in `poll_event/2` when mouse tracking is active.

- [ ] 2.8.3.1 Detect SGR mouse sequence prefix `\e[<`
- [ ] 2.8.3.2 Parse button, column, row from sequence `\e[<button;col;rowM` (press) or `m` (release)
- [ ] 2.8.3.3 Decode button to `:left`, `:middle`, `:right`, `:scroll_up`, `:scroll_down`
- [ ] 2.8.3.4 Decode modifiers from button byte (Shift, Alt, Ctrl)
- [ ] 2.8.3.5 Construct `Event.Mouse` with action, button, position, modifiers

### Unit Tests - Section 2.8

- [ ] **Unit Tests 2.8 Complete**
- [ ] Test `enable_mouse/2` with `:click` mode writes correct sequences
- [ ] Test `enable_mouse/2` with `:all` mode enables movement tracking
- [ ] Test `disable_mouse/1` disables all tracking modes
- [ ] Test SGR mouse sequence parsing for button press
- [ ] Test SGR mouse sequence parsing for button release
- [ ] Test mouse modifier detection
- [ ] Test scroll wheel event parsing

---

## 2.9 Integration Tests

- [ ] **Section 2.9 Complete**

Integration tests verify the Raw backend works correctly in realistic scenarios, including interaction with existing TermUI components.

### 2.9.1 Full Lifecycle Tests

- [ ] **Task 2.9.1 Complete**

Test complete backend lifecycle from init to shutdown.

- [ ] 2.9.1.1 Test init → draw_cells → poll_event → shutdown sequence
- [ ] 2.9.1.2 Test alternate screen is properly entered and exited
- [ ] 2.9.1.3 Test terminal state is properly restored after shutdown
- [ ] 2.9.1.4 Test shutdown after error during rendering

### 2.9.2 Renderer Integration Tests

- [ ] **Task 2.9.2 Complete**

Test Raw backend integration with existing renderer components.

- [ ] 2.9.2.1 Test `draw_cells/2` with cells from `TermUI.Renderer.Buffer`
- [ ] 2.9.2.2 Test `draw_cells/2` with diff operations from `TermUI.Renderer.Diff`
- [ ] 2.9.2.3 Test style rendering matches `TermUI.Renderer.Style` expectations
- [ ] 2.9.2.4 Test cell rendering matches `TermUI.Renderer.Cell` format

### 2.9.3 Input Integration Tests

- [ ] **Task 2.9.3 Complete**

Test input handling integration (requires terminal, tagged `:requires_terminal`).

- [ ] 2.9.3.1 Test keyboard input produces correct `Event.Key` structs
- [ ] 2.9.3.2 Test mouse input produces correct `Event.Mouse` structs when enabled
- [ ] 2.9.3.3 Test escape sequence handling with timeout disambiguation
- [ ] 2.9.3.4 Test input handling after resize event

### 2.9.4 Performance Tests

- [ ] **Task 2.9.4 Complete**

Verify rendering performance is acceptable.

- [ ] 2.9.4.1 Measure time to render full 80x24 screen
- [ ] 2.9.4.2 Measure time to render differential update (10% changed cells)
- [ ] 2.9.4.3 Verify output batching reduces write syscalls
- [ ] 2.9.4.4 Verify style delta tracking reduces escape sequence bytes

---

## Success Criteria

1. **Behaviour Implementation**: `TermUI.Backend.Raw` implements all `TermUI.Backend` callbacks
2. **Initialization**: Backend initializes correctly when raw mode is already active from Selector
3. **Rendering**: Cell drawing produces correct ANSI output for all color modes and attributes
4. **Input Handling**: Input polling correctly parses keyboard and mouse events
5. **Shutdown**: Clean shutdown restores terminal state even after errors
6. **Performance**: Rendering performance is comparable to existing `TermUI.Terminal` implementation
7. **Test Coverage**: All unit and integration tests pass

---

## Provides Foundation

This phase establishes:
- **Phase 3**: Reference implementation for TTY backend to follow
- **Phase 4**: Input polling pattern for input abstraction
- **Phase 5**: Full-capability baseline for widget degradation comparison
- **Phase 6**: Backend implementation for runtime integration

---

## Key Outputs

- `lib/term_ui/backend/raw.ex` - Complete Raw backend implementation
- `test/term_ui/backend/raw_test.exs` - Unit tests for all callbacks
- `test/integration/backend_raw_test.exs` - Integration tests
- Documentation updates for backend usage patterns

---

## Critical Files to Reference

- `lib/term_ui/terminal.ex` - Existing raw mode handling and escape sequences
- `lib/term_ui/ansi.ex` - ANSI escape sequence generation functions
- `lib/term_ui/terminal/escape_parser.ex` - Escape sequence parsing for input
- `lib/term_ui/renderer/cell.ex` - Cell structure and types
- `lib/term_ui/renderer/cursor_optimizer.ex` - Cursor movement optimization algorithm
