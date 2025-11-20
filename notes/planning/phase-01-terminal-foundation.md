# Phase 1: Terminal Foundation

## Overview

This phase establishes the foundational terminal infrastructure for TermUI, enabling direct control over terminal input and output using OTP 28's native raw mode support. We build the low-level terminal abstraction layer that handles raw mode activation, ANSI escape sequence generation and parsing, terminal capability detection, and cross-platform compatibility. The goal is to create a robust terminal interface that subsequent phases can build upon without concerning themselves with terminal protocol details.

By the end of this phase, we will have a working terminal backend that can activate raw mode via OTP 28's `shell.start_interactive({:noshell, :raw})`, generate escape sequences for cursor movement and styling, parse incoming key and mouse events through a state machine, detect terminal capabilities for graceful feature degradation, and support Linux, macOS, and Windows 10+ platforms. This establishes the technical foundation for all subsequent phases, particularly the rendering engine in Phase 2 and the component system in Phase 3.

The design prioritizes pure Elixir implementation leveraging OTP 28's native capabilities, avoiding NIFs or ports for terminal control. This ensures crash isolation, hot code reloading compatibility, and simpler deployment. The terminal layer exposes a clean API that abstracts platform differences while providing access to advanced terminal features when available.

---

## 1.1 Raw Mode Activation

- [x] **Section 1.1 Complete**

Raw mode activation transforms the terminal from its default line-buffered canonical mode into character-at-a-time mode where every keystroke is immediately available to the application. This is the fundamental requirement for interactive TUI applications—without raw mode, the terminal waits for Enter before delivering input, making real-time keyboard response impossible. OTP 28 provides native raw mode support through `shell.start_interactive({:noshell, :raw})`, eliminating the need for NIFs wrapping termios that previous Elixir TUI frameworks required.

In raw mode, the application takes full responsibility for input handling: no automatic echo (we must redraw input ourselves), no signal generation (Ctrl-C arrives as byte 3, not SIGINT), no special character processing (backspace arrives as byte 127, not deletion). We also disable output processing to prevent newline-to-CRLF translation that would interfere with precise cursor positioning. The terminal state must be carefully managed—failure to restore terminal settings on exit leaves the user's shell in an unusable state.

### 1.1.1 OTP 28 Raw Mode Integration

- [x] **Task 1.1.1 Complete**

Integrating with OTP 28's raw mode requires understanding the new shell subsystem architecture. The `shell.start_interactive/1` function configures terminal behavior at the Erlang runtime level, affecting all subsequent I/O operations. We wrap this in an Elixir API that handles initialization, provides callbacks for input events, and ensures proper cleanup. The integration must work correctly whether the application runs in a standalone BEAM instance or within a release.

- [x] 1.1.1.1 Implement `TermUI.Terminal.enable_raw_mode/0` function that calls `shell.start_interactive({:noshell, :raw})` and configures the terminal for TUI operation, returning `{:ok, terminal_state}` or `{:error, reason}`
- [x] 1.1.1.2 Implement terminal state structure tracking raw mode status, original terminal settings, and active features (mouse tracking, bracketed paste, alternate screen)
- [ ] 1.1.1.3 Implement input configuration setting VMIN=0 and VTIME=1 for non-blocking reads with 100ms timeout, enabling responsive polling without busy-waiting
- [x] 1.1.1.4 Implement `TermUI.Terminal.disable_raw_mode/1` function that restores original terminal settings, ensuring clean exit regardless of application state

### 1.1.2 Alternate Screen Buffer

- [x] **Task 1.1.2 Complete**

Modern terminals provide an alternate screen buffer that preserves the user's shell history while the TUI runs. Activating the alternate screen (`ESC[?1049h`) switches to a fresh buffer; deactivating (`ESC[?1049l`) restores the original content. This creates a clean separation between TUI output and the surrounding shell session. We must ensure alternate screen is always deactivated on exit, even during crashes, to prevent leaving users with a blank terminal.

- [x] 1.1.2.1 Implement `enter_alternate_screen/0` sending `ESC[?1049h` escape sequence to activate alternate buffer
- [x] 1.1.2.2 Implement `leave_alternate_screen/0` sending `ESC[?1049l` escape sequence to restore original buffer
- [x] 1.1.2.3 Integrate alternate screen management with terminal state, tracking activation status
- [x] 1.1.2.4 Implement cleanup hooks ensuring alternate screen is exited on application termination, crash, or signal

### 1.1.3 Terminal Restoration

- [x] **Task 1.1.3 Complete**

