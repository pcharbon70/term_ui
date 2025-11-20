# Phase 2: Rendering Engine

## Overview

This phase implements the rendering engine that bridges the component system with terminal output. The renderer maintains a virtual screen buffer, calculates differences from the previous frame, and emits minimal escape sequences to update the terminal display. This differential rendering approach—pioneered by curses in the 1970s and refined by modern TUI frameworks—minimizes I/O operations for responsive performance, especially over SSH or on resource-constrained systems.

By the end of this phase, we will have a working rendering engine with ETS-based double buffering that supports concurrent access, a diff algorithm that identifies changed regions and skips unchanged content, cursor optimization that chooses the cheapest movement strategy, escape sequence batching that reduces system calls, and a framerate limiter that caps updates at 60 FPS (configurable). The engine exposes a clean API where components simply set cells in the buffer, and the renderer handles all optimization transparently.

The design leverages BEAM's strengths: ETS tables provide fast concurrent reads/writes without process message overhead, GenServer manages the render loop and timing, and process isolation ensures renderer crashes don't affect component state. The renderer integrates with Phase 1's escape sequence generator and capability system to produce correct output for any terminal.

---

## 2.1 Cell and Buffer Data Structures

- [x] **Section 2.1 Complete**

The fundamental data structures represent individual screen cells and the complete screen buffer. A cell contains a character (grapheme cluster), foreground and background colors, and style attributes (bold, italic, etc.). The buffer is a two-dimensional array of cells indexed by row and column. We optimize these structures for both memory efficiency and fast access patterns—cells are small fixed-size structures, and buffers use ETS ordered_set tables for O(log n) access.

The cell representation must handle Unicode correctly: a cell contains a grapheme cluster (possibly multiple codepoints), tracks display width for East Asian characters (2 columns), and supports combining characters. Style information uses compact encoding—colors as integers or RGB tuples, attributes as a bitfield. The buffer structure supports efficient region operations (clear rectangle, copy region) needed for scrolling and partial updates.

### 2.1.1 Cell Structure

- [x] **Task 2.1.1 Complete**

The cell structure holds all information needed to render a single character position. We balance between completeness (supporting all terminal features) and efficiency (small memory footprint, fast comparison). Cells are immutable—updates create new cells, enabling efficient diffing by reference comparison when unchanged.

- [x] 2.1.1.1 Define `%Cell{char: String.t(), fg: color(), bg: color(), attrs: MapSet.t()}` struct with compact representation
- [x] 2.1.1.2 Implement color type supporting `:default`, named colors (`:red`), 256-color integers (0-255), and RGB tuples (`{r, g, b}`)
- [x] 2.1.1.3 Implement attribute set for style modifiers: `:bold`, `:dim`, `:italic`, `:underline`, `:blink`, `:reverse`, `:hidden`, `:strikethrough`
- [x] 2.1.1.4 Implement cell comparison function for efficient diffing checking character, colors, and attributes
- [x] 2.1.1.5 Implement `Cell.empty/0` returning default empty cell (space, default colors, no attributes)

### 2.1.2 Display Width Handling

- [x] **Task 2.1.2 Complete**

Display width determines how many columns a character occupies. Most characters are single-width, but East Asian characters (CJK) are double-width, and combining characters (accents) are zero-width. Correct width handling is essential for proper cursor positioning and layout. We use `wcwidth` algorithm to calculate display width and handle edge cases.

- [x] 2.1.2.1 Implement `display_width/1` function returning column count for a grapheme cluster using Unicode East Asian Width property
- [x] 2.1.2.2 Implement double-width character handling storing character in first cell, placeholder in second cell
- [x] 2.1.2.3 Implement combining character handling merging combining marks with base character in single cell
- [x] 2.1.2.4 Implement text width calculation summing display widths for string layout

### 2.1.3 Style Structure

- [x] **Task 2.1.3 Complete**

