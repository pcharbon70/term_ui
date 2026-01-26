# Phase 5 Review Fixes

## Problem Statement

The Phase 5 review identified several issues that need to be addressed before moving to Phase 6:

1. **3 test failures** - ContextMenu.Inline and VisualDegradation tests failing
2. **Missing callback protection** - Widgets don't protect against callback exceptions
3. **Undocumented blocking behavior** - TextInput.Line blocking behavior not documented
4. **Code duplication** - Border rendering, cursor movement, and line drawing duplicated

## Solution Overview

### Priority 2: Should Fix (Required before Phase 6)
- Fix all test failures
- Add try/catch protection around callbacks in TextInput.Line, ContextMenu.Inline, SplitPane
- Document TextInput.Line blocking behavior in moduledoc and widget-compatibility.md

### Priority 3: Should Consider (Code quality improvements)
- Create BorderHelper module for shared border rendering
- Add CharacterSet line drawing convenience methods
- Create CursorHelper module for navigation patterns

## Implementation Plan

### Step 1: Fix Test Failures
- [x] Create planning document
- [x] Fix ContextMenu.Inline separator tests (use CharacterSet in tests)
- [x] Fix VisualDegradation sparkline_levels test (exclude list values)

### Step 2: Add Callback Protection
- [x] Add try/catch to TextInput.Line on_blur callback
- [x] Add try/catch to ContextMenu.Inline on_select callback (via Behavior)
- [x] Add try/catch to ContextMenu.Behavior (on_select, on_close)
- [x] Add try/catch to SplitPane on_resize callback

### Step 3: Document TextInput.Line Blocking Behavior
- [x] Add "Blocking Behavior" section to TextInput.Line moduledoc
- [x] Update widget-compatibility.md with blocking note
- [x] Document as intentional architectural decision

### Step 4: Create BorderHelper Module
- [x] Create `lib/term_ui/helpers/border_helper.ex`
- [x] Implement `horizontal_line/1` - renders horizontal line with width
- [x] Implement `horizontal_line_heavy/1` - heavy horizontal line
- [x] Implement `vertical_line/1` - renders vertical line as list
- [x] Implement `box_top/1`, `box_bottom/1` - box borders with corners
- [x] Implement `box_top_round/1`, `box_bottom_round/1` - rounded corners
- [x] Implement `left_border/1`, `right_border/1` - side borders
- [x] Implement `bordered_row/3` - complete row with padding
- [x] Add tests (26 tests)

### Step 5: Add CharacterSet Line Drawing Helpers
- [x] Add `horizontal_line/1` to CharacterSet
- [x] Add `vertical_line/1` to CharacterSet
- [x] Add `box_top/1` to CharacterSet
- [x] Add `box_bottom/1` to CharacterSet
- [x] Add tests (12 tests)
- [x] Fix pre-existing test failures for sparkline_levels

### Step 6: Create CursorHelper Module
- [x] Create `lib/term_ui/helpers/cursor_helper.ex`
- [x] Implement `move_up/4`, `move_down/4` - moves cursor with bounds/wrap
- [x] Implement `wrap_cursor/3` - wraps cursor at bounds
- [x] Implement `clamp_cursor/3` - clamps cursor to bounds
- [x] Implement `move_to_next_valid/5` - skips invalid positions
- [x] Implement `first_valid/2`, `last_valid/2` - find valid positions
- [x] Add tests (29 tests)

### Step 7: Update Widgets to Use Helpers (deferred)
- Note: Actually updating widgets is deferred to avoid scope creep
- Widgets that would benefit: Dialog, AlertDialog, Table, TreeView, Menu

### Step 8: Cleanup and Summary
- [x] Run `mix format`
- [x] Run `mix compile --warnings-as-errors`
- [x] Run `mix credo --strict` (only pre-existing style issues)
- [x] Run tests for modified files (251 tests, 0 failures)
- [x] Write summary document

## Current Status

**Status:** Complete

### What Works
- All 3 test failures fixed
- Callback protection added to TextInput.Line, ContextMenu.Inline, ContextMenu.Behavior, SplitPane
- TextInput.Line blocking behavior documented in moduledoc and widget-compatibility.md
- BorderHelper module created with comprehensive border rendering functions
- CharacterSet line drawing helpers added (horizontal_line, vertical_line, box_top, box_bottom)
- CursorHelper module created with cursor navigation functions
- Additional pre-existing test failures in CharacterSetTest fixed (sparkline_levels)
- All modified file tests pass (251 tests)

### How to Run
```bash
# Run tests for modified files
mix test test/term_ui/helpers/ test/term_ui/character_set_test.exs test/term_ui/widgets/context_menu/inline_test.exs test/integration/visual_degradation_integration_test.exs
```

## Files to Create
- `lib/term_ui/helpers/border_helper.ex`
- `lib/term_ui/helpers/cursor_helper.ex`
- `test/term_ui/helpers/border_helper_test.exs`
- `test/term_ui/helpers/cursor_helper_test.exs`

## Files to Modify
- `test/term_ui/widgets/context_menu/inline_test.exs` - Fix separator assertions
- `test/integration/visual_degradation_integration_test.exs` - Exclude sparkline_levels
- `lib/term_ui/widgets/text_input/line.ex` - Add callback protection, update docs
- `lib/term_ui/widgets/context_menu/inline.ex` - Add callback protection
- `lib/term_ui/widgets/split_pane.ex` - Add callback protection (if needed)
- `lib/term_ui/character_set.ex` - Add line drawing helpers
- `docs/widget-compatibility.md` - Document blocking behavior