Terminal restoration is critical for user experience—a TUI that leaves the terminal in raw mode after exit makes the shell unusable. We implement multiple layers of protection: explicit cleanup functions, process exit traps, and OS signal handlers. The restoration sequence must reverse all terminal modifications: disable raw mode, exit alternate screen, show cursor, disable mouse tracking, and restore original terminal attributes.

- [x] 1.1.3.1 Implement process exit trap using `Process.flag(:trap_exit, true)` to catch exits and perform cleanup before termination
- [ ] 1.1.3.2 Implement signal handler registration for SIGTERM and SIGINT to ensure cleanup on forced termination
- [x] 1.1.3.3 Implement `TermUI.Terminal.restore/1` function that performs complete terminal restoration in correct sequence
- [x] 1.1.3.4 Implement crash recovery mechanism that detects unclean termination and offers terminal reset on next startup

### 1.1.4 Terminal Size Detection

- [x] **Task 1.1.4 Complete**

Terminal size (rows and columns) determines the available rendering area. We detect size at startup and monitor for resize events (SIGWINCH). Size changes trigger re-layout and re-render of the entire UI. The detection must work across platforms—Unix provides ioctl(TIOCGWINSZ), while Windows uses GetConsoleScreenBufferInfo. We also handle edge cases like running in non-terminal contexts (pipes, tests).

- [x] 1.1.4.1 Implement `get_terminal_size/0` returning `{:ok, {rows, cols}}` by querying terminal dimensions via appropriate system call
- [x] 1.1.4.2 Implement SIGWINCH handler that detects terminal resize events and notifies the application
- [x] 1.1.4.3 Implement size change callback system allowing components to register for resize notifications
- [ ] 1.1.4.4 Implement fallback size detection using cursor position query (`ESC[6n`) for terminals that don't support ioctl

### Unit Tests - Section 1.1

- [x] **Unit Tests 1.1 Complete**
- [x] Test raw mode activation returns success on OTP 28+ runtime
- [x] Test raw mode disabling restores original terminal settings correctly
- [x] Test alternate screen activation and deactivation sequence
- [x] Test terminal restoration on normal exit cleans up all modifications
- [x] Test terminal restoration on crash via exit trap
- [x] Test terminal size detection returns valid dimensions
- [x] Test resize event notification triggers registered callbacks
- [x] Test terminal operations fail gracefully in non-terminal contexts

---

## 1.2 ANSI Escape Sequence Generation

- [x] **Section 1.2 Complete**

ANSI escape sequences control terminal behavior through special character codes embedded in the output stream. Sequences beginning with ESC (0x1B) followed by control characters instruct the terminal to move the cursor, change colors, clear regions, and enable special modes. We implement a comprehensive sequence generator that produces correct codes for all operations while optimizing for minimal byte output. The generator abstracts the complexity of escape codes behind a semantic API—callers request "move cursor to row 5, column 10" rather than constructing raw byte sequences.

The VT100/ANSI X3.64 standard forms the foundation, with extensions for 256-color and true-color support, mouse tracking protocols, and modern terminal features like bracketed paste. Our generator produces the most efficient sequence for each operation—using relative cursor movement when cheaper than absolute positioning, compressing color specifications, and batching multiple operations when possible.

### 1.2.1 Cursor Control Sequences

- [x] **Task 1.2.1 Complete**

Cursor control is fundamental to TUI rendering. We generate sequences for absolute positioning (`ESC[{row};{col}H`), relative movement (up/down/left/right), and cursor visibility. The generator tracks current cursor position to enable optimization—moving one column right is cheaper as `ESC[C` (3 bytes) than absolute positioning (6+ bytes). We provide both low-level sequence generation and higher-level movement functions that choose optimal sequences automatically.

- [x] 1.2.1.1 Implement `cursor_position(row, col)` returning `ESC[{row};{col}H` sequence for absolute positioning (1-indexed)
- [x] 1.2.1.2 Implement relative movement functions `cursor_up(n)`, `cursor_down(n)`, `cursor_forward(n)`, `cursor_back(n)` with parameter omission when n=1
- [x] 1.2.1.3 Implement `cursor_show/0` and `cursor_hide/0` returning `ESC[?25h` and `ESC[?25l` sequences
- [x] 1.2.1.4 Implement `save_cursor/0` and `restore_cursor/0` returning `ESC[s` and `ESC[u` for cursor position stack operations

### 1.2.2 Screen Manipulation Sequences

- [x] **Task 1.2.2 Complete**

Screen manipulation sequences clear regions and scroll content. Clear operations range from entire screen (`ESC[2J`) to end-of-line (`ESC[K`). Scroll regions enable efficient content movement without redrawing—scrolling up by one line is much cheaper than redrawing the entire screen. We implement all standard clearing and scrolling operations with efficient parameterization.

