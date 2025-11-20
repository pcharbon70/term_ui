# Building a Direct-Mode Terminal UI Framework for Elixir/BEAM

The Elixir ecosystem stands at a pivotal moment for terminal UI development. With OTP 28's native raw mode support arriving and new pure-Elixir approaches emerging, the foundation exists to build a world-class TUI framework that embraces BEAM's unique strengths. This report synthesizes research across historical terminal architecture, modern frameworks in multiple languages, and BEAM-specific capabilities to propose a comprehensive design for truly interactive terminal applications on the BEAM.

## Current state: Limitations blocking progress

The Elixir TUI ecosystem has been constrained by three fundamental limitations. **First, the raw mode problem**: Until OTP 28, Elixir lacked native terminal raw mode support, forcing developers to rely on NIFs wrapping C libraries like termbox to achieve character-by-character input. The standard `IO.gets/1` function is line-buffered, waiting for Enter before processing input—completely unsuitable for interactive UIs where arrow keys, Ctrl combinations, and single keystrokes must trigger immediate responses.

**Second, the deprecated foundation crisis**: The most mature solutions (Ratatouille and ExTermbox) built on termbox, which the original author explicitly deprecated around 2019 with the stark warning "this library is no longer maintained" and recommendation to "avoid using terminals for UI." This creates compatibility issues with modern terminals, tmux problems, and dependency on unmaintained C code with Python 2.x build scripts. Projects using these libraries face an uncertain future.

**Third, the abstraction gap**: Even frameworks claiming to be "high-level" require manual cursor tracking, explicit data structure indexing for rendering, and reimplementation of common UI patterns. Ratatouille provides declarative syntax but lacks standard widgets like scrollbars, input fields, and dialogs. Developers building terminal applications spend time reimplementing basic components rather than focusing on their application logic.

The landscape is shifting rapidly. **OTP 28 introduces native raw mode** through `shell.start_interactive({:noshell, :raw})`, enabling immediate character response without NIFs. **Termite**, a new pure-Elixir library, demonstrates ANSI-escape-sequence-based terminal control without C dependencies, though it's early-stage. **ElementTUI** uses the maintained termbox2 fork, showing the community adapting to newer foundations. The ecosystem needs a comprehensive framework that leverages these developments while providing the abstractions developers expect.

## Learning from history: Unix terminals got it right

The 1980s Unix terminal architecture established patterns that remain relevant today because they solved fundamental problems with elegant abstractions. **Terminfo and termcap** created terminal-independent programming by maintaining databases of terminal capabilities—escape sequences for cursor movement, colors, and special features—allowing programs to query "how do I clear the screen on this terminal?" rather than hardcoding vendor-specific codes. This abstraction enabled vi, emacs, and curses-based applications to run across hundreds of incompatible terminal models.

The **VT100 terminal** (1978) established the ANSI X3.64 standard that modern emulators still implement. Its control sequences like `ESC[H` (home cursor) and `ESC[2J` (clear screen) became universal. The DEC Special Graphics character set provided box-drawing characters through clever character mapping—sending lowercase 'q' while in graphics mode produced horizontal lines, enabling rich text-based UIs with borders and tables without requiring pixel graphics.

**Curses library design principles** remain instructive. Ken Arnold's abstraction of vi's cursor optimization code into curses created a window-based API where applications described desired screen state, and the library calculated minimal escape sequences to achieve it. The key insight: **maintain a virtual screen in memory, calculate differences from current state, and send only changed portions**. This made 300-baud modem connections usable by reducing every character transmitted through sophisticated cost-based optimization—comparing direct cursor addressing versus relative movement, explicit clearing versus overwriting with spaces, choosing the cheapest approach.

Three architectural patterns proved essential: **cursor optimization** (never send more bytes than necessary), **buffering at multiple levels** (application stdio, TTY driver, flow control), and **deferred updates** (accumulate changes then apply atomically). These patterns transformed sluggish, flickering interfaces into responsive experiences that felt instant despite severe bandwidth constraints.

Modern TUI frameworks rediscover these patterns. BubbleTea and Ratatui both implement virtual screen buffers with diffing. The lesson: **terminal I/O is expensive; minimize it through intelligent buffering and differential updates**. For BEAM applications, this suggests maintaining rendering state in ETS tables for fast access while batching terminal writes.