Styles encapsulate visual presentation: colors and text attributes. We provide a Style struct that can be built incrementally and merged with other styles. Style inheritance allows components to specify partial styles that inherit from parent. The style system integrates with Phase 1's capability detection to automatically downgrade colors on limited terminals.

- [x] 2.1.3.1 Define `%Style{fg: color(), bg: color(), attrs: MapSet.t()}` struct with defaults for unset properties
- [x] 2.1.3.2 Implement style builder functions: `Style.new() |> Style.fg(:red) |> Style.bold()` for fluent construction
- [x] 2.1.3.3 Implement `Style.merge/2` combining styles with later style overriding earlier for cascading
- [x] 2.1.3.4 Implement style to cell conversion applying style to create styled cells

### 2.1.4 Buffer Structure

- [x] **Task 2.1.4 Complete**

The buffer holds all cells for the entire screen. We use ETS ordered_set tables keyed by `{row, col}` tuples for O(log n) access and efficient range operations. The buffer tracks dimensions and provides operations for cell access, region clearing, and content copying. Two buffers exist simultaneously for double-buffering: current (being built) and previous (last rendered).

- [x] 2.1.4.1 Implement `Buffer.new(rows, cols)` creating ETS table and initializing with empty cells
- [x] 2.1.4.2 Implement `Buffer.get_cell(buffer, row, col)` returning cell at position with bounds checking
- [x] 2.1.4.3 Implement `Buffer.set_cell(buffer, row, col, cell)` updating cell at position
- [x] 2.1.4.4 Implement `Buffer.clear_region(buffer, x, y, width, height)` filling rectangle with empty cells
- [x] 2.1.4.5 Implement `Buffer.resize(buffer, new_rows, new_cols)` handling terminal resize with content preservation

### Unit Tests - Section 2.1

- [x] **Unit Tests 2.1 Complete**
- [x] Test cell creation with various color and attribute combinations
- [x] Test cell comparison detects differences in char, colors, and attributes
- [x] Test display width calculation for ASCII, CJK, and combining characters
- [x] Test style builder produces correct style structs with all properties
- [x] Test style merging correctly overrides properties from base style
- [x] Test buffer creation initializes all cells to empty
- [x] Test buffer get/set operations maintain cell values correctly
- [x] Test buffer clear_region fills specified area with empty cells
- [x] Test buffer resize preserves existing content where possible

---

## 2.2 ETS-Based Double Buffering

- [x] **Section 2.2 Complete**

Double buffering uses two screen buffers: the current buffer being populated and the previous buffer showing the last rendered frame. Components write to the current buffer, then the renderer diffs current against previous to identify changes. After rendering, buffers swap roles. ETS tables provide concurrent access—multiple component processes can write cells simultaneously without message-passing bottlenecks.

ETS `:ordered_set` tables enable efficient iteration in row-major order for sequential terminal output. We use `:public` access allowing any process to read/write, with the renderer GenServer owning the tables to ensure cleanup. The double-buffer swap is atomic—we swap references, not content—making buffer switching instantaneous.

### 2.2.1 Buffer Manager

- [x] **Task 2.2.1 Complete**

The buffer manager GenServer owns the ETS tables and coordinates buffer operations. It tracks current and previous buffer references, handles buffer swapping, and manages table lifecycle. The manager exposes a simple API: get current buffer for writing, trigger render, handle resize events that require buffer reallocation.

- [x] 2.2.1.1 Implement `TermUI.BufferManager` GenServer owning both buffer ETS tables
- [x] 2.2.1.2 Implement `init/1` callback creating initial buffers based on terminal size
- [x] 2.2.1.3 Implement `get_current_buffer/0` returning reference to current buffer for component writes
- [x] 2.2.1.4 Implement `swap_buffers/0` atomically swapping current and previous buffer references
- [x] 2.2.1.5 Implement `handle_resize/2` callback reallocating buffers on terminal size change

### 2.2.2 Concurrent Write Support

- [x] **Task 2.2.2 Complete**

