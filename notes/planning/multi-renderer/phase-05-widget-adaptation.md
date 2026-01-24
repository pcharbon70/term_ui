# Phase 5: Widget Adaptation

## Overview

Phase 5 addresses widget compatibility with both raw and TTY backends. The key insight from our architecture is that **most widgets require no changes**—keyboard navigation works identically in both modes because `IO.getn/2` provides character-by-character input regardless of terminal mode.

Widgets fall into three categories based on their requirements:

1. **Fully compatible** (no changes needed): List, Menu, Tabs, Table, TreeView, Dialog, CommandPalette, Toast, Gauge, BarChart, LineChart, Sparkline, Canvas, Viewport. These widgets use keyboard navigation (arrows, Tab, Enter) which works identically in both modes.

2. **TextInput variants**: The existing `TextInput` widget handles its own character input. We add `TextInput.Line` as a TTY-friendly variant that uses `IO.gets/1` for shell line editing support.

3. **Mouse-dependent features**: Some widgets have mouse-only features that need keyboard fallbacks:
   - `SplitPane`: Mouse dragging for resize → keyboard shortcuts (Ctrl+arrows)
   - `ContextMenu`: Mouse positioning → inline numbered menu
   - Scrollbars: Click-to-scroll → already have keyboard alternatives

The main work in this phase is:
- Creating `TextInput.Line` for TTY-friendly text entry
- Adding keyboard alternatives for mouse-dependent features
- Ensuring all widgets query capabilities for color/character degradation

---

## 5.1 Create TextInput.Line Widget

- [x] **Section 5.1 Complete**

Create a TTY-friendly variant of TextInput that uses `IO.gets/1` for line-based input. This widget is useful when shell line editing (backspace, history, cursor movement) is desirable.

### 5.1.1 Create TextInput.Line Module

- [x] **Task 5.1.1 Complete**

Create the line-based text input module.

- [x] 5.1.1.1 Create `lib/term_ui/widgets/text_input/line.ex` with `@moduledoc`
- [x] 5.1.1.2 Document that this uses shell line editing via `IO.gets/1`
- [x] 5.1.1.3 Document use case: free-form text entry where shell editing is preferred
- [x] 5.1.1.4 Note: standard TextInput still works in TTY mode for character-by-character input

### 5.1.2 Define TextInput.Line State

- [x] **Task 5.1.2 Complete** *(Completed as part of Task 5.1.1)*

Define the state structure for line-based input.

- [x] 5.1.2.1 Define `defstruct` with field `prompt :: String.t()` for input prompt
- [x] 5.1.2.2 Define field `value :: String.t()` for current/last value
- [x] 5.1.2.3 Define field `label :: String.t()` for display label
- [x] 5.1.2.4 Define field `validator :: (String.t() -> :ok | {:error, String.t()}) | nil`
- [x] 5.1.2.5 Define field `placeholder :: String.t()` shown when empty

### 5.1.3 Implement Rendering

- [x] **Task 5.1.3 Complete**

Implement rendering for the line input widget.

- [x] 5.1.3.1 Render label on first line if provided
- [x] 5.1.3.2 Render prompt + current value on input line
- [x] 5.1.3.3 Render validation error below if present
- [x] 5.1.3.4 Support styling via theme

### 5.1.4 Implement Input Handling

- [x] **Task 5.1.4 Complete** *(Completed as part of Task 5.1.1)*

Implement the input reading flow.

- [x] 5.1.4.1 Implement `read/1` that calls `LineReader.read_line/1`
- [x] 5.1.4.2 Apply validator if configured
- [x] 5.1.4.3 Update state with new value
- [x] 5.1.4.4 Return `{:ok, value, state}` or `{:error, reason, state}`

### 5.1.5 Implement Focus Behavior

- [x] **Task 5.1.5 Complete**

Implement focus handling for the widget.

- [x] 5.1.5.1 When focused, initiate line read
- [x] 5.1.5.2 Block until Enter pressed (shell handles editing)
- [x] 5.1.5.3 Return focus to parent after input complete
- [x] 5.1.5.4 Handle Ctrl+C to cancel input