## Modern frameworks reveal convergent design patterns

Analyzing six contemporary TUI frameworks across five languages reveals remarkable convergence on core architectural patterns, while each leverages language-specific strengths.

### BubbleTea: Functional elegance in Go

BubbleTea brings The Elm Architecture to terminal UIs with three simple methods defining every application: `Init()` returns initial commands, `Update(msg)` handles events and returns new state plus optional command, `View()` renders current state as a string. This **message-driven architecture** creates predictable, unidirectional data flow where UI always equals a pure function of state.

The **command system** solves asynchronous I/O without exposing goroutines. Commands are functions returning messages; BubbleTea executes them concurrently and routes resulting messages back through Update. This keeps the event loop fast—Update must return in under 1ms for smooth 60 FPS rendering. All expensive operations (HTTP requests, file I/O, complex calculations) move to commands that run without blocking the UI.

**Framerate-based rendering** caps screen updates at 60 FPS (configurable to 120) regardless of Update call frequency. The renderer diffs current output against previous render, compresses redundant ANSI sequences, and writes only changed portions. This prevents terminal emulator overload and reduces CPU usage, especially over SSH where bandwidth matters.

BubbleTea's design succeeds by making difficult things simple: developers think about state (Model), events (Messages), and side effects (Commands) without worrying about terminal codes, rendering loops, or concurrency primitives. The Bubbles component library demonstrates composability—widgets are just Models that can be embedded in larger Models, with messages routed through the tree.

### Ratatui: Zero-cost abstractions in Rust

Ratatui embraces **immediate-mode rendering** where the UI reconstructs completely each frame. Applications call `terminal.draw(|frame| { ... })` explicitly, widgets render into a buffer, then diffing produces minimal terminal output. This differs from retained-mode frameworks (like Cursive) that maintain persistent widget trees and automatically redraw on events.

The immediate approach provides simplicity—UI is always a pure function of application state with no synchronization between widget state and model state—but requires managing the render loop manually. Ratatui compensates through **double-buffering with intelligent diffing**: maintain current and previous buffers as vectors of Cells (symbol + style), compare line-by-line, skip unchanged lines, use cursor positioning to jump to changed regions.

**Rust's zero-cost abstractions** deliver performance without sacrificing expressiveness. Widget traits resolve at compile time through monomorphization. Iterator chains optimize to manual loops. The ownership system prevents memory leaks and data races without runtime overhead. Stack-allocated Cell and Rect types (8 bytes, passed in registers) minimize allocation. The Cassowary constraint solver for layouts caches results in a thread-local LRU cache—500 entries prevent recomputation for common layout patterns.