Multiple processes (components) write to the buffer concurrently. ETS provides atomic single-key operations—concurrent writes to different cells are safe. We document the concurrency model: cell writes are atomic but not ordered, overlapping writes have undefined winner. Components should write non-overlapping regions for deterministic results.

- [x] 2.2.2.1 Implement concurrent cell write with `ets:insert/2` ensuring atomic operation
- [x] 2.2.2.2 Document concurrency semantics: last-writer-wins for same cell, no ordering guarantees
- [x] 2.2.2.3 Implement batch write `Buffer.set_cells(buffer, cells)` for efficient multi-cell updates
- [x] 2.2.2.4 Implement region locking mechanism (optional) for components requiring write ordering

### 2.2.3 Buffer Initialization and Clearing

- [x] **Task 2.2.3 Complete**

Buffers must be initialized to a known state before use and cleared between frames when needed. Initialization fills all cells with empty (space, default colors). Clearing resets regions without reallocating the entire buffer. We optimize clearing for common patterns: full screen clear, row clear, rectangular region clear.

- [x] 2.2.3.1 Implement efficient full buffer initialization using `ets:insert/2` with cell list
- [x] 2.2.3.2 Implement row clear `Buffer.clear_row(buffer, row)` for single-row reset
- [x] 2.2.3.3 Implement column clear `Buffer.clear_col(buffer, col)` for single-column reset
- [x] 2.2.3.4 Implement selective initialization clearing only changed regions for faster reset

### 2.2.4 Buffer Lifecycle Management

- [x] **Task 2.2.4 Complete**

Buffer lifecycle includes creation, resize, and cleanup. ETS tables persist until explicitly deleted or owning process dies. We ensure proper cleanup on renderer shutdown to avoid orphaned tables. Resize events require careful handling—we must preserve content where possible while adapting to new dimensions.

- [x] 2.2.4.1 Implement buffer cleanup in GenServer `terminate/2` callback deleting ETS tables
- [x] 2.2.4.2 Implement resize content preservation copying cell data from old to new buffer
- [x] 2.2.4.3 Implement resize content clipping truncating content that exceeds new dimensions
- [x] 2.2.4.4 Implement resize event coordination notifying components of dimension changes

### Unit Tests - Section 2.2

- [x] **Unit Tests 2.2 Complete**
- [x] Test buffer manager creates two ETS tables on initialization
- [x] Test get_current_buffer returns valid buffer reference
- [x] Test swap_buffers exchanges current and previous buffer references
- [x] Test concurrent writes from multiple processes don't corrupt buffer
- [x] Test batch write updates multiple cells atomically
- [x] Test buffer clearing resets all cells to empty state
- [x] Test resize preserves content within new dimensions
- [x] Test cleanup deletes ETS tables preventing memory leaks

---

## 2.3 Diff Algorithm

- [x] **Section 2.3 Complete**

The diff algorithm compares current and previous buffers to identify changed cells, producing a minimal set of update operations. We iterate row-by-row comparing cells and tracking change spans—contiguous changed cells in a row that can be rendered with a single cursor move. The algorithm balances between finding optimal diffs and maintaining fast O(n) performance where n is total cells.

The diff output is a sequence of render operations: position cursor, emit styled text, repeat. We optimize for common patterns: mostly-unchanged screens (skip most cells), localized changes (single-widget updates), and full redraws (avoid per-cell overhead). The algorithm handles wide characters correctly, ensuring partial updates don't corrupt double-width character display.

### 2.3.1 Cell Comparison

- [x] **Task 2.3.1 Complete**

Cell comparison determines if two cells are visually identical. We compare character content, foreground color, background color, and all attributes. Comparison must be efficient since we compare thousands of cells per frame. We use structural comparison optimized for the common case (cells unchanged).

- [x] 2.3.1.1 Implement `Cell.equal?/2` comparing all cell properties for visual equality
- [x] 2.3.1.2 Optimize comparison for common case using early-exit on first difference
- [x] 2.3.1.3 Implement hash-based comparison option caching cell hashes for repeated comparisons
- [x] 2.3.1.4 Handle special cases: different color representations (named vs RGB) that appear identical

