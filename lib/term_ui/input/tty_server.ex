defmodule TermUI.Input.TTY.Server do
  @moduledoc """
  GenServer that manages IEx-compatible TTY input using a separate process.

  This server spawns a separate process that continuously polls for input using
  `:io.get_chars/2`. This approach allows TUI applications to work correctly
  inside IEx, bypassing IEx's input interception.

  ## Architecture

  The server manages a spawned process that:
  1. Continuously polls with `receive after 0` for non-blocking behavior
  2. Calls `:io.get_chars("", 1)` to read single characters
  3. Parses escape sequences and converts charlists to binaries
  4. Sends parsed key events as messages to the server

  The server maintains:
  - A queue of parsed events waiting to be delivered
  - The original IO options (for restoration on shutdown)
  - The spawned input process PID

  ## Usage

      {:ok, server} = TermUI.Input.TTY.Server.start_link(receiver: self())
      {:ok, event} = TermUI.Input.TTY.Server.poll(server, 100)
      :ok = TermUI.Input.TTY.Server.stop(server)

  ## IO Server Configuration

  The server configures the IO server on startup:
  - Saves original options via `:io.getopts/0`
  - Sets `echo: false` to disable character echo
  - Sets `binary: false` so `:io.get_chars/2` returns charlists

  On termination, it restores the original options.
  """

  use GenServer
  require Logger

  alias TermUI.Terminal.EscapeParser

  # Dialyzer: Complex guard patterns in handle_escape_timeout/3 and parse_buffer/1
  # Dialyzer: input_loop/4 is called in spawn, Dialyzer cannot prove safety
  @dialyzer {:nowarn_function,
             handle_escape_timeout: 3,
             parse_buffer: 1,
             input_loop: 4,
             handle_info: 2,
             terminate: 2,
             setup_io_opts: 0,
             restore_io_opts: 1}

  @escape_timeout 100
  @max_queue_size 1000

  defstruct event_queue: [],
            buffer: <<>>,
            original_opts: nil,
            input_pid: nil,
            receiver: nil

  # Client API

  @doc """
  Starts the TTY input server.

  ## Options

  - `:receiver` - PID to send key events to (defaults to `self()`)
  - `:name` - Name for GenServer registration (optional)

  ## Examples

      {:ok, server} = TermUI.Input.TTY.Server.start_link()
      {:ok, server} = TermUI.Input.TTY.Server.start_link(receiver: some_pid)
  """
  def start_link(opts \\ []) do
    {gen_opts, opts} = Keyword.split(opts, [:name])
    GenServer.start_link(__MODULE__, opts, gen_opts)
  end

  @doc """
  Stops the TTY input server.
  """
  def stop(server, reason \\ :normal, timeout \\ 5000) do
    GenServer.stop(server, reason, timeout)
  end

  @doc """
  Polls for a key event.

  Returns the next queued event, or waits for one if none is available.
  The timeout is in milliseconds.

  ## Returns

  - `{:ok, event}` - A key event was received
  - `{:error, :eof}` - End of input stream
  - `{:error, :timeout}` - No event within timeout (rare in TTY mode)

  ## Examples

      case TermUI.Input.TTY.Server.poll(server, 100) do
        {:ok, %Event.Key{} = event} -> handle_key(event)
        {:error, :eof} -> handle_shutdown()
      end
  """
  def poll(server, timeout \\ 100) do
    GenServer.call(server, {:poll, timeout}, timeout + 100)
  end

  @doc """
  Returns the current event queue size.
  """
  def queue_size(server) do
    GenServer.call(server, :queue_size)
  end

  # Server Callbacks

  @impl true
  def init(opts) do
    receiver = Keyword.get(opts, :receiver)

    # Save original IO options and configure for TTY input
    original_opts = setup_io_opts()

    # Spawn the input process
    input_pid = spawn_input_process(self(), receiver)

    state = %__MODULE__{
      original_opts: original_opts,
      input_pid: input_pid,
      receiver: receiver,
      buffer: <<>>,
      event_queue: []
    }

    {:ok, state}
  end

  @impl true
  def handle_call({:poll, _timeout}, _from, %__MODULE__{} = state) do
    case state.event_queue do
      [event | rest] ->
        {:reply, {:ok, event}, %{state | event_queue: rest}}

      [] ->
        # Check if input process is still alive
        if Process.alive?(state.input_pid) do
          # No events queued, wait a bit and check again
          # In TTY mode, we typically block, so we'll tell caller to try again
          # or wait for next message
          {:reply, {:error, :no_event}, state}
        else
          # Input process died, likely EOF
          {:reply, {:error, :eof}, state}
        end
    end
  end

  @impl true
  def handle_call(:queue_size, _from, state) do
    {:reply, length(state.event_queue), state}
  end

  @impl true
  def handle_cast({:input, data}, state) do
    # Process input data from the input process
    new_state = process_input_data(state, data)
    {:noreply, new_state}
  end

  @impl true
  def handle_cast(:eof, state) do
    # Input process reached EOF
    {:noreply, state}
  end

  @impl true
  def handle_info({:input_event, event}, state) do
    # Direct event from input process (for immediate delivery)
    new_queue = limit_queue(state.event_queue ++ [event])
    {:noreply, %{state | event_queue: new_queue}}
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, pid, reason}, %{input_pid: pid} = state) do
    # Input process died
    Logger.debug("TTY.Server: Input process died: #{inspect(reason)}")
    {:noreply, state}
  end

  @impl true
  def terminate(_reason, state) do
    # Stop input process
    if state.input_pid && Process.alive?(state.input_pid) do
      Process.exit(state.input_pid, :stop)
    end

    # Restore original IO options
    if state.original_opts do
      restore_io_opts(state.original_opts)
    end

    :ok
  end

  # Private Functions

  defp setup_io_opts do
    # Save original options
    original = :io.getopts() |> Keyword.take([:echo, :binary])

    # Set options for TTY input
    :io.setopts(echo: false, binary: false)

    original
  end

  defp restore_io_opts(original) do
    :io.setopts(original)
  end

  defp spawn_input_process(server, receiver) do
    spawn(fn ->
      input_loop(server, receiver, <<>>, System.monotonic_time(:millisecond))
    end)
  end

  # Input loop - runs in separate process
  # Inspired by snake_test's TUI.loop/3
  defp input_loop(server, receiver, buffer, last_read_time) do
    receive do
      :stop ->
        :ok
    after
      0 ->
        # Try to read input
        case :io.get_chars(~c"", 1) do
          :eof ->
            # End of input
            GenServer.cast(server, :eof)
            :ok

          chars when is_list(chars) ->
            now = System.monotonic_time(:millisecond)
            dt = now - last_read_time

            # Handle escape sequence timeout
            {new_buffer, events} = handle_escape_timeout(buffer, chars, dt)

            # Parse complete sequences
            {remaining_buffer, parsed_events} = parse_buffer(new_buffer)

            # Combine events from timeout handling and parsing
            all_events = events ++ parsed_events

            # Send events to receiver
            Enum.each(all_events, fn event ->
              send(receiver, {:input_event, event})
            end)

            # Also queue them in the server for poll/2
            if all_events != [] do
              GenServer.cast(server, {:input, all_events})
            end

            input_loop(server, receiver, remaining_buffer, now)

          other ->
            Logger.debug("TTY.Server: Unexpected input: #{inspect(other)}")
            input_loop(server, receiver, buffer, System.monotonic_time(:millisecond))
        end
    end
  end

  # Handle escape sequence timeout (similar to snake_test timeout/3)
  # If we get another ESC quickly (<100ms), it's an ESC key press
  # If we get other chars, accumulate them for parsing
  defp handle_escape_timeout(buffer, chars, dt) when dt < @escape_timeout do
    # Within timeout window, just accumulate
    {buffer ++ chars, []}
  end

  defp handle_escape_timeout(~c"\e", ~c"\e", _dt) do
    # Two ESC presses - emit ESC key
    {~c"\e", [:escape]}
  end

  defp handle_escape_timeout(~c"\e", chars, _dt) do
    # ESC followed by other chars - start of escape sequence
    {~c"\e" ++ chars, []}
  end

  defp handle_escape_timeout(buffer, chars, _dt) do
    # Normal case - just accumulate
    {buffer ++ chars, []}
  end

  # Parse buffer for complete sequences
  defp parse_buffer(charlist) do
    # Convert charlist to binary for parsing
    binary = :unicode.characters_to_binary(charlist)

    case EscapeParser.parse(binary) do
      {[event | rest_events], remaining} ->
        # Got at least one event
        # Convert remaining back to charlist
        remaining_charlist = :unicode.characters_to_list(remaining)
        {remaining_charlist, [event | rest_events]}

      {[], _remaining} ->
        # No complete events yet
        {charlist, []}
    end
  end

  defp limit_queue(events) when length(events) <= @max_queue_size, do: events

  defp limit_queue(events) do
    Logger.warning(
      "TTY.Server: Event queue overflow, dropping #{length(events) - @max_queue_size} events"
    )

    Enum.take(events, @max_queue_size)
  end

  defp process_input_data(state, events) when is_list(events) do
    new_queue = limit_queue(state.event_queue ++ events)
    %{state | event_queue: new_queue}
  end

  defp process_input_data(state, event) do
    new_queue = limit_queue(state.event_queue ++ [event])
    %{state | event_queue: new_queue}
  end
end
