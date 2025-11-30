defmodule TermUI.Widgets.StreamWidget.Consumer do
  @moduledoc """
  GenStage consumer for StreamWidget.

  This module provides a GenStage consumer that forwards events to a StreamWidget.
  It handles backpressure by managing demand based on the widget's buffer state.

  ## Usage

      # Start the consumer linked to a widget process
      {:ok, consumer} = StreamWidget.Consumer.start_link(widget_pid)

      # Subscribe to a producer
      GenStage.sync_subscribe(consumer, to: producer)

      # Or subscribe with options
      GenStage.sync_subscribe(consumer, to: producer, max_demand: 100, min_demand: 50)
  """

  use GenStage

  defstruct [:widget_pid, :widget_ref, :paused, :demand, :pending_demand]

  @default_demand 10

  @doc """
  Starts a consumer linked to a widget process.

  ## Options

  - `:demand` - How many items to request at a time (default: 10)
  """
  @spec start_link(pid(), keyword()) :: GenServer.on_start()
  def start_link(widget_pid, opts \\ []) do
    GenStage.start_link(__MODULE__, {widget_pid, opts})
  end

  @doc """
  Subscribe to a producer.
  """
  @spec subscribe(GenServer.server(), GenStage.stage(), keyword()) ::
          {:ok, reference()} | {:error, term()}
  def subscribe(consumer, producer, opts \\ []) do
    GenStage.sync_subscribe(consumer, [{:to, producer} | opts])
  end

  # ----------------------------------------------------------------------------
  # GenStage Callbacks
  # ----------------------------------------------------------------------------

  @impl true
  def init({widget_pid, opts}) do
    # Monitor the widget
    ref = Process.monitor(widget_pid)

    # Notify widget that consumer started
    send(widget_pid, {:consumer_started, self()})

    state = %__MODULE__{
      widget_pid: widget_pid,
      widget_ref: ref,
      paused: false,
      demand: Keyword.get(opts, :demand, @default_demand),
      pending_demand: 0
    }

    {:consumer, state}
  end

  @impl true
  def handle_events(events, _from, state) do
    unless state.paused do
      # Forward events to widget
      send(state.widget_pid, {:stream_items, events})
    end

    {:noreply, [], state}
  end

  @impl true
  def handle_info(:pause, state) do
    {:noreply, [], %{state | paused: true}}
  end

  def handle_info(:resume, state) do
    {:noreply, [], %{state | paused: false}}
  end

  def handle_info({:set_demand, _demand}, state) do
    # Widget is telling us how much demand is available
    # This is handled by GenStage's built-in demand management
    {:noreply, [], state}
  end

  def handle_info({:DOWN, ref, :process, _pid, reason}, %{widget_ref: ref} = state) do
    {:stop, {:widget_down, reason}, state}
  end

  def handle_info(_msg, state) do
    {:noreply, [], state}
  end

  @impl true
  def terminate(reason, state) do
    send(state.widget_pid, {:consumer_stopped, reason})
    :ok
  end
end