- [x] 1.2.2.1 Implement screen clear functions: `clear_screen/0` (`ESC[2J`), `clear_screen_from_cursor/0` (`ESC[0J`), `clear_screen_to_cursor/0` (`ESC[1J`)
- [x] 1.2.2.2 Implement line clear functions: `clear_line/0` (`ESC[2K`), `clear_line_from_cursor/0` (`ESC[K`), `clear_line_to_cursor/0` (`ESC[1K`)
- [x] 1.2.2.3 Implement scroll region setting `set_scroll_region(top, bottom)` returning `ESC[{top};{bottom}r`
- [x] 1.2.2.4 Implement scroll operations `scroll_up(n)` and `scroll_down(n)` returning `ESC[{n}S` and `ESC[{n}T`

### 1.2.3 Color and Style Sequences

- [x] **Task 1.2.3 Complete**

Color sequences control text foreground and background colors plus text attributes like bold, italic, and underline. We support three color modes: basic 16-color (SGR 30-37, 40-47, 90-97, 100-107), 256-color palette (SGR 38;5;n and 48;5;n), and true-color RGB (SGR 38;2;r;g;b and 48;2;r;g;b). The generator selects the appropriate format based on terminal capabilities and optimizes by combining multiple attributes into single sequences.

- [x] 1.2.3.1 Implement basic color functions for 16-color mode with named colors (black, red, green, yellow, blue, magenta, cyan, white) and bright variants
- [x] 1.2.3.2 Implement `color_256(index)` for 256-color palette supporting both foreground and background
- [x] 1.2.3.3 Implement `color_rgb(r, g, b)` for true-color support with validation of RGB values (0-255)
- [x] 1.2.3.4 Implement text attribute functions: `bold/0`, `dim/0`, `italic/0`, `underline/0`, `blink/0`, `reverse/0`, `hidden/0`, `strikethrough/0`
- [x] 1.2.3.5 Implement `reset_style/0` returning `ESC[0m` and combined style function that merges multiple attributes into single SGR sequence

### 1.2.4 Special Mode Sequences

- [x] **Task 1.2.4 Complete**

Special modes enable advanced terminal features beyond basic text display. Bracketed paste mode wraps pasted text in escape sequences, distinguishing it from typed input. Focus events report when the terminal gains or loses focus. Application cursor keys change arrow key sequences for better compatibility. We generate activation and deactivation sequences for all supported modes.

- [x] 1.2.4.1 Implement bracketed paste mode `enable_bracketed_paste/0` (`ESC[?2004h`) and `disable_bracketed_paste/0` (`ESC[?2004l`)
- [x] 1.2.4.2 Implement focus event reporting `enable_focus_events/0` (`ESC[?1004h`) and `disable_focus_events/0` (`ESC[?1004l`)
- [x] 1.2.4.3 Implement application cursor keys mode `enable_app_cursor/0` (`ESC[?1h`) and `disable_app_cursor/0` (`ESC[?1l`)
- [x] 1.2.4.4 Implement mouse tracking mode sequences for X10 (`ESC[?9h`), normal (`ESC[?1000h`), button (`ESC[?1002h`), and all motion (`ESC[?1003h`) modes

### 1.2.5 Sequence Optimization

- [x] **Task 1.2.5 Complete**

Escape sequence optimization reduces terminal I/O overhead—critical for responsive TUIs, especially over SSH. We implement several optimizations: parameter omission (default parameters can be omitted), relative vs absolute movement (choose cheaper option based on current position), attribute combination (merge adjacent SGR sequences), and delta encoding (skip unchanged attributes). The optimizer processes sequence lists and produces minimal byte output.

- [x] 1.2.5.1 Implement parameter omission optimization removing default values (e.g., `ESC[1A` becomes `ESC[A`)
- [ ] 1.2.5.2 Implement cursor movement optimization choosing between absolute and relative positioning based on distance
- [x] 1.2.5.3 Implement SGR sequence combination merging adjacent style changes into single sequence (`ESC[1;31;44m` instead of three sequences)
- [ ] 1.2.5.4 Implement style delta tracking only emitting changed attributes from previous state

### Unit Tests - Section 1.2

- [x] **Unit Tests 1.2 Complete**
- [x] Test cursor positioning generates correct escape sequences for various row/column combinations
- [x] Test relative cursor movement generates correct sequences with parameter omission for n=1
- [x] Test screen clear functions generate correct sequences for all clear modes
- [x] Test 16-color, 256-color, and true-color sequences generate correctly formatted SGR codes
- [x] Test text attribute sequences generate correct SGR codes for all attributes
- [x] Test combined styles merge into single SGR sequence
- [x] Test special mode activation/deactivation generates correct sequences
- [x] Test sequence optimization reduces byte count without changing semantics