### 2.3.2 Row-Based Diffing

- [x] **Task 2.3.2 Complete**

We diff row-by-row for efficient sequential output—cursor movement between rows is cheap, and terminals optimize for row-wise output. For each row, we find spans of changed cells and generate render operations. Unchanged rows are skipped entirely. We track whether the row is completely unchanged, partially changed, or completely new.

- [x] 2.3.2.1 Implement `diff_row/3` comparing corresponding rows from current and previous buffers
- [x] 2.3.2.2 Implement change span detection grouping contiguous changed cells within a row
- [x] 2.3.2.3 Implement row skip optimization for completely unchanged rows
- [x] 2.3.2.4 Implement row cache invalidation tracking which rows have been modified since last render

### 2.3.3 Change Span Optimization

- [x] **Task 2.3.3 Complete**

Change spans represent contiguous changed cells that can be rendered together. We optimize span boundaries based on cursor movement cost—sometimes it's cheaper to render unchanged cells than to move cursor around them. We merge adjacent small spans when the gap is small, and split large spans when beneficial for style changes.

- [x] 2.3.3.1 Implement span boundary calculation minimizing total output bytes (cursor moves + content)
- [x] 2.3.3.2 Implement span merging combining adjacent spans when gap is smaller than cursor move cost
- [x] 2.3.3.3 Implement span splitting at style changes to optimize SGR sequence output
- [x] 2.3.3.4 Implement span generation producing cursor position and styled text for each span

### 2.3.4 Wide Character Handling

- [x] **Task 2.3.4 Complete**

Double-width characters require special handling during diffing. If either cell of a wide character changes, both must be redrawn to avoid display corruption. We detect wide characters and ensure their pairs are included in change spans. Partial overwrite of wide characters must clear both cells.

- [x] 2.3.4.1 Implement wide character detection checking for double-width characters in cells
- [x] 2.3.4.2 Implement pair inclusion ensuring both cells of wide character are in same change span
- [x] 2.3.4.3 Implement overwrite detection flagging when single-width overwrites half of wide character
- [x] 2.3.4.4 Implement wide character clearing emitting space pair to erase corrupted wide characters

### 2.3.5 Diff Output Generation

- [x] **Task 2.3.5 Complete**

The diff output is a list of render operations that the escape sequence generator converts to terminal output. Operations include: move cursor, set style, emit text, reset style. We optimize operation ordering to minimize style changes and cursor movements. The output is deterministic—same buffer diff always produces same operations.

- [x] 2.3.5.1 Define render operation types: `{:move, row, col}`, `{:style, style}`, `{:text, string}`, `{:reset}`
- [x] 2.3.5.2 Implement operation generation from change spans
- [x] 2.3.5.3 Implement operation merging combining adjacent same-style texts
- [x] 2.3.5.4 Implement operation sorting ensuring optimal cursor movement path

### Unit Tests - Section 2.3

- [x] **Unit Tests 2.3 Complete**
- [x] Test cell comparison correctly identifies identical and different cells
- [x] Test row diffing finds all changed cells within a row
- [x] Test unchanged row detection skips rows with no changes
- [x] Test change span detection groups contiguous changes correctly
- [x] Test span merging combines small gaps to reduce cursor movements
- [x] Test wide character pairs are included together in change spans
- [x] Test diff output generates correct sequence of render operations
- [x] Test deterministic output produces same operations for same input

---

## 2.4 Cursor Optimization

- [x] **Section 2.4 Complete**

Cursor optimization selects the cheapest way to move the cursor between positions. Options include absolute positioning (`ESC[{row};{col}H`), relative movements (up/down/left/right), and special movements (home, newline, carriage return). We calculate byte cost for each option and choose the minimum. This optimization is critical for performance—naive absolute positioning adds significant overhead.

