# Context Menu Widget Feature

## Problem Statement

Phase 6.2.3 requires a Context Menu widget for displaying floating menus at cursor position. The widget should appear on right-click or shortcut, close on selection/escape/outside click, and render above other content.

## Solution Overview

The `TermUI.Widgets.ContextMenu` widget is already implemented with:
- Floating overlay at specified position
- Keyboard navigation (Up/Down/Enter/Escape)
- Closes on selection, escape, or outside click
- Z-order (z: 100) for rendering above other content

**Missing**: Example application in `examples/` directory.

## Technical Details

### Existing Files
- Widget: `lib/term_ui/widgets/context_menu.ex`
- Tests: `test/term_ui/widgets/context_menu_test.exs` (28 tests passing)

### Files to Create
- Example: `examples/context_menu/` directory with mix project

## Implementation Plan

### 6.2.3.1 Context menu trigger on right-click or shortcut
- [x] Mouse click handling implemented
- [x] Position-based rendering

### 6.2.3.2 Floating overlay positioning at click location
- [x] Position prop accepts {x, y} tuple
- [x] Render returns overlay structure with position

### 6.2.3.3 Close on selection, Escape, or outside click
- [x] Selection closes menu and triggers callback
- [x] Escape key closes menu
- [x] Click outside bounds closes menu

### 6.2.3.4 Z-order ensuring context menu above other content
- [x] Render returns z: 100 in overlay structure

### Create Example Application
- [x] Create `examples/context_menu/` mix project structure
- [x] Implement `ContextMenu.App` demonstrating right-click context menu
- [x] Add README with usage instructions

## Success Criteria

- [x] Widget renders correctly as floating overlay
- [x] All keyboard navigation works
- [x] Selection/cancel/outside-click close works
- [x] All tests pass (28 tests)
- [x] Example application demonstrates usage

## Current Status

**Completed**: All tasks done. Widget, tests, and example are complete.