### Unit Tests - Section 5.1

- [x] **Unit Tests 5.1 Complete**
- [x] Test TextInput.Line initializes with default state
- [x] Test rendering includes label and prompt
- [x] Test `read/1` returns entered value (mock LineReader)
- [x] Test validator is applied to input
- [x] Test invalid input returns error with message
- [x] Test EOF/cancellation behavior (`:eof` and `:cancelled` return values)
- [x] Test edge cases (unicode, long input, special characters)

---

## 5.2 Add Keyboard Alternatives for SplitPane

- [x] **Section 5.2 Complete**

Add keyboard-based resize controls to SplitPane for environments where mouse dragging is unavailable or not preferred.

### 5.2.1 Define Keyboard Resize Shortcuts

- [x] **Task 5.2.1 Complete**

Define keyboard shortcuts for resizing panes.

- [x] 5.2.1.1 Ctrl+Left: Decrease left/top pane size
- [x] 5.2.1.2 Ctrl+Right: Increase left/top pane size
- [x] 5.2.1.3 Ctrl+Up: Decrease top pane size (vertical split)
- [x] 5.2.1.4 Ctrl+Down: Increase top pane size (vertical split)
- [x] 5.2.1.5 Document shortcuts in widget moduledoc

### 5.2.2 Implement Keyboard Event Handling

- [x] **Task 5.2.2 Complete** *(Completed as part of Task 5.2.1)*

Handle keyboard events for resize.

- [x] 5.2.2.1 Add `handle_key/2` clauses for Ctrl+arrow combinations
- [x] 5.2.2.2 Calculate new split ratio based on step size (default 5%)
- [x] 5.2.2.3 Clamp ratio to min/max bounds
- [x] 5.2.2.4 Update state with new ratio

### 5.2.3 Add Resize Step Configuration

- [x] **Task 5.2.3 Complete**

Allow configuring keyboard resize step size.

- [x] 5.2.3.1 Add `:ctrl_resize_step` option (default 0.05 = 5%)
- [x] 5.2.3.2 Add `:min_ratio` option (default 0.1 = 10%)
- [x] 5.2.3.3 Add `:max_ratio` option (default 0.9 = 90%)

### Unit Tests - Section 5.2

- [x] **Unit Tests 5.2 Complete**
- [x] Test Ctrl+Right increases left pane ratio
- [x] Test Ctrl+Left decreases left pane ratio
- [x] Test ratio is clamped to min/max bounds
- [x] Test resize_step is configurable
- [x] Test keyboard resize works in both modes

---

## 5.3 Add Keyboard Alternative for ContextMenu

- [x] **Section 5.3 Complete**

ContextMenu typically appears at mouse cursor position. Add an inline numbered menu variant for keyboard-only environments.

### 5.3.1 Create ContextMenu.Inline Variant

- [x] **Task 5.3.1 Complete**

Create an inline context menu that doesn't require mouse positioning.

- [x] 5.3.1.1 Create `lib/term_ui/widgets/context_menu/inline.ex`
- [x] 5.3.1.2 Render menu items with numbers: `[1] Copy  [2] Paste  [3] Delete`
- [x] 5.3.1.3 Accept number keys for direct selection
- [x] 5.3.1.4 Support arrow key navigation as well

### 5.3.2 Implement show/2 with Position Fallback

- [x] **Task 5.3.2 Complete**

Implement menu display with position fallback.

- [x] 5.3.2.1 If position provided, show at position (mouse mode)
- [x] 5.3.2.2 If no position, show inline below current focus
- [x] 5.3.2.3 Auto-detect based on backend capabilities

### 5.3.3 Implement Number Key Selection

- [x] **Task 5.3.3 Complete**

Handle number key presses for direct item selection.

- [x] 5.3.3.1 Map number keys 1-9 to menu item indices
- [x] 5.3.3.2 Immediately select and close on number press
- [x] 5.3.3.3 Show numbers in rendering when in inline mode

Note: Completed as part of Task 5.3.1 (ContextMenu.Inline implementation)

### Unit Tests - Section 5.3

