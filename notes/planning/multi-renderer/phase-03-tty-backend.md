# Phase 3: TTY Backend Implementation

## Overview

Phase 3 implements the `TermUI.Backend.TTY` module, which provides terminal rendering for constrained environments where raw mode is unavailable. This includes Nerves devices, SSH sessions, remote IEx consoles, and other scenarios where `:shell.start_interactive({:noshell, :raw})` returns `{:error, :already_started}`.

**Important**: The TTY backend is still **fully interactive**. Even without raw mode, we can read individual characters and escape sequences using `IO.getn/2`. Arrow keys, Tab, function keys, and other control sequences work normally. The main differences from raw mode are:

1. **No terminal mode control** - We can't switch terminal modes (a shell is already running)
2. **Potential interference** - The existing shell's line editing may occasionally interfere
3. **Capability uncertainty** - We must detect and adapt to available features
4. **Mouse tracking limitations** - Mouse events may not be available or reliable

Navigation with arrow keys, Tab focus cycling, and keyboard shortcuts all work as expected. Only free-form text input (TextInput widget) requires special handling with line-based entry.

This backend supports two rendering modes: **full_redraw** (default) clears the screen and redraws everything on each frame, which is reliable but may flicker; **incremental** attempts cursor-addressed updates for changed cells only, which is faster but may have artifacts depending on terminal behavior.

The TTY backend also implements graceful color degradation, automatically converting true color to 256-color, 16-color, or monochrome based on detected capabilities.

---

## 3.1 Create TTY Backend Module Structure

- [x] **Section 3.1 Complete**

Set up the `TermUI.Backend.TTY` module implementing the `TermUI.Backend` behaviour. This module is designed for environments where a shell is already running.

### 3.1.1 Define Module with Behaviour Declaration

- [x] **Task 3.1.1 Complete**

Create the module with proper structure and documentation explaining TTY mode limitations.

- [x] 3.1.1.1 Create `lib/term_ui/backend/tty.ex` with `@behaviour TermUI.Backend` declaration
- [x] 3.1.1.2 Add `@moduledoc` explaining the backend's purpose (fallback when raw mode unavailable)
- [x] 3.1.1.3 Document that this backend is selected when raw mode fails with `:already_started`
- [x] 3.1.1.4 Document supported features: ANSI output, colors, cursor positioning, keyboard input via `IO.getn/2`
- [x] 3.1.1.5 Document limitations: no terminal mode control, potential shell interference, limited mouse support

### 3.1.2 Define Internal State Structure

- [x] **Task 3.1.2 Complete**

Define the internal state struct for tracking TTY backend state.

- [x] 3.1.2.1 Define `defstruct` with field `size :: {rows :: pos_integer(), cols :: pos_integer()}`
- [x] 3.1.2.2 Define field `capabilities :: map()` storing detected terminal capabilities
- [x] 3.1.2.3 Define field `line_mode :: :full_redraw | :incremental` for rendering strategy
- [x] 3.1.2.4 Define field `last_frame :: map() | nil` for incremental mode frame comparison
- [x] 3.1.2.5 Define field `character_set :: :unicode | :ascii` for box-drawing characters
- [x] 3.1.2.6 Define field `color_mode :: :true_color | :color_256 | :color_16 | :monochrome`

### Unit Tests - Section 3.1

- [x] **Unit Tests 3.1 Complete**
- [x] Test module compiles and declares `@behaviour TermUI.Backend`
- [x] Test state struct has all expected fields with correct defaults
- [x] Test state struct correctly stores capabilities from init

---

## 3.2 Implement Initialization and Shutdown

- [ ] **Section 3.2 Complete**

Implement lifecycle callbacks that set up the TTY backend using capabilities detected by the Selector.

### 3.2.1 Implement init/1 Callback

- [ ] **Task 3.2.1 Complete**

Implement initialization that configures the backend from provided capabilities.

- [ ] 3.2.1.1 Implement `@impl true` `init/1` accepting keyword options
- [ ] 3.2.1.2 Extract `capabilities` from options (provided by Selector)
- [ ] 3.2.1.3 Accept `:line_mode` option defaulting to `:full_redraw`
- [ ] 3.2.1.4 Determine `color_mode` from capabilities (`:colors` field)
- [ ] 3.2.1.5 Determine `character_set` from capabilities (`:unicode` field) with `:ascii` fallback
- [ ] 3.2.1.6 Extract `size` from capabilities `:dimensions` or default to `{80, 24}`
- [ ] 3.2.1.7 Return `{:ok, state}` with initialized state struct

### 3.2.2 Implement Terminal Setup

- [ ] **Task 3.2.2 Complete**

