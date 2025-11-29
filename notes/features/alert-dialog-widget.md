# Alert Dialog Widget Feature

## Problem Statement

Phase 6.3.2 requires an Alert Dialog widget for standardized messages and confirmations. The widget should provide predefined alert types (info, warning, error, success, confirm) with appropriate icons and button configurations.

## Solution Overview

The `TermUI.Widgets.AlertDialog` widget is already implemented with:
- Predefined alert types: info, success, warning, error, confirm, ok_cancel
- Type-specific icons (ℹ, ✓, ⚠, ✗, ?)
- Standard button configurations per type
- Default focus on appropriate button
- Shortcut keys (Y/N for confirm dialogs)
- Z-order (z: 100) for rendering above other content

**Missing**: Example application in `examples/` directory.

## Technical Details

### Existing Files
- Widget: `lib/term_ui/widgets/alert_dialog.ex`
- Tests: `test/term_ui/widgets/alert_dialog_test.exs` (22 tests passing)

### Files to Create
- Example: `examples/alert_dialog/` directory with mix project

### Alert Types and Buttons
| Type | Icon | Buttons |
|------|------|---------|
| info | ℹ | OK |
| success | ✓ | OK |
| warning | ⚠ | OK |
| error | ✗ | OK |
| confirm | ? | No, Yes |
| ok_cancel | ? | Cancel, OK |

## Implementation Plan

### 6.3.2.1 Alert types: info, warning, error, success, confirm
- [x] All alert types implemented with appropriate icons
- [x] Type stored in state for behavior customization

### 6.3.2.2 Standard button configurations: OK, OK/Cancel, Yes/No
- [x] @type_buttons map defines buttons per type
- [x] Buttons rendered with proper styling

### 6.3.2.3 Icon display for alert type
- [x] @type_icons map defines icons per type
- [x] Icon displayed alongside message

### 6.3.2.4 Default focus on appropriate button
- [x] Default button marked in configuration
- [x] Focus initialized to default button

### Create Example Application
- [x] Create `examples/alert_dialog/` mix project structure
- [x] Implement example demonstrating all alert types
- [x] Add README with usage instructions

## Success Criteria

- [x] Widget renders correctly with type-specific icons
- [x] All button configurations work
- [x] Default focus on correct button
- [x] Y/N shortcuts for confirm dialogs
- [x] All tests pass (22 tests)
- [x] Example application demonstrates usage

## Current Status

**Completed**: All tasks done. Widget, tests, and example are complete.
