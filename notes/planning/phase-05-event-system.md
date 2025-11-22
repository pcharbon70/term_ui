# Phase 5: Event System and Advanced Interactions

## Overview

This phase implements the message-driven event system based on The Elm Architecture, adapted for OTP patterns. We create a unified approach where all state changes flow through explicit messages, side effects are managed through commands, and the UI is always a pure function of state. Additionally, we implement advanced interaction features: comprehensive mouse support, keyboard shortcut registry, clipboard integration, and terminal focus event handling.

By the end of this phase, we will have a complete event system with typed events and messages, a runtime that orchestrates component updates and command execution, the command pattern for managing side effects without blocking the UI, SGR Extended mouse tracking with proper coordinate handling, a keyboard shortcut registry supporting global and scoped bindings, clipboard operations through bracketed paste and OSC 52, and focus event handling for optimization opportunities.

This phase unifies the component system from Phase 3 with a formal event architecture. While Phase 3 established basic event routing, this phase adds the Command pattern for side effects, formal message types, and a central runtime for coordination. The advanced interactions build on Phase 1's terminal foundation and Phase 4's spatial layout for comprehensive user input handling.

---

## 5.1 Message-Driven Architecture

- [x] **Section 5.1 Complete**

The message-driven architecture implements The Elm Architecture for OTP. Every state change results from handling a message. Components define their message types, and the runtime delivers messages and collects updates. This creates predictable, debuggable state flow—you can trace any state change back to the message that caused it.

The architecture distinguishes between events (input from outside—key presses, mouse clicks), messages (domain-specific meanings—Increment, Submit, SelectItem), and commands (side effects to perform—HTTP requests, file reads). Events become messages through component logic; messages update state; commands run asynchronously and generate messages on completion.

### 5.1.1 Event Types

- [x] **Task 5.1.1 Complete**

Event types represent all possible input from the terminal and system. We define typed structs for each event category using the parsing results from Phase 1. Events are the external interface—they arrive from outside the application and trigger component updates.

- [x] 5.1.1.1 Define `%TermUI.Event.Key{key: atom | char, modifiers: [atom]}` for keyboard input
- [x] 5.1.1.2 Define `%TermUI.Event.Mouse{action: atom, button: atom, x: integer, y: integer, modifiers: [atom]}` for mouse input
- [x] 5.1.1.3 Define `%TermUI.Event.Resize{width: integer, height: integer}` for terminal resize
- [x] 5.1.1.4 Define `%TermUI.Event.Focus{type: :gained | :lost}` for terminal focus changes
- [x] 5.1.1.5 Define `%TermUI.Event.Paste{content: String.t()}` for clipboard paste
- [x] 5.1.1.6 Define `%TermUI.Event.Tick{interval: integer}` for timer events

### 5.1.2 Message Types

- [x] **Task 5.1.2 Complete**

Messages are component-specific types representing meaningful actions. Components define their own message types as structs or atoms. Messages carry semantic meaning—`{:select_item, 3}` is clearer than the raw key event that triggered it. The runtime routes messages to the component that should handle them.

- [x] 5.1.2.1 Define message type specification for component behaviours
- [x] 5.1.2.2 Implement message struct convention: `%MyComponent.Msg.SelectItem{index: 3}`
- [x] 5.1.2.3 Implement atom message support for simple messages: `:increment`, `:decrement`
- [x] 5.1.2.4 Implement message routing from events to messages via `event_to_msg/2` callback

### 5.1.3 Update Function

- [x] **Task 5.1.3 Complete**

The update function is the core of component logic. It receives the current state and a message, and returns new state plus optional commands. Update functions must be pure—no side effects, no external calls. This makes components testable and predictable.

- [x] 5.1.3.1 Define `update(msg, state) :: {new_state, [command]}` callback signature
- [x] 5.1.3.2 Implement state-only return shorthand: `{new_state, []}`
- [x] 5.1.3.3 Implement unchanged state return: `:noreply` keeps state unchanged
- [x] 5.1.3.4 Implement update validation ensuring pure function (no side effects)

### 5.1.4 View Function

- [x] **Task 5.1.4 Complete**

The view function renders current state to a render tree. Like update, it must be pure—given the same state, it always produces the same output. View functions should be fast since they run every frame. They use the render tree builders from Phase 3.