Perform minimal terminal setup that works in TTY mode.

- [ ] 3.2.2.1 Optionally enter alternate screen with `\e[?1049h` if configured
- [ ] 3.2.2.2 Hide cursor with `\e[?25l` for cleaner rendering
- [ ] 3.2.2.3 Clear screen with `\e[2J\e[H` for fresh start
- [ ] 3.2.2.4 Note: No raw mode activation (shell already running)

### 3.2.3 Implement shutdown/1 Callback

- [ ] **Task 3.2.3 Complete**

Implement clean shutdown that resets terminal state.

- [ ] 3.2.3.1 Implement `@impl true` `shutdown/1` accepting state
- [ ] 3.2.3.2 Reset all attributes with `\e[0m`
- [ ] 3.2.3.3 Show cursor with `\e[?25h`
- [ ] 3.2.3.4 Leave alternate screen with `\e[?1049l` if it was entered
- [ ] 3.2.3.5 Note: No cooked mode restoration needed (never left cooked mode)
- [ ] 3.2.3.6 Return `:ok`

### Unit Tests - Section 3.2

- [ ] **Unit Tests 3.2 Complete**
- [ ] Test `init/1` with capabilities sets correct color_mode
- [ ] Test `init/1` with capabilities sets correct character_set
- [ ] Test `init/1` defaults to `{80, 24}` when dimensions not provided
- [ ] Test `init/1` defaults to `:full_redraw` line_mode
- [ ] Test `shutdown/1` returns `:ok`
- [ ] Test shutdown is safe to call multiple times

---

## 3.3 Implement Full Redraw Rendering

- [ ] **Section 3.3 Complete**

Implement the full redraw rendering mode, which clears the screen and renders all cells on each frame. This is the default mode, prioritizing reliability over performance.

### 3.3.1 Implement clear/1 Callback

- [ ] **Task 3.3.1 Complete**

Implement screen clearing.

- [ ] 3.3.1.1 Implement `@impl true` `clear/1` accepting state
- [ ] 3.3.1.2 Write `\e[2J` (clear entire screen)
- [ ] 3.3.1.3 Write `\e[H` (cursor to home position)
- [ ] 3.3.1.4 Clear `last_frame` in state if incremental mode
- [ ] 3.3.1.5 Return `{:ok, updated_state}`

### 3.3.2 Implement draw_cells/2 for Full Redraw Mode

- [ ] **Task 3.3.2 Complete**

Implement cell drawing that clears and redraws the entire screen.

- [ ] 3.3.2.1 Implement `@impl true` `draw_cells/2` accepting state and cells list
- [ ] 3.3.2.2 If `line_mode == :full_redraw`, start with screen clear `\e[2J\e[H`
- [ ] 3.3.2.3 Build frame buffer from cells list, organized by row
- [ ] 3.3.2.4 For each row, position cursor and write styled cell content
- [ ] 3.3.2.5 Apply color degradation based on `color_mode`
- [ ] 3.3.2.6 Use character set mapping for box-drawing characters
- [ ] 3.3.2.7 Return `{:ok, updated_state}`

### 3.3.3 Implement Row-by-Row Output

- [ ] **Task 3.3.3 Complete**

Implement efficient row-by-row output for full redraw.

- [ ] 3.3.3.1 Group cells by row number
- [ ] 3.3.3.2 Sort rows by row number for sequential output
- [ ] 3.3.3.3 For each row, position cursor at start with `\e[row;1H`
- [ ] 3.3.3.4 Output cells left-to-right, tracking style changes
- [ ] 3.3.3.5 Fill gaps with spaces if cells are non-contiguous

### Unit Tests - Section 3.3

- [ ] **Unit Tests 3.3 Complete**
- [ ] Test `clear/1` writes clear sequence
- [ ] Test `clear/1` clears last_frame state
- [ ] Test `draw_cells/2` in full_redraw mode starts with clear
- [ ] Test `draw_cells/2` outputs cells by row
- [ ] Test empty cells list renders empty screen

---

## 3.4 Implement Incremental Rendering

- [ ] **Section 3.4 Complete**

Implement the incremental rendering mode, which only updates changed cells. This reduces output and may improve perceived performance, but requires careful frame tracking.

### 3.4.1 Implement Frame Tracking

- [ ] **Task 3.4.1 Complete**

Implement frame state tracking for incremental comparison.

- [ ] 3.4.1.1 Store `last_frame` as map of `{row, col} => cell` after each render
- [ ] 3.4.1.2 On first frame (nil last_frame), fall back to full redraw
- [ ] 3.4.1.3 Clear last_frame on resize or explicit clear