- [x] **Unit Tests 5.3 Complete**
- [x] Test inline menu renders with numbers
- [x] Test number key selects correct item
- [x] Test arrow navigation still works
- [x] Test Enter confirms selection
- [x] Test Escape cancels menu

---

## 5.4 Ensure Color Degradation in Widgets

- [ ] **Section 5.4 Complete**

Ensure all widgets that use colors query backend capabilities and degrade gracefully.

### 5.4.1 Audit Widget Color Usage

- [x] **Task 5.4.1 Complete**

Identify all widgets that specify colors.

- [x] 5.4.1.1 List all widgets with hardcoded colors
- [x] 5.4.1.2 List all widgets using theme colors
- [x] 5.4.1.3 Identify any widgets with RGB-only colors

### 5.4.2 Implement Theme-Based Colors

- [x] **Task 5.4.2 Complete**

Ensure colors come from theme system.

- [x] 5.4.2.1 Verify all widgets use `Theme.color/1` or similar
- [x] 5.4.2.2 Ensure themes define semantic color names
- [x] 5.4.2.3 Theme system handles degradation via backend capabilities

### 5.4.3 Add Monochrome Fallbacks

- [x] **Task 5.4.3 Complete**

Ensure widgets remain usable in monochrome mode.

- [x] 5.4.3.1 Selected items use reverse video in mono mode
- [x] 5.4.3.2 Focused items use bold in mono mode
- [x] 5.4.3.3 Error states use underline in mono mode
- [x] 5.4.3.4 Charts use character differentiation (*, +, o, x)

### Unit Tests - Section 5.4

- [ ] **Unit Tests 5.4 Complete**
- [ ] Test widgets render correctly in true_color mode
- [ ] Test widgets render correctly in color_256 mode
- [ ] Test widgets render correctly in color_16 mode
- [ ] Test widgets render correctly in monochrome mode
- [ ] Test selection is visible in all color modes

---

## 5.5 Ensure Character Set Handling in Widgets

- [x] **Section 5.5 Complete**

Ensure all widgets that use box-drawing or special characters query the character set and use appropriate fallbacks.

### 5.5.1 Audit Widget Character Usage

- [x] **Task 5.5.1 Complete**

Identify all widgets using special characters.

- [x] 5.5.1.1 List widgets using box-drawing characters (11 widgets identified)
- [x] 5.5.1.2 List widgets using arrows or symbols (11 + 4 widgets identified)
- [x] 5.5.1.3 List widgets using Braille patterns (2 widgets identified)
- [x] 5.5.1.4 Document current fallback behavior (zero widgets use CharacterSet)

### 5.5.2 Use CharacterSet Module

- [x] **Task 5.5.2 Complete**

Ensure widgets use CharacterSet for special characters.

- [x] 5.5.2.1 Replace hardcoded box chars with `CharacterSet.current_charset().tl` etc.
- [x] 5.5.2.2 Replace hardcoded arrows with `CharacterSet.current_charset().arrow_right` etc.
- [x] 5.5.2.3 Replace hardcoded progress chars with `CharacterSet.current_charset().bar_full` etc.

### 5.5.3 Verify ASCII Fallbacks

- [x] **Task 5.5.3 Complete**

Verify ASCII fallbacks render correctly.

- [x] 5.5.3.1 Test box borders render with +, -, | in ASCII mode
- [x] 5.5.3.2 Test arrows render with <, >, ^, v in ASCII mode
- [x] 5.5.3.3 Test progress bars render with #, . in ASCII mode

### Unit Tests - Section 5.5

- [x] **Unit Tests 5.5 Complete**
- [x] Test widgets render correctly with Unicode character set (existing tests)
- [x] Test widgets render correctly with ASCII character set
- [x] Test box-drawing degrades to ASCII correctly
- [x] Test arrows degrade to ASCII correctly
- [x] Test gauges/progress degrade to ASCII correctly

---

## 5.6 Document Widget Compatibility

- [x] **Section 5.6 Complete**

Create documentation explaining widget behavior across backends.

### 5.6.1 Create Compatibility Matrix

- [x] **Task 5.6.1 Complete**

Document widget compatibility.

