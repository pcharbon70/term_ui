# Phase 3: Component System

## Overview

This phase creates the OTP-based component system that forms the structural foundation for TUI applications. Components are GenServers that encapsulate UI state and behavior, organized into supervision trees that mirror the UI hierarchy. This design leverages BEAM's strengths: process isolation for fault tolerance (one widget crash doesn't bring down the entire UI), message passing for event handling, and lightweight processes (2KB initial heap) making process-per-component practical.

By the end of this phase, we will have component behaviours defining the standard interface for all widgets, lifecycle management handling component creation and destruction, event routing delivering input events to the appropriate components, focus management tracking which component receives keyboard input, essential widgets (Block, Label, Button, TextInput, List, Progress) demonstrating the patterns, and supervision strategy ensuring fault tolerance and proper resource cleanup.

The design adopts The Elm Architecture pattern adapted for OTP: components maintain state via GenServer callbacks, receive events as messages, produce render trees describing their UI, and emit commands for side effects. This creates predictable unidirectional data flow while integrating naturally with OTP patterns. Components are composable—container components manage children, creating hierarchical UIs from simple building blocks.

---

## 3.1 Component Behaviours

- [ ] **Section 3.1 Complete**

Component behaviours define the standard interface that all widgets implement. We define three behaviours: `Component` for stateless widgets, `StatefulComponent` for widgets maintaining state, and `Container` for widgets with children. These behaviours specify required callbacks for initialization, event handling, rendering, and cleanup. Using behaviours enables polymorphic component handling—the runtime treats all widgets uniformly regardless of specific type.

The behaviours follow Elixir conventions: `@callback` definitions with type specs, `@optional_callbacks` for hooks, and `__using__` macros that inject default implementations. Components implementing these behaviours become GenServers with additional TUI-specific functionality. The behaviour design balances between flexibility (minimal required callbacks) and capability (rich optional callbacks for advanced features).

### 3.1.1 Component Behaviour

- [ ] **Task 3.1.1 Complete**

The base `Component` behaviour defines the core interface for all widgets. Every widget must implement `render/2` to produce its visual representation. Stateless components receive props and render directly. This behaviour is the simplest—suitable for display-only widgets like labels, dividers, and static graphics.

- [ ] 3.1.1.1 Define `TermUI.Component` behaviour with `@callback render(props :: map(), area :: Rect.t()) :: render_tree()` required callback
- [ ] 3.1.1.2 Define `@type render_tree :: %RenderNode{} | [render_tree()] | String.t()` for render output
- [ ] 3.1.1.3 Implement `__using__` macro that imports common types and provides default implementations
- [ ] 3.1.1.4 Define optional `@callback describe() :: String.t()` for component self-documentation

### 3.1.2 StatefulComponent Behaviour

- [ ] **Task 3.1.2 Complete**

The `StatefulComponent` behaviour extends `Component` with state management. Stateful components maintain internal state across events and renders. They implement `init/1` for state initialization, `handle_event/2` for event processing, and optionally `handle_info/2` for arbitrary messages. This behaviour powers interactive widgets like buttons, text inputs, and lists.

- [ ] 3.1.2.1 Define `TermUI.StatefulComponent` behaviour extending Component with `@callback init(props :: map()) :: {:ok, state :: any()}`
- [ ] 3.1.2.2 Define `@callback handle_event(event :: Event.t(), state :: any()) :: {:noreply, new_state} | {:noreply, new_state, [command]}`
- [ ] 3.1.2.3 Define `@callback render(state :: any(), area :: Rect.t()) :: render_tree()` overriding Component.render to use state
- [ ] 3.1.2.4 Define optional callbacks: `terminate/2` for cleanup, `handle_info/2` for custom messages, `handle_call/3` for synchronous queries

### 3.1.3 Container Behaviour

- [ ] **Task 3.1.3 Complete**

The `Container` behaviour extends `StatefulComponent` for widgets that manage children. Containers handle child component lifecycle, layout children within their area, and route events to children. Examples include panels, forms, tabs, and the root application component. Containers implement the composite pattern—they're components composed of other components.