### 3.4.2 Implement Frame Comparison

- [ ] **Task 3.4.2 Complete**

Implement comparison between current and previous frames.

- [ ] 3.4.2.1 Convert current cells list to position-keyed map
- [ ] 3.4.2.2 Compare each position in current frame to last_frame
- [ ] 3.4.2.3 Identify changed cells (different content or style)
- [ ] 3.4.2.4 Identify removed cells (in last_frame but not current)
- [ ] 3.4.2.5 Return list of cells to update

### 3.4.3 Implement draw_cells/2 for Incremental Mode

- [ ] **Task 3.4.3 Complete**

Implement incremental cell drawing.

- [ ] 3.4.3.1 If `line_mode == :incremental` and `last_frame` exists, compute diff
- [ ] 3.4.3.2 For each changed cell, position cursor and write cell
- [ ] 3.4.3.3 For removed cells, position cursor and write space with default style
- [ ] 3.4.3.4 Update `last_frame` with current frame
- [ ] 3.4.3.5 If no last_frame, delegate to full_redraw logic

### 3.4.4 Implement Cursor Movement Optimization

- [ ] **Task 3.4.4 Complete**

Optimize cursor movement for sparse updates.

- [ ] 3.4.4.1 Sort changed cells by position (row, then col)
- [ ] 3.4.4.2 Track current cursor position
- [ ] 3.4.4.3 Use relative moves when cheaper than absolute positioning
- [ ] 3.4.4.4 Group adjacent cells to minimize cursor operations

### Unit Tests - Section 3.4

- [ ] **Unit Tests 3.4 Complete**
- [ ] Test incremental mode falls back to full_redraw on first frame
- [ ] Test frame comparison detects changed cells
- [ ] Test frame comparison detects removed cells
- [ ] Test unchanged cells are not re-rendered
- [ ] Test last_frame is updated after render
- [ ] Test resize clears last_frame

---

## 3.5 Implement Color Degradation

- [ ] **Section 3.5 Complete**

Implement automatic color degradation based on detected terminal capabilities. Colors are downgraded from true color to 256-color to 16-color to monochrome as needed.

### 3.5.1 Implement True Color Output

- [ ] **Task 3.5.1 Complete**

Implement true color output when capabilities indicate support.

- [ ] 3.5.1.1 Detect `color_mode == :true_color` in state
- [ ] 3.5.1.2 Output RGB colors using `\e[38;2;r;g;bm` and `\e[48;2;r;g;bm`
- [ ] 3.5.1.3 Pass through RGB tuples unchanged

### 3.5.2 Implement 256-Color Degradation

- [ ] **Task 3.5.2 Complete**

Implement RGB to 256-color mapping when true color unavailable.

- [ ] 3.5.2.1 Detect `color_mode == :color_256` in state
- [ ] 3.5.2.2 Implement `rgb_to_256/1` mapping RGB to 256-color palette
- [ ] 3.5.2.3 Use 6x6x6 color cube (indices 16-231) for colors
- [ ] 3.5.2.4 Use grayscale ramp (indices 232-255) for near-gray colors
- [ ] 3.5.2.5 Output using `\e[38;5;nm` and `\e[48;5;nm`

### 3.5.3 Implement 16-Color Degradation

- [ ] **Task 3.5.3 Complete**

Implement RGB to 16-color mapping for basic terminals.

- [ ] 3.5.3.1 Detect `color_mode == :color_16` in state
- [ ] 3.5.3.2 Implement `rgb_to_16/1` mapping RGB to nearest basic color
- [ ] 3.5.3.3 Map to standard 8 colors + 8 bright variants
- [ ] 3.5.3.4 Use Euclidean distance in RGB space for nearest match
- [ ] 3.5.3.5 Output using standard SGR codes (30-37, 40-47, 90-97, 100-107)

### 3.5.4 Implement Monochrome Degradation

- [ ] **Task 3.5.4 Complete**

Implement monochrome output when no color support detected.

- [ ] 3.5.4.1 Detect `color_mode == :monochrome` in state
- [ ] 3.5.4.2 Skip all color sequences
- [ ] 3.5.4.3 Preserve text attributes (bold, underline, reverse) for contrast
- [ ] 3.5.4.4 Use reverse video for highlighting where color was used

### 3.5.5 Implement Named Color Handling

- [ ] **Task 3.5.5 Complete**

Handle named color atoms appropriately for each color mode.

- [ ] 3.5.5.1 Pass named colors (`:red`, `:blue`, etc.) directly to SGR in 16-color mode
- [ ] 3.5.5.2 Map named colors to RGB, then to palette in 256-color mode
- [ ] 3.5.5.3 Pass named colors directly in true color mode (terminal handles mapping)
- [ ] 3.5.5.4 Handle `:default` color in all modes with `\e[39m`/`\e[49m`