---

## 1.3 Escape Sequence Parser

- [ ] **Section 1.3 Complete**

The escape sequence parser transforms raw terminal input bytes into structured events (key presses, mouse actions, paste content, focus changes). Parsing terminal input is complex because escape sequences are variable-length—a single ESC byte might be the Escape key or the start of a multi-byte sequence like arrow keys or mouse events. We implement a state machine parser that handles all standard VT100/xterm sequences plus modern extensions for mouse tracking and special keys.

The parser must handle ambiguity: receiving ESC followed by nothing within a timeout indicates Escape key press; ESC followed by `[A` indicates Up arrow. We use a trie data structure for efficient sequence matching and timeout-based disambiguation. The parser produces semantic events (`%KeyEvent{key: :up, modifiers: []}`) rather than raw sequences, insulating higher layers from terminal protocol details.

### 1.3.1 Input Event Data Structures

- [ ] **Task 1.3.1 Complete**

We define event structs representing all possible terminal input events. Key events include the key identifier (character, special key name, or keycode) plus modifiers (Ctrl, Alt, Shift). Mouse events include action (press, release, motion), button, coordinates, and modifiers. Other events cover paste content, focus changes, and resize signals. These structs form the public API—all input handling works with these types.

- [ ] 1.3.1.1 Define `%KeyEvent{key: atom | char, modifiers: [atom]}` struct for keyboard input with modifier tracking
- [ ] 1.3.1.2 Define `%MouseEvent{action: atom, button: atom, x: integer, y: integer, modifiers: [atom]}` struct for mouse input
- [ ] 1.3.1.3 Define `%PasteEvent{content: String.t()}` struct for bracketed paste content
- [ ] 1.3.1.4 Define `%FocusEvent{focused: boolean}` struct for focus gained/lost events
- [ ] 1.3.1.5 Define `%ResizeEvent{rows: integer, cols: integer}` struct for terminal size changes

### 1.3.2 State Machine Parser

- [ ] **Task 1.3.2 Complete**