The optimizer maintains current cursor position and calculates cost for each movement option. Costs include escape sequence bytes and any side effects (newline also does carriage return). We handle edge cases: movement past screen bounds, cursor wrapping behavior, and position after last character. The optimization integrates with the diff output, rewriting move operations with optimal sequences.

### 2.4.1 Movement Cost Model

- [x] **Task 2.4.1 Complete**

We define cost functions for all cursor movement options. Absolute positioning costs 6-10 bytes depending on coordinate size. Relative movements cost 3-6 bytes. Special movements (CR, LF, home) cost 1-3 bytes. Literal spaces cost 1 byte each but also overwrite content. We model all costs and compare to find minimum.

- [x] 2.4.1.1 Implement absolute positioning cost `cost_absolute(row, col)` calculating escape sequence length
- [x] 2.4.1.2 Implement relative movement costs `cost_up(n)`, `cost_down(n)`, `cost_left(n)`, `cost_right(n)`
- [x] 2.4.1.3 Implement special movement costs for carriage return, newline, home, and their combinations
- [x] 2.4.1.4 Implement literal space cost for small rightward movements where spaces are cheaper

### 2.4.2 Optimal Path Selection

- [x] **Task 2.4.2 Complete**

Given current and target cursor positions, we select the optimal movement sequence. This may combine multiple movements (e.g., CR + down is cheaper than absolute for column 1). We enumerate viable options and select minimum cost. For complex cases, we use dynamic programming or A* search.

- [x] 2.4.2.1 Implement `optimal_move(from, to)` returning cheapest movement sequence
- [x] 2.4.2.2 Implement option enumeration generating all viable movement combinations
- [x] 2.4.2.3 Implement cost comparison selecting minimum total cost option
- [x] 2.4.2.4 Implement movement sequence generation converting chosen option to escape sequences

### 2.4.3 Cursor Position Tracking

- [x] **Task 2.4.3 Complete**

We track cursor position throughout rendering to enable relative movement optimization. Position updates after each movement and text output (cursor advances with each character). We handle line wrapping (cursor moves to next row) and scrolling (screen content shifts). Position tracking must exactly match terminal behavior.

- [x] 2.4.3.1 Implement cursor state tracking current row and column during render
- [x] 2.4.3.2 Implement position update after movement operations
- [x] 2.4.3.3 Implement position advance after text output accounting for display width
- [x] 2.4.3.4 Implement wrap handling detecting when cursor advances past last column

### 2.4.4 Movement Sequence Integration

- [x] **Task 2.4.4 Complete**

We integrate cursor optimization into the render pipeline, converting diff output move operations to optimized escape sequences. The optimizer processes operations in order, maintaining cursor state and rewriting moves. We batch optimizations for efficiency and provide fallback to absolute positioning when optimization fails.

- [x] 2.4.4.1 Implement render operation processor that optimizes move operations in sequence
- [x] 2.4.4.2 Implement optimization fallback using absolute positioning when calculation exceeds time limit
- [x] 2.4.4.3 Implement optimization statistics tracking bytes saved for performance monitoring
- [x] 2.4.4.4 Implement cursor sync operation forcing known position when tracking may be incorrect

### Unit Tests - Section 2.4

- [x] **Unit Tests 2.4 Complete**
- [x] Test movement cost calculations return correct byte counts
- [x] Test optimal path selection chooses cheapest option for various position pairs
- [x] Test CR+down is chosen over absolute for column 1 movements
- [x] Test literal spaces are used for small rightward movements
- [x] Test cursor position tracking stays synchronized during rendering
- [x] Test text output advances cursor by display width
- [x] Test optimization produces shorter output than naive absolute positioning
- [x] Test fallback to absolute positioning works when optimization disabled

---

## 2.5 Escape Sequence Batching

- [x] **Section 2.5 Complete**

Escape sequence batching combines multiple operations into single write calls, reducing system call overhead. Each write syscall has fixed overhead—batching amortizes this across many operations. We also combine adjacent SGR sequences (style changes) into single sequences, reducing byte count. Batching is transparent to the rest of the renderer—we collect sequences in a buffer and flush periodically.