### Unit Tests - Section 3.5

- [ ] **Unit Tests 3.5 Complete**
- [ ] Test true_color mode outputs RGB sequences unchanged
- [ ] Test 256-color mode maps RGB to palette index
- [ ] Test 256-color mapping uses color cube correctly
- [ ] Test 256-color mapping uses grayscale for near-gray
- [ ] Test 16-color mode maps to nearest basic color
- [ ] Test monochrome mode omits color sequences
- [ ] Test monochrome preserves text attributes
- [ ] Test named colors work in all color modes
- [ ] Test `:default` color resets in all modes

---

## 3.6 Implement Character Set Handling

- [ ] **Section 3.6 Complete**

Implement character set selection and mapping for box-drawing and special characters. This enables ASCII fallback when Unicode is unavailable.

### 3.6.1 Create Character Set Module

- [ ] **Task 3.6.1 Complete**

Create the `TermUI.CharacterSet` module with Unicode and ASCII character sets.

- [ ] 3.6.1.1 Create `lib/term_ui/character_set.ex` with `@moduledoc`
- [ ] 3.6.1.2 Define `get(:unicode)` returning map with Unicode box-drawing characters
- [ ] 3.6.1.3 Define `get(:ascii)` returning map with ASCII equivalents
- [ ] 3.6.1.4 Include box corners: `tl`, `tr`, `bl`, `br`
- [ ] 3.6.1.5 Include lines: `h_line`, `v_line`
- [ ] 3.6.1.6 Include junctions: `t_up`, `t_down`, `t_left`, `t_right`, `cross`
- [ ] 3.6.1.7 Include progress/gauge characters: `bar_full`, `bar_empty`, `bar_levels`
- [ ] 3.6.1.8 Include check marks: `check`, `cross_mark`
- [ ] 3.6.1.9 Include arrows: `arrow_up`, `arrow_down`, `arrow_left`, `arrow_right`

### 3.6.2 Implement Character Mapping in TTY Backend

- [ ] **Task 3.6.2 Complete**

Integrate character set selection into TTY backend rendering.

- [ ] 3.6.2.1 Store selected `character_set` in state from capabilities
- [ ] 3.6.2.2 Implement `map_character/2` accepting character and character_set
- [ ] 3.6.2.3 Replace Unicode box-drawing with ASCII equivalents when `character_set == :ascii`
- [ ] 3.6.2.4 Pass through regular characters unchanged

### 3.6.3 Implement Runtime Character Set Query

- [ ] **Task 3.6.3 Complete**

Provide runtime access to current character set.

- [ ] 3.6.3.1 Implement `CharacterSet.current/0` reading from application config
- [ ] 3.6.3.2 Fall back to `:unicode` if not configured
- [ ] 3.6.3.3 Document that widgets should use `CharacterSet.current/0` for box drawing

### Unit Tests - Section 3.6

- [ ] **Unit Tests 3.6 Complete**
- [ ] Test `CharacterSet.get(:unicode)` returns Unicode characters
- [ ] Test `CharacterSet.get(:ascii)` returns ASCII equivalents
- [ ] Test all expected keys present in character sets
- [ ] Test `map_character/2` replaces Unicode with ASCII when configured
- [ ] Test `map_character/2` passes through regular characters
- [ ] Test `CharacterSet.current/0` reads configuration

---

## 3.7 Implement Remaining Callbacks

- [ ] **Section 3.7 Complete**

Implement the remaining backend callbacks required by the behaviour.

### 3.7.1 Implement Cursor Operations

- [ ] **Task 3.7.1 Complete**

Implement cursor positioning and visibility callbacks.

- [ ] 3.7.1.1 Implement `@impl true` `move_cursor/2` writing `\e[row;colH`
- [ ] 3.7.1.2 Implement `@impl true` `hide_cursor/1` writing `\e[?25l`
- [ ] 3.7.1.3 Implement `@impl true` `show_cursor/1` writing `\e[?25h`

### 3.7.2 Implement size/1 Callback

- [ ] **Task 3.7.2 Complete**

Implement terminal size query.

- [ ] 3.7.2.1 Implement `@impl true` `size/1` returning `{:ok, state.size}`
- [ ] 3.7.2.2 Size is determined at init from capabilities
- [ ] 3.7.2.3 Provide `refresh_size/1` for manual size update

### 3.7.3 Implement flush/1 Callback

- [ ] **Task 3.7.3 Complete**

Implement output flush.

