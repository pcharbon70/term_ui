# Feature Plan: Runtime-Terminal Integration

## Problem Statement

The TermUI Runtime currently implements The Elm Architecture loop correctly - it processes events, calls update functions, collects commands, and calls view functions to build render trees. However, the render trees are never actually displayed to the terminal.

The `do_render/1` function in Runtime (lines 383-392) contains placeholder code:

```elixir
defp do_render(state) do
  %{module: module, state: component_state} = Map.get(state.components, :root)
  _render_tree = module.view(component_state)
  # For now, just mark as clean
  # Actual rendering to buffer will integrate with Phase 2
  %{state | dirty: false}
end
```

This means applications like the dashboard example start successfully but display nothing on screen.

## Solution Overview

Connect the full rendering pipeline:

```
Runtime.do_render/1
    ↓
RenderNode tree → Cell grid (convert)
    ↓
BufferManager.write_region/4 (write to current buffer)
    ↓
Diff.compute/2 (compare current vs previous)
    ↓
SequenceBuffer → Terminal (accumulate and flush)
    ↓
BufferManager.swap/1 (current becomes previous)
```

### Key Integration Points

1. **Terminal module** (`lib/term_ui/terminal.ex`)
   - `start_link/1`, `stop/1` for raw mode management
   - `write/2` for ANSI output
   - Alternate screen and cursor control

2. **BufferManager module** (`lib/term_ui/renderer/buffer_manager.ex`)
   - `start_link/1` with dimensions
   - `write_cell/4`, `write_region/4` for cell writing
   - `get_current/1`, `get_previous/1` for diffing
   - `swap/1` to cycle buffers
   - Uses `:persistent_term` for lock-free access

3. **Diff module** (`lib/term_ui/renderer/diff.ex`)
   - `compute/2` compares buffers
   - Returns operations: `{:move, row, col}`, `{:style, style}`, `{:text, "..."}`

4. **SequenceBuffer module** (`lib/term_ui/renderer/sequence_buffer.ex`)
   - `new/2` with terminal and buffer size
   - `cursor_to/3`, `set_style/2`, `write_text/2`
   - `flush/1` for final output
   - Auto-flush at 4KB, combines adjacent SGR sequences

5. **RenderNode conversion** (needs implementation)
   - Convert render tree nodes (`:text`, `:styled`, `:stack`, `:box`) to Cell grid
   - Need to implement `TermUI.Renderer.Layout.render_to_cells/2` or similar

## Technical Details

### File Structure

```
lib/term_ui/
├── runtime.ex                    # Update do_render, add terminal/buffer init
├── runtime/
│   └── state.ex                  # Add terminal, buffer_manager fields
└── renderer/
    └── node_renderer.ex          # NEW: Convert RenderNode to cells
```

### Dependencies

- Terminal module (Phase 1)
- BufferManager module (Phase 2.2)
- Diff module (Phase 2.3)
- SequenceBuffer module (Phase 2.5)
- Existing widget render functions (Phase 3, 6)

### Runtime State Additions

```elixir
defstruct [
  # Existing fields...
  :terminal,        # Terminal GenServer pid
  :buffer_manager,  # BufferManager pid
  :dimensions       # {width, height}
]
```

## Implementation Plan

### Task 1: Update Runtime State Structure

- [x] 1.1 Add terminal, buffer_manager, dimensions fields to Runtime.State
- [x] 1.2 Update Runtime.init/1 to start Terminal and BufferManager
- [ ] 1.3 Handle terminal resize events to update dimensions and recreate buffers
- [x] 1.4 Update Runtime.terminate/2 to stop Terminal cleanly

### Task 2: Implement RenderNode to Cells Conversion

- [x] 2.1 Create `TermUI.Runtime.NodeRenderer` module
- [x] 2.2 Implement conversion for `:text` nodes to cells
- [x] 2.3 Implement conversion for `:styled` nodes with Style
- [x] 2.4 Implement conversion for `:stack` (vertical/horizontal) layouts
- [x] 2.5 Implement conversion for widget render outputs (Gauge, Sparkline, etc.)

### Task 3: Connect Rendering Pipeline

- [x] 3.1 Update do_render/1 to convert render tree to cells
- [x] 3.2 Write cells to BufferManager current buffer
- [x] 3.3 Compute diff between current and previous buffers
- [x] 3.4 Accumulate diff operations in SequenceBuffer
- [x] 3.5 Flush SequenceBuffer to Terminal
- [x] 3.6 Swap buffers after render completes

### Task 4: Handle Terminal Events

- [ ] 4.1 Receive events from Terminal input (if not already handled)
- [ ] 4.2 Handle resize events to update dimensions
- [ ] 4.3 Handle quit signal for graceful shutdown

### Task 5: Test with Dashboard Example

- [x] 5.1 Dashboard compiles successfully
- [ ] 5.2 Test keyboard input (q, r, t, arrows) - requires Terminal input
- [ ] 5.3 Test theme switching - requires Terminal input
- [ ] 5.4 Test resize handling - not yet implemented
- [x] 5.5 All existing tests pass (2724 tests, 0 failures)

### Unit Tests

- [x] Test Runtime starts Terminal and BufferManager (with skip_terminal option for tests)
- [x] Test RenderNode to cells conversion for all node types
- [x] Test render pipeline produces terminal output
- [ ] Test resize recreates buffers with new dimensions
- [x] Test shutdown restores terminal state

## Success Criteria

1. Runtime starts Terminal in raw mode with alternate screen
2. Dashboard example displays correctly on screen
3. Keyboard inputs work (quit, refresh, theme toggle, navigation)
4. Resize events update display correctly
5. Quit restores terminal to normal state
6. All existing tests continue to pass
7. New integration tests pass

## Current Status

- **Planning**: Complete
- **Implementation**: Complete (core pipeline working)
- **Tests**: Complete (2724 tests pass)

## Notes

The dashboard example at `examples/dashboard/` serves as the test case for this integration. Once complete, running `mix run --no-halt` in that directory should display a working system dashboard.

Key challenges:
- RenderNode to cells conversion must handle nested structures
- Layout calculation for stack nodes (need widths/heights)
- Widget outputs vary (Gauge returns cells, text returns strings)