- [x] 5.1.4.1 Define `view(state) :: render_tree()` callback signature
- [x] 5.1.4.2 Implement render tree types: nodes, text, styled spans
- [x] 5.1.4.3 Implement view memoization caching result when state unchanged
- [x] 5.1.4.4 Implement view performance warning for slow view functions

### 5.1.5 Message Batching

- [x] **Task 5.1.5 Complete**

Multiple messages may arrive between renders. We batch messages, applying all updates before rendering once. This prevents redundant renders when multiple events arrive quickly. The batch preserves message order for deterministic updates.

- [x] 5.1.5.1 Implement message queue for incoming messages
- [x] 5.1.5.2 Implement batch processing applying all queued messages sequentially
- [x] 5.1.5.3 Implement single render after batch processing
- [x] 5.1.5.4 Implement batch size limits to prevent unbounded accumulation

### Unit Tests - Section 5.1

- [x] **Unit Tests 5.1 Complete**
- [x] Test event types contain correct fields
- [x] Test message routing delivers to correct component
- [x] Test update function produces new state from message
- [x] Test update commands are collected for execution
- [x] Test view function produces render tree from state
- [x] Test view memoization skips render for unchanged state
- [x] Test message batching applies all messages before render

---

## 5.2 Runtime Orchestration

- [ ] **Section 5.2 Complete**

The runtime orchestrates the entire application: receiving events, routing to components, collecting updates, executing commands, and triggering renders. It's the central coordinator that implements The Elm Architecture dispatch loop. The runtime is a GenServer maintaining the component tree and coordinating all activity.

The runtime loop: receive event → route to component → call update → collect commands → execute commands → mark dirty → (on timer) call view → render. This loop runs continuously, processing events as they arrive and rendering at the framerate limit from Phase 2.

### 5.2.1 Runtime GenServer

- [ ] **Task 5.2.1 Complete**

The runtime GenServer is the main application process. It maintains state including the component tree, focus state, and command supervisor. It receives terminal events and coordinates the update cycle.

- [ ] 5.2.1.1 Implement `TermUI.Runtime` GenServer with application state
- [ ] 5.2.1.2 Implement `init/1` building initial component tree from root module
- [ ] 5.2.1.3 Implement `handle_info/2` for terminal events processing them through the loop
- [ ] 5.2.1.4 Implement `handle_cast/2` for command results feeding back as messages

### 5.2.2 Event Dispatch

- [ ] **Task 5.2.2 Complete**

Event dispatch routes terminal events to appropriate components and transforms them to messages. Keyboard events go to focused component. Mouse events go to component at position. Resize and focus events broadcast to all components.

- [ ] 5.2.2.1 Implement keyboard event dispatch to focused component
- [ ] 5.2.2.2 Implement mouse event dispatch using spatial index from Phase 3
- [ ] 5.2.2.3 Implement broadcast dispatch for global events (resize, focus)
- [ ] 5.2.2.4 Implement event transformation calling component's event_to_msg

### 5.2.3 Update Cycle

- [ ] **Task 5.2.3 Complete**

The update cycle processes messages through component update functions and collects new state and commands. It traverses affected components, applies updates, and accumulates commands for execution.

- [ ] 5.2.3.1 Implement message dispatch to component update function
- [ ] 5.2.3.2 Implement state update in component process
- [ ] 5.2.3.3 Implement command collection from update results
- [ ] 5.2.3.4 Implement update propagation for parent-child message passing

### 5.2.4 Render Trigger

- [ ] **Task 5.2.4 Complete**

Render trigger marks the buffer dirty when state changes and coordinates with the framerate limiter from Phase 2. It calls view functions, processes render trees, and updates the buffer.

- [ ] 5.2.4.1 Implement dirty marking when component state changes
- [ ] 5.2.4.2 Implement view call collecting render tree from component
- [ ] 5.2.4.3 Implement render tree processing writing cells to buffer
- [ ] 5.2.4.4 Integrate with framerate limiter for controlled rendering

### 5.2.5 Shutdown Coordination

- [ ] **Task 5.2.5 Complete**

Shutdown coordination ensures clean application exit. It terminates components in order, completes pending commands, restores terminal state, and exits. Shutdown may be triggered by quit command, user signal, or error.

