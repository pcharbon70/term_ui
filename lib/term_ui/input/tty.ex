defmodule TermUI.Input.TTY do
  @moduledoc """
  TTY mode input handler implementing the `TermUI.Input` behaviour.

  This module requests one character at a time using `IO.getn/2` for IEx
  compatibility. The terminal remains in cooked mode, so the shell or terminal
  driver may still buffer those characters until Enter is pressed.

  ## Features

  - **IEx Compatible**: Reads through the active shell's IO server without
    replacing its cooked mode
  - **Single-character reads**: Processes one requested character at a time
  - **Normalized keyboard parsing**: Arrow keys, Tab, Enter, and function keys
    are parsed once their bytes are delivered
  - **Escape sequence parsing**: Handles arrow keys, function keys, mouse events,
    and other terminal escape sequences
  - **Buffer management**: Maintains partial escape sequences between poll calls
  - **Security**: Buffer and queue size limits prevent memory exhaustion

  ## IEx Compatibility

  IEx owns the active shell, so the TTY backend reads through that shell's IO
  server instead of trying to replace it with a Raw shell. This allows a TermUI
  application to receive input and return cleanly to the IEx prompt.

  This approach was verified in the `snake_test` project where TUI applications
  run correctly inside IEx using this method.

  ## How Arrow Keys and Special Keys Work

  `IO.getn/2` requests one character, but it does not disable the operating
  system's canonical input mode. Delivery therefore depends on the active shell
  and terminal driver. Some environments deliver each key immediately; others
  buffer input until Enter. Once delivered:

  - **Arrow keys**: Work normally (↑↓←→)
  - **Tab**: Works for field/button navigation
  - **Enter**: Detected immediately for selection
  - **Function keys**: F1-F12 work normally
  - **Ctrl combinations**: Retain the active shell's cooked-mode behavior; some
    combinations may be handled by the terminal rather than emitted as events

  Most keyboard-driven widgets remain usable, with line buffering as the main
  compatibility difference from Raw mode.

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
  | Arrow/Tab/Enter | Yes (delivery may be buffered) | Yes |
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
  bytes), the partial sequence is buffered and completed in the dedicated input
  reader process before an event is returned.

  TTY IO requests cannot be cancelled safely: a timed-out request can still
  consume a later byte. Sequence completion therefore stays synchronous. In a
  cooked terminal, a lone Escape is emitted when the containing line is
  submitted.

  ## Security

  This module implements several security measures to prevent resource exhaustion:

  - **Buffer size limit**: Input buffer is limited by `InputBuffer.apply_limit/2`
    (1KB max, truncates to 256 bytes when exceeded). This prevents memory
    exhaustion from malformed or malicious escape sequences.

  - **Event queue limit**: Maximum 1000 events can be queued. Excess events are
    dropped with a warning. This prevents memory exhaustion from rapid input.

  - **Rate-limited logging**: Buffer overflow warnings use rate-limited logging
    (via `InputBuffer`) to prevent log flooding attacks.

  - **Dedicated blocking reader**: Partial sequences are completed outside the
    runtime process, so blocking TTY delivery cannot stall rendering or cleanup.

  For concurrent usage, each handler instance maintains independent state, so
  memory usage scales linearly with the number of concurrent handlers.
  """

  @behaviour TermUI.Input

  require Logger

  alias TermUI.Backend.InputBuffer
  alias TermUI.Event
  alias TermUI.Terminal.EscapeParser

  # Dialyzer: Functions return specific struct types
  # Dialyzer: emit_partial_escape/1 calls Event.key with string args for partial escape chars
  # Key.new/2 spec says atom() but the function works with strings too
  @dialyzer {:nowarn_function,
             new: 0,
             stop: 1,
             emit_partial_escape: 1,
             restore_io_opts: 1,
             process_input: 2,
             poll: 2,
             setup_io_opts: 0,
             read_char: 0}

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
    # TTY input is blocking, so complete escape sequences in this reader
    # process. A timed Task cannot safely cancel an outstanding IO request:
    # the request may still consume a byte after the Task is stopped.
    do_read_blocking(state)
  end

  # Emit partial escape sequence as individual key events
  @spec emit_partial_escape(t()) :: TermUI.Input.poll_result()
  defp emit_partial_escape(%__MODULE__{buffer: <<27, rest::binary>>} = state) do
    {rest_events, remaining} = EscapeParser.parse(rest)
    event = Event.key(:escape)

    {{:ok, event}, %{state | buffer: remaining, event_queue: limit_queue(rest_events)}}
  end

  defp emit_partial_escape(%__MODULE__{} = state), do: do_read_blocking(state)

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
    data = normalize_line_ending(state.buffer, data)
    new_buffer = state.buffer <> data
    # InputBuffer.apply_limit uses rate-limited logging via the :source option
    {limited_buffer, _truncated} = InputBuffer.apply_limit(new_buffer, source: :input_tty)

    new_state = %{state | buffer: limited_buffer}

    case try_parse_buffer(new_state) do
      {:ok, event, final_state} ->
        {{:ok, event}, final_state}

      :need_more ->
        if line_ending?(data) and not bracketed_paste?(new_state.buffer) do
          emit_partial_escape(new_state)
        else
          # Still need more, continue reading in the same process so no IO
          # request can consume and discard part of an escape sequence.
          read_blocking(new_state)
        end
    end
  end

  defp line_ending?(data), do: data in ["\n", "\r"]

  # Cooked terminal input commonly reports Enter as LF, while TermUI's event
  # parser uses CR for :enter. Preserve literal LF inside bracketed paste.
  defp normalize_line_ending(buffer, "\n") do
    if bracketed_paste?(buffer), do: "\n", else: "\r"
  end

  defp normalize_line_ending(_buffer, data), do: data

  defp bracketed_paste?(<<27, "[200~", _rest::binary>>), do: true
  defp bracketed_paste?(_buffer), do: false

  # Read a single character from stdin using :io.get_chars/2
  # This is the key to IEx compatibility - using Erlang's :io module directly
  @spec read_char() :: {:ok, binary()} | :eof | {:error, term()}
  defp read_char do
    result = :io.get_chars(~c"", 1)

    case result do
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

      chars when is_binary(chars) ->
        {:ok, chars}

      {:error, reason} ->
        {:error, reason}

      other ->
        {:error, {:unexpected_io_return, other}}
    end
  end
end