The parser state machine tracks position within potential escape sequences. States include: Ground (normal input), Escape (received ESC), CSI (received ESC[), SS3 (received ESCO), and various parameter-collecting states. Transitions occur on each input byte, accumulating parameters until sequence completion. Invalid sequences return to Ground with accumulated bytes emitted as literal input.

- [ ] 1.3.2.1 Implement parser state enum with Ground, Escape, CSI, SS3, DCS, OSC states and transitions
- [ ] 1.3.2.2 Implement state transition logic processing each input byte and updating parser state
- [ ] 1.3.2.3 Implement parameter accumulation for CSI sequences collecting numeric parameters separated by semicolons
- [ ] 1.3.2.4 Implement timeout handling for ambiguous sequences (ESC alone vs ESC+sequence) using configurable timeout (default 50ms)

### 1.3.3 Key Sequence Recognition

- [ ] **Task 1.3.3 Complete**

Key sequences map escape codes to semantic key events. Arrow keys use CSI sequences (`ESC[A` through `ESC[D`). Function keys use SS3 (`ESCOP` through `ESCO[`) or CSI (`ESC[15~` through `ESC[24~`) depending on terminal. Modified keys add parameters (`ESC[1;5A` for Ctrl+Up). We build a trie from sequence bytes to key events for O(k) lookup where k is sequence length.

- [ ] 1.3.3.1 Implement sequence trie data structure mapping byte sequences to key events
- [ ] 1.3.3.2 Populate trie with arrow key sequences (Up/Down/Left/Right) including modified variants
- [ ] 1.3.3.3 Populate trie with function key sequences (F1-F12) for both SS3 and CSI formats
- [ ] 1.3.3.4 Populate trie with special key sequences (Home, End, Insert, Delete, PageUp, PageDown)
- [ ] 1.3.3.5 Implement modifier extraction from CSI parameters (1=none, 2=Shift, 3=Alt, 4=Shift+Alt, 5=Ctrl, etc.)

### 1.3.4 Mouse Event Parsing

- [ ] **Task 1.3.4 Complete**

Mouse events arrive in various formats depending on the tracking mode. X10 mode uses `ESC[M` followed by button+32, column+32, row+32 (limited to 223 columns). SGR extended mode (`ESC[<{button};{col};{row}M/m`) uses decimal encoding with no coordinate limit and distinguishes press from release. We parse both formats, preferring SGR when available for its superior encoding.

- [ ] 1.3.4.1 Implement X10 mouse event parsing extracting button, column, row from `ESC[M` sequences
- [ ] 1.3.4.2 Implement SGR mouse event parsing extracting parameters from `ESC[<` sequences with M (press) or m (release) terminator
- [ ] 1.3.4.3 Implement button decoding mapping encoded values to button names (left, middle, right, wheel-up, wheel-down)
- [ ] 1.3.4.4 Implement modifier extraction for mouse events (Shift, Alt, Ctrl held during click)
- [ ] 1.3.4.5 Implement motion event detection distinguishing move events from click events

### 1.3.5 Bracketed Paste Parsing

- [ ] **Task 1.3.5 Complete**

Bracketed paste mode wraps pasted content in `ESC[200~` (start) and `ESC[201~` (end) markers. This allows the application to distinguish pasted text from typed input—important for avoiding auto-indent cascades in editors and preventing pasted shell commands from executing line-by-line. The parser accumulates content between markers and emits a single paste event.

- [ ] 1.3.5.1 Implement paste start detection recognizing `ESC[200~` sequence and entering paste accumulation mode
- [ ] 1.3.5.2 Implement paste content accumulation collecting all bytes until end marker
- [ ] 1.3.5.3 Implement paste end detection recognizing `ESC[201~` sequence and emitting PasteEvent
- [ ] 1.3.5.4 Implement paste timeout handling for malformed paste sequences (start without end)

### 1.3.6 Parser API

- [ ] **Task 1.3.6 Complete**

The parser exposes a clean API for processing input bytes into events. The main function accepts a byte buffer and returns parsed events plus remaining unparsed bytes (for incomplete sequences). The parser maintains state between calls for handling sequences split across read boundaries. We provide both synchronous parsing and streaming modes for different use cases.

- [ ] 1.3.6.1 Implement `parse(bytes, state)` returning `{events, remaining_bytes, new_state}` for incremental parsing
- [ ] 1.3.6.2 Implement `new_parser/0` creating initial parser state for fresh parsing context
- [ ] 1.3.6.3 Implement `reset_parser/1` clearing parser state while preserving configuration
- [ ] 1.3.6.4 Implement streaming mode API with callback-based event delivery for GenServer integration

### Unit Tests - Section 1.3

- [ ] **Unit Tests 1.3 Complete**
- [ ] Test single character parsing produces correct KeyEvent for printable ASCII
- [ ] Test Ctrl+key combinations produce KeyEvent with ctrl modifier
- [ ] Test arrow key sequences parse to correct directional KeyEvents
- [ ] Test function key sequences (F1-F12) parse correctly in both SS3 and CSI formats
- [ ] Test modifier key combinations (Ctrl+Shift+Up) extract all modifiers correctly
- [ ] Test X10 mouse event parsing produces correct MouseEvent coordinates and button
- [ ] Test SGR mouse event parsing handles extended coordinates and press/release distinction
- [ ] Test bracketed paste parsing accumulates content and produces single PasteEvent
- [ ] Test timeout handling disambiguates bare ESC from escape sequence start
- [ ] Test parser state persists correctly across split sequences

---

## 1.4 Terminal Capability Detection

- [ ] **Section 1.4 Complete**

Terminal capability detection determines which features the current terminal supports, enabling graceful degradation on limited terminals while exploiting advanced features when available. Capabilities include color support (16, 256, or true-color), Unicode handling, mouse tracking, bracketed paste, focus events, and special character rendering. We query capabilities through multiple methods: environment variables ($TERM, $COLORTERM), terminfo database, and direct terminal queries.

Detection runs at startup and caches results for the session. The capability system exposes boolean feature flags (`supports_true_color?`, `supports_mouse?`) that higher layers use to select appropriate rendering strategies. When features are unavailable, we provide fallbacks—true-color falls back to 256-color to 16-color to monochrome, ensuring the application runs everywhere while looking best where possible.

### 1.4.1 Environment Variable Detection

- [ ] **Task 1.4.1 Complete**

Environment variables provide hints about terminal capabilities without requiring terminal queries. $TERM identifies the terminal type (xterm-256color, screen, linux). $COLORTERM indicates color support ("truecolor", "24bit"). $TERM_PROGRAM identifies the specific emulator (iTerm.app, Apple_Terminal). We parse these variables to establish baseline capability assumptions before more expensive detection methods.

- [ ] 1.4.1.1 Implement $TERM parsing extracting terminal type and color capability hints (256color, truecolor suffixes)
- [ ] 1.4.1.2 Implement $COLORTERM parsing detecting true-color support ("truecolor" or "24bit" values)
- [ ] 1.4.1.3 Implement $TERM_PROGRAM parsing identifying specific terminal emulators with known capabilities
- [ ] 1.4.1.4 Implement $LC_ALL/$LANG parsing detecting UTF-8 support for Unicode rendering

### 1.4.2 Terminfo Database Query

- [ ] **Task 1.4.2 Complete**

The terminfo database provides detailed terminal capability information compiled from terminfo source files. Capabilities include max_colors, set_a_foreground, key_f1, etc. We query terminfo via `infocmp` or by reading compiled terminfo files directly. This provides authoritative capability data but requires proper terminfo installation and correct $TERM value.

- [ ] 1.4.2.1 Implement terminfo query via `infocmp` command parsing output for capability values
- [ ] 1.4.2.2 Implement direct terminfo file reading from /usr/share/terminfo or ~/.terminfo locations
- [ ] 1.4.2.3 Implement capability extraction for colors (max_colors), cursor keys, and function key sequences
- [ ] 1.4.2.4 Implement fallback when terminfo unavailable defaulting to conservative VT100 capabilities

### 1.4.3 Dynamic Capability Queries

- [ ] **Task 1.4.3 Complete**

Some capabilities can only be determined by querying the terminal directly. Device Attributes query (`ESC[c`) returns terminal identification. Color query (`ESC]4;{index};?ST`) returns palette colors. Terminal size query via TIOCGWINSZ ioctl. These queries provide runtime capability detection but require careful timeout handling for terminals that don't respond.

- [ ] 1.4.3.1 Implement Primary Device Attributes query (`ESC[c`) parsing response for terminal identification
- [ ] 1.4.3.2 Implement true-color support detection via color query and response parsing
- [ ] 1.4.3.3 Implement terminal size query via ioctl(TIOCGWINSZ) with fallback to cursor position method
- [ ] 1.4.3.4 Implement query timeout handling (default 100ms) with conservative fallback on no response

### 1.4.4 Capability Registry

- [ ] **Task 1.4.4 Complete**

The capability registry stores detected capabilities in a structured format accessible throughout the application. We cache results at startup to avoid repeated detection overhead. The registry provides typed accessors for each capability category and supports runtime capability updates (e.g., when switching terminals via SSH).

- [ ] 1.4.4.1 Implement capability struct holding all detected features as typed fields
- [ ] 1.4.4.2 Implement `detect_capabilities/0` running all detection methods and populating registry
- [ ] 1.4.4.3 Implement capability accessors: `supports_true_color?/0`, `supports_256_color?/0`, `supports_mouse?/0`, `supports_bracketed_paste?/0`
- [ ] 1.4.4.4 Implement capability persistence in ETS for fast concurrent access from multiple processes

### 1.4.5 Graceful Degradation

- [ ] **Task 1.4.5 Complete**

Graceful degradation ensures the application works on any terminal by falling back to simpler features when advanced ones are unavailable. We implement fallback chains: true-color → 256-color → 16-color → monochrome for colors, Unicode box-drawing → ASCII art for borders, SGR mouse → no mouse for interaction. The degradation is automatic and transparent to application code.

- [ ] 1.4.5.1 Implement color fallback chain with automatic color approximation (nearest 256-color for RGB, nearest 16 for 256)
- [ ] 1.4.5.2 Implement character fallback for box-drawing characters to ASCII equivalents (+, -, |)
- [ ] 1.4.5.3 Implement feature disable for unsupported modes (mouse tracking, bracketed paste)
- [ ] 1.4.5.4 Implement capability-aware API that automatically selects best available implementation

### Unit Tests - Section 1.4

- [ ] **Unit Tests 1.4 Complete**
- [ ] Test environment variable parsing extracts correct capability hints from $TERM variants
- [ ] Test $COLORTERM parsing correctly identifies true-color support
- [ ] Test terminfo query extracts max_colors and key sequences correctly
- [ ] Test terminfo fallback provides VT100 baseline when database unavailable
- [ ] Test dynamic capability queries parse terminal responses correctly
- [ ] Test query timeout handling returns fallback values on no response
- [ ] Test capability registry stores and retrieves all capability types
- [ ] Test color fallback produces visually similar approximations
- [ ] Test character fallback produces readable ASCII alternatives

---

## 1.5 Cross-Platform Compatibility

- [ ] **Section 1.5 Complete**

Cross-platform compatibility ensures TermUI works correctly on Linux, macOS, and Windows 10+. While Linux and macOS share POSIX terminal semantics, Windows historically used a completely different console API. Modern Windows 10 (1511+) supports VT sequences via Console Virtual Terminal Sequences, and Windows Terminal provides full modern terminal features. We implement platform detection and abstraction to provide a unified API while handling platform-specific details internally.

The compatibility layer handles: terminal initialization differences, input handling variations, signal handling (Unix signals vs Windows console events), and path/filesystem differences. Testing must cover all supported platforms to ensure consistent behavior. CI/CD includes matrix testing across platform versions.

### 1.5.1 Platform Detection

- [ ] **Task 1.5.1 Complete**

Platform detection identifies the current operating system and version to select appropriate implementations. We detect platform at compile-time where possible (using Elixir's module attributes) and runtime for dynamic selection. Detection includes OS family (Unix, Windows), specific OS (Linux, macOS, Windows), OS version, and whether running in Windows Subsystem for Linux (WSL).

- [ ] 1.5.1.1 Implement `platform/0` returning `:linux`, `:macos`, `:windows`, or `:unknown` based on OS family
- [ ] 1.5.1.2 Implement `os_version/0` returning parsed version tuple for version-dependent features
- [ ] 1.5.1.3 Implement `wsl?/0` detecting Windows Subsystem for Linux environment
- [ ] 1.5.1.4 Implement platform-specific module selection using behaviour pattern for clean abstraction

### 1.5.2 Unix Terminal Handling

- [ ] **Task 1.5.2 Complete**

Unix (Linux and macOS) terminal handling uses standard POSIX termios and signal APIs. We implement termios manipulation through Erlang's native mechanisms (OTP 28 raw mode), signal handling via Erlang's signal server, and ioctl for terminal size queries. macOS-specific handling includes differences in terminal.app capabilities versus iTerm2.

- [ ] 1.5.2.1 Implement Unix raw mode activation using OTP 28's `shell.start_interactive/1`
- [ ] 1.5.2.2 Implement Unix signal handling for SIGWINCH (resize), SIGTERM, SIGINT via Erlang signal server
- [ ] 1.5.2.3 Implement ioctl(TIOCGWINSZ) wrapper for terminal size query
- [ ] 1.5.2.4 Implement Unix-specific capability detection for Linux terminals vs macOS terminal variants

### 1.5.3 Windows Terminal Handling

- [ ] **Task 1.5.3 Complete**

Windows terminal handling enables VT sequence support via SetConsoleMode with ENABLE_VIRTUAL_TERMINAL_PROCESSING flag. We also handle input processing (ENABLE_VIRTUAL_TERMINAL_INPUT) and window size changes via console events. For pre-Windows 10 systems, we provide an error message since VT support is required. Windows Terminal and ConPTY provide the most complete experience.

- [ ] 1.5.3.1 Implement Windows console mode detection checking for VT sequence support availability
- [ ] 1.5.3.2 Implement SetConsoleMode wrapper enabling ENABLE_VIRTUAL_TERMINAL_PROCESSING and ENABLE_VIRTUAL_TERMINAL_INPUT
- [ ] 1.5.3.3 Implement Windows console event handling for window size changes and focus events
- [ ] 1.5.3.4 Implement clear error messaging for unsupported Windows versions (pre-1511)

### 1.5.4 Platform Abstraction Layer

- [ ] **Task 1.5.4 Complete**

The platform abstraction layer provides a unified API that delegates to platform-specific implementations. This uses Elixir behaviours with implementations for each platform. Applications use the abstract API without platform conditionals. The layer handles: raw mode enable/disable, terminal size, signal registration, and capability detection.

- [ ] 1.5.4.1 Define `TermUI.Platform` behaviour with callbacks for all platform-specific operations
- [ ] 1.5.4.2 Implement `TermUI.Platform.Unix` module for Linux and macOS
- [ ] 1.5.4.3 Implement `TermUI.Platform.Windows` module for Windows 10+
- [ ] 1.5.4.4 Implement automatic platform selection loading correct implementation at startup

### Unit Tests - Section 1.5

- [ ] **Unit Tests 1.5 Complete**
- [ ] Test platform detection returns correct platform identifier on each OS
- [ ] Test OS version parsing handles various version string formats
- [ ] Test WSL detection correctly identifies WSL vs native Linux
- [ ] Test Unix raw mode activation works on Linux and macOS
- [ ] Test Unix signal handling receives SIGWINCH correctly
- [ ] Test Windows VT mode activation enables escape sequence support (Windows only)
- [ ] Test Windows console event handling receives size change events (Windows only)
- [ ] Test platform abstraction layer routes to correct implementation

---

## 1.6 Integration Tests

- [ ] **Section 1.6 Complete**

Integration tests validate that all terminal foundation components work together correctly. We test complete workflows: initialize terminal → enable raw mode → render content → handle input → restore terminal. These tests run on actual terminals (not mocks) when possible, using PTY allocation for CI environments. Integration tests catch interaction bugs that unit tests miss and validate real-world terminal behavior.

### 1.6.1 Terminal Lifecycle Testing

- [ ] **Task 1.6.1 Complete**

We test the complete terminal lifecycle from initialization through cleanup. Tests verify that raw mode enables correctly, alternate screen activates, input events parse correctly, and terminal restores on exit. We test both normal termination and crash recovery paths to ensure robust cleanup.

- [ ] 1.6.1.1 Test complete initialization sequence: detect capabilities → enable raw mode → enter alternate screen → hide cursor
- [ ] 1.6.1.2 Test clean shutdown sequence: show cursor → leave alternate screen → disable raw mode → restore settings
- [ ] 1.6.1.3 Test crash recovery: simulate crash after partial initialization and verify terminal restoration
- [ ] 1.6.1.4 Test reinitialization: verify terminal can be re-enabled after clean shutdown

### 1.6.2 Input/Output Round-Trip Testing

- [ ] **Task 1.6.2 Complete**

Round-trip tests verify that output sequences produce expected terminal state and input bytes parse to expected events. We use a PTY pair where we can both send input and observe output. Tests verify cursor positioning accuracy, color rendering, and event parsing fidelity.

- [ ] 1.6.2.1 Test cursor positioning round-trip: move cursor, query position, verify coordinates match
- [ ] 1.6.2.2 Test key event round-trip: send key sequence bytes, verify parsed event matches expected
- [ ] 1.6.2.3 Test mouse event round-trip: send mouse sequence, verify parsed coordinates and button
- [ ] 1.6.2.4 Test style round-trip: set style, render text, verify visual appearance (where testable)

### 1.6.3 Capability Detection Accuracy

- [ ] **Task 1.6.3 Complete**

We validate that capability detection accurately reflects terminal features. Tests run on various terminal emulators (xterm, iTerm2, Alacritty, Windows Terminal) verifying detected capabilities match known terminal features. We test both positive cases (feature detected when present) and negative cases (feature not detected when absent).

- [ ] 1.6.3.1 Test color capability detection matches known terminal capabilities for common emulators
- [ ] 1.6.3.2 Test mouse support detection correctly identifies terminals with/without mouse tracking
- [ ] 1.6.3.3 Test Unicode detection matches terminal Unicode rendering capability
- [ ] 1.6.3.4 Test capability queries timeout correctly on non-responding terminals

### 1.6.4 Cross-Platform Integration

- [ ] **Task 1.6.4 Complete**

Cross-platform integration tests verify consistent behavior across operating systems. Tests run in CI matrix covering Linux (Ubuntu), macOS, and Windows. We verify that the same application code produces equivalent behavior on all platforms despite internal implementation differences.

- [ ] 1.6.4.1 Test terminal initialization succeeds on all supported platforms
- [ ] 1.6.4.2 Test input parsing produces consistent events across platforms for same key sequences
- [ ] 1.6.4.3 Test terminal size detection returns valid dimensions on all platforms
- [ ] 1.6.4.4 Test cleanup restores terminal correctly on all platforms

---

## Success Criteria

1. **Raw Mode Support**: OTP 28 native raw mode enables character-at-a-time input on all supported platforms
2. **Escape Sequence Generation**: Complete coverage of cursor control, colors (16/256/true), and special modes with optimization
3. **Event Parsing**: Accurate parsing of all standard key sequences, mouse events (X10 and SGR), and paste events
4. **Capability Detection**: Accurate detection via environment, terminfo, and queries with 95%+ accuracy on tested terminals
5. **Cross-Platform**: Works correctly on Linux, macOS, and Windows 10+ with platform-specific optimizations
6. **Terminal Safety**: 100% terminal restoration on normal exit, crash, and signal termination
7. **Test Coverage**: 85% test coverage with comprehensive unit and integration tests

## Provides Foundation

This phase establishes the infrastructure for:
- **Phase 2**: Rendering engine building on escape sequence generation and terminal capabilities
- **Phase 3**: Component system using event parsing for input handling
- **Phase 4**: Layout system using terminal size detection for constraint solving
- **Phase 5**: Event system building on parsed events and input handling
- All future phases relying on terminal abstraction for output and input

## Key Outputs

- Working OTP 28 raw mode integration with clean initialization/cleanup
- Comprehensive ANSI escape sequence generator with optimization
- Complete event parser handling keys, mouse, paste, and focus events
- Terminal capability detection with graceful degradation
- Cross-platform abstraction layer for Linux, macOS, and Windows
- Terminal safety guarantees with crash recovery
- Comprehensive test suite covering all terminal operations
- API documentation for terminal foundation modules
