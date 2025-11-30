defmodule StreamWidgetExample.Producer do
  @moduledoc """
  A GenStage producer that generates streaming data events.
  """

  use GenStage

  defstruct [:counter, :interval_ms, :paused, :timer_ref]

  @doc """
  Start the producer.

  ## Options

  - `:interval_ms` - Time between events in milliseconds (default: 100)
  """
  def start_link(opts \\ []) do
    GenStage.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Set the event generation interval.
  """
  def set_interval(producer \\ __MODULE__, interval_ms) do
    GenStage.cast(producer, {:set_interval, interval_ms})
  end

  @doc """
  Pause event generation.
  """
  def pause(producer \\ __MODULE__) do
    GenStage.cast(producer, :pause)
  end

  @doc """
  Resume event generation.
  """
  def resume(producer \\ __MODULE__) do
    GenStage.cast(producer, :resume)
  end

  # GenStage Callbacks

  @impl true
  def init(opts) do
    interval_ms = Keyword.get(opts, :interval_ms, 100)

    state = %__MODULE__{
      counter: 0,
      interval_ms: interval_ms,
      paused: false,
      timer_ref: nil
    }

    # Schedule first tick
    timer_ref = Process.send_after(self(), :tick, interval_ms)

    {:producer, %{state | timer_ref: timer_ref}}
  end

  @impl true
  def handle_demand(_demand, state) do
    # We produce on timer, not on demand
    {:noreply, [], state}
  end

  @impl true
  def handle_cast({:set_interval, interval_ms}, state) do
    {:noreply, [], %{state | interval_ms: interval_ms}}
  end

  def handle_cast(:pause, state) do
    if state.timer_ref do
      Process.cancel_timer(state.timer_ref)
    end

    {:noreply, [], %{state | paused: true, timer_ref: nil}}
  end

  def handle_cast(:resume, state) do
    if state.paused do
      timer_ref = Process.send_after(self(), :tick, state.interval_ms)
      {:noreply, [], %{state | paused: false, timer_ref: timer_ref}}
    else
      {:noreply, [], state}
    end
  end

  @impl true
  def handle_info(:tick, %{paused: true} = state) do
    {:noreply, [], state}
  end

  def handle_info(:tick, state) do
    # Generate an event
    event = generate_event(state.counter)

    # Schedule next tick
    timer_ref = Process.send_after(self(), :tick, state.interval_ms)

    new_state = %{state | counter: state.counter + 1, timer_ref: timer_ref}

    {:noreply, [event], new_state}
  end

  defp generate_event(counter) do
    type = Enum.random([:info, :warning, :error, :debug, :data])

    case type do
      :info ->
        "[INFO] Event ##{counter}: System status OK"

      :warning ->
        "[WARN] Event ##{counter}: Memory usage at #{:rand.uniform(100)}%"

      :error ->
        "[ERROR] Event ##{counter}: Connection timeout after #{:rand.uniform(5000)}ms"

      :debug ->
        "[DEBUG] Event ##{counter}: Processing batch of #{:rand.uniform(100)} items"

      :data ->
        value = :rand.uniform(1000) / 10
        "[DATA] Event ##{counter}: Metric value = #{value}"
    end
  end
end
