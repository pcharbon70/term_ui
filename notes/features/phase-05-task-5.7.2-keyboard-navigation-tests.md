# Task 5.7.2: Keyboard Navigation Tests

## Problem Statement

Need to verify keyboard navigation works identically in both Raw and TTY modes across widgets. This is critical because:
1. Users expect consistent behavior regardless of mode
2. The architectural decision was that keyboard navigation is cross-compatible
3. Integration tests should verify this works end-to-end

## Solution Overview

Create `test/integration/keyboard_navigation_integration_test.exs` that tests:

1. **Menu widget navigation** (Up/Down arrows, Enter, Escape)
2. **Tabs widget navigation** (Left/Right arrows, Enter, Home/End)
3. **TreeView navigation** (Up/Down arrows, Left/Right for expand/collapse)
4. **Cross-mode identical behavior verification**

### Key Insight

The plan mentions "List arrow navigation" but there's no List widget. TreeView serves this purpose as a list-like widget with up/down navigation. Menu also provides list-like navigation.

### Why Testing Works

Arrow keys produce identical ANSI escape sequences in both modes:
- Up: `\e[A`
- Down: `\e[B`
- Left: `\e[D`
- Right: `\e[C`

Widgets use `Event.Key{key: :up}` etc. which is produced by the same key sequences regardless of backend. Testing the widgets' `handle_event` behavior verifies they respond correctly to keyboard input.

## Test Categories

### 5.7.2.1/2: List-like Navigation (TreeView/Menu)
- TreeView: Up/Down to move cursor, verify state changes
- Menu: Up/Down to move cursor, verify state changes
- Both: State changes are deterministic given same events

### 5.7.2.3: Menu Navigation (both modes)
- Up/Down: Move cursor
- Enter/Space: Select item
- Left/Right: Collapse/expand submenus
- Escape: Close menu

### 5.7.2.4: Tabs Navigation (both modes)
- Left/Right: Move focus between tabs
- Enter/Space: Select focused tab
- Home/End: Jump to first/last tab

### 5.7.2.5: Identical Behavior Verification
- Same events produce same state changes
- Behavior is deterministic and mode-independent
- State transitions follow same patterns

## Success Criteria

✅ Menu keyboard navigation tests pass
✅ Tabs keyboard navigation tests pass
✅ TreeView keyboard navigation tests pass
✅ Tests verify identical state changes for same events
✅ All tests passing

## Implementation Plan

1. Create planning document (this file)
2. Create `test/integration/keyboard_navigation_integration_test.exs`
3. Add Menu navigation tests
4. Add Tabs navigation tests
5. Add TreeView navigation tests (as "list" replacement)
6. Add cross-mode verification tests
7. Run and verify all tests pass
8. Update phase plan
9. Create summary document

## Current Status

- ✅ Planning document created
- ✅ Test file created with 30 tests
- ✅ Menu navigation tests implemented (10 tests)
- ✅ Tabs navigation tests implemented (10 tests)
- ✅ TreeView navigation tests implemented (10 tests)
- ✅ All tests passing
- ✅ Phase plan updated
- ✅ Implementation complete
