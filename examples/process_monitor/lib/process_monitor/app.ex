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

  alias TermUI.Event
  alias TermUI.Widgets.ProcessMonitor
  alias TermUI.Renderer.Style

  # ----------------------------------------------------------------------------
  # Component Callbacks
  # ----------------------------------------------------------------------------

  @doc """
  Initialize the component state.
  """
  @impl true
  def init(_args) do
    props =
      ProcessMonitor.new(
        update_interval: 1000,
        show_system_processes: false
      )

    {:ok, monitor_state} = ProcessMonitor.init(props)

    %{
      monitor_state: monitor_state,
      message: "ProcessMonitor Example - Press w to spawn test workers",
      worker_pids: []
    }
  end

  @doc """
  Convert events to messages.
  """
  @impl true
  def event_to_msg(%Event.Key{char: "q"}, %{monitor_state: %{filter_input: nil}}) do
    {:msg, :quit}
  end

  def event_to_msg(%Event.Key{key: key}, _state)
      when key in [:up, :down, :page_up, :page_down, :home, :end] do
    {:msg, {:monitor_event, %Event.Key{key: key}}}
  end

  def event_to_msg(%Event.Key{key: :enter}, _state) do
    {:msg, {:monitor_event, %Event.Key{key: :enter}}}
  end

  def event_to_msg(%Event.Key{char: "r"}, _state) do
    {:msg, :refresh_monitor}
  end

  def event_to_msg(%Event.Key{char: "s"}, _state) do
    {:msg, {:monitor_event, %Event.Key{char: "s"}}}
  end

  def event_to_msg(%Event.Key{char: "S"}, _state) do
    {:msg, {:monitor_event, %Event.Key{char: "S"}}}
  end

  def event_to_msg(%Event.Key{char: "/"}, _state) do
    {:msg, {:monitor_event, %Event.Key{char: "/"}}}
  end

  def event_to_msg(%Event.Key{char: "l"}, _state) do
    {:msg, {:monitor_event, %Event.Key{char: "l"}}}
  end

  def event_to_msg(%Event.Key{char: "t"}, _state) do
    {:msg, {:monitor_event, %Event.Key{char: "t"}}}
  end

  def event_to_msg(%Event.Key{char: "k"}, _state) do
    {:msg, {:monitor_event, %Event.Key{char: "k"}}}
  end

  def event_to_msg(%Event.Key{char: "p"}, _state) do
    {:msg, {:monitor_event, %Event.Key{char: "p"}}}
  end

  def event_to_msg(%Event.Key{char: "y"}, _state) do
    {:msg, {:monitor_event, %Event.Key{char: "y"}}}
  end

  def event_to_msg(%Event.Key{char: "n"}, _state) do
    {:msg, {:monitor_event, %Event.Key{char: "n"}}}
  end

  def event_to_msg(%Event.Key{key: :escape}, _state) do
    {:msg, {:monitor_event, %Event.Key{key: :escape}}}
  end

  def event_to_msg(%Event.Key{char: "w"}, _state) do
    {:msg, :spawn_workers}
  end

  def event_to_msg(%Event.Key{char: char}, %{monitor_state: %{filter_input: input}})
      when input != nil and char != nil do
    {:msg, {:monitor_event, %Event.Key{char: char}}}
  end

  def event_to_msg(%Event.Key{key: :backspace}, %{monitor_state: %{filter_input: input}})
      when input != nil do
    {:msg, {:monitor_event, %Event.Key{key: :backspace}}}
  end

  def event_to_msg(_event, _state) do
    :ignore
  end

  @doc """
  Update state based on messages.
  """
  @impl true
  def update(:quit, model) do
    # Cleanup workers
    Enum.each(model.worker_pids, fn pid ->
      if Process.alive?(pid), do: Process.exit(pid, :shutdown)
    end)

    {model, [:quit]}
  end

  def update(:refresh_monitor, model) do
    {:ok, monitor_state} = ProcessMonitor.refresh(model.monitor_state)
    {%{model | monitor_state: monitor_state, message: "Refreshed"}, []}
  end

  def update(:spawn_workers, model) do
    new_pids = spawn_workers(5)
    {:ok, monitor_state} = ProcessMonitor.refresh(model.monitor_state)

    {%{
       model
       | monitor_state: monitor_state,
         worker_pids: model.worker_pids ++ new_pids,
         message: "Spawned 5 test workers (filter 'Worker' to see them)"
     }, []}
  end

  def update({:monitor_event, event}, model) do
    {:ok, monitor_state} = ProcessMonitor.handle_event(event, model.monitor_state)

    # Update message based on event
    message =
      case event do
        %Event.Key{char: "s"} ->
          "Sort: #{monitor_state.sort_field}"

        %Event.Key{char: "S"} ->
          dir = if monitor_state.sort_direction == :asc, do: "ascending", else: "descending"
          "Sort direction: #{dir}"

        %Event.Key{char: "l"} ->
          "Showing links/monitors"

        %Event.Key{char: "t"} ->
          "Showing stack trace"

        %Event.Key{char: "y"} ->
          "Action confirmed"

        %Event.Key{char: "n"} ->
          "Action cancelled"

        _ ->
          model.message
      end

    {%{model | monitor_state: monitor_state, message: message}, []}
  end

  def update(_msg, model) do
    {model, []}
  end

  @doc """
  Render the application view.
  """
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

  # ----------------------------------------------------------------------------
  # Helpers
  # ----------------------------------------------------------------------------

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

  # ----------------------------------------------------------------------------
  # Run
  # ----------------------------------------------------------------------------

  @doc """
  Run the process monitor example application.
  """
  def run do
    TermUI.Runtime.run(root: __MODULE__)
  end
end