- [ ] 5.2.5.1 Implement shutdown trigger from quit message or signal
- [ ] 5.2.5.2 Implement graceful command completion waiting for pending commands
- [ ] 5.2.5.3 Implement component tree shutdown in leaf-to-root order
- [ ] 5.2.5.4 Implement terminal restoration ensuring clean exit

### Unit Tests - Section 5.2

- [ ] **Unit Tests 5.2 Complete**
- [ ] Test runtime initializes with component tree
- [ ] Test event dispatch routes to correct component
- [ ] Test update cycle produces new state
- [ ] Test commands collected from update results
- [ ] Test render trigger marks buffer dirty
- [ ] Test view produces correct render tree
- [ ] Test shutdown terminates cleanly

---

## 5.3 Command System

- [ ] **Section 5.3 Complete**

The command system manages side effects without blocking the UI. Commands are values describing effects to perform—they don't execute immediately. The runtime executes commands asynchronously, sending result messages back to components. This keeps update functions pure while enabling real-world interaction.

Commands include: HTTP requests, file operations, timers, process spawning, and clipboard access. Commands execute under a Task.Supervisor for fault isolation. Each command specifies the result message to send on completion, closing the loop back to the update function.

### 5.3.1 Command Structure

- [ ] **Task 5.3.1 Complete**

Commands are structs describing the effect and its result handler. They're data, not functions—this makes them serializable, inspectable, and testable. The runtime interprets commands and performs the actual effects.

- [ ] 5.3.1.1 Define `%Command{type: atom, payload: any, on_result: msg_type}` struct
- [ ] 5.3.1.2 Define command types: `:http`, `:file_read`, `:file_write`, `:timer`, `:clipboard`
- [ ] 5.3.1.3 Implement command builder functions: `Command.http_get(url, on_result)`
- [ ] 5.3.1.4 Implement command validation ensuring valid type and payload

### 5.3.2 Command Executor

- [ ] **Task 5.3.2 Complete**

The command executor runs commands asynchronously and delivers results. It uses Task.Supervisor for fault isolation—failing commands don't crash the runtime. Results are sent as messages to the originating component.

- [ ] 5.3.2.1 Implement Task.Supervisor for command execution
- [ ] 5.3.2.2 Implement `execute_command/2` starting async task for command
- [ ] 5.3.2.3 Implement result delivery sending message to component
- [ ] 5.3.2.4 Implement error handling converting failures to error messages

### 5.3.3 Built-in Commands

- [ ] **Task 5.3.3 Complete**

Built-in commands provide common effects without custom implementation. They cover typical needs: HTTP, files, timers, and clipboard. These commands demonstrate the pattern and provide immediate utility.

- [ ] 5.3.3.1 Implement timer command scheduling message after delay
- [ ] 5.3.3.2 Implement interval command scheduling repeated messages
- [ ] 5.3.3.3 Implement file_read command reading file and sending content
- [ ] 5.3.3.4 Implement clipboard_read command fetching clipboard contents (where supported)

### 5.3.4 Command Cancellation

- [ ] **Task 5.3.4 Complete**

Long-running commands may need cancellation—when navigating away or on timeout. We implement cancellation by tracking command tasks and allowing explicit cancel. Cancelled commands don't send result messages.

- [ ] 5.3.4.1 Implement command ID tracking for cancel reference
- [ ] 5.3.4.2 Implement `cancel_command/1` terminating running command task
- [ ] 5.3.4.3 Implement automatic cancellation on component unmount
- [ ] 5.3.4.4 Implement timeout cancellation for commands exceeding duration

### 5.3.5 Command Batching

- [ ] **Task 5.3.5 Complete**

Multiple commands from one update execute concurrently. We batch commands and execute in parallel where possible. Dependencies between commands require explicit sequencing using command chaining.

- [ ] 5.3.5.1 Implement concurrent execution for independent commands
- [ ] 5.3.5.2 Implement command chaining for sequential execution
- [ ] 5.3.5.3 Implement batch result aggregation collecting all results
- [ ] 5.3.5.4 Implement max concurrent limit preventing resource exhaustion

### Unit Tests - Section 5.3

- [ ] **Unit Tests 5.3 Complete**
- [ ] Test command structure contains required fields
- [ ] Test command execution runs async task
- [ ] Test result delivery sends message to component
- [ ] Test error handling converts failure to error message
- [ ] Test timer command delivers message after delay
- [ ] Test command cancellation prevents result delivery
- [ ] Test batch execution runs commands concurrently

