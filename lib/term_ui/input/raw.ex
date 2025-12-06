defmodule TermUI.Input.Raw do
  @moduledoc """
  Raw mode input handler implementing the `TermUI.Input` behaviour.

  This module provides synchronous input polling with timeout support for
  applications running with the Raw backend. It reads single characters
  from stdin and parses escape sequences into `TermUI.Event` structs.

  ## Features

  - **Non-blocking input**: Supports timeout-based polling (including 0ms for
    non-blocking checks)
  - **Escape sequence parsing**: Handles arrow keys, function keys, mouse events,
    and other terminal escape sequences
  - **Buffer management**: Maintains partial escape sequences between poll calls

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

  The module spawns a Task to read from stdin using `IO.getn/2`. Since `IO.getn`
  blocks until input is available, using a Task allows us to implement timeout
  semantics via `Task.yield/2`.

  When an escape sequence spans multiple reads (e.g., arrow keys send multiple
  bytes), the partial sequence is buffered and completed on subsequent polls.

  ## Comparison with InputReader

  Unlike `TermUI.Terminal.InputReader` which is a GenServer that asynchronously
  sends events to a target process, this module provides synchronous polling
  suitable for use with the `TermUI.Input` behaviour interface.
  """

  @behaviour TermUI.Input

  alias TermUI.Event
  alias TermUI.Terminal.EscapeParser

  # Timeout for escape sequence completion (ms)
  @escape_timeout 50

  defstruct buffer: <<>>,
            event_queue: [],
            reader_task: nil

  @typedoc """
  State for the Raw input handler.

  - `:buffer` - Binary buffer for partial escape sequences
  - `:event_queue` - Queue of parsed events waiting to be returned
  - `:reader_task` - Active Task reading from stdin, or nil
  """
  @type t :: %__MODULE__{
          buffer: binary(),
          event_queue: [Event.t()],
          reader_task: Task.t() | nil
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
      event_queue: [],
      reader_task: nil
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

  # Private Functions

  # Try to parse a complete event from the buffer
  @spec try_parse_buffer(t()) :: {:ok, Event.t(), t()} | :need_more
  defp try_parse_buffer(%__MODULE__{buffer: <<>>}), do: :need_more

  defp try_parse_buffer(%__MODULE__{buffer: buffer} = state) do
    case EscapeParser.parse(buffer) do
      {[event | rest_events], remaining} ->
        # Got at least one event
        # Queue any additional events for subsequent polls
        new_state = %{state | buffer: remaining, event_queue: rest_events}
        {:ok, event, new_state}

      {[], remaining} ->
        # No complete events yet
        if EscapeParser.partial_sequence?(remaining) do
          # Have partial escape sequence, might need timeout handling
          :need_more
        else
          # Not a partial sequence, just need more input
          :need_more
        end
    end
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
      {{:ok, _event}, _new_state} = result ->
        result

      {:timeout, state_after_short} ->
        # Escape sequence didn't complete, emit what we have
        emit_partial_escape(state_after_short, timeout - @escape_timeout)

      {:eof, _new_state} = result ->
        result
    end
  end

  # Emit partial escape sequence as individual key events
  @spec emit_partial_escape(t(), non_neg_integer()) :: TermUI.Input.poll_result()
  defp emit_partial_escape(%__MODULE__{buffer: buffer} = state, remaining_timeout) do
    events =
      cond do
        # Lone ESC
        buffer == <<0x1B>> ->
          [Event.key(:escape)]

        # ESC[ without terminator
        buffer == <<0x1B, ?[>> ->
          [Event.key(:escape), Event.key("[", char: "[")]

        # ESC O without terminator
        buffer == <<0x1B, ?O>> ->
          [Event.key(:escape), Event.key("O", char: "O")]

        # Other partial sequences starting with ESC
        String.starts_with?(buffer, <<0x1B>>) ->
          <<0x1B, rest::binary>> = buffer
          {rest_events, _} = EscapeParser.parse(rest)
          [Event.key(:escape) | rest_events]

        true ->
          []
      end

    case events do
      [event | _rest] ->
        # Return first event, clear buffer
        {{:ok, event}, %{state | buffer: <<>>}}

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

    case Task.yield(task, timeout) || Task.shutdown(task) do
      {:ok, {:ok, data}} ->
        # Got input, add to buffer and try to parse
        new_buffer = state.buffer <> data
        new_state = %{state | buffer: new_buffer}

        case try_parse_buffer(new_state) do
          {:ok, event, final_state} ->
            {{:ok, event}, final_state}

          :need_more ->
            # Still need more, but we've used our timeout
            # Check if it's a partial escape sequence
            if EscapeParser.partial_sequence?(new_buffer) do
              # Return timeout, let next poll handle escape timeout
              {:timeout, new_state}
            else
              {:timeout, new_state}
            end
        end

      {:ok, :eof} ->
        {:eof, state}

      {:ok, {:error, _reason}} ->
        {:eof, state}

      nil ->
        # Timeout - no input received
        {:timeout, state}
    end
  end

  # Read a single character from stdin
  @spec read_char() :: {:ok, binary()} | :eof | {:error, term()}
  defp read_char do
    case IO.getn("", 1) do
      :eof -> :eof
      {:error, reason} -> {:error, reason}
      data when is_binary(data) -> {:ok, data}
      # Handle unexpected return types
      other -> {:error, {:unexpected_io_return, other}}
    end
  end
end