The batch buffer accumulates escape sequences and text until flush. We flush on: buffer size threshold (prevent memory growth), frame completion, and explicit request. Write operations use IO.binwrite for raw binary output without encoding overhead. We handle partial writes and retry on interruption.

### 2.5.1 Sequence Buffer

- [x] **Task 2.5.1 Complete**

The sequence buffer accumulates escape sequences and text for batched output. We use iolist format for efficient concatenation without copying. The buffer tracks size for threshold-based flushing and provides append/flush operations. Buffer management is efficient—we avoid intermediate allocations.

- [x] 2.5.1.1 Implement sequence buffer using iolist accumulator for efficient append
- [x] 2.5.1.2 Implement `buffer_append/2` adding sequence to buffer and tracking size
- [x] 2.5.1.3 Implement size tracking counting bytes for flush threshold comparison
- [x] 2.5.1.4 Implement `buffer_flush/1` writing accumulated data to terminal and resetting buffer

### 2.5.2 SGR Sequence Combining

- [x] **Task 2.5.2 Complete**

SGR (Select Graphic Rendition) sequences set text style. Multiple SGR sequences can combine into one: `ESC[1mESC[31m` becomes `ESC[1;31m`, saving 4 bytes. We track pending style changes and emit combined sequence before text output. We reset tracking after each flush or explicit reset.

- [x] 2.5.2.1 Implement SGR accumulator collecting style parameters during rendering
- [x] 2.5.2.2 Implement combined SGR emission before text output with all pending parameters
- [x] 2.5.2.3 Implement SGR delta tracking emitting only changed parameters from previous style
- [x] 2.5.2.4 Implement SGR reset handling clearing accumulator on style reset

### 2.5.3 Flush Management

- [x] **Task 2.5.3 Complete**

Flush management determines when to write accumulated sequences. We flush on: size threshold (default 4KB) to bound memory usage, frame completion to ensure visibility, explicit flush requests, and process exit. Flushing must be atomic—partial frames cause visual glitches.

- [x] 2.5.3.1 Implement size threshold flush triggering write when buffer exceeds limit
- [x] 2.5.3.2 Implement frame completion flush ensuring all frame data is written
- [x] 2.5.3.3 Implement explicit flush API for immediate output when needed
- [x] 2.5.3.4 Implement exit flush using process trap_exit to flush on termination

### 2.5.4 Write Optimization

- [x] **Task 2.5.4 Complete**

We optimize the actual write operation for maximum throughput. This includes using IO.binwrite for raw output, handling EAGAIN for non-blocking writes, and measuring write performance. We consider synchronous vs asynchronous writing based on terminal latency.

- [x] 2.5.4.1 Implement raw binary write using `IO.binwrite/2` without text encoding
- [x] 2.5.4.2 Implement write retry handling EAGAIN/EWOULDBLOCK errors
- [x] 2.5.4.3 Implement write timing measurement for performance monitoring
- [x] 2.5.4.4 Implement async write option for high-latency connections (SSH)

### Unit Tests - Section 2.5

- [x] **Unit Tests 2.5 Complete**
- [x] Test sequence buffer accumulates data without premature writes
- [x] Test buffer size tracking counts bytes correctly
- [x] Test buffer flush writes all accumulated data
- [x] Test SGR combining produces single sequence from multiple style changes
- [x] Test SGR delta only emits changed parameters
- [x] Test size threshold triggers automatic flush
- [x] Test frame completion flush writes all pending data
- [x] Test raw binary write produces correct terminal output

---

## 2.6 Framerate Limiter

- [x] **Section 2.6 Complete**

The framerate limiter caps rendering to a maximum FPS (default 60, configurable up to 120), preventing the renderer from overwhelming the terminal or wasting CPU on invisible updates. Components can request redraws at any rate—the limiter coalesces requests and renders at the next frame boundary. This creates smooth animation while being efficient.