- [ ] 3.1.3.1 Define `TermUI.Container` behaviour extending StatefulComponent with `@callback children(state :: any()) :: [child_spec]`
- [ ] 3.1.3.2 Define `@type child_spec :: {module(), props :: map()} | {module(), props :: map(), id :: term()}`
- [ ] 3.1.3.3 Define `@callback layout(children :: [component_ref], area :: Rect.t(), state :: any()) :: [{component_ref, Rect.t()}]`
- [ ] 3.1.3.4 Implement default child lifecycle management: spawn children on mount, terminate on unmount

### 3.1.4 Behaviour Helpers

- [ ] **Task 3.1.4 Complete**

Behaviour helpers provide common functionality used across all component types. This includes prop validation, default value handling, style merging, and render tree construction utilities. Helpers reduce boilerplate and ensure consistency across widgets.

- [ ] 3.1.4.1 Implement `props!/2` macro for declarative prop validation with type checking and defaults
- [ ] 3.1.4.2 Implement render tree builder functions: `text/2`, `styled/2`, `box/2`, `stack/2`
- [ ] 3.1.4.3 Implement `merge_styles/2` for combining component styles with inherited styles
- [ ] 3.1.4.4 Implement `compute_size/2` helper for widgets that need size information during render

### Unit Tests - Section 3.1

- [ ] **Unit Tests 3.1 Complete**
- [ ] Test Component behaviour can be implemented with just render callback
- [ ] Test StatefulComponent behaviour validates required callbacks
- [ ] Test Container behaviour children/1 callback returns valid child specs
- [ ] Test __using__ macro injects default implementations correctly
- [ ] Test props! macro validates prop types and applies defaults
- [ ] Test render tree builders produce correct node structures
- [ ] Test style merging correctly combines multiple style sources

---

## 3.2 Component Lifecycle

- [ ] **Section 3.2 Complete**

Component lifecycle defines the stages a component goes through from creation to destruction. We implement: `init` (create state), `mount` (component added to tree), `update` (props changed), `unmount` (component removed). Clear lifecycle semantics enable resource management—open files in mount, close in unmount—and ensure consistent behavior across all components.

The lifecycle integrates with OTP's GenServer callbacks and supervision. Components are spawned as GenServer processes under a DynamicSupervisor. Mount happens after spawn when the component is added to the render tree. Unmount triggers cleanup before supervision tree terminates the process. We provide hooks at each stage for custom logic.

### 3.2.1 Initialization

- [ ] **Task 3.2.1 Complete**

Initialization creates the component's initial state from props. The `init/1` callback receives props and returns initial state. Initialization should be fast—defer expensive operations to mount. We validate props before init, providing clear errors for invalid configurations.

- [ ] 3.2.1.1 Implement component spawning via `DynamicSupervisor.start_child/2` with component module and props
- [ ] 3.2.1.2 Implement GenServer `init/1` callback delegating to component's `init/1`
- [ ] 3.2.1.3 Implement prop validation before initialization with descriptive error messages
- [ ] 3.2.1.4 Implement init timeout handling preventing slow init from blocking startup

### 3.2.2 Mounting

- [ ] **Task 3.2.2 Complete**

Mounting occurs when a component is added to the active component tree and will begin receiving events and rendering. Mount is the appropriate place for setup requiring the component to be "live": registering event handlers, starting timers, fetching initial data. We call the optional `mount/1` callback after init.

- [ ] 3.2.2.1 Define `@callback mount(state :: any()) :: {:ok, new_state} | {:ok, new_state, [command]}`
- [ ] 3.2.2.2 Implement mount triggering after component added to tree
- [ ] 3.2.2.3 Implement command execution for side effects initiated during mount
- [ ] 3.2.2.4 Implement mount error handling with clear reporting and recovery

### 3.2.3 Updates

- [ ] **Task 3.2.3 Complete**

Updates occur when a component's props change. The parent passes new props, triggering re-initialization or update callback. We compare old and new props, calling `update/2` only when changed. Updates may change state and trigger re-render. We support both controlled (parent manages state) and uncontrolled (component manages state) patterns.

- [ ] 3.2.3.1 Define `@callback update(new_props :: map(), state :: any()) :: {:ok, new_state}`
- [ ] 3.2.3.2 Implement prop change detection comparing old and new props
- [ ] 3.2.3.3 Implement selective update calling update only for changed props
- [ ] 3.2.3.4 Implement prop diffing utility for complex prop comparison

### 3.2.4 Unmounting

