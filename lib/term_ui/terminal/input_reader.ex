defmodule TermUI.Terminal.InputReader do
  @moduledoc """
  GenServer that reads keyboard input from stdin and sends events to a target process.

  Uses a port to read from stdin in a non-blocking way. Parses escape sequences
  and emits Event.Key structs to the configured target process.

  ## Usage

      {:ok, reader} = InputReader.start_link(target: self())
      # Events will be sent as {:input, %Event.Key{}}

  ## Escape Sequence Handling

  Some sequences are ambiguous (ESC alone vs ESC followed by another key).
  The reader uses a timeout (default 50ms) to disambiguate - if no more bytes
  arrive within the timeout, a lone ESC is emitted.
  """

  use GenServer

  alias TermUI.Event
  alias TermUI.Terminal.EscapeParser

  @escape_timeout 50

  defstruct [:target, :port, :buffer, :timer_ref]

  @type t :: %__MODULE__{
          target: pid(),
          port: port() | nil,
          buffer: binary(),
          timer_ref: reference() | nil
        }

  # Client API

  @doc """
  Starts the InputReader.

  ## Options

  - `:target` - PID to receive events (required)
  - `:name` - GenServer name (optional)
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts) do
    target = Keyword.fetch!(opts, :target)
    name = Keyword.get(opts, :name)

    gen_opts = if name, do: [name: name], else: []
    GenServer.start_link(__MODULE__, target, gen_opts)
  end

  @doc """
  Stops the InputReader.
  """
  @spec stop(GenServer.server()) :: :ok
  def stop(server) do
    GenServer.stop(server)
  end

  # Server Callbacks

  @impl true
  def init(target) do
    state = %__MODULE__{
      target: target,
      port: nil,
      buffer: <<>>,
      timer_ref: nil
    }

    # Open port for stdin reading
    # Using `cat` as a simple way to read stdin
    port = Port.open({:spawn, "cat"}, [:binary, :eof])

    {:ok, %{state | port: port}}
  end

  @impl true
  def handle_info({port, {:data, data}}, %{port: port} = state) do
    # Cancel any pending escape timeout
    state = cancel_timer(state)

    # Add new data to buffer
    buffer = state.buffer <> data

    # Parse what we can
    {events, remaining} = EscapeParser.parse(buffer)

    # Send events to target
    Enum.each(events, fn event ->
      send(state.target, {:input, event})
    end)

    # If we have a partial escape sequence, set timeout
    state =
      if EscapeParser.partial_sequence?(remaining) do
        timer_ref = Process.send_after(self(), :escape_timeout, @escape_timeout)
        %{state | buffer: remaining, timer_ref: timer_ref}
      else
        %{state | buffer: remaining}
      end

    {:noreply, state}
  end

  @impl true
  def handle_info(:escape_timeout, state) do
    # Timeout waiting for more escape sequence bytes
    # Emit what we have as individual keys

    buffer = state.buffer

    events =
      cond do
        # Lone ESC
        buffer == <<0x1B>> ->
          [Event.key(:escape)]

        # ESC[ without terminator - emit ESC and [
        buffer == <<0x1B, ?[>> ->
          [Event.key(:escape), Event.key("[")]

        # ESC O without terminator
        buffer == <<0x1B, ?O>> ->
          [Event.key(:escape), Event.key("O")]

        # Other partial sequences - just emit ESC and try to parse rest
        String.starts_with?(buffer, <<0x1B>>) ->
          <<0x1B, rest::binary>> = buffer
          {rest_events, _} = EscapeParser.parse(rest)
          [Event.key(:escape) | rest_events]

        true ->
          []
      end

    Enum.each(events, fn event ->
      send(state.target, {:input, event})
    end)

    {:noreply, %{state | buffer: <<>>, timer_ref: nil}}
  end

  @impl true
  def handle_info({port, :eof}, %{port: port} = state) do
    # stdin closed
    {:stop, :normal, state}
  end

  @impl true
  def handle_info(_msg, state) do
    {:noreply, state}
  end

  @impl true
  def terminate(_reason, state) do
    # Close port if open
    if state.port && Port.info(state.port) do
      Port.close(state.port)
    end

    :ok
  end

  # Private functions

  defp cancel_timer(%{timer_ref: nil} = state), do: state

  defp cancel_timer(%{timer_ref: ref} = state) do
    Process.cancel_timer(ref)
    %{state | timer_ref: nil}
  end
end
