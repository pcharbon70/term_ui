defmodule ClusterDashboardExample.App do
  @moduledoc """
  Example application demonstrating the ClusterDashboard widget.

  This example shows:
  - Connected nodes display with status
  - Node health metrics (processes, memory)
  - Global registered names
  - PG process groups
  - Connection events log
  - Network partition detection

  ## Running

  To test with a single node (non-distributed):

      cd examples/cluster_dashboard
      mix deps.get
      iex -S mix
      ClusterDashboardExample.App.run()

  To test with multiple nodes (distributed):

  Terminal 1:
      iex --sname node1 -S mix
      ClusterDashboardExample.App.run()

  Terminal 2:
      iex --sname node2 -S mix
      Node.connect(:node1@hostname)

  Terminal 3:
      iex --sname node3 -S mix
      Node.connect(:node1@hostname)

  ## Controls

  - Up/Down: Navigate list
  - PageUp/PageDown: Scroll by page
  - Enter: Toggle details panel
  - r: Refresh now
  - n: Show nodes view
  - g: Show global names view
  - p: Show :pg groups view
  - e: Show events view
  - i: Inspect selected node (in nodes view)
  - Escape: Close details / clear alerts
  - q: Quit
  """

  use TermUI.Elm

  alias TermUI.Widgets.ClusterDashboard
  alias TermUI.Renderer.Style

  @impl true
  def init(_args) do
    props =
      ClusterDashboard.new(
        update_interval: 2000,
        show_health_metrics: true,
        show_pg_groups: true,
        show_global_names: true
      )

    {:ok, dashboard_state} = ClusterDashboard.init(props)

    model = %{
      dashboard_state: dashboard_state,
      message: "ClusterDashboard Example - Views: [n]odes [g]lobals [p]g [e]vents"
    }

    {:ok, model}
  end

  @impl true
  def update(msg, model) do
    case msg do
      # Navigation
      {:key, %{key: key}} when key in [:up, :down, :page_up, :page_down, :home, :end] ->
        event = %TermUI.Event.Key{key: key}
        {:ok, dashboard_state} = ClusterDashboard.handle_event(event, model.dashboard_state)
        {:ok, %{model | dashboard_state: dashboard_state}}

      # Enter - toggle details
      {:key, %{key: :enter}} ->
        event = %TermUI.Event.Key{key: :enter}
        {:ok, dashboard_state} = ClusterDashboard.handle_event(event, model.dashboard_state)
        {:ok, %{model | dashboard_state: dashboard_state}}

      # Escape
      {:key, %{key: :escape}} ->
        event = %TermUI.Event.Key{key: :escape}
        {:ok, dashboard_state} = ClusterDashboard.handle_event(event, model.dashboard_state)
        {:ok, %{model | dashboard_state: dashboard_state}}

      # View mode switches
      {:key, %{char: "n"}} ->
        event = %TermUI.Event.Key{char: "n"}
        {:ok, dashboard_state} = ClusterDashboard.handle_event(event, model.dashboard_state)
        {:ok, %{model | dashboard_state: dashboard_state, message: "Nodes view"}}

      {:key, %{char: "g"}} ->
        event = %TermUI.Event.Key{char: "g"}
        {:ok, dashboard_state} = ClusterDashboard.handle_event(event, model.dashboard_state)
        {:ok, %{model | dashboard_state: dashboard_state, message: "Global names view"}}

      {:key, %{char: "p"}} ->
        event = %TermUI.Event.Key{char: "p"}
        {:ok, dashboard_state} = ClusterDashboard.handle_event(event, model.dashboard_state)
        {:ok, %{model | dashboard_state: dashboard_state, message: "PG groups view"}}

      {:key, %{char: "e"}} ->
        event = %TermUI.Event.Key{char: "e"}
        {:ok, dashboard_state} = ClusterDashboard.handle_event(event, model.dashboard_state)
        {:ok, %{model | dashboard_state: dashboard_state, message: "Events view"}}

      # Inspect node
      {:key, %{char: "i"}} ->
        event = %TermUI.Event.Key{char: "i"}
        {:ok, dashboard_state} = ClusterDashboard.handle_event(event, model.dashboard_state)
        {:ok, %{model | dashboard_state: dashboard_state, message: "Inspecting node..."}}

      # Refresh
      {:key, %{char: "r"}} ->
        {:ok, dashboard_state} = ClusterDashboard.refresh(model.dashboard_state)
        {:ok, %{model | dashboard_state: dashboard_state, message: "Refreshed"}}

      # Spawn test global name
      {:key, %{char: "G"}} ->
        spawn_global_process()
        {:ok, dashboard_state} = ClusterDashboard.refresh(model.dashboard_state)
        {:ok, %{model | dashboard_state: dashboard_state, message: "Registered global process"}}

      # Join a PG group
      {:key, %{char: "P"}} ->
        join_pg_group()
        {:ok, dashboard_state} = ClusterDashboard.refresh(model.dashboard_state)
        {:ok, %{model | dashboard_state: dashboard_state, message: "Joined :pg group"}}

      # Quit
      {:key, %{char: "q"}} ->
        {:stop, :normal}

      # Refresh timer from dashboard
      :refresh ->
        {:ok, dashboard_state} = ClusterDashboard.handle_info(:refresh, model.dashboard_state)
        {:ok, %{model | dashboard_state: dashboard_state}}

      # Node events
      {:nodeup, node} ->
        {:ok, dashboard_state} =
          ClusterDashboard.handle_info({:nodeup, node}, model.dashboard_state)

        {:ok, %{model | dashboard_state: dashboard_state, message: "Node connected: #{node}"}}

      {:nodedown, node} ->
        {:ok, dashboard_state} =
          ClusterDashboard.handle_info({:nodedown, node}, model.dashboard_state)

        {:ok, %{model | dashboard_state: dashboard_state, message: "Node disconnected: #{node}"}}

      _ ->
        {:ok, model}
    end
  end

  @impl true
  def view(model) do
    area = %{x: 0, y: 0, width: 100, height: 25}
    dashboard_view = ClusterDashboard.render(model.dashboard_state, area)

    stack(:vertical, [
      text("ClusterDashboard Widget Example", Style.new(fg: :cyan, attrs: [:bold])),
      text(model.message, Style.new(fg: :yellow)),
      text("", nil),
      dashboard_view,
      text("", nil),
      text(
        "[G] Register global | [P] Join PG group | [q] Quit",
        Style.new(fg: :white, attrs: [:dim])
      )
    ])
  end

  # Helper to spawn a test globally registered process
  defp spawn_global_process do
    name = :"test_global_#{System.unique_integer([:positive])}"

    pid =
      spawn(fn ->
        receive do
          :stop -> :ok
        end
      end)

    case :global.register_name(name, pid) do
      :yes -> :ok
      :no -> :error
    end
  rescue
    _ -> :error
  end

  # Helper to join a PG group
  defp join_pg_group do
    group = :test_group

    # Ensure :pg is started
    case :pg.start_link() do
      {:ok, _} -> :ok
      {:error, {:already_started, _}} -> :ok
      _ -> :ok
    end

    pid =
      spawn(fn ->
        receive do
          :stop -> :ok
        end
      end)

    :pg.join(group, pid)
  rescue
    _ -> :error
  catch
    _, _ -> :error
  end

  @doc """
  Run the example application.

  ## Examples

      # Run interactively
      ClusterDashboardExample.App.run()

  """
  def run do
    TermUI.Elm.run(__MODULE__)
  end
end
