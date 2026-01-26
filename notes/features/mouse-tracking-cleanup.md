# Feature: Terminal Mouse Tracking Cleanup Fix

## Status: Ready for Testing

### Current Status
- [x] Phase 1: Fix Immediate Cleanup Issues
- [x] Phase 2: Handle Edge Cases
- [ ] Phase 3: Testing

### What Works
- Added `@all_mouse_off` constant for comprehensive mouse disable
- `do_restore/1` now unconditionally disables all mouse modes
- `check_previous_crash/0` now includes mouse disable for crash recovery
- `Runtime.terminate/2` has defensive direct IO cleanup as backup

### What's Next
- Manual testing to verify the fix works

### How to Run
```bash
cd /home/ducky/code/term_ui/examples/text_input && mix run run.exs
# Exit via Q or Ctrl+C
# Move mouse - should NOT see escape sequences
```

---

## Problem Statement

**Observed Symptom:**
After TermUI applications exit, mouse movements cause strange characters to appear in the terminal. This manifests as escape sequence characters like `[M` followed by coordinates being echoed when the user moves their mouse.

**Root Cause:**
When mouse tracking mode is enabled in the terminal (using escape sequences like `\e[?1000h`, `\e[?1003h`, `\e[?1006h`), the terminal sends mouse event escape sequences back to the application. If the application exits without disabling mouse tracking (sending `\e[?1000l`, `\e[?1003l`, `\e[?1006l`), the terminal continues to send these escape sequences, which are then echoed as visible characters since there is no application consuming them.

---

## Current Implementation Analysis

### Mouse Tracking Enable (Runtime)
```elixir
defp setup_terminal_and_buffers do
  Terminal.enable_raw_mode()
  Terminal.enter_alternate_screen()
  Terminal.hide_cursor()
  Terminal.enable_mouse_tracking(:all)  # Enables mouse tracking
  ...
end
```

### Current Cleanup (Terminal)
```elixir
defp do_restore(state) do
  if not state.cursor_visible do
    write_to_terminal(@show_cursor)
  end

  if state.mouse_tracking != :off do
    disable_current_mouse_mode(state.mouse_tracking)
    write_to_terminal(@mouse_sgr_off)
  end
  # ... rest of cleanup
end
```

### Identified Issues

1. **Race Condition in Crash Scenarios:** The `check_previous_crash/0` function does NOT reset mouse tracking when recovering from a previous unclean termination.

2. **Kill Signal Handling:** When the process is killed with `Process.exit(pid, :kill)` (SIGKILL), `terminate/2` is NOT called, so cleanup never happens.

3. **State Dependency:** The cleanup relies on having valid state to know which mouse mode was enabled. In some exit scenarios, state may be corrupted or unavailable.

4. **Multiple Mouse Modes:** The `disable_current_mouse_mode/1` function only disables ONE mode (the one in state), but should disable ALL modes defensively.

5. **ETS State Not Tracking Mouse Mode:** The ETS table only tracks `raw_mode_active`, not `mouse_tracking`. This means crash recovery cannot know to disable mouse tracking.

---

## Implementation Plan

### Phase 1: Fix Immediate Cleanup Issues

#### Task 1.1: Add comprehensive mouse disable to cleanup
- [x] Modify `do_restore/1` to always disable ALL mouse modes regardless of state
- [x] Use comprehensive sequence: `\e[?1006l\e[?1003l\e[?1002l\e[?1000l`

#### Task 1.2: Fix crash recovery
- [x] Update `check_previous_crash/0` to also disable mouse tracking
- [x] Add all mouse disable sequences to crash recovery

#### Task 1.3: Add defensive cleanup to Runtime.terminate/2
- [x] Add explicit mouse tracking disable in terminate callback
- [x] Ensure cleanup happens even if Terminal GenServer is unavailable

### Phase 2: Handle Edge Cases

#### Task 2.1: Defensive write operations
- [x] Always write mouse disable sequences to terminal on any cleanup path
- [x] Do not depend on state being valid
- [x] Wrap in try/rescue to prevent cleanup failures from cascading

### Phase 3: Testing

#### Task 3.1: Manual testing
- [ ] Test normal shutdown disables mouse tracking
- [ ] Test shutdown via quit command
- [ ] Test Ctrl+C handling

---

## File Changes Required

### /home/ducky/code/term_ui/lib/term_ui/terminal.ex

1. Add comprehensive mouse disable sequence:
```elixir
@all_mouse_off "\e[?1006l\e[?1003l\e[?1002l\e[?1000l"
```

2. Update `do_restore/1` to unconditionally disable all mouse modes

3. Update `check_previous_crash/0` to include mouse disable

### /home/ducky/code/term_ui/lib/term_ui/runtime.ex

1. Update `terminate/2` to directly write cleanup sequences as backup

---

## Success Criteria

1. After normal application exit via quit command, mouse movements do not produce visible characters
2. After Ctrl+C interrupt, mouse movements do not produce visible characters
3. After application crash and restart, previous session's mouse tracking is disabled
4. All existing terminal tests continue to pass

---

## Manual Testing Protocol

```bash
# 1. Run example application
cd examples/text_input && mix run run.exs

# 2. Exit via Q or Ctrl+C

# 3. Move mouse - should NOT see escape sequences

# 4. If characters appear, the fix didn't work
```