- [ ] **Task 3.2.4 Complete**

Unmounting occurs when a component is removed from the tree. This is the appropriate place for cleanup: canceling timers, closing files, unregistering handlers. We call the optional `unmount/1` callback before termination. Unmount must complete even if the component crashed—cleanup runs in termination handler.

- [ ] 3.2.4.1 Define `@callback unmount(state :: any()) :: :ok`
- [ ] 3.2.4.2 Implement unmount triggering when component removed from tree
- [ ] 3.2.4.3 Implement cleanup in GenServer `terminate/2` callback
- [ ] 3.2.4.4 Implement graceful unmount with timeout for long-running cleanup

### 3.2.5 Lifecycle Hooks

- [ ] **Task 3.2.5 Complete**

Lifecycle hooks allow components to execute logic at specific points without implementing full callbacks. Hooks are simpler than callbacks—they don't return new state. We provide hooks for common cases: after_mount, before_unmount, on_focus, on_blur.

- [ ] 3.2.5.1 Implement hook system allowing registration of hook functions at lifecycle points
- [ ] 3.2.5.2 Implement `after_mount` hook called after successful mount
- [ ] 3.2.5.3 Implement `before_unmount` hook called before unmount cleanup
- [ ] 3.2.5.4 Implement `on_prop_change` hook called when specific prop changes

### Unit Tests - Section 3.2

- [ ] **Unit Tests 3.2 Complete**
- [ ] Test component initialization creates process with correct initial state
- [ ] Test invalid props fail initialization with descriptive error
- [ ] Test mount callback is called after component added to tree
- [ ] Test mount commands are executed after mount completes
- [ ] Test update callback receives new props when props change
- [ ] Test update not called when props unchanged
- [ ] Test unmount callback called when component removed
- [ ] Test cleanup completes even after component crash
- [ ] Test lifecycle hooks fire at correct times

---

## 3.3 Event Routing

- [ ] **Section 3.3 Complete**

Event routing delivers input events (key presses, mouse clicks, resize) to the appropriate component. We implement a routing system that considers focus (keyboard events go to focused component), position (mouse events go to component under cursor), and bubbling (events propagate up the tree if not handled). Event routing is the bridge between terminal input and component event handlers.

The router maintains the component tree structure and focus state. When events arrive from the terminal, the router determines the target component(s) and sends event messages. Components handle events via `handle_event/2` and may: consume the event (stop propagation), modify and forward it, or ignore it (continue propagation). The routing system is efficient—we use spatial indexing for mouse event routing.

### 3.3.1 Event Types

- [ ] **Task 3.3.1 Complete**

We define event types matching Phase 1 parser output plus synthetic events for component-specific behavior. Event types include keyboard events, mouse events, focus events, and custom events. All events have common fields (timestamp, source) plus type-specific data.

- [ ] 3.3.1.1 Define `TermUI.Event` protocol for polymorphic event handling
- [ ] 3.3.1.2 Define keyboard events: `%KeyEvent{key, modifiers, char}`
- [ ] 3.3.1.3 Define mouse events: `%MouseEvent{action, button, x, y, modifiers}`
- [ ] 3.3.1.4 Define focus events: `%FocusEvent{type: :gained | :lost}`, `%BlurEvent{}`
- [ ] 3.3.1.5 Define custom events: `%CustomEvent{name, payload}` for application-specific events

### 3.3.2 Event Router

- [ ] **Task 3.3.2 Complete**

The event router is a GenServer that receives terminal events and routes them to components. It maintains the component tree and focus state. Routing logic varies by event type: keyboard to focused, mouse to positional, broadcast for resize. The router is the central coordinator for all event handling.

- [ ] 3.3.2.1 Implement `TermUI.EventRouter` GenServer maintaining component tree and routing events
- [ ] 3.3.2.2 Implement keyboard event routing sending to focused component
- [ ] 3.3.2.3 Implement mouse event routing using spatial index to find component at coordinates
- [ ] 3.3.2.4 Implement broadcast events sending to all components (resize, focus change)
- [ ] 3.3.2.5 Implement route registration allowing components to register for specific event types

### 3.3.3 Event Propagation

- [ ] **Task 3.3.3 Complete**

