# Feature: Phase 5 Task 5.2.1 - SplitPane Keyboard Resize Shortcuts

**Branch:** `feature/phase-05-task-5.2.1-splitpane-keyboard`
**Base:** `multi-renderer`
**Date:** 2025-12-06
**Status:** In Progress

## Overview

Add Ctrl+arrow keyboard shortcuts for resizing SplitPane without requiring a focused divider. This makes the widget usable in TTY mode where mouse interaction may not be available.

## Current State

The SplitPane already has keyboard controls:
- Arrow keys resize when a divider is focused
- Tab moves focus between dividers
- Home/End move to min/max positions

However, focusing a divider requires either:
1. Mouse click on the divider
2. Pressing Tab to cycle through dividers

## Task Requirements

| Subtask | Requirement | Description |
|---------|-------------|-------------|
| 5.2.1.1 | Ctrl+Left | Decrease left/top pane size |
| 5.2.1.2 | Ctrl+Right | Increase left/top pane size |
| 5.2.1.3 | Ctrl+Up | Decrease top pane size (vertical split) |
| 5.2.1.4 | Ctrl+Down | Increase top pane size (vertical split) |
| 5.2.1.5 | Document shortcuts | Update widget moduledoc |

## Design Decisions

### Ctrl+Arrows Target First Divider

Since Ctrl+arrows work without a focused divider, they will always target the **first divider** (index 0). This is the most common use case (two-pane split).

For multi-pane splits, users can still use Tab to focus specific dividers and then use regular arrow keys.

### Orientation-Aware Shortcuts

- **Horizontal split**: Ctrl+Left/Right resize (left/right panes)
- **Vertical split**: Ctrl+Up/Down resize (top/bottom panes)

Both work in either orientation for convenience, but the appropriate ones for the orientation will have the expected effect.

### Resize Step

Use the existing `@resize_step` (1) for Ctrl+arrows. Users wanting larger steps can use the existing Shift+arrow when a divider is focused.

---

## Implementation Plan

### Step 1: Add Ctrl+Arrow Event Handlers

Add new `handle_event` clauses that match Ctrl+arrow combinations and call `move_divider/3` with divider index 0.

### Step 2: Update Moduledoc

Add Ctrl+arrow shortcuts to the Keyboard Controls section.

### Step 3: Add Tests

Test that Ctrl+arrows resize without needing a focused divider.

---

## Success Criteria

- [x] Ctrl+Left/Right resize horizontal splits
- [x] Ctrl+Up/Down resize vertical splits
- [x] Works without focused divider
- [x] Moduledoc updated
- [x] Unit tests pass (51 tests, 0 failures)
