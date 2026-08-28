# AlertDialog Mouse Click Support - Feature Plan

## Overview

Add mouse click support for AlertDialog buttons in RAW MODE ONLY. The AlertDialog currently ignores all mouse events (lines 187-189 in `lib/term_ui/widgets/alert_dialog.ex`). This feature will enable users to click on dialog buttons to select them, providing the same result as pressing Enter on the focused button.

**Branch**: `feature/alert-dialog-mouse-support`
**Base Branch**: `develop`
**Date**: 2026-02-01

## Problem Statement

The AlertDialog widget explicitly ignores mouse events in its current implementation:

```elixir
# In lib/term_ui/widgets/alert_dialog.ex:187-189
%TermUI.Event.Mouse{} ->
  # Ignore mouse events
  {:ok, state}
```

The related Dialog widget has placeholder code for mouse clicks but `find_button_at_position` is not implemented:

```elixir
# In lib/term_ui/widgets/dialog.ex:134-147
def handle_event(%Event.Mouse{action: :click, x: x, y: y}, state) do
  case find_button_at_position(state, x, y) do
    nil -> {:ok, state}
    button_id -> ...
  end
end

# Line 218-220 - Not implemented
defp find_button_at_position(_state, _x, _y) do
  nil
end
```

### Current Behavior

- Mouse events are captured by the runtime via `Event.Mouse`
- AlertDialog receives mouse events but ignores them
- Users must use keyboard navigation (Tab/Enter/Arrow keys) to interact with dialogs

### Expected Behavior

- In RAW MODE: Users can click on dialog buttons to select them
- Clicking a button triggers the same result as pressing Enter on that button
- Visual feedback shows the clicked button as focused before activation
- In TTY MODE: Mouse events continue to be ignored (TTY mode does not support mouse events)

## Implementation Constraints

1. **Raw Mode Only** - Mouse events are only available in raw mode. TTY mode does not support mouse events, so this feature is raw mode exclusive.

2. **Backend Mode Detection** - Use `TermUI.PersistentTerms.backend_mode()` or `TermUI.Runtime.backend_mode()` to check if running in raw mode before handling mouse events.

3. **Backward Compatibility** - Maintain all existing keyboard navigation behavior.

4. **State Structure** - The AlertDialog needs to track button screen positions during render to detect clicks within button bounds.

## Technical Design

### Button Position Tracking

During `render/2`, the widget calculates:
- Dialog position: `pos_x = max(0, div(area.width - dialog_width, 2))`, `pos_y = max(0, div(area.height - dialog_height, 2))`
- Button positions relative to dialog (in `render_buttons/2`)

To enable click detection, we need to:
1. Store button bounds in state during render
2. Use those bounds to detect clicks in `handle_event`

### State Fields to Add

```elixir
# In init/1, add to state:
%{
  # ... existing fields ...
  button_bounds: %{}  # Maps button_id to {x, y, width, height} in screen coordinates
}
```

### Event Handling Flow

```
Mouse Click Event (x, y)
    |
    v
Check backend_mode == :raw
    |
    v
Lookup button at position (x, y)
    |
    v
If button found:
    1. Update focused_button to clicked button
    2. Trigger handle_result with button_id
    3. Set visible: false
```

## Implementation Plan

### Step 1: Add State Field for Button Bounds

Add `button_bounds` field to AlertDialog state structure.

**Location**: `lib/term_ui/widgets/alert_dialog.ex:113-133`

### Step 2: Implement `calculate_button_bounds/4`

Create a helper function to calculate screen bounds for each button.

### Step 3: Update `render/2` to Store Button Bounds

Modify the render function to calculate and store button bounds.

### Step 4: Implement `find_button_at_position/3`

Create a function to find which button (if any) was clicked.

### Step 5: Add Mouse Event Handler

Update `handle_event/2` to process mouse clicks in raw mode.

**Location**: `lib/term_ui/widgets/alert_dialog.ex:187-189` (replace the ignore clause)

### Step 6: Implement Click Detection Logic

### Step 7: Update Render to Store Bounds

Modify `render_buttons/4` to store button bounds during rendering.

## Test Plan

### Unit Tests

Add tests in `test/term_ui/widgets/alert_dialog_test.exs`:

1. Mouse click handler ignores events in TTY mode
2. Mouse click on button activates it in raw mode
3. Click outside button bounds does nothing
4. Multiple button click detection
5. Button focus updates on click

### Integration Testing

Use the existing example at `examples/alert_dialog`:

1. Run the alert dialog example in raw mode
2. Click each button with mouse
3. Verify correct result is returned
4. Verify keyboard navigation still works

## Critical Files for Implementation

- `/home/ducky/code/term_ui/lib/term_ui/widgets/alert_dialog.ex` - Main implementation file
- `/home/ducky/code/term_ui/lib/term_ui/widgets/dialog.ex` - Reference implementation
- `/home/ducky/code/term_ui/lib/term_ui/event.ex` - Event type definitions
- `/home/ducky/code/term_ui/lib/term_ui/persistent_terms.ex` - Backend mode detection
- `/home/ducky/code/term_ui/test/term_ui/widgets/alert_dialog_test.exs` - Test file