Event propagation controls how events flow through the component tree. We support capture (root to target), bubble (target to root), and direct (target only) propagation. Components indicate whether they handled an event; unhandled events continue propagating. This enables both specific handling and delegation patterns.

- [ ] 3.3.3.1 Implement capture phase routing event down from root to target
- [ ] 3.3.3.2 Implement bubble phase routing event up from target to root
- [ ] 3.3.3.3 Implement event handling result: `{:handled, state}`, `{:unhandled, state}`, `{:stop, state}`
- [ ] 3.3.3.4 Implement propagation stopping when component returns `{:handled, _}`

### 3.3.4 Spatial Indexing

- [ ] **Task 3.3.4 Complete**

Spatial indexing enables fast lookup of components by screen position for mouse event routing. We build an index mapping screen coordinates to components. The index updates when components mount, unmount, or resize. For overlapping components (z-order), we route to topmost.

- [ ] 3.3.4.1 Implement spatial index data structure storing component bounds
- [ ] 3.3.4.2 Implement `index_update/3` updating index when component bounds change
- [ ] 3.3.4.3 Implement `find_at/2` returning component(s) at given coordinates
- [ ] 3.3.4.4 Implement z-order handling for overlapping components (modals, dropdowns)

### 3.3.5 Event Transformation

- [ ] **Task 3.3.5 Complete**

Event transformation allows events to be modified as they route. Coordinates transform from screen to component-local. Key events may remap based on keybindings. Containers may intercept and synthesize child events. Transformation makes event handling component-centric rather than screen-centric.

- [ ] 3.3.5.1 Implement coordinate transformation converting screen coords to component-local
- [ ] 3.3.5.2 Implement key remapping allowing components to define keybinding transformations
- [ ] 3.3.5.3 Implement event synthesis creating new events from handled events
- [ ] 3.3.5.4 Implement event filtering allowing components to block events from children

### Unit Tests - Section 3.3

- [ ] **Unit Tests 3.3 Complete**
- [ ] Test keyboard events route to focused component
- [ ] Test mouse events route to component at click position
- [ ] Test broadcast events reach all components
- [ ] Test event bubbling propagates unhandled events to parent
- [ ] Test event handling stops propagation
- [ ] Test spatial index returns correct component for coordinates
- [ ] Test coordinate transformation produces correct local coordinates
- [ ] Test z-order routes to topmost overlapping component

---

## 3.4 Focus Management

- [ ] **Section 3.4 Complete**

Focus management tracks which component receives keyboard input. Only one component has focus at a time. We implement focus traversal (Tab/Shift+Tab navigation), programmatic focus changes, and focus visual indicators. Focus state affects both event routing and rendering (focused components typically display a visual indicator).

The focus system maintains a focus stack for modal contexts—when a modal opens, it captures focus; when closed, focus returns to the previous component. We implement focus trapping for modals preventing Tab from leaving the modal. Components can be focusable or non-focusable, and can disable focus dynamically.

### 3.4.1 Focus State

- [ ] **Task 3.4.1 Complete**

Focus state tracks the currently focused component and the focus history. We store focus as a component reference (pid + id). Focus state is global—stored in the EventRouter or dedicated FocusManager. Focus changes emit events to both losing and gaining components.

- [ ] 3.4.1.1 Implement focus state storing current focused component reference
- [ ] 3.4.1.2 Implement focus history stack for modal/overlay focus management
- [ ] 3.4.1.3 Implement `get_focused/0` returning currently focused component
- [ ] 3.4.1.4 Implement `set_focused/1` changing focus and emitting focus/blur events

### 3.4.2 Focus Traversal

- [ ] **Task 3.4.2 Complete**

Focus traversal moves focus between components via Tab key. We implement a tab order based on component position (left-to-right, top-to-bottom) with optional explicit ordering via `tab_index`. Shift+Tab reverses direction. We skip non-focusable and disabled components during traversal.

- [ ] 3.4.2.1 Implement `focus_next/0` moving focus to next focusable component in tab order
- [ ] 3.4.2.2 Implement `focus_prev/0` moving focus to previous focusable component
- [ ] 3.4.2.3 Implement tab order calculation from component positions
- [ ] 3.4.2.4 Implement explicit tab_index prop for custom focus order

### 3.4.3 Focus Properties

- [ ] **Task 3.4.3 Complete**

