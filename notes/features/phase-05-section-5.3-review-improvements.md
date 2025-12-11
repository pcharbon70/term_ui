# Phase 5 - Section 5.3 Context Menu Review Improvements

**Date:** 2025-12-11
**Status:** In Progress
**Related Review:** `notes/reviews/section-5.3-context-menu-review.md`
**Branch:** `feature/phase-05-section-5.3-review-improvements`

---

## Overview

This document provides a comprehensive implementation plan to address all findings from the Section 5.3 ContextMenu review. The review identified 9 actionable recommendations (excluding #10 which is deferred as a larger refactoring).

The improvements are organized into three priority levels based on impact and effort:

- **Priority 1 (High Impact):** Tasks 1-3 - Core refactoring and test coverage
- **Priority 2 (Medium Impact):** Tasks 4-6 - Performance and code quality
- **Priority 3 (Low Impact):** Tasks 7-9 - Developer experience and documentation

**Estimated Total Effort:** ~8.5 hours
**Estimated P1 Effort:** ~3.5 hours

---

## Task Status

### Priority 1 (High Impact)
- [x] Task 1: Create ContextMenu.Behavior module (~2h) - **COMPLETE**
- [x] Task 2: Fix render/2 performance bug (~30m) - **COMPLETE**
- [x] Task 3: Add style verification tests (~1h) - **COMPLETE**

### Priority 2 (Medium Impact)
- [x] Task 4: Add item_map to state for O(1) lookups (~1h) - **COMPLETE**
- [x] Task 5: Add rendering content tests (~1h) - **COMPLETE**
- [x] Task 6: Simplify find_number_for_item/2 (~15m) - **COMPLETE**

### Priority 3 (Low Impact)
- [ ] Task 7: Extract test helpers (~30m)
- [ ] Task 8: Improve test environment restoration (~15m)
- [x] Task 9: Document callback error behavior (~15m) - **COMPLETE**

---

## Priority 1: High Impact Tasks

### Task 1: Create ContextMenu.Behavior Module

**Status:** ⏳ Not Started

**Issue:** 154 lines duplicated between `ContextMenu` and `ContextMenu.Inline`

**Impact:** High - Reduces duplication, improves maintainability, single source of truth
**Effort:** ~2 hours
**Files Affected:**
- CREATE: `lib/term_ui/widgets/context_menu/behavior.ex`
- MODIFY: `lib/term_ui/widgets/context_menu.ex`
- MODIFY: `lib/term_ui/widgets/context_menu/inline.ex`
- CREATE: `test/term_ui/widgets/context_menu/behavior_test.exs`

#### Implementation Details

See full planning document for detailed implementation steps.

**Key Functions to Extract:**
- `selectable?/1` - Item selection predicate
- `find_first_selectable/1` - Find first selectable item
- `move_cursor/2` - Cursor movement logic
- `select_at_cursor/1` - Selection at cursor
- `close_menu/1` - Menu close logic

---

### Task 2: Fix render/2 Performance Bug

**Status:** ⏳ Not Started

**Issue:** `number_map` rebuilt on every frame in Inline.render/2

**Impact:** High - Eliminates unnecessary computation on every render
**Effort:** ~30 minutes
**Files Affected:**
- MODIFY: `lib/term_ui/widgets/context_menu/inline.ex`

#### Implementation Summary

Remove line 151 that rebuilds `number_map` and use cached `state.number_map` instead.

---

### Task 3: Add Style Verification Tests

**Status:** ⏳ Not Started

**Issue:** Tests check structure but not actual style application

**Impact:** High - Improves test coverage from 89.5% to 95%+
**Effort:** ~1 hour
**Files Affected:**
- MODIFY: `test/term_ui/widgets/context_menu/inline_test.exs`

#### Test Coverage Needed

- Test `item_style` application to normal items
- Test `selected_style` application to cursor item
- Test `disabled_style` application to disabled items
- Test `number_style` application to number prefix
- Test style priority (disabled > selected > normal)

---

## Priority 2: Medium Impact Tasks

### Task 4: Add item_map to State for O(1) Lookups

**Status:** ⏳ Not Started

**Issue:** Multiple O(n) list searches for items by ID

**Impact:** Medium - Performance improvement for large menus
**Effort:** ~1 hour

---

### Task 5: Add Rendering Content Tests

**Status:** ⏳ Not Started

**Issue:** Tests verify structure, not actual rendered text

**Impact:** Medium - Catches visual bugs
**Effort:** ~1 hour

---

### Task 6: Simplify find_number_for_item/2

**Status:** ⏳ Not Started

**Issue:** Could be more idiomatic using `Enum.find_value/2`

**Impact:** Low - Code clarity improvement
**Effort:** ~15 minutes

---

## Priority 3: Low Impact Tasks

### Task 7: Extract Test Helpers

**Status:** ⏳ Not Started

**Issue:** Duplicated test utilities across test files

**Impact:** Low - Reduces test duplication, improves consistency
**Effort:** ~30 minutes

---

### Task 8: Improve Test Environment Restoration

**Status:** ⏳ Not Started

**Issue:** Repetitive environment cleanup pattern

**Impact:** Low - DRYer test code
**Effort:** ~15 minutes

---

### Task 9: Document Callback Error Behavior

**Status:** ⏳ Not Started

**Issue:** Callbacks executed without try/catch - unclear error handling

**Impact:** Low - Developer documentation
**Effort:** ~15 minutes

---

## Testing Strategy

### Test Execution Order

1. **After Task 1 (Behavior Module)**
   ```bash
   mix test test/term_ui/widgets/context_menu/behavior_test.exs
   mix test test/term_ui/widgets/context_menu/
   ```

2. **After Task 2 (Performance Fix)**
   ```bash
   mix test test/term_ui/widgets/context_menu/inline_test.exs
   ```

3. **After Task 3 (Style Tests)**
   ```bash
   mix test test/term_ui/widgets/context_menu/inline_test.exs
   ```

4. **After All P1 Tasks**
   ```bash
   mix test
   ```

### Coverage Goals

- **Before:** 94.4% coverage (99/108 lines)
- **After P1:** 95%+ coverage
- **After P2:** 96%+ coverage

---

## Success Criteria

### Code Quality
- [ ] All tests pass
- [ ] Coverage ≥ 95%
- [ ] Code duplication reduced by ~154 lines

### Performance
- [ ] Render performance improved (no redundant number_map builds)
- [ ] Item lookups optimized to O(1) where possible

### Documentation
- [ ] Callback error behavior documented
- [ ] All new functions have `@doc` and `@spec`

### Backward Compatibility
- [ ] All existing tests pass
- [ ] Public API unchanged
- [ ] Examples work without modification

---

## Notes

### Design Decisions

1. **Behavior Module Name**
   - Named `Behavior` (not `Behaviour` or `Common`)
   - Not a formal Elixir `@behavior` - just shared functions
   - Located in `context_menu/` subdirectory for clarity

2. **item_map vs items**
   - Keep both in state for compatibility
   - `items` preserves order for rendering
   - `item_map` provides O(1) lookups

---

## References

- Review Document: `notes/reviews/section-5.3-context-menu-review.md`
- Planning Doc: `notes/planning/multi-renderer/phase-05-widget-adaptation.md`