- [x] 5.6.1.1 Create table: Widget | Raw Mode | TTY Mode | Notes
- [x] 5.6.1.2 List fully compatible widgets (majority)
- [x] 5.6.1.3 List widgets with variants (TextInput → TextInput.Line)
- [x] 5.6.1.4 List features requiring keyboard alternatives (SplitPane drag, ContextMenu position)

### 5.6.2 Document Best Practices

- [x] **Task 5.6.2 Complete**

Document best practices for widget development.

- [x] 5.6.2.1 Always use Theme for colors
- [x] 5.6.2.2 Always use CharacterSet for special characters
- [x] 5.6.2.3 Provide keyboard alternatives for mouse features
- [x] 5.6.2.4 Test with both backends during development

### Unit Tests - Section 5.6

- [x] **Unit Tests 5.6 Complete**
- [x] Test documentation compiles without errors
- [x] Test code examples in documentation work

---

## 5.7 Integration Tests

- [x] **Section 5.7 Complete**

Integration tests verify widgets work correctly across both backends.

### 5.7.1 TextInput.Line Integration

- [x] **Task 5.7.1 Complete**

Test TextInput.Line works correctly.

- [x] 5.7.1.1 Test line input with shell editing
- [x] 5.7.1.2 Test validation feedback
- [x] 5.7.1.3 Test focus flow

### 5.7.2 Keyboard Navigation Tests

- [x] **Task 5.7.2 Complete**

Test keyboard navigation works identically in both modes.

- [x] 5.7.2.1 Test List arrow navigation in raw mode
- [x] 5.7.2.2 Test List arrow navigation in TTY mode
- [x] 5.7.2.3 Test Menu navigation in both modes
- [x] 5.7.2.4 Test Tabs navigation in both modes
- [x] 5.7.2.5 Verify identical behavior between modes

### 5.7.3 Mouse Fallback Tests

- [x] **Task 5.7.3 Complete**

Test mouse feature fallbacks work correctly.

- [x] 5.7.3.1 Test SplitPane keyboard resize
- [x] 5.7.3.2 Test ContextMenu.Inline number selection
- [x] 5.7.3.3 Test scrollbar keyboard alternatives (covered by keyboard navigation tests)

### 5.7.4 Visual Degradation Tests

- [x] **Task 5.7.4 Complete**

Test visual degradation across capability levels.

- [x] 5.7.4.1 Test rendering in each color mode
- [x] 5.7.4.2 Test rendering with Unicode vs ASCII
- [x] 5.7.4.3 Test combined degradation (monochrome + ASCII)

---

## Success Criteria

1. **TextInput.Line**: New widget provides shell line editing via `IO.gets/1`
2. **Keyboard Alternatives**: SplitPane and ContextMenu have keyboard-only modes
3. **Color Degradation**: All widgets use theme colors with graceful degradation
4. **Character Sets**: All widgets use CharacterSet with ASCII fallbacks
5. **Navigation Equivalence**: Arrow keys, Tab, Enter work identically in both modes
6. **Documentation**: Compatibility matrix and best practices documented
7. **Test Coverage**: All unit and integration tests pass

---

## Provides Foundation

This phase establishes:
- **Phase 6**: Complete widget set for runtime integration

---

## Key Outputs

- `lib/term_ui/widgets/text_input/line.ex` - Line-based text input
- `lib/term_ui/widgets/context_menu/inline.ex` - Inline context menu
- Updated SplitPane with keyboard resize
- Updated widgets using CharacterSet
- `docs/widget-compatibility.md` - Compatibility documentation
- `test/term_ui/widgets/` - Unit tests
- `test/integration/widget_adaptation_test.exs` - Integration tests

---

## Critical Files to Reference

- `lib/term_ui/widgets/text_input.ex` - Existing TextInput implementation
- `lib/term_ui/widgets/split_pane.ex` - SplitPane for keyboard resize
- `lib/term_ui/widgets/context_menu.ex` - ContextMenu for inline variant
- `lib/term_ui/character_set.ex` - Character set module from Phase 3
- `lib/term_ui/theme.ex` - Theme system for color handling