Components have properties controlling their focus behavior. `focusable` determines if a component can receive focus. `disabled` temporarily prevents focus. `auto_focus` requests focus on mount. These properties integrate with the component prop system.

- [ ] 3.4.3.1 Implement `focusable` prop (default true for interactive widgets, false for display widgets)
- [ ] 3.4.3.2 Implement `disabled` prop preventing focus and dimming appearance
- [ ] 3.4.3.3 Implement `auto_focus` prop requesting focus when component mounts
- [ ] 3.4.3.4 Implement focus query `is_focused?/1` for conditional rendering

### 3.4.4 Focus Trapping

- [ ] **Task 3.4.4 Complete**

Focus trapping restricts focus to a subset of components, typically within a modal or dialog. When trapped, Tab cycles within the trapped group rather than escaping. We implement trapping via focus groups—named sets of components that form a tab cycle.

- [ ] 3.4.4.1 Implement focus group registration grouping components for trapped traversal
- [ ] 3.4.4.2 Implement `trap_focus/1` activating focus trap for a group
- [ ] 3.4.4.3 Implement `release_focus/0` deactivating focus trap returning to normal traversal
- [ ] 3.4.4.4 Implement wrap-around traversal within trapped group

### 3.4.5 Focus Indicators

- [ ] **Task 3.4.5 Complete**

Focus indicators provide visual feedback showing which component has focus. We support multiple indicator styles: border highlight, background change, cursor display, and custom indicators. Indicators are styling concerns but require focus state integration.

- [ ] 3.4.5.1 Implement focus indicator style props: `focus_border`, `focus_bg`, `focus_style`
- [ ] 3.4.5.2 Implement default focus indicator (highlighted border) for standard widgets
- [ ] 3.4.5.3 Implement focus state injection into component render for custom indicators
- [ ] 3.4.5.4 Implement focus indicator animations (optional blink or fade)

### Unit Tests - Section 3.4

- [ ] **Unit Tests 3.4 Complete**
- [ ] Test focus state tracks currently focused component
- [ ] Test focus change emits blur event to old and focus event to new
- [ ] Test Tab traversal moves to next focusable component
- [ ] Test Shift+Tab traversal moves to previous focusable component
- [ ] Test non-focusable components are skipped during traversal
- [ ] Test disabled components cannot receive focus
- [ ] Test auto_focus requests focus on mount
- [ ] Test focus trap restricts traversal to trapped group
- [ ] Test focus indicator styling applies when focused

---

## 3.5 Essential Widgets

- [ ] **Section 3.5 Complete**

Essential widgets provide the basic building blocks for TUI applications. We implement six fundamental widgets: Block (container with border), Label (text display), Button (clickable action), TextInput (text entry), List (selectable items), and Progress (progress indication). These widgets demonstrate component patterns and provide immediate utility for applications.

Each widget implements the appropriate behaviour (Component, StatefulComponent, or Container), handles relevant events, and produces render output. Widgets are styled via props and integrate with the styling system. They serve as both practical components and reference implementations showing correct patterns.

### 3.5.1 Block Widget

- [ ] **Task 3.5.1 Complete**

Block is a container widget that draws a border and optional title around its children. It's the fundamental layout container—most UIs are hierarchies of blocks. Block implements the Container behaviour, managing child layout within its bordered area. Border styles include none, single, double, rounded, and custom.

- [ ] 3.5.1.1 Implement `TermUI.Widget.Block` module with Container behaviour
- [ ] 3.5.1.2 Implement border rendering with styles: `:none`, `:single`, `:double`, `:rounded`, `:thick`
- [ ] 3.5.1.3 Implement title rendering in top border with alignment options
- [ ] 3.5.1.4 Implement padding props controlling space between border and children
- [ ] 3.5.1.5 Implement children layout delegating to layout system within padded area

### 3.5.2 Label Widget

- [ ] **Task 3.5.2 Complete**

Label displays static or dynamic text. It's the simplest widget—stateless, no event handling, just rendering. Label supports text wrapping, alignment, and truncation for text longer than available space. It demonstrates the base Component behaviour.

- [ ] 3.5.2.1 Implement `TermUI.Widget.Label` module with Component behaviour
- [ ] 3.5.2.2 Implement text rendering with style props (color, bold, etc.)
- [ ] 3.5.2.3 Implement text alignment: `:left`, `:center`, `:right`
- [ ] 3.5.2.4 Implement text wrapping for multiline labels
- [ ] 3.5.2.5 Implement text truncation with ellipsis for overflow