- [ ] 3.7.3.1 Implement `@impl true` `flush/1` returning `{:ok, state}`
- [ ] 3.7.3.2 TTY output is synchronous, so flush is largely a no-op

### 3.7.4 Implement poll_event/2 Callback

- [ ] **Task 3.7.4 Complete**

Implement input polling using `IO.getn/2` for character-by-character input. Even in TTY mode, we can read individual characters and escape sequences.

- [ ] 3.7.4.1 Implement `@impl true` `poll_event/2` accepting state and timeout
- [ ] 3.7.4.2 Use `IO.getn("", 1)` to read single character (blocking)
- [ ] 3.7.4.3 Parse escape sequences using `TermUI.Terminal.EscapeParser`
- [ ] 3.7.4.4 Return `{:ok, event, state}` for key events
- [ ] 3.7.4.5 Note: timeout parameter may not be honored (IO.getn is blocking)

### Unit Tests - Section 3.7

- [ ] **Unit Tests 3.7 Complete**
- [ ] Test `move_cursor/2` returns `{:ok, state}`
- [ ] Test `hide_cursor/1` returns `{:ok, state}`
- [ ] Test `show_cursor/1` returns `{:ok, state}`
- [ ] Test `size/1` returns configured size
- [ ] Test `flush/1` returns `{:ok, state}`
- [ ] Test `poll_event/2` returns `{:ok, event, state}` for key input

---

## 3.8 Integration Tests

- [ ] **Section 3.8 Complete**

Integration tests verify the TTY backend works correctly in realistic scenarios and properly degrades features.

### 3.8.1 Full Redraw Lifecycle Tests

- [ ] **Task 3.8.1 Complete**

Test complete backend lifecycle in full_redraw mode.

- [ ] 3.8.1.1 Test init → draw_cells → shutdown sequence
- [ ] 3.8.1.2 Test multiple frames render correctly
- [ ] 3.8.1.3 Test style changes between frames

### 3.8.2 Incremental Rendering Tests

- [ ] **Task 3.8.2 Complete**

Test incremental rendering mode functionality.

- [ ] 3.8.2.1 Test first frame falls back to full redraw
- [ ] 3.8.2.2 Test subsequent frames only update changes
- [ ] 3.8.2.3 Test resize triggers full redraw

### 3.8.3 Color Degradation Tests

- [ ] **Task 3.8.3 Complete**

Test color degradation across all modes.

- [ ] 3.8.3.1 Test rendering with true_color capabilities
- [ ] 3.8.3.2 Test rendering with color_256 capabilities
- [ ] 3.8.3.3 Test rendering with color_16 capabilities
- [ ] 3.8.3.4 Test rendering with monochrome capabilities

### 3.8.4 Character Set Fallback Tests

- [ ] **Task 3.8.4 Complete**

Test character set selection and fallback.

- [ ] 3.8.4.1 Test Unicode box-drawing renders correctly
- [ ] 3.8.4.2 Test ASCII fallback renders correctly
- [ ] 3.8.4.3 Test mixed content (Unicode text with ASCII boxes)

---

## Success Criteria

1. **Behaviour Implementation**: `TermUI.Backend.TTY` implements all `TermUI.Backend` callbacks
2. **Initialization**: Backend initializes correctly with capabilities from Selector
3. **Full Redraw**: Full redraw mode reliably renders complete frames
4. **Incremental**: Incremental mode correctly tracks and updates changes
5. **Color Degradation**: Colors degrade gracefully across all capability levels
6. **Character Sets**: Unicode and ASCII character sets work correctly
7. **Input Polling**: `poll_event/2` reads character input using `IO.getn/2`
8. **Test Coverage**: All unit and integration tests pass

---

## Provides Foundation

This phase establishes:
- **Phase 4**: Input abstraction to provide line-based input for TTY mode
- **Phase 5**: Backend for widgets to query capabilities and adapt rendering
- **Phase 6**: TTY backend for runtime integration

---

## Key Outputs

- `lib/term_ui/backend/tty.ex` - Complete TTY backend implementation
- `lib/term_ui/character_set.ex` - Unicode/ASCII character sets
- `test/term_ui/backend/tty_test.exs` - Unit tests
- `test/term_ui/character_set_test.exs` - Character set tests
- `test/integration/tty_backend_test.exs` - Integration tests

---

## Critical Files to Reference

- `lib/term_ui/capabilities.ex` - Capability detection patterns
- `lib/term_ui/renderer/style.ex` - Style handling and color types
- `lib/term_ui/ansi.ex` - ANSI escape sequence generation
- `lib/term_ui/backend/raw.ex` - Reference implementation for behaviour callbacks