---

## 5.4 Mouse Support

- [ ] **Section 5.4 Complete**

Mouse support enables point-and-click interaction in TUI applications. We implement full mouse tracking: press, release, motion, and scroll wheel. Mouse events route to components based on position using the spatial index from Phase 3. We use SGR Extended mode for accurate coordinates and press/release distinction.

Mouse interaction enhances usability—clicking buttons, dragging sliders, selecting list items—without replacing keyboard navigation. We support both interaction modes and ensure all functions remain accessible via keyboard for accessibility.

### 5.4.1 Mouse Mode Activation

- [ ] **Task 5.4.1 Complete**

Mouse tracking activates by sending escape sequences to the terminal. We support multiple tracking modes for different needs. SGR Extended mode is preferred for its decimal encoding and coordinate accuracy.

- [ ] 5.4.1.1 Implement `enable_mouse/0` activating normal tracking mode (1000)
- [ ] 5.4.1.2 Implement `enable_mouse_motion/0` activating all-motion mode (1003)
- [ ] 5.4.1.3 Implement SGR Extended mode activation (1006) for better coordinate handling
- [ ] 5.4.1.4 Implement `disable_mouse/0` deactivating tracking on cleanup

### 5.4.2 Mouse Event Routing

- [ ] **Task 5.4.2 Complete**

Mouse events route to components based on click position. The spatial index (from Phase 3) maps coordinates to components. For overlapping components, the topmost receives the event first with bubbling to parents.

- [ ] 5.4.2.1 Implement position-based routing using spatial index lookup
- [ ] 5.4.2.2 Implement z-order handling routing to topmost component
- [ ] 5.4.2.3 Implement coordinate transformation to component-local coordinates
- [ ] 5.4.2.4 Implement mouse event bubbling from target to ancestors

### 5.4.3 Drag and Drop

- [ ] **Task 5.4.3 Complete**

Drag and drop tracks mouse motion while button is held. We implement drag state management: start (press), move (motion with button), end (release). Components opt-in to drag handling and receive drag events.

- [ ] 5.4.3.1 Implement drag state tracking button press and position
- [ ] 5.4.3.2 Implement drag start event when motion begins after press
- [ ] 5.4.3.3 Implement drag move events during motion with button held
- [ ] 5.4.3.4 Implement drag end event on button release

### 5.4.4 Scroll Wheel

- [ ] **Task 5.4.4 Complete**

Scroll wheel events enable natural scrolling for lists, viewports, and text areas. We detect wheel events (buttons 4/5 in mouse protocol) and route to the component under cursor for scrolling.

- [ ] 5.4.4.1 Implement scroll wheel event detection from mouse protocol
- [ ] 5.4.4.2 Implement scroll event routing to component at cursor position
- [ ] 5.4.4.3 Implement scroll amount calculation (lines per wheel tick)
- [ ] 5.4.4.4 Integrate scroll events with scrollable components (List, Viewport)

### 5.4.5 Mouse Cursors

- [ ] **Task 5.4.5 Complete**

Mouse cursor feedback indicates interactive elements. We can't change the cursor shape in most terminals, but we can change the cursor text or component appearance on hover. This provides visual feedback for clickable elements.

- [ ] 5.4.5.1 Implement hover detection for mouse enter/leave events
- [ ] 5.4.5.2 Implement hover state in components for visual feedback
- [ ] 5.4.5.3 Implement cursor text update for terminals supporting it
- [ ] 5.4.5.4 Document cursor feedback patterns for widgets

### Unit Tests - Section 5.4

- [ ] **Unit Tests 5.4 Complete**
- [ ] Test mouse mode activation sends correct escape sequences
- [ ] Test mouse event routing finds correct component for coordinates
- [ ] Test coordinate transformation produces local coordinates
- [ ] Test drag tracking maintains state through press-move-release
- [ ] Test scroll wheel events route to component under cursor
- [ ] Test hover detection fires enter/leave events

---

## 5.5 Keyboard Shortcuts

- [ ] **Section 5.5 Complete**

Keyboard shortcuts provide quick access to actions without navigating UI. We implement a registry mapping key combinations to actions. Shortcuts can be global (always active) or scoped (active in specific contexts). The registry handles conflicts and provides discoverability.

