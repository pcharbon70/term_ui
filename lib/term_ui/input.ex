defmodule TermUI.Input do
  @moduledoc """
  Behaviour defining the input abstraction for TermUI.

  This module establishes a unified interface for reading terminal input,
  regardless of whether the application is running with the Raw backend
  or the TTY backend.

  ## Input Modes

  TermUI supports two input approaches:

  ### Character Mode (Default)

  Both Raw and TTY handlers request one character at a time. Raw mode receives
  each keystroke immediately. TTY mode leaves the terminal in cooked mode, so
  the shell or terminal driver may buffer input until Enter. After delivery,
  both handlers normalize navigation keys into the same TermUI events.

  This is the primary input mode used by most widgets:
  - `Menu`, `PickList`, `Table` - navigation with arrows, selection with Enter
  - `Dialog`, `AlertDialog` - button navigation with Tab
  - `Tabs`, `TreeView` - keyboard navigation

  ### Line Mode (TextInput.Line Only)

  The `TermUI.Input.LineReader` module provides line-based input using
  `IO.gets/1`. This is **only** used by the `TextInput.Line` widget, which
  benefits from shell line editing features:
  - Backspace, delete, cursor movement
  - Command history (if shell supports it)
  - Input submitted on Enter

  Most applications should use character mode. Line mode is a specialized
  feature for free-form text entry where shell editing is desirable.

  ## Implementing the Behaviour

  Input handlers must implement three callbacks:

  - `poll/2` - Read input with optional timeout
  - `mode/1` - Return the input mode (`:raw` or `:tty`)
  - `stop/1` - Cleanup and release resources

  ## Example Implementation

      defmodule MyApp.CustomInput do
        @behaviour TermUI.Input

        @impl true
        def poll(state, timeout) do
          # Read input, return {:ok, event}, :timeout, or :eof
          {:ok, event, state}
        end

        @impl true
        def mode(_state), do: :custom
      end

  ## Built-in Handlers

  - `TermUI.Input.Raw` - Wraps `TermUI.Terminal.InputReader` for raw mode
  - `TermUI.Input.TTY` - Uses blocking `IO.getn/2` through the active shell's
    IO server; cooked-mode delivery may be line-buffered

  Use `TermUI.Input.Selector` to automatically choose the appropriate handler
  based on the active backend.
  """

  alias TermUI.Event

  # Type Definitions

  @typedoc """
  Key event returned from input polling.

  This is the standard key event type from `TermUI.Event.Key`.
  """
  @type key_event :: Event.Key.t()

  @typedoc """
  Result of an input polling operation.

  - `{:ok, key_event()}` - A key event was received
  - `{:ok, Event.Mouse.t()}` - A mouse event was received
  - `{:ok, Event.Paste.t()}` - A paste event was received (bracketed paste)
  - `:timeout` - No input within the timeout period
  - `:eof` - End of input stream
  """
  @type input_result ::
          {:ok, key_event() | Event.Mouse.t() | Event.Paste.t()}
          | :timeout
          | :eof

  @typedoc """
  Result of poll/2 including updated state.
  """
  @type poll_result :: {input_result(), state()}

  @typedoc """
  Opaque state maintained by the input handler.

  Each handler implementation defines its own state structure.
  """
  @type state :: term()

  @typedoc """
  Input mode indicator.

  - `:raw` - Raw mode with full terminal control
  - `:tty` - TTY mode with shell present
  """
  @type mode :: :raw | :tty

  # Callbacks

  @doc """
  Poll for input with an optional timeout.

  Reads input from the terminal and returns a parsed event. The timeout
  specifies the maximum time to wait for input in milliseconds.

  ## Parameters

  - `state` - Handler-specific state (escape sequence buffer, etc.)
  - `timeout` - Maximum wait time in milliseconds (0 for non-blocking)

  ## Returns

  - `{{:ok, event}, new_state}` - An event was received
  - `{:timeout, new_state}` - No input within timeout
  - `{:eof, new_state}` - End of input stream

  ## Timeout Semantics

  The timeout is best-effort:

  - **Raw mode**: Supports non-blocking reads; timeout is honored accurately
  - **TTY mode**: Uses blocking `IO.getn/2`; timeout may not be honored

  Components should not rely on precise timeout behavior. Use `:timeout`
  results for periodic updates, but design for the blocking case.

  ## Escape Sequences

  Handlers are responsible for buffering and parsing escape sequences.
  Multi-byte sequences (arrow keys, function keys) should be assembled
  before returning an event. Incomplete sequences should be buffered
  in the state and completed on subsequent calls.

  ## Examples

      # Non-blocking poll
      {result, new_state} = MyInput.poll(state, 0)

      # Wait up to 100ms
      {result, new_state} = MyInput.poll(state, 100)

      # Process result
      case result do
        {:ok, %Event.Key{key: :enter}} -> handle_enter()
        {:ok, %Event.Key{key: :up}} -> handle_up()
        :timeout -> continue_animation()
        :eof -> shutdown()
      end
  """
  @callback poll(state(), timeout :: non_neg_integer()) :: poll_result()

  @doc """
  Return the input mode for this handler.

  Returns `:raw` or `:tty` to indicate which mode the handler operates in.
  This allows components to adapt their behavior if needed. Most widgets handle
  the normalized events identically, although event delivery timing differs.

  ## Use Cases

  Most widgets do not need to check the mode—input events are normalized
  across both handlers. However, some specialized components might use this:

  - Displaying mode indicator in status bar
  - Adjusting behavior for mode-specific features
  - Debugging and logging

  ## Examples

      mode = MyInput.mode(state)
      # => :raw or :tty
  """
  @callback mode(state()) :: mode()

  @doc """
  Stop the input handler and release any resources.

  This callback is called during runtime shutdown to allow the handler
  to perform cleanup operations such as:

  - Restoring terminal IO options
  - Stopping any background processes
  - Closing file descriptors or ports

  The function should be idempotent—calling it multiple times should
  have the same effect as calling it once.

  ## Parameters

  - `state` - Handler-specific state

  ## Returns

  - `:ok` - Cleanup completed successfully

  ## Examples

      :ok = MyInput.stop(state)

  ## Implementation Notes

  - **Raw handler**: Typically a no-op since InputReader is managed separately
  - **TTY handler**: Should restore IO options (echo, binary mode)
  - Custom handlers: Implement any necessary cleanup

  This callback is always called during runtime shutdown, even if
  the handler was never successfully started or has already been
  stopped due to EOF.
  """
  @callback stop(state()) :: :ok
end
