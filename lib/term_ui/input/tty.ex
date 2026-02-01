defmodule TermUI.Input.TTY do
  @moduledoc """
  TTY mode input handler implementing the `TermUI.Input` behaviour.

  This module provides character-by-character input using `:io.get_chars/2`
  for IEx compatibility. The key to IEx compatibility is using Erlang's `:io`
  module directly instead of Elixir's `IO` module wrapper.

  ## Features

  - **IEx Compatible**: Uses `:io.get_chars/2` to bypass IEx's input interception
  - **Character-by-character input**: Single character reads work immediately
  - **Full keyboard support**: Arrow keys, Tab, Enter, function keys work normally
  - **Escape sequence parsing**: Handles arrow keys, function keys, mouse events,
    and other terminal escape sequences
  - **Buffer management**: Maintains partial escape sequences between poll calls
  - **Security**: Buffer and queue size limits prevent memory exhaustion

  ## IEx Compatibility

  The key to IEx compatibility is using `:io.get_chars/2` (Erlang) instead of
  `IO.getn/2` (Elixir). While both ultimately use the same IO server, the direct
  Erlang call behaves differently when running inside IEx, allowing TUI applications
  to receive keyboard input instead of having it stolen by IEx.

  This approach was verified in the `snake_test` project where TUI applications
  run correctly inside IEx using this method.

  ## How Arrow Keys and Special Keys Work

  A common misconception is that TTY mode requires Enter to submit input. This is
  only true for `IO.gets/1` (line-based input). Single character reads via
  `:io.get_chars/2` return immediately, so:

  - **Arrow keys**: Work normally (↑↓←→)
  - **Tab**: Works for field/button navigation
  - **Enter**: Detected immediately for selection
  - **Function keys**: F1-F12 work normally
  - **Ctrl combinations**: Ctrl+C, Ctrl+Z, etc. work

  This means most TUI widgets work **identically** in both Raw and TTY modes.

  ## Usage

      # Create initial state
      state = TermUI.Input.TTY.new()

      # Poll for input (timeout is noted but not honored - blocking I/O)
      case TermUI.Input.TTY.poll(state, 100) do
        {{:ok, event}, new_state} -> handle_event(event, new_state)
        {:eof, new_state} -> handle_shutdown(new_state)
      end

  ## Timeout Semantics

  **Important**: The timeout parameter is accepted for API compatibility but
  is **not honored** in TTY mode. `:io.get_chars/2` is blocking and will wait
  indefinitely for input. Design your application to handle this:

  - Don't rely on `:timeout` results for animations
  - Consider using a separate process for time-based updates
  - For timeout support, use the Raw backend instead

  ## Comparison with Raw Input Handler

  | Feature | TTY (`Input.TTY`) | Raw (`Input.Raw`) |
  |---------|-------------------|-------------------|
  | IEx Compatible | Yes | No |
  | Timeout support | No (blocking) | Yes (Task-based) |
  | Non-blocking poll | No | Yes |
  | Escape sequences | Yes | Yes |
  | Arrow/Tab/Enter | Yes | Yes |
  | Mouse events | Yes | Yes |

  ## When to Use TTY Mode

  TTY mode is appropriate when:
  - You want to run TUI applications inside IEx
  - You don't need timeout-based polling
  - You want simpler deployment (no raw mode setup)
  - Your application can block waiting for input
  - You're building simple interactive scripts

  For applications requiring animations, periodic updates, or non-blocking
  input checks, use the Raw backend with `Input.Raw` instead.

  ## Escape Sequence Handling

  When an escape sequence spans multiple reads (e.g., arrow keys send multiple
  bytes), the partial sequence is buffered and completed on subsequent polls.

  When a partial escape sequence is detected (e.g., lone ESC), the handler waits
  up to 100ms for completion using a blocking read. This matches standard terminal
  emulator behavior and distinguishes ESC key presses from escape sequences.

  ## Security

  This module implements several security measures to prevent resource exhaustion:

  - **Buffer size limit**: Input buffer is limited by `InputBuffer.apply_limit/2`
    (1KB max, truncates to 256 bytes when exceeded). This prevents memory
    exhaustion from malformed or malicious escape sequences.

  - **Event queue limit**: Maximum 1000 events can be queued. Excess events are
    dropped with a warning. This prevents memory exhaustion from rapid input.

  - **Rate-limited logging**: Buffer overflow warnings use rate-limited logging
    (via `InputBuffer`) to prevent log flooding attacks.

  - **Escape sequence timeout**: Partial sequences timeout after 100ms, preventing
    indefinite buffering of incomplete sequences.

  For concurrent usage, each handler instance maintains independent state, so
  memory usage scales linearly with the number of concurrent handlers.
  """

  @behaviour TermUI.Input

  require Logger

  alias TermUI.Backend.InputBuffer
  alias TermUI.Event
  alias TermUI.Terminal.EscapeParser

  # Timeout for escape sequence completion (ms).
  # Matches snake_test's 100ms timeout for distinguishing ESC key presses.
  @escape_timeout 100

  # Maximum event queue size to prevent memory exhaustion.
  @max_queue_size 1000

  defstruct buffer: <<>>,
            event_queue: [],
            io_opts_restored: false,
            io_opts_set: false,
            original_opts: []

  @typedoc """
  State for the TTY input handler.

  - `:buffer` - Binary buffer for partial escape sequences
  - `:event_queue` - Queue of parsed events waiting to be returned
  - `:io_opts_restored` - Whether IO options have been restored
  - `:io_opts_set` - Whether IO options have been set
  """
  @type t :: %__MODULE__{
          buffer: binary(),
          event_queue: [Event.t()],
          io_opts_restored: boolean(),
          io_opts_set: boolean()
        }

  @doc """
  Creates a new TTY input handler state.

  Configures the IO server for TTY input (echo: false, binary: false).

  ## Examples

      state = TermUI.Input.TTY.new()
  """
  @spec new() :: t()
  def new do
    # Set IO options for IEx-compatible TTY input
    # We save the original options so we can restore them later
    original_opts = setup_io_opts()

    %__MODULE__{
      buffer: <<>>,
      event_queue: [],
      io_opts_set: true,
      io_opts_restored: false,
      original_opts: original_opts
    }
  end

  @doc """
  Polls for input.

  **Note**: The timeout parameter is accepted for API compatibility but is
  **not honored** in TTY mode. `:io.get_chars/2` is blocking and will wait
  indefinitely for input. This function will not return `:timeout` in normal operation.

  ## Parameters

  - `state` - Current handler state
  - `timeout` - Maximum wait time in milliseconds (ignored in TTY mode)

  ## Returns

  - `{{:ok, event}, new_state}` - An event was received
  - `{:eof, new_state}` - End of input stream

  ## Examples

      # Note: timeout is ignored, this will block until input
      {result, state} = TTY.poll(state, 100)
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
            # Need to read more input (blocking)
            read_blocking(state)
        end
    end
  end

  @doc """
  Returns the input mode for this handler.

  Always returns `:tty` for the TTY input handler.

  ## Examples

      mode = TTY.mode(state)
      # => :tty
  """
  @impl TermUI.Input
  @spec mode(t()) :: :tty
  def mode(%__MODULE__{}), do: :tty

  @doc """
  Stops the TTY input handler and restores IO options.

  ## Examples

      :ok = TTY.stop(state)
  """
  @impl TermUI.Input
  @spec stop(t()) :: :ok
  def stop(%__MODULE__{original_opts: original_opts}) do
    restore_io_opts(original_opts)
    # Ensure echo is enabled after stopping (critical for IEx compatibility)
    # We do this unconditionally because IEx always needs echo on
    :io.setopts(echo: true)
    :ok
  end

  # Private Functions

  defp setup_io_opts do
    # Save original options
    original = :io.getopts() |> Keyword.take([:echo, :binary])

    # Set options for TTY input (like snake_test does)
    # binary: false means :io.get_chars returns charlists
    :io.setopts(echo: false, binary: false)

    original
  end

  defp restore_io_opts(original_opts) do
    # Restore echo and binary mode from original options
    # We use Keyword.get to safely extract values with defaults
    echo = Keyword.get(original_opts, :echo, true)
    binary = Keyword.get(original_opts, :binary, true)
    :io.setopts(echo: echo, binary: binary)
  end

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
      "Input.TTY: Event queue overflow, dropping #{length(events) - @max_queue_size} events"
    )

    Enum.take(events, @max_queue_size)
  end

  # Read input with blocking I/O
  @spec read_blocking(t()) :: TermUI.Input.poll_result()
  defp read_blocking(%__MODULE__{} = state) do
    # Check if we have a partial escape sequence that needs timeout handling
    if EscapeParser.partial_sequence?(state.buffer) do
      # Wait a short time for escape sequence completion
      handle_escape_timeout(state)
    else
      # Normal blocking read
      do_read_blocking(state)
    end
  end

  # Handle the case where we have a partial escape sequence
  @spec handle_escape_timeout(t()) :: TermUI.Input.poll_result()
  defp handle_escape_timeout(%__MODULE__{} = state) do
    # For TTY mode, we use a Task with short timeout to check for sequence completion
    task = Task.async(fn -> read_char() end)

    case Task.yield(task, @escape_timeout) do
      {:ok, {:ok, data}} ->
        # Got more input, add to buffer and try to parse
        process_input(state, data)

      {:ok, :eof} ->
        {:eof, state}

      {:ok, {:error, reason}} ->
        Logger.debug("Input.TTY: IO read error: #{inspect(reason)}")
        {:eof, state}

      nil ->
        # Timeout - escape sequence didn't complete, emit partial
        Task.shutdown(task)
        emit_partial_escape(state)
    end
  end

  # Emit partial escape sequence as individual key events
  @spec emit_partial_escape(t()) :: TermUI.Input.poll_result()
  defp emit_partial_escape(%__MODULE__{buffer: buffer} = state) do
    events =
      cond do
        # Lone ESC
        buffer == <<27>> ->
          [Event.key(:escape)]

        # ESC[ without terminator
        buffer == <<27, ?[>> ->
          [Event.key(:escape), Event.key("[", char: "[")]

        # ESC O without terminator
        buffer == <<27, ?O>> ->
          [Event.key(:escape), Event.key("O", char: "O")]

        # Other partial sequences starting with ESC
        String.starts_with?(buffer, <<27>>) ->
          <<27, rest::binary>> = buffer
          {rest_events, _} = EscapeParser.parse(rest)
          [Event.key(:escape) | rest_events]

        true ->
          []
      end

    case events do
      [event | rest] ->
        # Return first event, queue rest, clear buffer
        {{:ok, event}, %{state | buffer: <<>>, event_queue: rest}}

      [] ->
        # No events to emit, continue with blocking read
        do_read_blocking(%{state | buffer: <<>>})
    end
  end

  # Perform the actual blocking read
  @spec do_read_blocking(t()) :: TermUI.Input.poll_result()
  defp do_read_blocking(%__MODULE__{} = state) do
    case read_char() do
      {:ok, data} ->
        process_input(state, data)

      :eof ->
        {:eof, state}

      {:error, reason} ->
        Logger.debug("Input.TTY: IO read error: #{inspect(reason)}")
        {:eof, state}
    end
  end

  # Process input data and try to parse
  @spec process_input(t(), binary()) :: TermUI.Input.poll_result()
  defp process_input(%__MODULE__{} = state, data) do
    new_buffer = state.buffer <> data
    # InputBuffer.apply_limit uses rate-limited logging via the :source option
    {limited_buffer, _truncated} = InputBuffer.apply_limit(new_buffer, source: :input_tty)

    new_state = %{state | buffer: limited_buffer}

    case try_parse_buffer(new_state) do
      {:ok, event, final_state} ->
        {{:ok, event}, final_state}

      :need_more ->
        # Still need more, continue reading
        read_blocking(new_state)
    end
  end

  # Read a single character from stdin using :io.get_chars/2
  # This is the key to IEx compatibility - using Erlang's :io module directly
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
