# Backend contract

A backend implements `TermUI.Backend`.

```elixir
@callback init(keyword()) :: {:ok, state()} | {:error, term()}
@callback size(state()) :: {:ok, {rows, columns}} | {:error, term()}
@callback capabilities(state()) :: map()
@callback draw(state(), TermUI.Frame.t()) :: {:ok, state()} | {:error, term()}
@callback flush(state()) :: {:ok, state()} | {:error, term()}
@callback clipboard(state(), TermUI.Clipboard.Operation.t()) ::
            {:ok, state()} | {:error, term()}
@callback poll_event(state(), non_neg_integer()) ::
            {:ok, TermUI.Event.t(), state()} | {:timeout, state()} | {:error, term(), state()}
@callback resize(state(), {rows, columns}) :: {:ok, state()} | {:error, term()}
@callback shutdown(state(), term()) :: :ok
```

`clipboard/2` is optional. The runtime returns a structured unsupported error
when a custom backend does not implement it. The callback must return the next
backend state so clipboard output stays in sequence with draw and cleanup.

The size at the backend boundary is `{rows, columns}`. The runtime converts it
to application dimensions `{columns, rows}`.

`init/1` must not leave partial terminal state after an error. `shutdown/2`
must be safe during error cleanup. `draw/2` must retain the last successful
frame or equivalent backend state so that a later frame can clear old cells.

A test backend must avoid real terminal I/O. It can receive frames and return a
fixed size. See `test/support/deterministic_backend.ex`.

The runtime puts each backend behind one serialized owner. State returned by
input, size, draw, flush, and resize callbacks becomes the state for the next
callback and for final cleanup.

Size polling uses a 200 ms interval when direct terminal or environment size
checks are available. It uses a 1 second interval when detection must start
`stty`. Set `backend_opts: [size_poll_interval: milliseconds]` to use an
interval of at least 50 ms. Use `:disabled` when the application supplies all
resize events through its backend input stream.
