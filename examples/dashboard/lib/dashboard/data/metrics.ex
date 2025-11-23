defmodule Dashboard.Data.Metrics do
  @moduledoc """
  Generates simulated system metrics with realistic patterns.

  Metrics follow realistic patterns:
  - CPU varies smoothly with occasional spikes
  - Memory gradually increases then drops (simulating GC)
  - Network has bursty patterns
  - Processes have stable resource usage with slight variations
  """

  use GenServer

  @update_interval 1000

  # State structure
  defstruct [
    :cpu_history,
    :memory_history,
    :network_rx_history,
    :network_tx_history,
    :processes,
    :uptime_seconds,
    :cpu_base,
    :memory_base,
    :tick
  ]

  # Public API

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def get_metrics do
    GenServer.call(__MODULE__, :get_metrics)
  end

  def get_cpu do
    GenServer.call(__MODULE__, :get_cpu)
  end

  def get_memory do
    GenServer.call(__MODULE__, :get_memory)
  end

  def get_network do
    GenServer.call(__MODULE__, :get_network)
  end

  def get_processes do
    GenServer.call(__MODULE__, :get_processes)
  end

  def get_system_info do
    GenServer.call(__MODULE__, :get_system_info)
  end

  # GenServer callbacks

  @impl true
  def init(_opts) do
    state = %__MODULE__{
      cpu_history: List.duplicate(25.0, 60),
      memory_history: List.duplicate(45.0, 60),
      network_rx_history: List.duplicate(0.0, 30),
      network_tx_history: List.duplicate(0.0, 30),
      processes: generate_initial_processes(),
      uptime_seconds: :rand.uniform(86400 * 7),
      cpu_base: 25.0,
      memory_base: 45.0,
      tick: 0
    }

    schedule_update()
    {:ok, state}
  end

  @impl true
  def handle_call(:get_metrics, _from, state) do
    metrics = %{
      cpu: current_cpu(state),
      memory: current_memory(state),
      network_rx: state.network_rx_history,
      network_tx: state.network_tx_history,
      processes: state.processes,
      uptime: state.uptime_seconds
    }

    {:reply, metrics, state}
  end

  def handle_call(:get_cpu, _from, state) do
    {:reply, %{current: current_cpu(state), history: state.cpu_history}, state}
  end

  def handle_call(:get_memory, _from, state) do
    {:reply, %{current: current_memory(state), history: state.memory_history}, state}
  end

  def handle_call(:get_network, _from, state) do
    {:reply, %{rx: state.network_rx_history, tx: state.network_tx_history}, state}
  end

  def handle_call(:get_processes, _from, state) do
    {:reply, state.processes, state}
  end

  def handle_call(:get_system_info, _from, state) do
    info = %{
      hostname: "localhost",
      kernel: "Linux 6.8.0",
      uptime: format_uptime(state.uptime_seconds),
      load_avg: generate_load_avg(state)
    }

    {:reply, info, state}
  end

  @impl true
  def handle_info(:update, state) do
    new_state = update_metrics(state)
    schedule_update()
    {:noreply, new_state}
  end

  # Private functions

  defp schedule_update do
    Process.send_after(self(), :update, @update_interval)
  end

  defp current_cpu(state), do: hd(state.cpu_history)
  defp current_memory(state), do: hd(state.memory_history)

  defp update_metrics(state) do
    tick = state.tick + 1

    # Update CPU with smooth variations and occasional spikes
    cpu_base = update_cpu_base(state.cpu_base, tick)
    cpu_value = cpu_base + :rand.uniform() * 5 - 2.5 + spike_factor(tick, 0.05) * 30
    cpu_value = clamp(cpu_value, 5.0, 95.0)

    # Update memory with gradual increase and periodic drops (GC simulation)
    memory_base = update_memory_base(state.memory_base, tick)
    memory_value = memory_base + :rand.uniform() * 3 - 1.5
    memory_value = clamp(memory_value, 20.0, 85.0)

    # Update network with bursty patterns
    rx_value = generate_network_value(tick, 0)
    tx_value = generate_network_value(tick, 100)

    # Update processes with slight variations
    processes = update_processes(state.processes)

    %{
      state
      | cpu_history: [cpu_value | Enum.take(state.cpu_history, 59)],
        memory_history: [memory_value | Enum.take(state.memory_history, 59)],
        network_rx_history: [rx_value | Enum.take(state.network_rx_history, 29)],
        network_tx_history: [tx_value | Enum.take(state.network_tx_history, 29)],
        processes: processes,
        uptime_seconds: state.uptime_seconds + 1,
        cpu_base: cpu_base,
        memory_base: memory_base,
        tick: tick
    }
  end

  defp update_cpu_base(base, tick) do
    # Slow sinusoidal variation
    adjustment = :math.sin(tick / 30) * 5
    new_base = base + adjustment * 0.1 + (:rand.uniform() - 0.5) * 2
    clamp(new_base, 15.0, 60.0)
  end

  defp update_memory_base(base, tick) do
    # Gradual increase with periodic drops
    if rem(tick, 60) == 0 do
      # Simulate GC - drop memory
      clamp(base - 10, 35.0, 75.0)
    else
      # Gradual increase
      clamp(base + 0.2, 35.0, 75.0)
    end
  end

  defp spike_factor(_tick, probability) do
    if :rand.uniform() < probability do
      1.0
    else
      0.0
    end
  end

  defp generate_network_value(tick, offset) do
    # Bursty network pattern
    base = :math.sin((tick + offset) / 5) * 30 + 40
    burst = if :rand.uniform() < 0.1, do: :rand.uniform() * 50, else: 0
    clamp(base + burst + :rand.uniform() * 10, 0.0, 100.0)
  end

  defp generate_initial_processes do
    [
      %{pid: 1, name: "systemd", cpu: 0.1, memory: 12},
      %{pid: 234, name: "beam.smp", cpu: 8.5, memory: 256},
      %{pid: 456, name: "postgres", cpu: 3.2, memory: 128},
      %{pid: 789, name: "nginx", cpu: 1.1, memory: 48},
      %{pid: 1012, name: "redis-server", cpu: 2.4, memory: 64},
      %{pid: 1234, name: "node", cpu: 5.6, memory: 192},
      %{pid: 1456, name: "docker", cpu: 1.8, memory: 96},
      %{pid: 1678, name: "sshd", cpu: 0.2, memory: 8},
      %{pid: 1890, name: "cron", cpu: 0.0, memory: 4},
      %{pid: 2012, name: "rsyslogd", cpu: 0.3, memory: 16}
    ]
  end

  defp update_processes(processes) do
    Enum.map(processes, fn proc ->
      %{
        proc
        | cpu: clamp(proc.cpu + (:rand.uniform() - 0.5) * 1.0, 0.0, 100.0),
          memory: max(proc.memory + round((:rand.uniform() - 0.5) * 4), 1)
      }
    end)
    |> Enum.sort_by(& &1.cpu, :desc)
  end

  defp generate_load_avg(state) do
    base = current_cpu(state) / 25
    {
      Float.round(base + :rand.uniform() * 0.3, 2),
      Float.round(base * 0.8 + :rand.uniform() * 0.2, 2),
      Float.round(base * 0.6 + :rand.uniform() * 0.1, 2)
    }
  end

  defp format_uptime(seconds) do
    days = div(seconds, 86400)
    hours = div(rem(seconds, 86400), 3600)
    minutes = div(rem(seconds, 3600), 60)

    cond do
      days > 0 -> "#{days}d #{hours}h #{minutes}m"
      hours > 0 -> "#{hours}h #{minutes}m"
      true -> "#{minutes}m"
    end
  end

  defp clamp(value, min, max) do
    value
    |> max(min)
    |> min(max)
  end
end