Shortcuts follow platform conventions where possible (Ctrl+Q quit, Ctrl+S save). We support modifier combinations (Ctrl+Shift+S), key sequences (gg for vim-style), and context-sensitive shortcuts (different in edit vs normal mode).

### 5.5.1 Shortcut Registry

- [ ] **Task 5.5.1 Complete**

The shortcut registry stores all defined shortcuts and matches incoming key events. It supports priority levels for conflict resolution and scoping for context-sensitive shortcuts.

- [ ] 5.5.1.1 Implement registry ETS table storing shortcuts
- [ ] 5.5.1.2 Implement `register_shortcut/3` adding shortcut with action
- [ ] 5.5.1.3 Implement `lookup_shortcut/2` finding action for key event
- [ ] 5.5.1.4 Implement priority-based conflict resolution

### 5.5.2 Key Combination Matching

- [ ] **Task 5.5.2 Complete**

Key combination matching handles modifiers and sequences. Modifiers (Ctrl, Alt, Shift) combine with base keys. Sequences (multiple keys in order) enable vim-style bindings. Matching must be fast since it runs for every key event.

- [ ] 5.5.2.1 Implement modifier matching checking all required modifiers present
- [ ] 5.5.2.2 Implement sequence matching tracking partial sequences
- [ ] 5.5.2.3 Implement sequence timeout canceling partial sequence
- [ ] 5.5.2.4 Implement wildcard matching for any-key bindings

### 5.5.3 Scoped Shortcuts

- [ ] **Task 5.5.3 Complete**

Scoped shortcuts activate only in specific contexts. Scopes include: global (always), focused component, mode (edit/normal), and custom application scopes. Scoping prevents conflicts between different parts of the application.

- [ ] 5.5.3.1 Implement scope tracking in registry entries
- [ ] 5.5.3.2 Implement scope checking during shortcut lookup
- [ ] 5.5.3.3 Implement component scope for focused component shortcuts
- [ ] 5.5.3.4 Implement mode scope for application state-dependent shortcuts

### 5.5.4 Shortcut Actions

- [ ] **Task 5.5.4 Complete**

Shortcut actions are functions or messages executed when shortcuts trigger. Actions may send messages to components, execute commands, or change application state. We support both inline functions and message-based actions.

- [ ] 5.5.4.1 Implement function actions: `fn -> ... end` for inline logic
- [ ] 5.5.4.2 Implement message actions: `{component_id, message}` for component updates
- [ ] 5.5.4.3 Implement command actions: `command` for side effects
- [ ] 5.5.4.4 Implement action result handling for success/failure

### 5.5.5 Shortcut Discoverability

- [ ] **Task 5.5.5 Complete**

Users need to discover available shortcuts. We provide introspection for listing shortcuts and integration with help displays. This improves usability and learning.

- [ ] 5.5.5.1 Implement `list_shortcuts/0` returning all registered shortcuts
- [ ] 5.5.5.2 Implement `shortcuts_for_scope/1` filtering by scope
- [ ] 5.5.5.3 Implement shortcut formatting for display (Ctrl+Q, ⌘S)
- [ ] 5.5.5.4 Implement help text association with shortcuts

### Unit Tests - Section 5.5

- [ ] **Unit Tests 5.5 Complete**
- [ ] Test shortcut registration stores correctly
- [ ] Test shortcut lookup finds registered action
- [ ] Test modifier matching requires all modifiers
- [ ] Test sequence matching tracks multiple keys
- [ ] Test scope checking filters shortcuts correctly
- [ ] Test action execution runs on shortcut match
- [ ] Test shortcut listing returns all shortcuts

---

## 5.6 Clipboard Integration

- [ ] **Section 5.6 Complete**

Clipboard integration enables copy and paste between the TUI application and system clipboard. We implement bracketed paste for incoming paste events and OSC 52 for clipboard writing (where supported). Clipboard operations are async since they may involve terminal queries.

Clipboard is essential for text editing components. Users expect to paste from other applications and copy selected text. We handle both keyboard (Ctrl+V) and terminal-initiated pastes.

### 5.6.1 Bracketed Paste Handling

- [ ] **Task 5.6.1 Complete**

Bracketed paste mode (from Phase 1) wraps pasted content in escape sequences. We handle paste events by accumulating content and delivering as a single event. This prevents pasted text from being interpreted as commands.