### 3.5.3 Button Widget

- [ ] **Task 3.5.3 Complete**

Button is an interactive widget that triggers an action when activated. Users activate buttons via Enter key when focused or mouse click. Button displays a label and visual feedback for hover and pressed states. It demonstrates StatefulComponent with event handling.

- [ ] 3.5.3.1 Implement `TermUI.Widget.Button` module with StatefulComponent behaviour
- [ ] 3.5.3.2 Implement state tracking focused, hovered, and pressed states
- [ ] 3.5.3.3 Implement Enter key and Space handling for activation
- [ ] 3.5.3.4 Implement mouse click handling for activation
- [ ] 3.5.3.5 Implement visual states: normal, focused, hovered, pressed, disabled
- [ ] 3.5.3.6 Implement `on_click` callback prop for action invocation

### 3.5.4 TextInput Widget

- [ ] **Task 3.5.4 Complete**

TextInput is a single-line text entry field. Users type characters, navigate with arrow keys, delete with backspace/delete, and submit with Enter. TextInput maintains cursor position and selected text range. It's more complex—demonstrating cursor rendering, text editing, and clipboard integration.

- [ ] 3.5.4.1 Implement `TermUI.Widget.TextInput` module with StatefulComponent behaviour
- [ ] 3.5.4.2 Implement state tracking value, cursor position, and selection range
- [ ] 3.5.4.3 Implement character input inserting at cursor position
- [ ] 3.5.4.4 Implement cursor navigation with Left, Right, Home, End keys
- [ ] 3.5.4.5 Implement text deletion with Backspace and Delete keys
- [ ] 3.5.4.6 Implement cursor rendering showing position within text
- [ ] 3.5.4.7 Implement `on_change` and `on_submit` callback props

### 3.5.5 List Widget

- [ ] **Task 3.5.5 Complete**

List displays a scrollable list of items with selection support. Users navigate with arrow keys, select with Enter, and scroll through long lists. List supports single and multi-select modes. It demonstrates scrolling, selection state, and efficient rendering for large lists.

- [ ] 3.5.5.1 Implement `TermUI.Widget.List` module with StatefulComponent behaviour
- [ ] 3.5.5.2 Implement state tracking items, selected index(es), and scroll offset
- [ ] 3.5.5.3 Implement arrow key navigation moving selection up/down
- [ ] 3.5.5.4 Implement scroll handling when selection moves beyond visible area
- [ ] 3.5.5.5 Implement item rendering with highlight for selected items
- [ ] 3.5.5.6 Implement `on_select` callback prop for selection changes
- [ ] 3.5.5.7 Implement multi-select mode with Space to toggle selection

### 3.5.6 Progress Widget

- [ ] **Task 3.5.6 Complete**

Progress shows progress toward completion or indeterminate activity. Bar mode shows a filled bar proportional to progress (0.0 to 1.0). Spinner mode shows an animated indicator for indeterminate operations. Progress is simple but demonstrates animation and numeric display.

- [ ] 3.5.6.1 Implement `TermUI.Widget.Progress` module with StatefulComponent behaviour
- [ ] 3.5.6.2 Implement bar mode rendering filled proportion of available width
- [ ] 3.5.6.3 Implement spinner mode with animated character sequence
- [ ] 3.5.6.4 Implement percentage display option showing numeric progress
- [ ] 3.5.6.5 Implement customizable bar characters (filled, empty, edges)

### Unit Tests - Section 3.5

- [ ] **Unit Tests 3.5 Complete**
- [ ] Test Block renders border correctly for all border styles
- [ ] Test Block title appears in correct position with alignment
- [ ] Test Label renders text with correct styling and alignment
- [ ] Test Label truncation adds ellipsis for overflow text
- [ ] Test Button handles Enter key and invokes on_click
- [ ] Test Button visual states change correctly on focus/hover/press
- [ ] Test TextInput accepts character input at cursor position
- [ ] Test TextInput cursor moves with arrow keys
- [ ] Test TextInput backspace deletes character before cursor
- [ ] Test List selection moves with arrow keys
- [ ] Test List scrolls when selection exceeds visible area
- [ ] Test Progress bar fills proportionally to value
- [ ] Test Progress spinner animates through frames

