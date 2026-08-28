# Buffer Management

`TermUI.Renderer.Buffer` is an ETS-backed rectangular cell grid.
`TermUI.Renderer.BufferManager` owns a current and previous buffer for
double-buffered rendering.

## Buffer coordinates and lifetime

Buffer coordinates are 1-based `{row, col}`. `Buffer.new/2` validates positive
dimensions and configured safety limits. Reads outside the grid return an
empty cell; writes report `{:error, :out_of_bounds}`. Call `Buffer.destroy/1`
for every standalone buffer.

The buffer API includes cell and batch writes, string writes, row/column/region
clears, resize, dimensions, row access, iteration, and conversion to a list.
`TermUI.Renderer.Cell` stores a grapheme, foreground/background colors,
attributes, and wide-character placeholder metadata.

## BufferManager

`BufferManager.start_link/1` requires `:rows` and `:cols` and accepts an
optional name. It exposes the two buffers, swap/resize/clear operations, direct
cell/string operations, and a separate dirty flag.

Runtime instances use unique global BufferManager names, avoiding collisions
between concurrent custom/SSH sessions.

## Runtime integration

Only Raw and explicit custom backends receive a BufferManager. Their frame
sequence is:

1. clear current buffer;
2. rasterize the complete root view;
3. compare current and previous cells;
4. emit changed cells and erasures;
5. swap buffers.

TTY does not use BufferManager. It allocates and destroys a temporary buffer per
dirty frame and lets `TermUI.Backend.TTY` perform its configured line strategy.

The runtime uses its own state-level `dirty` boolean. BufferManager's public
dirty API exists for direct users but is not the render scheduling source of
truth.

## Resize

Runtime resize handling resizes its BufferManager in Raw/custom operation and
updates dimensions before delivering a `%TermUI.Event.Resize{}` to the root.
`Buffer.resize/3` preserves overlapping cells and initializes newly exposed
space.

## Related standalone utilities

`TermUI.Renderer.Diff` can produce spans/operations from two buffers, but the
runtime performs its own backend-cell comparison. `TermUI.Test.TestRenderer`
wraps a buffer with text, style, search, and snapshot helpers.

Next: [Terminal Layer](06-terminal-layer.md).
