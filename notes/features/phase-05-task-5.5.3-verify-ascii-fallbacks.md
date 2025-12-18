# Task 5.5.3: Verify ASCII Fallbacks

## Problem Statement

Task 5.5.2 updated all widgets to use `CharacterSet.current_charset()` for special characters. This task verifies that widgets render correctly when the character set is configured for ASCII mode, ensuring graceful degradation on terminals that don't support Unicode.

## Solution Overview

Create comprehensive tests that:
1. Set the character set to ASCII mode via `Application.put_env(:term_ui, :character_set, :ascii)`
2. Render widgets and verify output contains ASCII characters
3. Test box-drawing characters render as `+`, `-`, `|`
4. Test arrows render as `<`, `>`, `^`, `v`
5. Test progress bars render as `#`, `.`

## Technical Details

### Key Files
- `test/term_ui/widgets/ascii_fallback_test.exs` - New test file for ASCII fallback verification
- `lib/term_ui/character_set.ex` - CharacterSet module with ASCII definitions

### ASCII Character Mappings (from CharacterSet)
| Unicode | ASCII | Keys |
|---------|-------|------|
| `┌┐└┘` | `+` | `tl`, `tr`, `bl`, `br` |
| `─` | `-` | `h_line` |
| `│` | `\|` | `v_line` |
| `←→↑↓` | `<>^v` | `arrow_left/right/up/down` |
| `▲▼◀▶` | `^v<>` | `triangle_up/down/left/right` |
| `█` | `#` | `bar_full` |
| `░` | `.` | `bar_empty` |
| `✓` | `x` | `check` |
| `✗` | `X` | `cross_mark` |

### Widgets to Test
1. **Dialog** - Box-drawing characters for borders
2. **Gauge** - Progress bar characters
3. **Menu** - Separator lines, checkbox indicators, submenu arrows
4. **TreeView** - Expand/collapse triangles
5. **Table** - Sort direction arrows
6. **Sparkline** - Bar levels
7. **Toast** - Box-drawing for borders

## Implementation Plan

### Step 1: Create ASCII Fallback Test File
- [x] Create `test/term_ui/widgets/ascii_fallback_test.exs`
- [x] Add setup to configure ASCII charset and restore after tests
- [x] Group tests by character type

### Step 2: Box-Drawing Tests
- [x] Test Dialog renders borders with `+`, `-`, `|`
- [x] Test Toast renders borders with `+`, `-`, `|`
- [x] Verify corners use `+` instead of `┌┐└┘`

### Step 3: Arrow/Indicator Tests
- [x] Test Table sort arrows render as `^`, `v`
- [x] Test TreeView expand/collapse renders as `>`, `v`
- [x] Test Menu submenu arrows render as `>`, `v`

### Step 4: Progress Bar Tests
- [x] Test Gauge renders bar with `#` and `.`
- [x] Test Sparkline levels degrade to ASCII

### Step 5: Run Tests and Verify
- [x] Run full test suite
- [x] Verify all ASCII fallback tests pass (21 tests, 0 failures)

## Success Criteria

1. ✅ All ASCII fallback tests pass
2. ✅ Widgets produce valid ASCII output when character set is `:ascii`
3. ✅ No Unicode characters appear in ASCII-mode output
4. ✅ Tests verify specific character substitutions match CharacterSet definitions

## Current Status

**Status:** Complete