The **pluggable backend system** (Crossterm, Termion, Termwiz) abstracts terminal interaction behind a trait, enabling cross-platform support, testing with TestBackend, and even GPU rendering (ratatui-wgpu achieves 800 FPS updating every cell at 1080p, proving the library isn't the bottleneck). Ratatui demonstrates that immediate mode suits terminal constraints: small rendering surfaces make full redraws fast, and diffing eliminates redundant output.

### Cross-language patterns

Surveying Tuile (Zig), Textual (Python), FTXUI (C++), and Blessed (JavaScript) reveals common design principles:

**Hierarchical component models** mirror HTML DOM structure across all frameworks. Parent-child relationships with composition over inheritance. Container widgets (boxes, grids, layouts) organize leaf widgets (labels, buttons, inputs). Message/event bubbling propagates through trees.

**Declarative UI definition** separates structure from imperative construction. Describe what the UI should look like; the framework handles how to build it. Tuile uses struct composition, Textual offers `compose()` generators, FTXUI enables functional composition with pipe operators, Blessed provides constructor-based trees.

**Styling systems** decouple presentation from structure. Textual goes furthest with CSS-like `.tcss` files supporting classes, IDs, and pseudo-selectors. FTXUI uses decorator functions (`element | bold | color`). This separation enables theming and consistent visual design.

**Screen buffer management with damage tracking** appears universally. Maintain previous and current screen state, identify changed regions, emit minimal escape sequences. The painter's algorithm: render back-to-front, use cursor positioning for efficiency, batch writes to reduce system calls.

Language-specific innovations matter. **Textual's web deployment** (compile TUI to web app with no code changes) and live hot-reload development environment show Python's dynamic nature. **FTXUI's WebAssembly compilation** leverages C++ portability. **Blessed's terminal emulation within TUI** (running pty.js processes) and image rendering demonstrate Node.js ecosystem integration. **Tuile's compile-time safety** through Zig's comptime execution catches errors before runtime.

The lesson: **a great TUI framework combines universal patterns with language-specific strengths**. For Elixir, this means embracing OTP supervision, actor-based event handling, and functional state management while adopting proven patterns like virtual screen buffers and component composition.

## Leveraging BEAM's unique architecture

The BEAM virtual machine offers capabilities unlike any platform running the surveyed frameworks. Building a TUI framework that truly embraces BEAM's design rather than fighting it creates opportunities for elegance and fault tolerance.

### OTP patterns for UI components

**GenServer provides natural state encapsulation** for interactive widgets. Each component (menu, list, text input, status bar) becomes a GenServer maintaining internal state through standard callbacks. The `init/1` callback establishes initial state. `handle_cast/2` processes asynchronous UI events (key press, mouse click). `handle_call/3` enables synchronous queries (get current value, validate state). This creates clear interfaces between components without shared mutable state.

A button component might maintain `%{label: "Submit", enabled: true, focused: false}` state, responding to `{:focus}` and `{:click}` messages. A text input tracks `%{value: "", cursor: 0, max_length: 100}`, handling character insertion and cursor movement. Each component encapsulates its logic in a single, testable module.

**Supervisors mirror UI component hierarchies**, providing fault isolation. A form containing three inputs and two buttons becomes a supervisor with five child processes. If input validation crashes one field, the supervisor restarts just that component without affecting siblings. Restart strategies express relationships: `:one_for_one` for independent widgets, `:rest_for_one` when later components depend on earlier ones (navigation bar determining content panel state).

This differs fundamentally from frameworks where a crash in any component corrupts global state, requiring full application restart. BEAM's lightweight processes (~2KB initial heap) make process-per-component architectures practical—a complex UI with hundreds of widgets consumes megabytes, acceptable for modern systems.

**GenStage handles external event streams** when back-pressure matters. Keyboard events from a terminal driver become a Producer, transforming and filtering through ProducerConsumer stages, ultimately consumed by UI components. Configurable demand prevents event queue overflow during input bursts. This architecture shines for monitoring dashboards aggregating high-frequency data streams—network packet analyzers, log tailing with complex filtering, real-time metrics visualization.

However, GenStage adds latency unsuitable for immediate keyboard response in text editors. For those cases, direct message passing to component processes provides sub-millisecond routing. The framework should support both patterns, choosing appropriately per use case.

### Actor model for event-driven interfaces

**Message passing eliminates locking complexity**. Each component process has an independent mailbox receiving events asynchronously. Send `{:key_press, ?q}` to a component—it processes when scheduled, no blocking. No mutexes, condition variables, or race conditions. Timeout handling built-in through `receive...after` constructs.

The **process-per-component versus shared state** decision depends on interactivity. Interactive widgets (buttons, inputs, selectable lists) benefit from process isolation—independent lifecycle, fault tolerance, natural event queuing. Static display widgets (labels, progress bars, decorative borders) can share state through Agents or ETS without isolation overhead.

A **hybrid architecture** proves optimal: component processes for interactive elements, shared rendering backend as a GenServer managing an ETS table for screen buffers. Components generate render commands (`{:draw, x, y, styled_text}`) sent to the render manager, which accumulates changes and flushes periodically. This separates concerns: components focus on logic, rendering focuses on optimization.

### Functional state management

**Immutability** prevents entire classes of bugs. State updates create new data structures rather than mutating existing ones. A list widget receiving `{:select, index}` returns `%{state | selected: index}`, leaving the original state unchanged. This enables time-travel debugging (save state history, replay events), easy testing (pure functions, no setup/teardown), and safe concurrent access.

Structural sharing minimizes copying overhead. Updating one field in a map creates a new map structure sharing unchanged fields. List prepending is O(1) because it reuses the tail. ETS tables provide mutable storage when truly needed—render buffers updated thousands of times per second benefit from in-place modification—but immutability remains the default.

**Performance characteristics** matter for interactive UIs. Map updates are O(log n), acceptable for component state (rarely exceeding hundreds of keys). ETS lookups range O(1) for hash tables to O(log n) for ordered sets. The `:persistent_term` module offers O(1) reads for truly immutable configuration without copying. Per-process garbage collection prevents stop-the-world pauses common in Go or Python—a crashed component with accumulated garbage simply disappears, not slowing unrelated processes.

### Ports versus NIFs for terminal I/O

**Ports are strongly recommended** for terminal control despite higher latency. Ports run as separate OS processes communicating via IPC, isolating crashes—buggy C code in a termbox wrapper can't crash the BEAM VM. Binary term encoding adds ~100-500 microseconds per message, acceptable for human-scale input (under 100 events/second). Ports can use file descriptors 3/4 to bypass stdio, preserving stdin/stdout for debugging.

**NIFs provide zero serialization overhead** by running inside the VM, accessing BEAM data structures directly. Use NIFs only for CPU-intensive operations proven to be bottlenecks—complex layout calculations with hundreds of constraints, image rendering for rich terminals. Always use **dirty schedulers** for operations exceeding 1ms to avoid blocking regular schedulers. Consider **Rustler** for NIFs to gain Rust's memory safety, eliminating the primary NIF danger (crashing the VM through segfaults).

**Port drivers** resemble NIFs with port-like interfaces but share crash risks. Rarely appropriate for new development. The ecosystem examples prove ports work: Ratatouille and ElementTUI use NIFs wrapping termbox by necessity (raw mode requirement), but with OTP 28's native raw mode, pure-Elixir ports become viable.

An ideal implementation uses **Elixir for terminal control** via OTP 28's raw mode and ANSI escape sequences (Termite's approach), optionally falling back to a **port wrapping termios** for OTP 26-27 compatibility. Avoid NIFs unless profiling demonstrates terminal I/O as the bottleneck—it almost never is, as rendering usually dominates.

