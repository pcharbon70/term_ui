# Phase 7: Terminal Integration

## Overview

Phase 7 completes the connection between Terminal I/O and the Runtime, making TermUI applications fully interactive. While Phases 1-6 built all the core modules—Terminal management, rendering pipeline, component system, layout engine, and the Elm architecture runtime—the actual flow of user input from the terminal to components was left as placeholder code.

By the end of this phase, TermUI will be a complete, usable TUI framework. Users will be able to type keys, click with the mouse, resize their terminal, and see their TUI applications respond in real-time. The dashboard example will be fully interactive, demonstrating all capabilities.

This phase builds directly on the Runtime-Terminal integration work that connected the render output pipeline. Now we complete the circle by connecting the input pipeline, enabling the full event loop: Terminal → Events → Runtime → Update → View → Render → Terminal.

---

## 7.1 Keyboard Input Routing

- [ ] **Section 7.1 Complete**

Keyboard input is the primary interaction method for TUI applications. This section implements reading raw keyboard input from stdin, parsing escape sequences into structured events, and routing those events to the Runtime for dispatch to components.

The Terminal must read input in a non-blocking way to avoid stalling the render loop. Escape sequences for special keys (arrows, function keys, etc.) must be parsed according to standard terminal conventions. The resulting Event.Key structs are then sent to Runtime.send_event for processing through the Elm architecture loop.

### 7.1.1 Terminal Input Reader

- [ ] **Task 7.1.1 Complete**

Implement a process that continuously reads from stdin and emits parsed events. This reader must handle both simple character input and multi-byte escape sequences without blocking the main application.

- [ ] 7.1.1.1 Create `TermUI.Terminal.InputReader` GenServer that reads from stdin
- [ ] 7.1.1.2 Implement non-blocking read loop using `:io.get_chars` or port-based input
- [ ] 7.1.1.3 Buffer partial escape sequences until complete or timeout
- [ ] 7.1.1.4 Handle UTF-8 multi-byte character sequences correctly
- [ ] 7.1.1.5 Provide start_link/1 accepting target pid for event delivery

### 7.1.2 Escape Sequence Parsing

- [ ] **Task 7.1.2 Complete**

