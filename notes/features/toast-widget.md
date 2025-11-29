# Toast Widget Feature

## Problem Statement

Phase 6.3.3 requires Toast Notifications for displaying brief, auto-dismissing messages. Toasts should appear at screen edge, stack when multiple appear, and not capture focus or block interaction.

## Solution Overview

The `TermUI.Widgets.Toast` widget is already implemented with:
- Positioning at screen edges (6 positions)
- Auto-dismiss with configurable duration
- Type-specific icons (info, success, warning, error)
- Z-order (z: 150) for rendering above dialogs
- Click or Escape to dismiss

Additionally, `TermUI.Widgets.ToastManager` provides:
- Multiple toast management
- Toast stacking
- Auto-dismiss handling via tick()
- Maximum toast limit

**Missing**: Example application in `examples/` directory.

## Technical Details

### Existing Files
- Widget: `lib/term_ui/widgets/toast.ex` (includes Toast and ToastManager)
- Tests: `test/term_ui/widgets/toast_test.exs` (30 tests passing)

### Files to Create
- Example: `examples/toast/` directory with mix project

### Toast Types
| Type | Icon | Color |
|------|------|-------|
| info | ℹ | blue |
| success | ✓ | green |
| warning | ⚠ | yellow |
| error | ✗ | red |

### Toast Positions
- top_left, top_center, top_right
- bottom_left, bottom_center, bottom_right

## Implementation Plan

### 6.3.3.1 Toast positioning at screen edge
- [x] 6 positions supported
- [x] Position calculated from area dimensions

### 6.3.3.2 Auto-dismiss with configurable duration
- [x] Default 3000ms duration
- [x] nil duration for no auto-dismiss
- [x] should_dismiss?() checks elapsed time
- [x] ToastManager.tick() removes expired toasts

### 6.3.3.3 Toast stacking for multiple notifications
- [x] ToastManager handles multiple toasts
- [x] Stacking with configurable spacing
- [x] max_toasts limit (default 5)

### 6.3.3.4 Toast types: info, success, warning, error
- [x] All 4 types with icons
- [x] Type stored in state

### Create Example Application
- [x] Create `examples/toast/` mix project structure
- [x] Implement example demonstrating toast types and positions
- [x] Add README with usage instructions

## Success Criteria

- [x] Widget renders at correct screen positions
- [x] Auto-dismiss works after duration
- [x] Multiple toasts stack correctly
- [x] All toast types have correct icons
- [x] All tests pass (30 tests)
- [x] Example application demonstrates usage

## Current Status

**Completed**: All tasks done. Widget, tests, and example are complete.