## Direct mode programming requirements

Building truly interactive terminal sessions requires bypassing standard line-buffered input and gaining character-level control.

### Raw terminal mode fundamentals

**Canonical mode** (the default) processes input line-by-line with local editing. Press keys, they echo to screen, but `read()` doesn't return until Enter. Backspace deletes characters in the terminal driver before the application sees anything. Ctrl-C generates SIGINT, killing the process. This enables shell-like line editing but prevents single-keystroke responsiveness.

**Raw mode** disables all processing. Every keypress immediately available to read. No echo—application must explicitly redraw input. No signal generation—Ctrl-C arrives as byte 3. No special character handling—arrow keys arrive as multi-byte escape sequences starting with ESC (0x1B).

**The termios structure** controls terminal behavior through flags. Setting raw mode involves: clearing `ECHO` (no automatic echo), clearing `ICANON` (no line buffering), clearing `ISIG` (no signal generation), clearing `IXON` (no flow control), clearing `OPOST` (no output processing like newline-to-CRLF translation), setting `CS8` (8-bit characters), and configuring `VMIN=0`/`VTIME=1` for non-blocking reads with 100ms timeout.

**OTP 28's native support** through `shell.start_interactive({:noshell, :raw})` eliminates the need for NIFs or ports to achieve raw mode, enabling pure-Elixir implementations. OTP 26-27 applications require external tools—a port running a C program calling `tcsetattr()`, or NIFs—but this interim solution suffices until OTP 28 adoption.

### Handling special keys and escape sequences

Arrow keys send multi-byte sequences: Up = `ESC[A`, Down = `ESC[B`, Right = `ESC[C`, Left = `ESC[D`. Function keys use longer sequences: F1 = `ESC[OP`, F5 = `ESC[15~`. Home, End, Page Up/Down all begin with ESC followed by CSI characters and modifiers.

**Parsing requires state machines**. Reading byte 0x1B might be ESC key alone (user pressed Escape) or start of multi-byte sequence (user pressed arrow). Wait for subsequent bytes with short timeout (typically 10ms). If more bytes arrive, parse as sequence. If timeout, treat as standalone Escape.

