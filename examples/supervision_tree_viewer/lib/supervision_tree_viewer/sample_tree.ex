defmodule SupervisionTreeViewerExample.SampleTree do
  @moduledoc """
  Creates a sample supervision tree for demonstration purposes.

  Tree structure:
  - SampleTree (supervisor, one_for_all)
    ├── DatabasePool (supervisor, one_for_one)
    │   ├── Connection1 (worker)
    │   ├── Connection2 (worker)
    │   └── Connection3 (worker)
    ├── WebServer (supervisor, rest_for_one)
    │   ├── Router (worker)
    │   ├── Handler1 (worker)
    │   └── Handler2 (worker)
    └── BackgroundJobs (supervisor, one_for_one)
        ├── JobRunner1 (worker)
        └── JobRunner2 (worker)
  """

  use Supervisor

  def start_link(_opts) do
    Supervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    children = [
      {SupervisionTreeViewerExample.DatabasePool, []},
      {SupervisionTreeViewerExample.WebServer, []},
      {SupervisionTreeViewerExample.BackgroundJobs, []}
    ]

    Supervisor.init(children, strategy: :one_for_all)
  end
end

defmodule SupervisionTreeViewerExample.DatabasePool do
  use Supervisor

  def start_link(_opts) do
    Supervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    children =
      for i <- 1..3 do
        %{
          id: :"connection_#{i}",
          start: {SupervisionTreeViewerExample.Worker, :start_link, [[name: :"Connection#{i}", type: :database]]}
        }
      end

    Supervisor.init(children, strategy: :one_for_one)
  end
end

defmodule SupervisionTreeViewerExample.WebServer do
  use Supervisor

  def start_link(_opts) do
    Supervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    children = [
      %{
        id: :router,
        start: {SupervisionTreeViewerExample.Worker, :start_link, [[name: :Router, type: :web]]}
      },
      %{
        id: :handler_1,
        start: {SupervisionTreeViewerExample.Worker, :start_link, [[name: :Handler1, type: :web]]}
      },
      %{
        id: :handler_2,
        start: {SupervisionTreeViewerExample.Worker, :start_link, [[name: :Handler2, type: :web]]}
      }
    ]

    Supervisor.init(children, strategy: :rest_for_one)
  end
end

defmodule SupervisionTreeViewerExample.BackgroundJobs do
  use Supervisor

  def start_link(_opts) do
    Supervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    children =
      for i <- 1..2 do
        %{
          id: :"job_runner_#{i}",
          start: {SupervisionTreeViewerExample.Worker, :start_link, [[name: :"JobRunner#{i}", type: :background]]}
        }
      end

    Supervisor.init(children, strategy: :one_for_one)
  end
end

defmodule SupervisionTreeViewerExample.Worker do
  @moduledoc """
  A sample worker that simulates different workloads.
  """

  use GenServer

  def start_link(opts) do
    name = Keyword.get(opts, :name)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @impl true
  def init(opts) do
    type = Keyword.get(opts, :type, :generic)

    # Start work simulation
    schedule_work(type)

    {:ok,
     %{
       type: type,
       work_count: 0,
       started_at: DateTime.utc_now()
     }}
  end

  @impl true
  def handle_info(:work, state) do
    # Simulate work
    work_intensity =
      case state.type do
        :database -> 1..100
        :web -> 1..500
        :background -> 1..1000
        _ -> 1..50
      end

    # Do some computation to generate reductions
    _ = Enum.reduce(work_intensity, 0, &(&1 + &2))

    # Schedule next work
    schedule_work(state.type)

    {:noreply, %{state | work_count: state.work_count + 1}}
  end

  @impl true
  def handle_call(:get_stats, _from, state) do
    {:reply, state, state}
  end

  defp schedule_work(type) do
    interval =
      case type do
        :database -> 200
        :web -> 100
        :background -> 500
        _ -> 300
      end

    Process.send_after(self(), :work, interval)
  end
end
