# Task 5.7.3: Mouse Fallback Tests

## Problem Statement

Need to verify that keyboard alternatives for mouse-dependent features work correctly. This ensures widgets remain fully functional in TTY mode where mouse interaction may not be available.

The plan identifies three mouse features with keyboard fallbacks:
1. SplitPane: Mouse dragging for resize → Ctrl+arrow keyboard shortcuts
2. ContextMenu.Inline: Numbered menu items for direct selection
3. Scrollbar keyboard alternatives (already have keyboard alternatives)

## Solution Overview

Create `test/integration/mouse_fallback_integration_test.exs` that tests:

1. **SplitPane keyboard resize** (Ctrl+Left/Right/Up/Down)
2. **ContextMenu.Inline number selection** (1-9 keys)
3. **Scrollbar keyboard alternatives** (already tested in keyboard navigation)

### Key Insight

The scrollbar keyboard alternatives subtask (5.7.3.3) is already covered by existing keyboard navigation tests since scrolling uses arrow keys which are tested in keyboard_navigation_integration_test.exs.

## Test Categories

### 5.7.3.1: SplitPane Keyboard Resize
- Ctrl+Right increases left/top pane ratio
- Ctrl+Left decreases left/top pane ratio
- Ctrl+Down increases top pane ratio (vertical split)
- Ctrl+Up decreases top pane ratio (vertical split)
- Ratio is clamped to min/max bounds
- Resize step is configurable via `:ctrl_resize_step` option
- Works with both horizontal and vertical orientations

### 5.7.3.2: ContextMenu.Inline Number Selection
- Number keys 1-9 directly select corresponding items
- Selection triggers on_select callback
- Menu closes after number selection
- Disabled items are not numbered
- Separators are not numbered
- Only first 9 selectable items get numbers

### 5.7.3.3: Scrollbar Keyboard Alternatives
Already covered by:
- TreeView tests use Up/Down arrows for scrolling
- Tabs tests use Left/Right arrows
- Menu tests use Up/Down arrows
All these scroll the view when needed.

## Implementation Plan

1. ✅ Create planning document (this file)
2. Create `test/integration/mouse_fallback_integration_test.exs`
3. Add SplitPane keyboard resize tests
4. Add ContextMenu.Inline number selection tests
5. Run and verify all tests pass
6. Mark Task 5.2.3 and 5.7.3 complete in phase plan
7. Create summary document

## Success Criteria

- SplitPane Ctrl+arrow resize tests pass
- ContextMenu.Inline number selection tests pass
- All integration tests passing
- Task 5.2.3 marked complete (was pending in phase plan)
- Task 5.7.3 marked complete

## Current Status

- ✅ Planning document created
- ✅ Test file created with 26 tests
- ✅ SplitPane keyboard resize tests (10 tests)
- ✅ ContextMenu.Inline number selection tests (16 tests)
- ✅ All tests passing
- ✅ Phase plan updated (Task 5.2.3 already complete, Task 5.7.3 marked complete)
- ✅ Implementation complete

## Existing Implementation Details

### SplitPane Keyboard Resize (lib/term_ui/widgets/split_pane.ex)

The widget already implements:
- Ctrl+Left/Up: decrease first pane size (calls `move_divider_by_ratio(state, 0, -state.ctrl_resize_step)`)
- Ctrl+Right/Down: increase first pane size (calls `move_divider_by_ratio(state, 0, state.ctrl_resize_step)`)
- Default `ctrl_resize_step` is 0.05 (5%)
- Default `min_ratio` is 0.1 (10%)
- Default `max_ratio` is 0.9 (90%)

### ContextMenu.Inline Number Selection (lib/term_ui/widgets/context_menu/inline.ex)

The widget already implements:
- Number keys 1-9 mapped to selectable items
- `build_number_map/1` creates mapping during init
- `select_by_number/2` handles number key selection
- Only selectable (non-disabled, non-separator) items are numbered