Terminals vary in sequences sent. Home key might be `ESC[H` (standard) or `ESC[1~` (some terminals) or `ESC[7~` (others). A robust framework maintains a **sequence trie** for efficient parsing and supports configuration for unusual terminals.

### Cross-platform terminal compatibility

**Linux and macOS** share POSIX termios APIs with minor differences. Standard ANSI escape sequences work universally. iTerm2 on macOS supports true color and advanced features; Terminal.app lacks true color but handles 256 colors. Most modern Linux terminals (GNOME Terminal, Konsole, Alacritty, Kitty, WezTerm) implement full ANSI standards including true color, mouse protocols, and modern extensions.

**Windows** diverges historically but converges in modern versions. Pre-Windows 10 required Win32 Console API—a completely different programming model with SetConsoleCursorPosition instead of escape sequences. Windows 10 (1511+) introduced native ANSI/VT sequence support activated via `SetConsoleMode()` with `ENABLE_VIRTUAL_TERMINAL_PROCESSING` flag. Windows 10 (1809+) added **ConPTY** (Pseudo Console), providing Unix-like PTY infrastructure. **Windows Terminal** (2019+) delivers full modern terminal capabilities rivaling Unix emulators.

A cross-platform framework uses feature detection: attempt enabling VT mode on Windows, fall back to Win32 Console API if unavailable. On Unix, query terminfo for capabilities, gracefully degrading features (true color → 256 color → 16 color → monochrome) based on terminal support.

### Modern terminal features

**True color** (24-bit RGB) uses `ESC[38;2;{r};{g};{b}m` for foreground, `ESC[48;2;{r};{g};{b}m` for background. Detection via `$COLORTERM` environment variable containing "truecolor" or "24bit". Supported by all major modern terminals (xterm 331+, iTerm2, Alacritty, Kitty, Windows Terminal).

**Mouse event protocols** evolved through extensions. X10 mode (oldest) reports basic clicks. Normal tracking (1000) adds releases. Button tracking (1002) reports motion while buttons held. All motion (1003) reports all movement. **SGR Extended mode (1006)** is recommended—uses decimal encoding allowing coordinates beyond column 223, unambiguous press/release distinction, easier parsing. Enable with `ESC[?1000h` (tracking) and `ESC[?1006h` (SGR format).

**Bracketed paste mode** (`ESC[?2004h`) distinguishes pasted text (wrapped in `ESC[200~` and `ESC[201~`) from typed text, preventing auto-indent chaos in editors and accidental command execution. **Focus events** (`ESC[?1004h`) report when terminal gains/loses focus (`ESC[I` / `ESC[O`), enabling pause/resume of animations and updates when backgrounded.

**Unicode and UTF-8** require careful handling. Characters may be 1-4 bytes. East Asian characters (CJK) occupy two terminal columns. Combining characters (accents) have zero width. Emoji width varies by terminal. Use `wcwidth()` for display width calculation, libraries like ICU for proper text segmentation.

A robust framework **abstracts these features** behind a capability system—query terminal capabilities at startup, expose feature flags to applications (`terminal.supports_true_color?`, `terminal.mouse_tracking_enabled?`), automatically degrade gracefully on limited terminals.

## Proposed framework architecture

Building on lessons from history and modern frameworks while embracing BEAM's strengths suggests a specific architectural approach.

### Component-based structure

The framework provides three abstraction levels:

**Low-level terminal interface** (the "Port layer"): Manages raw mode activation, escape sequence generation/parsing, terminal capability detection. On OTP 28+, pure Elixir using native raw mode. On OTP 26-27, falls back to minimal port wrapping termios. Exposes API: `Terminal.write_at(x, y, text, style)`, `Terminal.clear_region(x, y, width, height)`, `Terminal.read_event(timeout)`. Handles platform differences internally.

**Mid-level rendering engine** (the "Renderer layer"): Implements virtual screen buffer with differential updates. Maintains current and previous screen state in ETS tables (`:screen_current` and `:screen_previous` as ordered sets keyed by `{row, col}`). Provides `Renderer.set_cell(x, y, char, style)`, `Renderer.flush()` which diffs buffers and emits minimal escape sequences, `Renderer.set_cursor(x, y)`, `Renderer.get_buffer_region(x, y, w, h)`.

