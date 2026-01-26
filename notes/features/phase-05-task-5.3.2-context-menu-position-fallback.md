# Feature: Phase 5 Task 5.3.2 - ContextMenu Position Fallback

**Branch:** `feature/phase-05-task-5.3.2-context-menu-position-fallback`
**Base:** `multi-renderer`
**Date:** 2025-12-07
**Status:** Complete

## Overview

Implement a unified factory module that automatically selects between positioned (mouse) and inline (keyboard) context menus based on whether a position is provided and/or terminal capabilities.

## Requirements from Phase Plan

From `notes/planning/multi-renderer/phase-05-widget-adaptation.md`:

### Task 5.3.2: Implement show/2 with Position Fallback
- [x] 5.3.2.1 If position provided, show at position (mouse mode)
- [x] 5.3.2.2 If no position, show inline below current focus
- [x] 5.3.2.3 Auto-detect based on backend capabilities

---

## Design Decisions

### 1. API Design

Created a unified factory module `TermUI.Widgets.ContextMenu.Factory` that:
- Provides `create/1` to create the appropriate menu type
- Uses `TermUI.Capabilities.supports_mouse?/0` for auto-detection
- Accepts `:mode` option to force a specific mode (`:auto`, `:positioned`, `:inline`)

### 2. Mode Selection Logic

```
If :mode == :inline -> use Inline
Else If :mode == :positioned -> use ContextMenu (requires position)
Else (:mode == :auto, default)
  If :position provided -> use ContextMenu
  Else If Capabilities.supports_mouse?() -> require position (caller should provide)
  Else -> use Inline
```

### 3. Shared Interface

Both ContextMenu and ContextMenu.Inline already share:
- `init/1`, `handle_event/2`, `render/2` (StatefulComponent)
- `visible?/1`, `show/1`, `hide/1`, `get_cursor/1`
- Same item format (`ContextMenu.action/3`, `ContextMenu.separator/0`)

The Factory provides the unified entry point.

---

## Implementation Plan

### Step 1: Create Factory Module
- [x] Create `lib/term_ui/widgets/context_menu/factory.ex`
- [x] Implement `create/1` with mode detection
- [x] Document usage in `@moduledoc`

### Step 2: Implement Mode Detection
- [x] Handle `:mode` option (`:auto`, `:positioned`, `:inline`)
- [x] Auto-detect based on position and capabilities
- [x] Return appropriate props for selected menu type

### Step 3: Write Unit Tests
- [x] Test explicit `:mode` selection
- [x] Test auto-detection with position
- [x] Test auto-detection without position (mock capabilities)
- [x] Test fallback to inline when mouse not supported

---

## Success Criteria

- [x] Factory module created at `lib/term_ui/widgets/context_menu/factory.ex`
- [x] `create/1` returns correct menu type based on mode/position
- [x] Auto-detection uses `Capabilities.supports_mouse?/0`
- [x] All unit tests pass (23 tests)
- [x] `mix compile --warnings-as-errors` passes

---

## Files Created/Modified

| File | Changes |
|------|---------|
| `lib/term_ui/widgets/context_menu/factory.ex` | New module (~220 lines) |
| `test/term_ui/widgets/context_menu/factory_test.exs` | New tests (23 tests) |
| `notes/planning/multi-renderer/phase-05-widget-adaptation.md` | Mark tasks complete |