- [ ] 5.6.1.1 Implement paste event accumulation collecting content between markers
- [ ] 5.6.1.2 Implement paste event delivery to focused component
- [ ] 5.6.1.3 Implement paste timeout for incomplete pastes
- [ ] 5.6.1.4 Route paste events through event system as PasteEvent

### 5.6.2 Clipboard Writing

- [ ] **Task 5.6.2 Complete**

Clipboard writing uses OSC 52 escape sequence to set system clipboard. Not all terminals support this feature. We implement writing with capability detection and fallback notification.

- [ ] 5.6.2.1 Implement OSC 52 clipboard write sequence generation
- [ ] 5.6.2.2 Implement capability detection for OSC 52 support
- [ ] 5.6.2.3 Implement write command for clipboard operations
- [ ] 5.6.2.4 Implement fallback notification when clipboard not supported

### 5.6.3 Selection Management

- [ ] **Task 5.6.3 Complete**

Selection management tracks selected content for copy operations. Text components implement selection state; we provide utilities for selection operations. Selection typically copies to clipboard on explicit action.

- [ ] 5.6.3.1 Implement selection state tracking start and end positions
- [ ] 5.6.3.2 Implement selection expansion with Shift+arrow keys
- [ ] 5.6.3.3 Implement selection clearing on navigation without Shift
- [ ] 5.6.3.4 Implement copy command extracting selected content

### 5.6.4 Cut, Copy, Paste Commands

- [ ] **Task 5.6.4 Complete**

Standard edit commands use the clipboard. Cut removes selection and copies to clipboard. Copy copies selection to clipboard. Paste inserts clipboard content at cursor. These integrate with shortcut system (Ctrl+X/C/V).

- [ ] 5.6.4.1 Implement copy command writing selection to clipboard
- [ ] 5.6.4.2 Implement paste command inserting from paste event
- [ ] 5.6.4.3 Implement cut command combining copy and delete
- [ ] 5.6.4.4 Register standard shortcuts for clipboard operations

### Unit Tests - Section 5.6

- [ ] **Unit Tests 5.6 Complete**
- [ ] Test paste event accumulates content correctly
- [ ] Test paste event routes to focused component
- [ ] Test clipboard write generates correct OSC 52 sequence
- [ ] Test selection tracking maintains start/end positions
- [ ] Test copy extracts selected content
- [ ] Test paste inserts at cursor position
- [ ] Test cut removes and copies selection

---

## 5.7 Focus Events

- [ ] **Section 5.7 Complete**

Focus events report when the terminal window gains or loses system focus. This enables optimization—pausing animations when backgrounded—and proper state management—autosaving when losing focus. Not all terminals support focus events, so applications must work without them.

Focus tracking activates with escape sequence `ESC[?1004h` and reports `ESC[I` (focused) and `ESC[O` (unfocused). We parse these events and deliver to the application through the event system.

### 5.7.1 Focus Event Detection

- [ ] **Task 5.7.1 Complete**

Focus event detection parses focus sequences from terminal input. We integrate with the parser from Phase 1 to recognize focus gained and lost sequences.