Implements **cursor optimization**: compare cost of absolute positioning (`ESC[{row};{col}H` = 9+ bytes) versus relative movement (`ESC[{n}C` = 4+ bytes) or literal spaces (1 byte each). Choose cheapest option. Batch writes into single `IO.write()` call to minimize system calls.

**High-level component framework** (the "Widget layer"): Provides OTP-based widget system with supervision. Base behaviours: `Component` (stateless widgets), `StatefulComponent` (widgets with state), `Container` (widgets containing children). Built-in components: Block, Label, Button, TextInput, List, Table, Progress, Chart, Panel, Tabs, Menu, Scrollbar.

### Message-driven event system

Adopts The Elm Architecture adapted for OTP:

**Messages** are Elixir structs representing events:
```elixir
defmodule TermUI.Event do
  defmodule Key do
    defstruct [:key, :modifiers]  # %Key{key: :up, modifiers: [:ctrl]}
  end
  
  defmodule Mouse do
    defstruct [:action, :x, :y, :button, :modifiers]  # :press | :release | :motion
  end
  
  defmodule Resize do
    defstruct [:width, :height]
  end
  
  defmodule Tick do
    defstruct [:interval]  # Scheduled periodic events
  end
end
```

**Components implement callbacks**:
```elixir
defmodule TermUI.Component do
  @callback init(props :: map()) :: {:ok, state :: any()}
  @callback handle_event(event :: term(), state :: any()) :: 
    {:noreply, new_state :: any()} |
    {:noreply, new_state :: any(), [command]} |
    {:emit, message :: term(), new_state :: any()} |
    {:emit, message :: term(), new_state :: any(), [command]}
  
  @callback render(state :: any(), area :: Rect.t()) :: render_tree()
  @callback terminate(reason :: term(), state :: any()) :: :ok
end
```

**Commands** handle side effects:
```elixir
defmodule TermUI.Command do
  def http_get(url, on_result) do
    fn ->
      result = HTTPClient.get(url)
      on_result.(result)  # Returns message to send back
    end
  end
  
  def schedule_tick(interval) do
    fn ->
      Process.sleep(interval)
      %Event.Tick{interval: interval}
    end
  end
end
```

The **runtime** orchestrates:
```elixir
defmodule TermUI.Runtime do
  use GenServer
  
  def init(root_component_module) do
    state = %{
      component_tree: build_tree(root_component_module),
      event_queue: :queue.new(),
      command_supervisor: start_command_supervisor()
    }
    {:ok, state}
  end
  
  def handle_cast({:event, event}, state) do
    # Route event to focused component
    {new_tree, commands} = dispatch_event(state.component_tree, event)
    
    # Execute commands asynchronously
    execute_commands(commands, state.command_supervisor)
    
    # Re-render
    render(new_tree)
    
    {:noreply, %{state | component_tree: new_tree}}
  end
end
```

### Rendering pipeline

Implements **framerate-limited rendering** inspired by BubbleTea:

1. Components return render trees (nested data structures describing UI)
2. Layout engine calculates positions using constraint solver
3. Renderer traverses tree, populating virtual screen buffer (ETS table)
4. Timer triggers flush every 16ms (60 FPS) or 8ms (120 FPS)
5. Flush operation diffs current vs previous buffer
6. Minimal escape sequences emitted to terminal
7. Buffers swapped

**Render tree example**:
```elixir
%Block{
  border: :rounded,
  title: "Dashboard",
  children: [
    %Label{text: "CPU: 45%", style: %{fg: :green}},
    %Progress{value: 0.45, style: %{fg: :blue}}
  ]
}
```

**Layout constraints**:
```elixir
%Layout{
  direction: :vertical,
  constraints: [
    Constraint.length(3),      # Header: 3 rows
    Constraint.min(0),          # Content: remaining space
    Constraint.length(1)        # Footer: 1 row
  ]
}
```

The layout engine uses **Cassowary constraint solver** (via Erlang port to cassowary or pure Elixir implementation) with LRU caching. Cache key combines direction, constraints, and area dimensions. Thread-local (process-local) cache avoids synchronization. Default 500 entries configurable via `TermUI.Layout.init_cache(size)`.

### Supervision strategy

