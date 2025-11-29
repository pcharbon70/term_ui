# Dialog Widget Feature

## Problem Statement

Phase 6.3.1 requires a Dialog widget for modal overlays. The widget should appear centered over the application with a backdrop, trap focus within the dialog, and handle Escape for cancellation.

## Solution Overview

The `TermUI.Widgets.Dialog` widget is already implemented with:
- Centered display with customizable width
- Semi-transparent backdrop
- Focus trapping (Tab cycles within dialog)
- Escape to close (when closeable)
- Button navigation and selection
- Z-order (z: 100) for rendering above other content

**Status**: Widget, tests, and example already exist.

## Technical Details

### Existing Files
- Widget: `lib/term_ui/widgets/dialog.ex`
- Tests: `test/term_ui/widgets/dialog_test.exs` (25 tests passing)
- Example: `examples/dialog/` directory with mix project

### Widget Features
- Title bar with customizable style
- Content area for any render node
- Button bar with Tab/Arrow navigation
- Enter/Space activates focused button
- Escape closes dialog (when closeable)
- Callbacks: `on_close`, `on_confirm`

## Implementation Plan

### 6.3.1.1 Dialog container with title bar and content area
- [x] Title bar rendering with centering
- [x] Content area with border
- [x] Customizable width

### 6.3.1.2 Centering within terminal window
- [x] Calculate centered position from area dimensions
- [x] dialog_x and dialog_y in overlay structure

### 6.3.1.3 Backdrop rendering behind dialog
- [x] Semi-transparent backdrop using ░ character
- [x] Covers full terminal area
- [x] Customizable backdrop style

### 6.3.1.4 Focus trapping preventing Tab escape
- [x] Tab cycles through buttons only
- [x] Shift+Tab cycles backwards
- [x] Focus stays within dialog

### 6.3.1.5 Escape handling for dialog close
- [x] Escape closes when closeable=true
- [x] No-op when closeable=false
- [x] Calls on_close callback

### 6.3.1.6 on_close and on_confirm callbacks
- [x] on_close called when dialog closes
- [x] on_confirm called with button_id on selection

## Success Criteria

- [x] Widget renders correctly as centered overlay
- [x] Focus trapping works (Tab cycles buttons)
- [x] Escape closes dialog
- [x] Button navigation with Tab/Arrow keys
- [x] Button activation with Enter/Space
- [x] All tests pass (25 tests)
- [x] Example application demonstrates usage

## Current Status

**Completed**: All tasks done. Widget, tests, and example are complete.