## Success Criteria

1. Mouse clicks on AlertDialog buttons work correctly in raw mode
2. Mouse events are ignored in TTY mode (verified via backend_mode check)
3. Clicking a button produces same result as pressing Enter on focused button
4. Visual feedback shows clicked button as focused (via focused_button update)
5. All existing keyboard navigation continues to work
6. Tests pass for new mouse click functionality
7. No regression in existing AlertDialog behavior

## Progress Tracking

- [ ] Create feature branch `feature/alert-dialog-mouse-support`
- [x] Write working plan in notes/feature directory
- [ ] Add button_bounds field to state structure
- [ ] Implement `calculate_button_bounds/4` helper function
- [ ] Implement `find_button_at_click/3` click detection
- [ ] Update `render_buttons/4` to store button bounds
- [ ] Update mouse event handler in `handle_event/2`
- [ ] Add backend mode check (raw only)
- [ ] Add unit tests for mouse click handling
- [ ] Test with alert_dialog example in raw mode
- [ ] Verify TTY mode ignores mouse events
- [ ] Document feature in AlertDialog @moduledoc
- [ ] Write summary in notes/summaries
- [ ] Ask for permission to commit and merge

## Status: IN IMPLEMENTATION

## Developer Decisions

1. **Button Bounds Calculation**: Calculate bounds on-demand using stored dialog dimensions and last render area. We'll store `last_area` in state during render.

2. **Dialog Widget**: Also implement mouse support in Dialog widget as part of this feature.

3. **Area Context**: Store `last_area` field in state during render, calculate button bounds on-demand in `handle_event`.

## Implementation Plan (Updated)

### Step 1: Add `last_area` Field to State

Add `last_area` field to both AlertDialog and Dialog state structures.

### Step 2: Update `render/2` to Store Last Area

Modify render functions to store the area in state.

### Step 3: Implement `calculate_button_bounds/3` for AlertDialog

Create a helper function to calculate button bounds using `last_area`.

### Step 4: Add Mouse Event Handler to AlertDialog

Update `handle_event/2` to process mouse clicks in raw mode.

### Step 5: Implement `calculate_button_bounds/3` for Dialog

Add button bounds calculation for Dialog widget.

### Step 6: Add Mouse Event Handler to Dialog

Update Dialog's mouse event handler (currently placeholder).

### Step 7: Add Unit Tests

Add tests for mouse click handling in both widgets.

## Progress Tracking

- [x] Create feature branch `feature/alert-dialog-mouse-support`
- [x] Write working plan in notes/feature directory
- [x] Add last_area field to AlertDialog state structure
- [x] Update AlertDialog render/2 to store last_area
- [x] Implement `calculate_button_bounds/3` for AlertDialog
- [x] Add mouse event handler to AlertDialog
- [x] Add last_area field to Dialog state structure
- [x] Update Dialog render/2 to store last_area
- [x] Implement `calculate_button_bounds/3` for Dialog
- [x] Add mouse event handler to Dialog
- [x] Add unit tests for mouse click handling
- [ ] Test with alert_dialog example in raw mode
- [ ] Test with dialog example in raw mode
- [x] Verify TTY mode ignores mouse events (via tests)
- [x] Document feature in @moduledoc
- [ ] Write summary in notes/summaries
- [ ] Ask for permission to commit and merge

## Implementation Summary

### Files Modified

1. **lib/term_ui/widgets/alert_dialog.ex**
   - Added `last_area: nil` to state structure in init/1
   - Updated render/2 to store last_area in state
   - Added `calculate_button_bounds/3` and `find_button_at_x/4` private functions
   - Replaced mouse event ignore handler with click detection that:
     - Checks `PersistentTerms.backend_mode() == :raw`
     - Calculates button positions on-demand using stored last_area
     - Activates clicked button
   - Updated @moduledoc with Mouse Support section

2. **lib/term_ui/widgets/dialog.ex**
   - Added `last_area: nil` to state structure in init/1
   - Updated render/2 to store last_area in state
   - Implemented `find_button_at_position/3` and `find_button_at_x/4` private functions
   - Updated mouse event handler to check backend_mode and call find_button_at_position
   - Updated @moduledoc with Mouse Support section

3. **test/term_ui/widgets/alert_dialog_test.exs**
   - Added `describe "mouse support"` block with 4 tests:
     - Mouse click activates button in raw mode
     - Mouse click is ignored in TTY mode
     - Click outside button bounds does nothing
     - Click on wrong row does nothing

### Technical Implementation Details

**Button Bounds Calculation:**
- Dialog position is calculated using the same logic as render/2
- Button row position within dialog: `4 + message_lines` (AlertDialog) or `4 + content_lines` (Dialog)
- Button texts are reconstructed matching render_buttons logic
- Button bounds are calculated on-demand during click detection

**Backend Mode Detection:**
- Uses `TermUI.PersistentTerms.backend_mode()` to check if running in raw mode
- Mouse events are only processed when backend_mode == :raw
- TTY mode ignores all mouse events

**State Management:**
- `last_area` field stores the most recent render area
- This enables accurate button bounds calculation in handle_event
- Area is updated at the start of render/2 before calculating dialog position