---

## 3.6 Supervision Strategy

- [ ] **Section 3.6 Complete**

Supervision strategy defines how component processes are organized and recovered on failure. We implement a supervision tree mirroring the UI component hierarchy—each container supervises its children. This provides fault isolation (child crash doesn't kill parent) and automatic restart (crashed widgets recover). The strategy leverages OTP supervision patterns for production-ready reliability.

We use DynamicSupervisor for component trees since children are added/removed dynamically. The restart strategy is `:transient`—restart only on abnormal termination (crashes), not normal exit. We implement supervisor shutdown coordination ensuring orderly cleanup. The supervision tree is inspectable for debugging and monitoring.

### 3.6.1 Component Supervisor

- [ ] **Task 3.6.1 Complete**

The component supervisor manages all widget processes. We use a tree of DynamicSupervisors—one per container—to match UI hierarchy. The root supervisor manages top-level components; containers manage their children. This creates natural fault isolation boundaries.

- [ ] 3.6.1.1 Implement `TermUI.ComponentSupervisor` as application-level DynamicSupervisor
- [ ] 3.6.1.2 Implement `start_component/2` spawning component under appropriate supervisor
- [ ] 3.6.1.3 Implement `stop_component/1` terminating component and its children
- [ ] 3.6.1.4 Implement container-level supervision with container as child supervisor

### 3.6.2 Restart Strategies

- [ ] **Task 3.6.2 Complete**

Restart strategies control how the supervisor handles child failures. We use `:transient` by default—crashed components restart, normally-exited ones don't. Critical components may use `:permanent` for always-restart. We implement restart limits preventing infinite restart loops on persistent failures.

- [ ] 3.6.2.1 Implement `:transient` restart for normal components (restart on crash)
- [ ] 3.6.2.2 Implement `:permanent` restart option for critical components (always restart)
- [ ] 3.6.2.3 Implement `:temporary` restart option for ephemeral components (never restart)
- [ ] 3.6.2.4 Implement restart intensity limits (max_restarts, max_seconds) to prevent restart storms

### 3.6.3 Shutdown Coordination

- [ ] **Task 3.6.3 Complete**

Shutdown coordination ensures orderly cleanup when the application terminates. We implement graceful shutdown giving components time to cleanup (save state, close files). Children shut down before parents. We handle shutdown timeout killing components that don't terminate promptly.

- [ ] 3.6.3.1 Implement shutdown timeout configuration (default 5000ms) for graceful termination
- [ ] 3.6.3.2 Implement shutdown order ensuring children terminate before parent containers
- [ ] 3.6.3.3 Implement forced shutdown (brutal_kill) for components exceeding timeout
- [ ] 3.6.3.4 Implement shutdown hooks allowing components to perform cleanup actions

### 3.6.4 Fault Recovery

- [ ] **Task 3.6.4 Complete**

Fault recovery restores component state after restart. We implement state persistence options: recover last props (restart with same configuration), recover last state (restore internal state), or reset to initial. State recovery uses ETS or persistent_term for crash-safe storage.

- [ ] 3.6.4.1 Implement state persistence to ETS before crash for recovery
- [ ] 3.6.4.2 Implement state recovery in component init checking for persisted state
- [ ] 3.6.4.3 Implement recovery mode props: `:reset`, `:last_props`, `:last_state`
- [ ] 3.6.4.4 Implement crash notification alerting parent container of child crash

### 3.6.5 Supervision Introspection

- [ ] **Task 3.6.5 Complete**

Supervision introspection provides visibility into the component tree for debugging and monitoring. We expose the tree structure, component states, and supervision metrics. This integrates with the developer experience features in Phase 6.

- [ ] 3.6.5.1 Implement `get_component_tree/0` returning current supervision tree structure
- [ ] 3.6.5.2 Implement `get_component_info/1` returning component state and metrics
- [ ] 3.6.5.3 Implement supervision metrics: restart count, uptime, child count
- [ ] 3.6.5.4 Implement tree visualization for debugging (text representation)

### Unit Tests - Section 3.6

- [ ] **Unit Tests 3.6 Complete**
- [ ] Test components spawn under correct supervisor
- [ ] Test crashed component restarts with :transient strategy
- [ ] Test normally-exited component doesn't restart with :transient
- [ ] Test restart limits trigger supervisor shutdown on exceeded
- [ ] Test shutdown terminates children before parent
- [ ] Test forced shutdown kills component after timeout
- [ ] Test state recovery restores persisted state after restart
- [ ] Test tree introspection returns correct structure

---

## 3.7 Integration Tests

- [ ] **Section 3.7 Complete**

Integration tests validate the complete component system with realistic UI scenarios. We test component hierarchies, event flow, focus management, and fault tolerance. Tests simulate user interactions and verify correct behavior across the entire component stack. These tests ensure all component system elements work together correctly.

### 3.7.1 Component Hierarchy Testing

- [ ] **Task 3.7.1 Complete**

We test nested component hierarchies with containers managing children. Tests verify correct lifecycle sequencing (parent init before children), event routing (parent can intercept child events), and rendering (children render within parent bounds).

- [ ] 3.7.1.1 Test three-level component hierarchy initializes in correct order
- [ ] 3.7.1.2 Test child components render within parent container bounds
- [ ] 3.7.1.3 Test parent unmount terminates all descendants
- [ ] 3.7.1.4 Test dynamic child addition and removal during runtime

### 3.7.2 Event Flow Testing

- [ ] **Task 3.7.2 Complete**

We test event flow through component trees including routing, handling, and propagation. Tests verify keyboard events reach focused components, mouse events reach components at coordinates, and events bubble correctly when not handled.

- [ ] 3.7.2.1 Test keyboard event reaches deeply nested focused component
- [ ] 3.7.2.2 Test mouse event routes to correct component based on position
- [ ] 3.7.2.3 Test unhandled event bubbles to parent and is handled
- [ ] 3.7.2.4 Test handled event stops propagation

### 3.7.3 Focus Integration Testing

- [ ] **Task 3.7.3 Complete**

We test focus management in realistic UIs with multiple focusable components. Tests verify Tab traversal order, focus trapping in modals, and focus restoration after modal close.

- [ ] 3.7.3.1 Test Tab traversal through form with multiple inputs in correct order
- [ ] 3.7.3.2 Test focus trap in modal prevents Tab from escaping
- [ ] 3.7.3.3 Test focus returns to previous component after modal closes
- [ ] 3.7.3.4 Test programmatic focus change works during event handling

### 3.7.4 Fault Tolerance Testing

- [ ] **Task 3.7.4 Complete**

We test fault tolerance by crashing components and verifying recovery. Tests confirm crashed components restart, state recovers, and sibling components are unaffected. This validates the supervision strategy in realistic scenarios.

- [ ] 3.7.4.1 Test crashed child component restarts without affecting parent
- [ ] 3.7.4.2 Test crashed component state recovers from persistence
- [ ] 3.7.4.3 Test sibling components continue functioning during restart
- [ ] 3.7.4.4 Test restart storm triggers supervisor shutdown

---

## Success Criteria

1. **Behaviours**: Component, StatefulComponent, and Container behaviours fully defined with clear contracts
2. **Lifecycle**: Complete lifecycle (init, mount, update, unmount) implemented with proper cleanup
3. **Event Routing**: Events correctly route to focused/positional components with propagation control
4. **Focus Management**: Tab traversal, focus trapping, and visual indicators working correctly
5. **Essential Widgets**: All six widgets (Block, Label, Button, TextInput, List, Progress) fully functional
6. **Supervision**: Fault isolation and recovery working with component crashes not affecting siblings
7. **Test Coverage**: 85% test coverage with comprehensive unit and integration tests

## Provides Foundation

This phase establishes the infrastructure for:
- **Phase 4**: Layout system integrating with Container.layout callback
- **Phase 5**: Event system building on event routing infrastructure
- **Phase 6**: Advanced widgets building on essential widget patterns
- All application development using component system for UI structure

## Key Outputs

- Component behaviours (Component, StatefulComponent, Container) with full specifications
- Component lifecycle management with mount/unmount hooks
- Event routing system with keyboard, mouse, and propagation support
- Focus management with traversal and trapping
- Six essential widgets as functional examples and practical components
- Supervision strategy with fault isolation and recovery
- Comprehensive test suite covering all component operations
- API documentation for component system modules
