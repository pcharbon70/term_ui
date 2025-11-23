# Summary: Runtime-Terminal Integration

## Overview

This feature connects the TermUI Runtime's render loop to actual terminal output. Previously, the Runtime would build render trees via component `view/1` functions but never display them. Now the full pipeline is operational:

```
Component view() → RenderNode tree → Buffer cells → Diff operations → Terminal output
```

## Changes Made

### Core Implementation

1. **Runtime State Updates** (`lib/term_ui/runtime/state.ex`)
   - Added `terminal_started`, `buffer_manager`, and `dimensions` fields
   - These track whether terminal output is available and the current screen size

2. **Runtime Initialization** (`lib/term_ui/runtime.ex`)
   - Added `initialize_terminal/0` and `setup_terminal_and_buffers/0` functions
   - On startup: enables raw mode, enters alternate screen, hides cursor
   - Gets terminal dimensions and starts BufferManager with matching size
   - Added `skip_terminal: true` option for test isolation
   - Gracefully handles missing terminal (e.g., not a TTY, tests)

3. **NodeRenderer** (`lib/term_ui/runtime/node_renderer.ex`) - NEW
   - Converts render trees to buffer cells
   - Supports both tuple formats (`{:text, content}` from Elm.Helpers) and struct formats (`%RenderNode{}` from Component.Helpers)
   - Handles text, styled text, boxes, stacks (vertical/horizontal), and positioned cells
   - Applies style merging for nested styled nodes

4. **Render Pipeline** (`lib/term_ui/runtime.ex`)
   - `do_render/1` now:
     - Clears current buffer
     - Renders tree to buffer via NodeRenderer
     - Computes diff between current and previous buffers
     - Outputs diff operations via SequenceBuffer
     - Swaps buffers for next frame
   - Added `render_operations/1` and `apply_operation/2` for ANSI output

5. **Terminal Restoration** (`lib/term_ui/runtime.ex`)
   - `terminate/2` callback restores terminal on shutdown
   - Shows cursor, leaves alternate screen, disables raw mode

### Test Updates

- Changed `test/term_ui/runtime_test.exs` to use `async: false`
- Added `start_test_runtime/1` helper that passes `skip_terminal: true`
- All 31 Runtime tests now pass without terminal interference

## Files Modified

- `lib/term_ui/runtime/state.ex` - Added terminal state fields
- `lib/term_ui/runtime.ex` - Terminal init, render pipeline, cleanup
- `lib/term_ui/runtime/node_renderer.ex` - NEW: Tree to cells conversion
- `test/term_ui/runtime_test.exs` - Test isolation fixes

## How It Works

### Render Flow

1. Runtime receives events (keyboard, mouse, resize)
2. Events become messages via `event_to_msg/2`
3. Messages update component state via `update/2`
4. Changed state triggers render on next tick
5. `view/1` builds a RenderNode tree
6. NodeRenderer converts tree to buffer cells
7. Diff computes minimal operations vs previous frame
8. SequenceBuffer batches ANSI sequences
9. IO.write sends to terminal
10. BufferManager swaps buffers for next frame

### NodeRenderer Details

The NodeRenderer handles multiple render tree formats:

```elixir
# Tuple format (Elm.Helpers)
{:text, "Hello"}
{:styled, {:text, "Error"}, %Style{fg: :red}}
{:box, [], [...children...]}

# Struct format (Component.Helpers/RenderNode)
%RenderNode{type: :text, content: "Hello", style: nil}
%RenderNode{type: :stack, direction: :vertical, children: [...]}
%RenderNode{type: :cells, cells: [%{x: 0, y: 0, cell: %Cell{}}]}
```

Children are rendered recursively with style inheritance.

## Dashboard Example

The dashboard example at `examples/dashboard/` can now display:

```bash
cd examples/dashboard
mix deps.get
mix run --no-halt
```

Note: Actual display requires a real terminal with OTP 28+ for raw mode support.

## Testing

```bash
# All tests pass
mix test

# Output:
# 2724 tests, 0 failures, 2 excluded, 2 skipped
```

## Limitations

1. **Input handling not yet connected** - Terminal reads keyboard input but doesn't route to Runtime
2. **Resize handling** - Terminal resize events need to recreate buffers with new dimensions
3. **Widget format consistency** - Dashboard mixes Elm tuple format with RenderNode structs (both work)

## Next Steps

1. Connect Terminal input reader to Runtime event dispatch
2. Handle terminal resize by recreating BufferManager
3. Add keyboard shortcut for quit that actually exits the process
4. Consider making Terminal/BufferManager per-runtime (not singletons) for better isolation
