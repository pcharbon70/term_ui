defmodule ProcessMonitorExample.App do
  @moduledoc """
  Example application demonstrating the ProcessMonitor widget.

  This example shows:
  - Live BEAM process monitoring
  - Process info (PID, name, reductions, memory, queue)
  - Sorting and filtering
  - Process details and stack traces
  - Process actions (kill, suspend, resume)

  ## Controls

  - Up/Down: Move selection
  - PageUp/PageDown: Scroll by page
  - Enter: Toggle details panel
  - r: Refresh now
  - s: Cycle sort field
  - S: Toggle sort direction
  - /: Start filter input
  - k: Kill selected process (with confirmation)
  - p: Pause/resume selected process
  - l: Show links/monitors
  - t: Show stack trace
  - w: Spawn worker processes
  - Escape: Clear filter/close details
  - q: Quit
  """

  use TermUI.Elm

  alias TermUI.Widgets.ProcessMonitor
  alias TermUI.Renderer.Style

  @impl true
  def init(_args) do
    props =
      ProcessMonitor.new(
        update_interval: 1000,
        show_system_processes: false
      )

    {:ok, monitor_state} = ProcessMonitor.init(props)

    model = %{
      monitor_state: monitor_state,
      message: "ProcessMonitor Example - Press w to spawn test workers",
      worker_pids: []
    }

    {:ok, model}
  end

  @impl true
  def update(msg, model) do
    case msg do
      # Navigation
      {:key, %{key: key}} when key in [:up, :down, :page_up, :page_down, :home, :end] ->
        event = %TermUI.Event.Key{key: key}
        {:ok, monitor_state} = ProcessMonitor.handle_event(event, model.monitor_state)
        {:ok, %{model | monitor_state: monitor_state}}

      # Enter - toggle details
      {:key, %{key: :enter}} ->
        event = %TermUI.Event.Key{key: :enter}
        {:ok, monitor_state} = ProcessMonitor.handle_event(event, model.monitor_state)
        {:ok, %{model | monitor_state: monitor_state}}

      # Refresh
      {:key, %{char: "r"}} ->
        {:ok, monitor_state} = ProcessMonitor.refresh(model.monitor_state)
        {:ok, %{model | monitor_state: monitor_state, message: "Refreshed"}}

      # Sorting
      {:key, %{char: "s"}} ->
        event = %TermUI.Event.Key{char: "s"}
        {:ok, monitor_state} = ProcessMonitor.handle_event(event, model.monitor_state)
        {:ok, %{model | monitor_state: monitor_state, message: "Sort: #{monitor_state.sort_field}"}}

      {:key, %{char: "S"}} ->
        event = %TermUI.Event.Key{char: "S"}
        {:ok, monitor_state} = ProcessMonitor.handle_event(event, model.monitor_state)
        dir = if monitor_state.sort_direction == :asc, do: "ascending", else: "descending"
        {:ok, %{model | monitor_state: monitor_state, message: "Sort direction: #{dir}"}}

      # Filter
      {:key, %{char: "/"}} ->
        event = %TermUI.Event.Key{char: "/"}
        {:ok, monitor_state} = ProcessMonitor.handle_event(event, model.monitor_state)
        {:ok, %{model | monitor_state: monitor_state}}

      # Detail modes
      {:key, %{char: "l"}} ->
        event = %TermUI.Event.Key{char: "l"}
        {:ok, monitor_state} = ProcessMonitor.handle_event(event, model.monitor_state)
        {:ok, %{model | monitor_state: monitor_state, message: "Showing links/monitors"}}

      {:key, %{char: "t"}} ->
        event = %TermUI.Event.Key{char: "t"}
        {:ok, monitor_state} = ProcessMonitor.handle_event(event, model.monitor_state)
        {:ok, %{model | monitor_state: monitor_state, message: "Showing stack trace"}}

      # Process actions
      {:key, %{char: "k"}} ->
        event = %TermUI.Event.Key{char: "k"}
        {:ok, monitor_state} = ProcessMonitor.handle_event(event, model.monitor_state)
        {:ok, %{model | monitor_state: monitor_state}}

      {:key, %{char: "p"}} ->
        event = %TermUI.Event.Key{char: "p"}
        {:ok, monitor_state} = ProcessMonitor.handle_event(event, model.monitor_state)
        {:ok, %{model | monitor_state: monitor_state}}

      {:key, %{char: "y"}} ->
        event = %TermUI.Event.Key{char: "y"}
        {:ok, monitor_state} = ProcessMonitor.handle_event(event, model.monitor_state)
        {:ok, %{model | monitor_state: monitor_state, message: "Action confirmed"}}

      {:key, %{char: "n"}} ->
        event = %TermUI.Event.Key{char: "n"}
        {:ok, monitor_state} = ProcessMonitor.handle_event(event, model.monitor_state)
        {:ok, %{model | monitor_state: monitor_state, message: "Action cancelled"}}

      # Escape
      {:key, %{key: :escape}} ->
        event = %TermUI.Event.Key{key: :escape}
        {:ok, monitor_state} = ProcessMonitor.handle_event(event, model.monitor_state)
        {:ok, %{model | monitor_state: monitor_state}}

      # Spawn test workers
      {:key, %{char: "w"}} ->
        new_pids = spawn_workers(5)
        {:ok, monitor_state} = ProcessMonitor.refresh(model.monitor_state)

        {:ok,
         %{
           model
           | monitor_state: monitor_state,
             worker_pids: model.worker_pids ++ new_pids,
             message: "Spawned 5 test workers (filter 'Worker' to see them)"
         }}

      # Forward character input for filter
      {:key, %{char: char}} when char != nil and model.monitor_state.filter_input != nil ->
        event = %TermUI.Event.Key{char: char}
        {:ok, monitor_state} = ProcessMonitor.handle_event(event, model.monitor_state)
        {:ok, %{model | monitor_state: monitor_state}}

      {:key, %{key: :backspace}} when model.monitor_state.filter_input != nil ->
        event = %TermUI.Event.Key{key: :backspace}
        {:ok, monitor_state} = ProcessMonitor.handle_event(event, model.monitor_state)
        {:ok, %{model | monitor_state: monitor_state}}

      # Quit
      {:key, %{char: "q"}} when model.monitor_state.filter_input == nil ->
        # Cleanup workers
        Enum.each(model.worker_pids, fn pid ->
          if Process.alive?(pid), do: Process.exit(pid, :shutdown)
        end)

        {:stop, :normal}

      # Refresh timer
      :refresh ->
        {:ok, monitor_state} = ProcessMonitor.handle_info(:refresh, model.monitor_state)
        {:ok, %{model | monitor_state: monitor_state}}

      _ ->
        {:ok, model}
    end
  end

  @impl true
  def view(model) do
    area = %{x: 0, y: 0, width: 100, height: 25}
    monitor_view = ProcessMonitor.render(model.monitor_state, area)

    stack(:vertical, [
      text("ProcessMonitor Widget Example", Style.new(fg: :cyan, attrs: [:bold])),
      text(model.message, Style.new(fg: :yellow)),
      text("", nil),
      monitor_view,
      text("", nil),
      text("[w] Spawn workers | [q] Quit", Style.new(fg: :white, attrs: [:dim]))
    ])
  end

  # Spawn some test worker processes
  defp spawn_workers(count) do
    Enum.map(1..count, fn i ->
      spawn(fn ->
        Process.register(self(), :"Worker_#{System.unique_integer([:positive])}")
        worker_loop(i)
      end)
    end)
  end

  defp worker_loop(id) do
    # Do some work to generate reductions
    _ = Enum.reduce(1..1000, 0, &(&1 + &2))

    # Randomly vary behavior
    case rem(id, 3) do
      0 ->
        # Normal worker
        Process.sleep(100)

      1 ->
        # Worker with message queue buildup
        Enum.each(1..50, fn _ -> send(self(), :work) end)
        Process.sleep(200)

      2 ->
        # Worker with more memory
        _data = :binary.copy(<<0>>, 10_000)
        Process.sleep(150)
    end

    # Clear messages
    receive_all()

    worker_loop(id)
  end

  defp receive_all do
    receive do
      _ -> receive_all()
    after
      0 -> :ok
    end
  end
end
