# Feature: Phase 5 Task 5.3.1 - ContextMenu.Inline Variant

**Branch:** `feature/phase-05-task-5.3.1-context-menu-inline`
**Base:** `multi-renderer`
**Date:** 2025-12-07
**Status:** Complete

## Overview

Create an inline context menu variant that doesn't require mouse positioning. This widget renders menu items with numbers for direct selection (e.g., `[1] Copy  [2] Paste  [3] Delete`), making it usable in TTY mode where mouse positioning may not be available.

## Requirements from Phase Plan

From `notes/planning/multi-renderer/phase-05-widget-adaptation.md`:

### Task 5.3.1: Create ContextMenu.Inline Variant
- [x] 5.3.1.1 Create `lib/term_ui/widgets/context_menu/inline.ex`
- [x] 5.3.1.2 Render menu items with numbers: `[1] Copy  [2] Paste  [3] Delete`
- [x] 5.3.1.3 Accept number keys for direct selection
- [x] 5.3.1.4 Support arrow key navigation as well

---

## Design Decisions

### 1. Module Structure
- Create `TermUI.Widgets.ContextMenu.Inline` as a separate module
- Reuse item constructors from `ContextMenu` (action, separator)
- Different rendering approach - inline horizontal/vertical layout with numbers

### 2. Rendering Format
- Numbers in brackets: `[1] Copy  [2] Paste  [3] Delete`
- Separators skip numbering (not selectable)
- Only number selectable items (actions that are not disabled)
- Support both horizontal (inline) and vertical (list) orientations

### 3. Number Key Mapping
- Keys 1-9 map to visible numbered items
- Immediate selection on number press (no Enter needed)
- Numbers correspond to displayed numbers (not array indices)
- Max 9 items can be numbered (10th+ items require arrow navigation)

### 4. Compatibility
- Uses `StatefulComponent` like parent ContextMenu
- Compatible with existing event system
- No position required (renders where placed in layout)

---

## Implementation Plan

### Step 1: Create Module Structure
- [x] Create `lib/term_ui/widgets/context_menu/inline.ex`
- [x] Add `@moduledoc` with usage examples
- [x] `use TermUI.StatefulComponent`
- [x] Define type specs

### Step 2: Define Props and State
- [x] Define `new/1` accepting `:items`, `:on_select`, `:on_close`, `:orientation`
- [x] Define `init/1` to initialize state with cursor and numbering
- [x] Build number-to-item mapping for quick lookup

### Step 3: Implement Rendering
- [x] Render items with `[n]` prefix for numbered items
- [x] Skip numbering for separators and disabled items
- [x] Support `:horizontal` and `:vertical` orientations
- [x] Apply styles for selected/disabled items

### Step 4: Implement Event Handling
- [x] Handle number keys 1-9 for direct selection
- [x] Handle Up/Down/Left/Right for navigation
- [x] Handle Enter/Space for selection at cursor
- [x] Handle Escape to close menu

### Step 5: Write Unit Tests
- [x] Test inline menu renders with numbers
- [x] Test number key selects correct item
- [x] Test arrow navigation works
- [x] Test Enter confirms selection
- [x] Test Escape cancels menu
- [x] Test disabled items are skipped in numbering
- [x] Test separators are not numbered

---

## Success Criteria

- [x] Module created at `lib/term_ui/widgets/context_menu/inline.ex`
- [x] Items render with numbered prefixes `[1]`, `[2]`, etc.
- [x] Number keys 1-9 directly select corresponding item
- [x] Arrow keys navigate between items
- [x] Enter selects current item
- [x] Escape closes menu
- [x] All unit tests pass (32 tests)
- [x] `mix compile --warnings-as-errors` passes

---

## Files Created/Modified

| File | Changes |
|------|---------|
| `lib/term_ui/widgets/context_menu/inline.ex` | New module (~290 lines) |
| `test/term_ui/widgets/context_menu/inline_test.exs` | New tests (32 tests) |
| `notes/planning/multi-renderer/phase-05-widget-adaptation.md` | Mark tasks complete |