The limiter uses a GenServer with timer-based frame ticks. Render requests mark the buffer dirty; the tick handler renders if dirty, then clears the flag. We measure actual FPS for monitoring and adapt to terminal capability—slow terminals may benefit from lower FPS. The limiter provides immediate mode for when the next frame can't wait (critical updates).

### 2.6.1 Frame Timer

- [x] **Task 2.6.1 Complete**

The frame timer triggers render cycles at regular intervals. We use Process.send_after for scheduling to avoid timer drift. The interval is 16ms for 60 FPS, 8ms for 120 FPS. The timer runs continuously while the application is active, pausing when minimized or backgrounded if focus events are available.

- [x] 2.6.1.1 Implement frame timer using `Process.send_after/3` for interval scheduling
- [x] 2.6.1.2 Implement FPS configuration allowing 30, 60, or 120 FPS settings
- [x] 2.6.1.3 Implement timer drift compensation adjusting next interval based on actual elapsed time
- [x] 2.6.1.4 Implement timer pause/resume for application backgrounding (optional focus event integration)

### 2.6.2 Dirty Flag Management

- [x] **Task 2.6.2 Complete**

The dirty flag tracks whether the buffer needs rendering. Any buffer write sets the flag; rendering clears it. Multiple writes between frames coalesce—we render once with all changes. The flag is atomic to handle concurrent writes from multiple component processes.

- [x] 2.6.2.1 Implement atomic dirty flag using `:atomics` module for lock-free concurrent access
- [x] 2.6.2.2 Implement `mark_dirty/0` setting flag when buffer is modified
- [x] 2.6.2.3 Implement `clear_dirty/0` resetting flag after render completes
- [x] 2.6.2.4 Implement `is_dirty?/0` checking flag for render decision

### 2.6.3 Render Scheduling

- [x] **Task 2.6.3 Complete**

Render scheduling coordinates frame timing with dirty state. On each tick, we check if dirty and render if so. We skip rendering for clean frames, saving CPU. Immediate mode bypasses the scheduler for urgent updates. We track frame statistics: rendered frames, skipped frames, actual FPS.

- [x] 2.6.3.1 Implement tick handler checking dirty flag and triggering render
- [x] 2.6.3.2 Implement frame skip for clean buffers with skip counting for statistics
- [x] 2.6.3.3 Implement immediate render mode bypassing frame timing for urgent updates
- [x] 2.6.3.4 Implement frame statistics tracking actual FPS, render time, and skip ratio

### 2.6.4 Performance Monitoring

- [x] **Task 2.6.4 Complete**

Performance monitoring tracks rendering metrics for debugging and optimization. We measure: frame render time, diff calculation time, escape sequence generation time, write time, and total frame time. Metrics are available via API and optionally displayed in debug overlay.

- [x] 2.6.4.1 Implement timing instrumentation measuring each render phase duration
- [x] 2.6.4.2 Implement FPS calculation from rendered frame timestamps
- [x] 2.6.4.3 Implement performance metrics API exposing current and historical statistics
- [x] 2.6.4.4 Implement slow frame detection warning when frame time exceeds target interval

### Unit Tests - Section 2.6

- [x] **Unit Tests 2.6 Complete**
- [x] Test frame timer fires at correct intervals for configured FPS
- [x] Test dirty flag is set by buffer modifications
- [x] Test dirty flag is cleared after render
- [x] Test concurrent dirty flag writes don't lose updates
- [x] Test render is triggered only when buffer is dirty
- [x] Test clean frames are skipped without rendering
- [x] Test immediate mode renders without waiting for next tick
- [x] Test performance metrics accurately reflect render times

---

## 2.7 Integration Tests

- [x] **Section 2.7 Complete**

Integration tests validate the complete rendering pipeline from buffer writes through terminal output. We test realistic rendering scenarios: full screen updates, partial updates, animations, and resize handling. Tests verify both correctness (right content rendered) and performance (meets FPS target). We use PTY-based testing to capture actual terminal output.

