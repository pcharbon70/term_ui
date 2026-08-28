defmodule TermUI.Input.Raw do
  @moduledoc """
  Raw mode input handler implementing the `TermUI.Input` behaviour.

  This module provides synchronous input polling with timeout support for
  applications running with the Raw backend. It reads single characters
  from stdin and parses escape sequences into `TermUI.Event` structs.

  `TermUI.Runtime` selects this handler for Raw mode only when
  `use_input_handler: true`. The default Raw path uses the asynchronous
  `TermUI.Terminal.InputReader` instead.

  ## Features

  - **Non-blocking input**: Supports timeout-based polling (including 0ms for
    non-blocking checks)
  - **Escape sequence parsing**: Handles arrow keys, function keys, mouse events,
    and other terminal escape sequences
  - **Buffer management**: Maintains partial escape sequences between poll calls
  - **Security**: Buffer and queue size limits prevent memory exhaustion

  ## Usage

      # Create initial state
      state = TermUI.Input.Raw.new()

      # Poll for input with 100ms timeout
      case TermUI.Input.Raw.poll(state, 100) do
        {{:ok, event}, new_state} -> handle_event(event, new_state)
        {:timeout, new_state} -> handle_idle(new_state)
        {:eof, new_state} -> handle_shutdown(new_state)
      end

  ## How It Works

  The module spawns a Task to read from stdin using `:io.get_chars/2` (Erlang's
  IO module directly). This is critical for compatibility with raw mode activated
  via `:shell.start_interactive({:noshell, :raw})`, which redirects standard
  input. Elixir's `IO.getn/2` wrapper cannot access the redirected input, but
  `:io.get_chars/2` works correctly.

  Since `:io.get_chars/2` blocks until input is available, using a Task allows
  us to implement timeout semantics via `Task.yield/2`.

  When an escape sequence spans multiple reads (e.g., arrow keys send multiple
  bytes), the partial sequence is buffered and completed on subsequent polls.

  ## Escape Sequence Timeout

  When a partial escape sequence is detected (e.g., lone ESC), the handler waits
  up to 50ms for completion. This matches standard terminal emulator behavior
  and distinguishes ESC key presses from escape sequences. The 50ms timeout is
  the same value used by `TermUI.Terminal.InputReader`.

  ## Comparison with InputReader

  Unlike `TermUI.Terminal.InputReader` which is a GenServer that asynchronously
  sends events to a target process, this module provides synchronous polling
  suitable for use with the `TermUI.Input` behaviour interface. This module
  uses direct `:io.get_chars/2` calls wrapped in Tasks for timeout support, rather
  than delegating to InputReader, because InputReader's async message-based
  design is incompatible with the synchronous polling contract.

  Both modules use the same underlying approach (`:io.get_chars/2`) for reading
  from stdin, ensuring compatibility with raw mode's redirected input.
  """

  @behaviour TermUI.Input

  require Logger

  alias TermUI.Backend.InputBuffer
  alias TermUI.Event
  alias TermUI.Terminal.EscapeParser

  # Dialyzer: Functions return specific struct types
  # Dialyzer: emit_partial_escape/2 calls Event.key with string args for partial escape chars
  # Key.new/2 spec says atom() but the function works with strings too
  @dialyzer {:nowarn_function,
             new: 0,
             emit_partial_escape: 2,
             read_char: 0,
             poll: 2,
             handle_escape_timeout: 2,
             do_read_with_timeout: 2}

  # Escape sequence bytes
  @esc 0x1B
  @left_bracket ?[
  @letter_o ?O

  # Timeout for escape sequence completion (ms).
  # This matches terminal emulator behavior for distinguishing ESC key
  # presses from escape sequences. The same value is used by InputReader.
  @escape_timeout 50

  # Note: InputBuffer.apply_limit/2 uses its own limit (1KB) and truncates
  # to 256 bytes when exceeded. This provides security against memory
  # exhaustion from malformed escape sequences. We don't need a separate
  # buffer size constant here since InputBuffer handles the limiting.

  # Maximum event queue size to prevent memory exhaustion.
  @max_queue_size 1000

  defstruct buffer: <<>>,
            event_queue: []

  @typedoc """
  State for the Raw input handler.

  - `:buffer` - Binary buffer for partial escape sequences
  - `:event_queue` - Queue of parsed events waiting to be returned
  """
  @type t :: %__MODULE__{
          buffer: binary(),
          event_queue: [Event.t()]
        }

  @doc """
  Creates a new Raw input handler state.

  ## Examples

      state = TermUI.Input.Raw.new()
  """
  @spec new() :: t()
  def new do
    %__MODULE__{
      buffer: <<>>,
      event_queue: []
    }
  end

  @doc """
  Polls for input with the specified timeout.

  Reads input from stdin and parses it into events. The timeout specifies
  the maximum time to wait for input in milliseconds. Use 0 for non-blocking
  polls.

  ## Parameters

  - `state` - Current handler state
  - `timeout` - Maximum wait time in milliseconds

  ## Returns

  - `{{:ok, event}, new_state}` - An event was received
  - `{:timeout, new_state}` - No input within timeout
  - `{:eof, new_state}` - End of input stream

  ## Examples

      # Non-blocking check
      {result, state} = Raw.poll(state, 0)

      # Wait up to 100ms
      {result, state} = Raw.poll(state, 100)
  """
  @impl TermUI.Input
  @spec poll(t(), non_neg_integer()) :: TermUI.Input.poll_result()
  def poll(%__MODULE__{} = state, timeout) when is_integer(timeout) and timeout >= 0 do
    # First, check if we have queued events from a previous parse
    case state.event_queue do
      [event | rest] ->
        {{:ok, event}, %{state | event_queue: rest}}

      [] ->
        # Try to get an event from the buffer
        case try_parse_buffer(state) do
          {:ok, event, new_state} ->
            {{:ok, event}, new_state}

          :need_more ->
            # Need to read more input
            read_with_timeout(state, timeout)
        end
    end
  end

  @doc """
  Returns the input mode for this handler.

  Always returns `:raw` for the Raw input handler.

  ## Examples

      mode = Raw.mode(state)
      # => :raw
  """
  @impl TermUI.Input
  @spec mode(t()) :: :raw
  def mode(%__MODULE__{}), do: :raw

  @doc """
  Stops the Raw input handler.

  For the Raw handler, this is a no-op since the InputReader GenServer
  is managed separately by the Runtime. This function exists for
  compatibility with the `TermUI.Input` behaviour.

  ## Examples

      :ok = Raw.stop(state)
  """
  @impl TermUI.Input
  @spec stop(t()) :: :ok
  def stop(%__MODULE__{}), do: :ok

  # Private Functions

  # Try to parse a complete event from the buffer
  @spec try_parse_buffer(t()) :: {:ok, Event.t(), t()} | :need_more
  defp try_parse_buffer(%__MODULE__{buffer: <<>>}), do: :need_more

  defp try_parse_buffer(%__MODULE__{buffer: buffer} = state) do
    case EscapeParser.parse(buffer) do
      {[event | rest_events], remaining} ->
        # Got at least one event
        # Queue any additional events for subsequent polls (with size limit)
        queued_events = limit_queue(rest_events)
        new_state = %{state | buffer: remaining, event_queue: queued_events}
        {:ok, event, new_state}

      {[], _remaining} ->
        # No complete events yet, need more input
        :need_more
    end
  end

  # Limit queue size to prevent memory exhaustion
  @spec limit_queue([Event.t()]) :: [Event.t()]
  defp limit_queue(events) when length(events) <= @max_queue_size, do: events

  defp limit_queue(events) do
    Logger.warning(
      "Input.Raw: Event queue overflow, dropping #{length(events) - @max_queue_size} events"
    )

    Enum.take(events, @max_queue_size)
  end

  # Read input with timeout using a Task
  @spec read_with_timeout(t(), non_neg_integer()) :: TermUI.Input.poll_result()
  defp read_with_timeout(%__MODULE__{} = state, timeout) do
    # Check if we have a partial escape sequence that needs timeout handling
    if EscapeParser.partial_sequence?(state.buffer) and timeout > @escape_timeout do
      # Wait a short time for escape sequence completion
      handle_escape_timeout(state, timeout)
    else
      # Normal read with full timeout
      do_read_with_timeout(state, timeout)
    end
  end

  # Handle the case where we have a partial escape sequence
  @spec handle_escape_timeout(t(), non_neg_integer()) :: TermUI.Input.poll_result()
  defp handle_escape_timeout(%__MODULE__{} = state, timeout) do
    # First try to complete the escape sequence with a short timeout
    case do_read_with_timeout(state, @escape_timeout) do
      {:timeout, state_after_short} ->
        # Escape sequence didn't complete, emit what we have
        emit_partial_escape(state_after_short, timeout - @escape_timeout)

      # Success or EOF - return as-is
      result ->
        result
    end
  end

  # Emit partial escape sequence as individual key events
  @spec emit_partial_escape(t(), non_neg_integer()) :: TermUI.Input.poll_result()
  defp emit_partial_escape(%__MODULE__{buffer: buffer} = state, remaining_timeout) do
    events =
      cond do
        # Lone ESC
        buffer == <<@esc>> ->
          [Event.key(:escape)]

        # ESC[ without terminator
        buffer == <<@esc, @left_bracket>> ->
          [Event.key(:escape), Event.key("[", char: "[")]

        # ESC O without terminator
        buffer == <<@esc, @letter_o>> ->
          [Event.key(:escape), Event.key("O", char: "O")]

        # Other partial sequences starting with ESC
        String.starts_with?(buffer, <<@esc>>) ->
          <<@esc, rest::binary>> = buffer
          {rest_events, _} = EscapeParser.parse(rest)
          [Event.key(:escape) | rest_events]

        true ->
          []
      end

    case events do
      [event | rest] ->
        # Return first event, queue remaining events, clear buffer
        queued_events = limit_queue(rest)
        {{:ok, event}, %{state | buffer: <<>>, event_queue: queued_events}}

      [] ->
        # No events to emit, continue waiting with remaining timeout
        if remaining_timeout > 0 do
          do_read_with_timeout(%{state | buffer: <<>>}, remaining_timeout)
        else
          {:timeout, %{state | buffer: <<>>}}
        end
    end
  end

  # Perform the actual read with timeout
  @spec do_read_with_timeout(t(), non_neg_integer()) :: TermUI.Input.poll_result()
  defp do_read_with_timeout(%__MODULE__{} = state, timeout) do
    # Spawn a task to read input
    task = Task.async(fn -> read_char() end)

    # Use explicit Task.yield and Task.shutdown for clarity
    case Task.yield(task, timeout) do
      {:ok, {:ok, data}} ->
        # Got input, add to buffer with size limit and try to parse
        new_buffer = state.buffer <> data
        # InputBuffer.apply_limit uses rate-limited logging via the :source option
        {limited_buffer, _truncated} = InputBuffer.apply_limit(new_buffer, source: :input_raw)

        new_state = %{state | buffer: limited_buffer}

        case try_parse_buffer(new_state) do
          {:ok, event, final_state} ->
            {{:ok, event}, final_state}

          :need_more ->
            # Still need more, but we've used our timeout
            {:timeout, new_state}
        end

      {:ok, :eof} ->
        {:eof, state}

      {:ok, {:error, reason}} ->
        # Log IO errors at debug level for troubleshooting
        Logger.debug("Input.Raw: IO read error: #{inspect(reason)}")
        {:eof, state}

      nil ->
        # Timeout - no input received, shut down the task
        Task.shutdown(task)
        {:timeout, state}
    end
  end

  # Read a single character from stdin
  # Uses :io.get_chars/2 (Erlang's IO module) for compatibility with
  # :shell.start_interactive({:noshell, :raw}) which redirects standard input.
  # Elixir's IO.getn/2 cannot access the redirected input.
  @spec read_char() :: {:ok, binary()} | :eof | {:error, term()}
  defp read_char do
    case :io.get_chars(~c"", 1) do
      :eof ->
        :eof

      chars when is_list(chars) ->
        # Convert charlist to binary
        case :unicode.characters_to_binary(chars) do
          binary when is_binary(binary) ->
            {:ok, binary}

          :error ->
            {:error, :invalid_unicode}
        end

      {:error, reason} ->
        {:error, reason}

      other ->
        {:error, {:unexpected_io_return, other}}
    end
  end
end