```
Application.Supervisor
├── TermUI.Terminal (GenServer)
│   └── Port/NIF for raw mode (OTP \u003c 28)
├── TermUI.Renderer (GenServer)
│   └── Owns :screen_current and :screen_previous ETS tables
├── TermUI.EventManager (GenServer)
│   ├── Input loop process
│   └── Event router
├── TermUI.ComponentSupervisor (DynamicSupervisor)
│   ├── Root component (GenServer)
│   ├── Child components (GenServer)
│   └── ... (dynamically added/removed)
├── TermUI.CommandSupervisor (Task.Supervisor)
│   └── Command tasks (temporary)
└── TermUI.LayoutCache (Agent)
    └── LRU cache state
```

Components crash only affect their subtree. Renderer crash restarts without losing component state. Terminal crash triggers full restart (critical dependency).

### API design feeling natural in Elixir

**Declarative UI construction**:
```elixir
defmodule MyApp.Dashboard do
  use TermUI.Component
  
  def init(_props) do
    state = %{counter: 0, status: "Ready"}
    {:ok, state}
  end
  
  def render(state, area) do
    Block.new(
      border: :rounded,
      title: "Status: #{state.status}"
    )
    |> Block.child(
      Label.new("Count: #{state.counter}")
      |> Label.style(fg: :cyan, bold: true)
    )
    |> Block.child(
      Button.new("Increment")
      |> Button.on_click({:increment})
    )
  end
  
  def handle_event({:increment}, state) do
    {:noreply, %{state | counter: state.counter + 1}}
  end
  
  def handle_event(%Event.Key{key: ?q}, state) do
    {:emit, :quit, state}
  end
end
```

**Composable styling** with pipe-friendly API:
```elixir
Label.new("Warning!")
|> Label.style(fg: :yellow, bg: :black, bold: true)
|> Label.padding(left: 2, right: 2)
|> Label.border(:single)
```

**Macro-based layout DSL**:
```elixir
import TermUI.Layout
  
vlayout [
  fixed(3, Header.new()),
  flex(1, Content.new()),  # Takes remaining space
  fixed(1, Footer.new())
]
```

**Resource management via RAII patterns**:
```elixir
TermUI.run(MyApp.Dashboard, init_props: %{user: current_user()}) do
  # Automatic cleanup on exit
end

# Or explicit control:
{:ok, app} = TermUI.start_link(MyApp.Dashboard)
# ... do work ...
TermUI.stop(app)  # Restores terminal state
```

## Implementation roadmap

### Phase 1: Foundation (OTP 28+ first)

Build core terminal abstraction:
- Raw mode activation via OTP 28's native support
- ANSI escape sequence generation module
- Escape sequence parser with state machine
- Terminal capability detection (terminfo query, $TERM parsing)
- Basic cursor positioning and screen clearing
- Cross-platform compatibility layer (detect Windows, enable VT mode)

Implement renderer:
- ETS-based double buffering
- Cell structure (`%{char: String.t(), fg: color(), bg: color(), modifiers: [atom()]}`)
- Diff algorithm (line-by-line comparison)
- Escape sequence batching
- Cursor optimization logic
- Framerate limiter (GenServer with timer)

### Phase 2: Component system

Define behaviours and base modules:
- `TermUI.Component` behaviour
- `TermUI.StatefulComponent` behaviour
- `TermUI.Container` behaviour
- Component lifecycle (init, mount, update, unmount)
- Event routing through component tree
- Focus management

Implement essential widgets:
- Block (borders, padding, titles)
- Label (text display with wrapping)
- Button (clickable, keyboard navigable)
- TextInput (single-line editing with cursor)
- List (scrollable, selectable items)
- Progress (bar and spinner variants)

### Phase 3: Layout and styling

Build constraint-based layout:
- Port cassowary solver or implement subset in Elixir
- Define constraint types (length, percentage, ratio, min, max, fill)
- Layout cache with LRU eviction
- Support for nested layouts
- Flexbox-inspired alignment (start, end, center, space-between, space-around)

Create styling system:
- Style structs (`%Style{fg:, bg:, bold:, italic:, underline:}`)
- 16-color, 256-color, and true-color support with graceful degradation
- Theme system (load from config, switch at runtime)
- Style composition and inheritance

### Phase 4: Advanced features