### 2.7.1 Render Pipeline Testing

- [x] **Task 2.7.1 Complete**

We test the complete pipeline: write cells to buffer, trigger render, verify terminal output matches expected sequences. Tests cover all cell types (colors, styles, characters) and all rendering optimizations (diff, cursor optimization, batching). We verify output is correct and minimal.

- [x] 2.7.1.1 Test simple text rendering produces correct escape sequences and characters
- [x] 2.7.1.2 Test styled text rendering produces correct SGR sequences
- [x] 2.7.1.3 Test partial update only renders changed cells, not full screen
- [x] 2.7.1.4 Test cursor optimization produces shorter sequences than naive approach

### 2.7.2 Animation Testing

- [x] **Task 2.7.2 Complete**

Animation testing verifies smooth rendering over time. We render multiple frames with incremental changes and verify consistent frame rate, proper dirty flag handling, and no visual artifacts. Tests simulate spinner animation, progress bar updates, and scrolling content.

- [x] 2.7.2.1 Test spinner animation renders at consistent FPS
- [x] 2.7.2.2 Test progress bar updates render only changed region
- [x] 2.7.2.3 Test scrolling content uses scroll optimization when available
- [x] 2.7.2.4 Test high-frequency updates coalesce to target FPS

### 2.7.3 Resize Handling Testing

- [x] **Task 2.7.3 Complete**

Resize tests verify correct behavior when terminal dimensions change. The renderer must reallocate buffers, re-render content, and handle edge cases (content truncation, expanded space). We test resize during rendering, rapid resize sequences, and resize to very small dimensions.

- [x] 2.7.3.1 Test resize triggers buffer reallocation with correct new dimensions
- [x] 2.7.3.2 Test content is preserved within new dimensions after resize
- [x] 2.7.3.3 Test resize during render completes current frame before reallocating
- [x] 2.7.3.4 Test rapid resize sequence handles all resize events correctly

### 2.7.4 Performance Benchmarking

- [x] **Task 2.7.4 Complete**

Performance benchmarks measure rendering throughput and identify bottlenecks. We benchmark: cells per second, frames per second, bytes per frame, and optimization savings. Results validate performance targets and guide optimization efforts.

- [x] 2.7.4.1 Benchmark full screen render measuring time for complete screen update
- [x] 2.7.4.2 Benchmark incremental render measuring time for small changes
- [x] 2.7.4.3 Benchmark diff algorithm measuring cell comparisons per millisecond
- [x] 2.7.4.4 Benchmark cursor optimization measuring byte savings over naive approach

---

## Success Criteria

1. **Buffer Management**: ETS-based double buffering supports concurrent writes from multiple processes without corruption
2. **Diff Algorithm**: Correctly identifies all changed cells and generates minimal update operations
3. **Cursor Optimization**: Reduces movement bytes by 40%+ compared to naive absolute positioning
4. **Batching**: Reduces system calls by 80%+ through sequence accumulation
5. **Framerate**: Maintains 60 FPS with <16ms frame time for typical UI updates
6. **Memory Efficiency**: Buffer memory usage is O(rows × cols) with no leaks on resize
7. **Test Coverage**: 85% test coverage with comprehensive unit and integration tests

## Provides Foundation

This phase establishes the infrastructure for:
- **Phase 3**: Component system using buffer API for widget rendering
- **Phase 4**: Layout system requiring render area calculations
- **Phase 5**: Event system coordinating with frame timing
- **Phase 6**: Advanced widgets relying on efficient rendering for complex UIs
- All subsequent rendering building on optimized buffer and diff infrastructure

## Key Outputs

- Cell and Style data structures supporting all terminal display features
- ETS-based double buffering with concurrent write support
- Diff algorithm with change span optimization
- Cursor movement optimization with cost-based path selection
- Escape sequence batching and SGR combining
- Framerate limiter with dirty flag coalescing
- Performance monitoring and metrics
- Comprehensive test suite covering all renderer operations
- API documentation for rendering engine modules