Parse raw input bytes into Event.Key structs. This includes recognizing CSI sequences (ESC[...), SS3 sequences (ESCO...), and single-byte control characters.

- [ ] 7.1.2.1 Parse arrow keys: ESC[A (up), ESC[B (down), ESC[C (right), ESC[D (left)
- [ ] 7.1.2.2 Parse function keys F1-F12 with various terminal encodings
- [ ] 7.1.2.3 Parse modifier combinations (Ctrl+key, Alt+key, Shift+key)
- [ ] 7.1.2.4 Parse special keys: Home, End, Insert, Delete, PageUp, PageDown
- [ ] 7.1.2.5 Handle ambiguous sequences with timeout-based disambiguation

### 7.1.3 Runtime Event Connection

- [ ] **Task 7.1.3 Complete**

Connect the InputReader to the Runtime so parsed events flow into the Elm architecture event loop. The Runtime must register with the InputReader to receive events.

- [ ] 7.1.3.1 Add input_reader field to Runtime.State
- [ ] 7.1.3.2 Start InputReader in Runtime.init with Runtime pid as target
- [ ] 7.1.3.3 Implement handle_info for keyboard events from InputReader
- [ ] 7.1.3.4 Route keyboard events through existing dispatch_event pipeline
- [ ] 7.1.3.5 Stop InputReader in Runtime.terminate for clean shutdown

### Unit Tests - Section 7.1

- [ ] **Unit Tests 7.1 Complete**
- [ ] Test InputReader starts and stops cleanly
- [ ] Test single character parsing (a-z, 0-9, symbols)
- [ ] Test arrow key escape sequence parsing
- [ ] Test function key parsing for common terminal types
- [ ] Test Ctrl+key modifier detection
- [ ] Test Alt+key modifier detection
- [ ] Test keyboard event flows through to component update
- [ ] Test partial escape sequence buffering and timeout

---

## 7.2 Mouse Input Routing

- [ ] **Section 7.2 Complete**

Mouse support enables clicking, dragging, and scrolling in TUI applications. This section implements enabling mouse tracking mode, parsing mouse escape sequences, and routing mouse events to the Runtime for spatial dispatch to components.

Modern terminals support SGR mouse encoding which provides accurate coordinates and button state. The Runtime's existing spatial index (from Phase 3) will be used to determine which component receives mouse events based on click position.

### 7.2.1 Mouse Mode Activation

- [ ] **Task 7.2.1 Complete**

Enable and disable mouse tracking modes via Terminal escape sequences. Support multiple modes for different use cases (click only, drag tracking, all motion).

- [ ] 7.2.1.1 Implement enable_mouse_tracking/1 with mode parameter (:click, :drag, :all)
- [ ] 7.2.1.2 Send ESC[?1000h for basic click tracking
- [ ] 7.2.1.3 Send ESC[?1002h for button event tracking (drag)
- [ ] 7.2.1.4 Send ESC[?1003h for all motion tracking
- [ ] 7.2.1.5 Send ESC[?1006h to enable SGR extended coordinates
- [ ] 7.2.1.6 Implement disable_mouse_tracking/0 to restore normal mode

### 7.2.2 Mouse Event Parsing

- [ ] **Task 7.2.2 Complete**

Parse SGR mouse escape sequences into Event.Mouse structs with button, position, and modifier information.

- [ ] 7.2.2.1 Parse SGR format: ESC[<button;x;y;M (press) and ESC[<button;x;y;m (release)
- [ ] 7.2.2.2 Decode button field (0=left, 1=middle, 2=right, 64/65=scroll)
- [ ] 7.2.2.3 Extract modifier flags from button field (Shift, Alt, Ctrl)
- [ ] 7.2.2.4 Convert 1-indexed terminal coordinates to 0-indexed internal coordinates
- [ ] 7.2.2.5 Determine event type: click, release, drag, scroll

### 7.2.3 Runtime Mouse Dispatch

- [ ] **Task 7.2.3 Complete**

Route mouse events to the Runtime and dispatch to appropriate components based on position. Use the spatial index to find the component under the cursor.

- [ ] 7.2.3.1 Add mouse event handling to InputReader parsing
- [ ] 7.2.3.2 Route mouse events through Runtime.send_event
- [ ] 7.2.3.3 Use existing dispatch_event for Event.Mouse routing
- [ ] 7.2.3.4 Enable mouse tracking in Runtime.init when terminal available
- [ ] 7.2.3.5 Disable mouse tracking in Runtime.terminate

### Unit Tests - Section 7.2

- [ ] **Unit Tests 7.2 Complete**
- [ ] Test mouse mode enable/disable sequences
- [ ] Test SGR mouse press event parsing
- [ ] Test SGR mouse release event parsing
- [ ] Test mouse drag event parsing
- [ ] Test scroll wheel event parsing
- [ ] Test modifier key detection in mouse events
- [ ] Test coordinate conversion from terminal to internal
- [ ] Test mouse event dispatch to correct component

---

## 7.3 Terminal Resize Handling

- [ ] **Section 7.3 Complete**

When users resize their terminal window, the TUI must adapt to the new dimensions. This section implements detecting resize signals, updating the buffer dimensions, and triggering a full re-render to fill the new space.

Resize handling is critical for a good user experience. Without it, the display becomes corrupted or truncated when the terminal size changes. Proper handling ensures the application always fills the available space correctly.

### 7.3.1 Resize Signal Detection

- [ ] **Task 7.3.1 Complete**

Detect terminal resize events via SIGWINCH signal or polling. The Terminal GenServer must notify registered processes when the size changes.

- [ ] 7.3.1.1 Handle SIGWINCH in Terminal GenServer (already partially implemented)
- [ ] 7.3.1.2 Query new terminal size after signal received
- [ ] 7.3.1.3 Notify registered callbacks with new dimensions
- [ ] 7.3.1.4 Register Runtime with Terminal for resize notifications in init
- [ ] 7.3.1.5 Unregister Runtime in terminate

### 7.3.2 Buffer Recreation

- [ ] **Task 7.3.2 Complete**

When dimensions change, the BufferManager's buffers must be resized to match. This involves creating new ETS tables with the new dimensions and migrating any relevant state.

- [ ] 7.3.2.1 Add handle_info for {:terminal_resize, {rows, cols}} in Runtime
- [ ] 7.3.2.2 Call BufferManager.resize/3 with new dimensions
- [ ] 7.3.2.3 Update Runtime.State.dimensions with new size
- [ ] 7.3.2.4 Clear both buffers to force full redraw
- [ ] 7.3.2.5 Handle resize during render (defer until render complete)

### 7.3.3 Re-render Trigger

- [ ] **Task 7.3.3 Complete**

After resize, trigger a full re-render of the entire screen. Components may need to recalculate layouts based on new available space.

- [ ] 7.3.3.1 Mark state as dirty after resize
- [ ] 7.3.3.2 Broadcast Event.Resize to all components
- [ ] 7.3.3.3 Components receive new dimensions for layout calculation
- [ ] 7.3.3.4 Force immediate render rather than waiting for next tick
- [ ] 7.3.3.5 Clear screen before re-render to avoid artifacts

### Unit Tests - Section 7.3

- [ ] **Unit Tests 7.3 Complete**
- [ ] Test Runtime registers for resize callbacks
- [ ] Test resize event updates Runtime dimensions
- [ ] Test BufferManager.resize creates correctly sized buffers
- [ ] Test resize triggers dirty flag
- [ ] Test resize broadcasts Event.Resize to components
- [ ] Test rapid resize events are handled correctly
- [ ] Test resize during render is deferred

---

## 7.4 Raw Mode Improvements

- [ ] **Section 7.4 Complete**

Raw mode is essential for TUI applications—it disables line buffering and echo so applications receive each keystroke immediately. This section improves the OTP 28 raw mode implementation and provides fallbacks for compatibility.

Currently, raw mode via `shell.start_interactive({:noshell, :raw})` may not fully suppress echo on all systems. This section ensures consistent raw mode behavior across different terminals and OTP versions.

### 7.4.1 OTP 28 Raw Mode Verification

- [ ] **Task 7.4.1 Complete**

Verify and fix the OTP 28 raw mode implementation. Ensure shell.start_interactive properly configures the terminal for TUI operation.

- [ ] 7.4.1.1 Test shell.start_interactive on different terminal types
- [ ] 7.4.1.2 Verify echo is disabled after raw mode activation
- [ ] 7.4.1.3 Verify canonical mode is disabled (char-at-a-time input)
- [ ] 7.4.1.4 Document any terminal-specific quirks discovered
- [ ] 7.4.1.5 Add additional stty configuration if needed for full raw mode

### 7.4.2 Fallback Implementation

- [ ] **Task 7.4.2 Complete**

Provide a fallback raw mode implementation for systems without OTP 28 or where shell.start_interactive doesn't work correctly.

- [ ] 7.4.2.1 Implement raw mode via stty system command as fallback
- [ ] 7.4.2.2 Save original terminal settings before modification
- [ ] 7.4.2.3 Apply raw mode settings: -echo -icanon min 1 time 0
- [ ] 7.4.2.4 Restore original settings on exit
- [ ] 7.4.2.5 Detect which method to use based on OTP version and platform

### 7.4.3 Echo Suppression

- [ ] **Task 7.4.3 Complete**

Ensure keystrokes are not echoed to the terminal while the TUI is running. Any echo corrupts the display.

- [ ] 7.4.3.1 Verify -echo is applied in all raw mode paths
- [ ] 7.4.3.2 Test that arrow keys don't show ^[[A etc
- [ ] 7.4.3.3 Test that typed characters don't appear twice
- [ ] 7.4.3.4 Add explicit echo disable if shell.start_interactive misses it
- [ ] 7.4.3.5 Document terminal compatibility findings

### Unit Tests - Section 7.4

- [ ] **Unit Tests 7.4 Complete**
- [ ] Test raw mode enables without error
- [ ] Test input is received without echo
- [ ] Test raw mode disables cleanly
- [ ] Test fallback mode works on supported systems
- [ ] Test original settings restored after exit
- [ ] Test raw mode survives terminal type detection

---

## 7.5 Graceful Shutdown

- [ ] **Section 7.5 Complete**

When a TUI application exits, the terminal must be restored to its original state. This section ensures clean shutdown regardless of how the application terminates—normal exit, quit command, or crash.

Users must be able to return to their shell with a working terminal. Failure to restore means no cursor, wrong screen buffer, or unusable input. The shutdown sequence must be reliable even in error conditions.

### 7.5.1 Quit Command Handling

- [ ] **Task 7.5.1 Complete**

Handle the :quit command from components to initiate graceful shutdown. This is the normal way for applications to exit.

- [ ] 7.5.1.1 Detect :quit in command processing (already implemented)
- [ ] 7.5.1.2 Call initiate_shutdown which sets shutting_down flag
- [ ] 7.5.1.3 Wait for pending commands to complete
- [ ] 7.5.1.4 Stop the Runtime GenServer after cleanup
- [ ] 7.5.1.5 Return appropriate exit code to caller

### 7.5.2 Terminal State Restoration

- [ ] **Task 7.5.2 Complete**

Restore all terminal modifications in the correct sequence. This must happen in terminate callback to catch all exit paths.

- [ ] 7.5.2.1 Show cursor (ESC[?25h) if hidden
- [ ] 7.5.2.2 Leave alternate screen (ESC[?1049l) if entered
- [ ] 7.5.2.3 Disable mouse tracking if enabled
- [ ] 7.5.2.4 Disable raw mode and restore original settings
- [ ] 7.5.2.5 Reset terminal attributes (ESC[0m)
- [ ] 7.5.2.6 Ensure restoration happens even on crash (trap_exit)

### 7.5.3 Process Cleanup

- [ ] **Task 7.5.3 Complete**

Stop all processes started by the Runtime in the correct order. This includes Terminal, BufferManager, InputReader, and any component processes.

- [ ] 7.5.3.1 Stop InputReader first to stop receiving events
- [ ] 7.5.3.2 Stop any component GenServers (future feature)
- [ ] 7.5.3.3 Allow BufferManager to clean up ETS tables
- [ ] 7.5.3.4 Stop Terminal last after restoration
- [ ] 7.5.3.5 Handle crashes in cleanup gracefully (continue with remaining cleanup)

### Unit Tests - Section 7.5

- [ ] **Unit Tests 7.5 Complete**
- [ ] Test quit command triggers shutdown
- [ ] Test terminal cursor restored after exit
- [ ] Test alternate screen exited after exit
- [ ] Test raw mode disabled after exit
- [ ] Test mouse tracking disabled after exit
- [ ] Test cleanup completes even on crash
- [ ] Test all processes stopped after shutdown

---

## 7.6 Integration Tests

- [ ] **Section 7.6 Complete**

Integration tests verify the complete input/output cycle works correctly. These tests exercise the full path from terminal input through event dispatch, state update, view rendering, and terminal output.

The dashboard example serves as a comprehensive integration test, exercising keyboard navigation, theme switching, and display rendering. Additional focused tests verify specific integration points.

### 7.6.1 End-to-End Event Tests

- [ ] **Task 7.6.1 Complete**

Test complete event cycles from input to display update.

- [ ] 7.6.1.1 Test key press updates component state and display
- [ ] 7.6.1.2 Test mouse click dispatches to correct component
- [ ] 7.6.1.3 Test resize updates layout and re-renders
- [ ] 7.6.1.4 Test quit command exits cleanly with terminal restored
- [ ] 7.6.1.5 Test multiple rapid events are processed correctly

### 7.6.2 Dashboard Integration Tests

- [ ] **Task 7.6.2 Complete**

Use the dashboard example as a comprehensive integration test case.

- [ ] 7.6.2.1 Test dashboard starts and renders initial display
- [ ] 7.6.2.2 Test 'q' key quits the dashboard
- [ ] 7.6.2.3 Test 't' key toggles theme and re-renders
- [ ] 7.6.2.4 Test arrow keys navigate process list
- [ ] 7.6.2.5 Test dashboard handles resize correctly
- [ ] 7.6.2.6 Verify no terminal corruption after exit

### 7.6.3 Multi-Component Tests

- [ ] **Task 7.6.3 Complete**

Test event flow in applications with multiple interactive components.

- [ ] 7.6.3.1 Test focus changes route keyboard to new component
- [ ] 7.6.3.2 Test mouse click on unfocused component gives focus
- [ ] 7.6.3.3 Test broadcast events reach all components
- [ ] 7.6.3.4 Test parent-child message passing works correctly
- [ ] 7.6.3.5 Test command results return to correct component

### Unit Tests - Section 7.6

- [ ] **Unit Tests 7.6 Complete**
- [ ] All 7.6.1 tests passing
- [ ] All 7.6.2 tests passing
- [ ] All 7.6.3 tests passing
- [ ] Test suite runs without terminal corruption
- [ ] Test isolation (each test cleans up properly)

---

## Success Criteria

1. **Keyboard Input Works**: Press keys in dashboard and see responses (q quits, t toggles theme, arrows navigate)
2. **Mouse Input Works**: Click on components and see appropriate responses
3. **Resize Works**: Resize terminal window and display adapts correctly
4. **Raw Mode Works**: No key echo, immediate character reception
5. **Clean Shutdown**: Exit always restores terminal to usable state
6. **No Regressions**: All existing tests continue to pass
7. **Dashboard Fully Interactive**: Complete demonstration of all features
8. **Cross-Terminal Compatibility**: Works on common terminals (iTerm2, Terminal.app, GNOME Terminal, etc.)

## Provides Foundation

This phase completes TermUI as a usable framework for:
- **Application Development**: Developers can now build interactive TUI applications
- **Phase 8 (future)**: Advanced features like clipboard, notifications, custom widgets
- **Production Use**: Framework is complete enough for real applications

## Key Outputs

- `lib/term_ui/terminal/input_reader.ex` - Input reading GenServer
- Updated `lib/term_ui/terminal.ex` - Mouse mode, improved raw mode
- Updated `lib/term_ui/runtime.ex` - Input event handling, resize handling
- `lib/term_ui/terminal/escape_parser.ex` - Input escape sequence parsing
- `test/term_ui/integration/` - Integration test suite
- Updated `examples/dashboard/` - Fully interactive example
- `notes/features/7.1-*.md` through `7.6-*.md` - Detailed feature plans
