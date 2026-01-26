# Feature: Phase 5 Task 5.2.3 - SplitPane Resize Step Configuration

**Branch:** `feature/phase-05-task-5.2.2-5.2.3-splitpane-config`
**Base:** `multi-renderer`
**Date:** 2025-12-06
**Status:** Complete

## Overview

Add configurable options for keyboard resize behavior in SplitPane:
- `:resize_step` - Step size for Ctrl+arrow resize (default: 1 character)
- `:min_ratio` - Minimum ratio for first pane (default: 0.1 = 10%)
- `:max_ratio` - Maximum ratio for first pane (default: 0.9 = 90%)

## Task Requirements

| Subtask | Requirement | Description |
|---------|-------------|-------------|
| 5.2.3.1 | Add `:resize_step` option | Default 0.05 = 5% per task spec |
| 5.2.3.2 | Add `:min_ratio` option | Default 0.1 = 10% |
| 5.2.3.3 | Add `:max_ratio` option | Default 0.9 = 90% |

## Design Decisions

### Resize Step Interpretation

The task spec says "default 0.05 = 5%" but the current implementation uses character steps (1 char). Looking at the existing code:
- `@resize_step 1` - 1 character/line per step
- `@large_resize_step 5` - 5 characters/lines for Shift+arrow

I'll add a configurable `ctrl_resize_step` for Ctrl+arrow shortcuts that can be set as a percentage (0.0-1.0) of total size, while keeping the focused-divider arrow keys using character steps.

### Min/Max Ratio Enforcement

The `min_ratio` and `max_ratio` will be enforced in the `move_divider` function to prevent the first pane from becoming too small or too large when using Ctrl+arrows.

---

## Implementation Plan

### Step 1: Add Configuration Options to Props

Add to `new/1`:
- `:ctrl_resize_step` - Default 0.05 (5%)
- `:min_ratio` - Default 0.1 (10%)
- `:max_ratio` - Default 0.9 (90%)

### Step 2: Store Options in State

Add fields to state in `init/1`.

### Step 3: Use Options in Ctrl+Arrow Handlers

Modify the Ctrl+arrow handlers to use the configurable step and enforce min/max ratios.

### Step 4: Add Tests

Test configuration options are respected.

---

## Success Criteria

- [x] ctrl_resize_step configurable via props
- [x] min_ratio configurable via props
- [x] max_ratio configurable via props
- [x] Ctrl+arrows respect configured step size
- [x] Ratio bounds are enforced
- [x] Unit tests pass (62 tests, 0 failures)