- [ ] 5.7.1.1 Implement focus event parsing recognizing ESC[I and ESC[O
- [ ] 5.7.1.2 Implement focus event type with gained/lost variants
- [ ] 5.7.1.3 Implement focus mode activation during terminal setup
- [ ] 5.7.1.4 Implement capability detection for focus event support

### 5.7.2 Focus State Management

- [ ] **Task 5.7.2 Complete**

Focus state tracks whether the application is in foreground. Components can query focus state to adjust behavior. The runtime maintains focus state and broadcasts changes.

- [ ] 5.7.2.1 Implement focus state tracking in runtime
- [ ] 5.7.2.2 Implement `has_focus?/0` query for current focus state
- [ ] 5.7.2.3 Implement focus change broadcast to all components
- [ ] 5.7.2.4 Implement focus state in view for conditional rendering

### 5.7.3 Focus-Based Optimization

- [ ] **Task 5.7.3 Complete**

Focus-based optimization reduces work when backgrounded. We pause animations, reduce update frequency, and skip expensive rendering. This saves resources and battery on laptops.

- [ ] 5.7.3.1 Implement animation pause when focus lost
- [ ] 5.7.3.2 Implement framerate reduction when backgrounded
- [ ] 5.7.3.3 Implement render skip when unfocused
- [ ] 5.7.3.4 Implement resume on focus gained

### 5.7.4 Focus Actions

- [ ] **Task 5.7.4 Complete**

Focus actions perform tasks on focus changes. Common actions: autosave on focus lost, refresh on focus gained, cursor visibility changes. Applications define focus actions through configuration.

- [ ] 5.7.4.1 Implement focus action registration for focus gained/lost
- [ ] 5.7.4.2 Implement autosave action saving state on focus lost
- [ ] 5.7.4.3 Implement refresh action updating content on focus gained
- [ ] 5.7.4.4 Implement cursor hide on focus lost (optional)

### Unit Tests - Section 5.7

- [ ] **Unit Tests 5.7 Complete**
- [ ] Test focus event parsing recognizes focus sequences
- [ ] Test focus state updates on focus events
- [ ] Test has_focus? returns current state
- [ ] Test focus broadcast notifies all components
- [ ] Test animation pause on focus lost
- [ ] Test render resume on focus gained
- [ ] Test focus actions execute on focus change

---

## 5.8 Integration Tests

- [ ] **Section 5.8 Complete**

Integration tests validate the complete event system with realistic interaction scenarios. We test the full flow from terminal input through message handling to rendering. Tests cover keyboard navigation, mouse interaction, clipboard operations, and focus handling.

### 5.8.1 Event Flow Testing

- [ ] **Task 5.8.1 Complete**

We test complete event flow from terminal to component update to render. Tests verify correct routing, message transformation, state updates, and command execution.

- [ ] 5.8.1.1 Test keyboard event flows through to component update
- [ ] 5.8.1.2 Test mouse event routes and transforms correctly
- [ ] 5.8.1.3 Test command executes and result returns as message
- [ ] 5.8.1.4 Test render triggers after state update

### 5.8.2 Mouse Interaction Testing

- [ ] **Task 5.8.2 Complete**

We test mouse interactions: clicking buttons, dragging sliders, scrolling lists. Tests verify correct coordinate handling and event delivery.

- [ ] 5.8.2.1 Test button click triggers action
- [ ] 5.8.2.2 Test drag operation tracks through move
- [ ] 5.8.2.3 Test scroll wheel scrolls list content
- [ ] 5.8.2.4 Test hover changes component state

### 5.8.3 Shortcut Testing

- [ ] **Task 5.8.3 Complete**

We test keyboard shortcuts in various contexts. Tests verify registration, matching, scoping, and action execution.

- [ ] 5.8.3.1 Test global shortcut triggers from anywhere
- [ ] 5.8.3.2 Test scoped shortcut only triggers in scope
- [ ] 5.8.3.3 Test key sequence completes across multiple keys
- [ ] 5.8.3.4 Test shortcut conflict resolves by priority

### 5.8.4 Clipboard Testing

- [ ] **Task 5.8.4 Complete**

We test clipboard operations: paste handling, copy functionality, and selection management.

- [ ] 5.8.4.1 Test paste inserts content at cursor
- [ ] 5.8.4.2 Test copy writes selection to clipboard
- [ ] 5.8.4.3 Test cut removes and copies
- [ ] 5.8.4.4 Test selection expands with Shift+arrow

---

## Success Criteria

1. **Event Architecture**: Complete Elm Architecture implementation with events, messages, and commands
2. **Runtime**: Central runtime orchestrating update loop and command execution
3. **Commands**: Side effect management with async execution and result handling
4. **Mouse Support**: Full mouse tracking with SGR Extended coordinates and drag support
5. **Shortcuts**: Keyboard shortcut registry with scoping and conflict resolution
6. **Clipboard**: Copy/paste support through bracketed paste and OSC 52
7. **Focus Events**: Terminal focus detection with optimization hooks
8. **Test Coverage**: 85% test coverage with comprehensive unit and integration tests

## Provides Foundation

This phase establishes the infrastructure for:
- **Phase 6**: Advanced widgets using commands for async operations
- All application development using the event system for interaction
- Production applications requiring complete input handling

## Key Outputs

- Message-driven architecture with typed events, messages, and commands
- Runtime GenServer orchestrating application loop
- Command system for side effects with async execution
- Mouse support with SGR Extended tracking
- Keyboard shortcut registry with scoping
- Clipboard integration for copy/paste
- Focus event handling with optimization
- Comprehensive test suite covering all event operations
- API documentation for event system modules