Add rich interactions:
- Mouse support (tracking modes, SGR parsing, click/drag/scroll events)
- Keyboard shortcuts registry (global and component-scoped)
- Clipboard integration (bracketed paste, reading clipboard via OSC 52)
- Focus events for optimizing background updates

Implement advanced widgets:
- Table (multi-column, sortable, scrollable)
- Tabs (switchable panes)
- Menu (nested, keyboard/mouse navigable)
- Dialog (modal overlay, confirmation prompts)
- Chart (sparkline, bar chart using block characters)
- Viewport (scrollable content larger than display)
- Canvas (custom drawing with Braille/block characters)

Performance optimizations:
- Benchmark rendering pipeline
- Profile with `:fprof` and `:observer`
- Optimize hot paths (reduce allocations, batch messages)
- Consider selective use of NIFs for proven bottlenecks (likely layout solver only)

### Phase 5: Developer experience

Build tooling:
- Development mode with UI inspector (overlay showing component boundaries, states)
- Hot reload for component modules (leverage BEAM hot code swapping)
- Testing framework (`TermUI.Test` module capturing render output, simulating events)
- Example applications (dashboard, text editor, file manager, chat client)
- Comprehensive documentation with guides and API reference

## Technical specifications summary

**Platform support**:
- Elixir 1.15+ (for modern features)
- OTP 28+ for native raw mode (fallback to port for OTP 26-27)
- Linux, macOS, Windows 10+ (with VT support)
- Tested on major terminals: Alacritty, Kitty, WezTerm, iTerm2, GNOME Terminal, Windows Terminal

**Dependencies**:
- None for core (pure Elixir on OTP 28)
- Optional cassowary port for complex layouts
- Optional Rustler NIF for performance-critical paths if profiling justifies

**Performance targets**:
- 60 FPS rendering (16ms frame time)
- Support UIs with 1000+ components
- Sub-10ms event routing
- Startup time under 100ms

**Feature coverage**:
- 16/256/true color with auto-detection
- Unicode/UTF-8 with proper width handling
- Mouse tracking (all modes, SGR encoding)
- Modern terminal features (bracketed paste, focus events, alternate screen)
- Cross-platform (Linux/macOS/Windows)
- Configurable backends (direct ANSI, terminfo, future: web via Phoenix LiveView)

## Why this architecture succeeds on BEAM

This design leverages BEAM's unique strengths while adopting proven TUI patterns.

**Fault tolerance**: Component crashes don't kill the application. A buggy custom widget restarts via supervisor while other UI elements continue functioning. This differs fundamentally from frameworks where any uncaught exception corrupts global state requiring full restart.

**Concurrency without complexity**: Process-per-component scales to hundreds of widgets without manual thread management. Message passing eliminates race conditions. Command tasks run in parallel (fetching data, performing calculations) without blocking UI updates. The scheduler ensures fair scheduling—no component starves others.

**Hot code reloading**: Update component logic during development without restarting the application. Preserve UI state across code changes. This dramatically improves iteration speed compared to compiled languages requiring full restarts.

**Distribution ready**: Build multi-user terminal applications trivially. Each connected SSH user runs a separate UI process tree. Shared state lives in backend processes. Distributed BEAM enables monitoring dashboards accessing remote nodes, collaborative editing over terminals, operator consoles for distributed systems.

**Functional state management**: Immutability prevents entire classes of state synchronization bugs. Time-travel debugging (save message history, replay events) becomes straightforward. Testing pure `handle_event` functions requires no mocking or setup.

**OTP patterns map naturally**: GenServer encapsulates component state. Supervisors organize UI hierarchies. GenStage handles high-volume event streams. Application framework provides lifecycle management. The framework aligns with Elixir idioms rather than fighting them.

The convergence of OTP 28's raw mode support, lessons from modern TUI frameworks, and BEAM's architectural strengths creates an opportunity to build a world-class terminal UI framework. By embracing direct mode programming, leveraging OTP patterns, and providing developer-friendly abstractions, Elixir can join Go, Rust, and Python in offering first-class terminal application development—while adding unique value through fault tolerance, concurrency, and the BEAM's distributed capabilities. The ecosystem is ready; the foundation exists; the design presented here provides a clear path forward.
