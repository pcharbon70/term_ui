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
  - G: Register a test global process
  - P: Join a test PG group
  - q: Quit
  """

  use TermUI.Elm

  alias TermUI.Event
  alias TermUI.Renderer.Style
  alias TermUI.Widgets.ClusterDashboard

  # ----------------------------------------------------------------------------
  # Component Callbacks
  # ----------------------------------------------------------------------------

  @doc """
  Initialize the component state.
  """
  def init(_opts) do
    props =
      ClusterDashboard.new(
        update_interval: 2000,
        show_health_metrics: true,
        show_pg_groups: true,
        show_global_names: true
      )

    {:ok, dashboard_state} = ClusterDashboard.init(props)

    %{
      dashboard: dashboard_state,
      message: "ClusterDashboard Example - Views: [n]odes [g]lobals [p]g [e]vents"
    }
  end

  @doc """
  Convert events to messages.
  """
  # Navigation keys - forward to dashboard
  def event_to_msg(%Event.Key{key: key}, _state)
      when key in [:up, :down, :page_up, :page_down, :home, :end, :enter, :escape] do
    {:msg, {:dashboard_event, %Event.Key{key: key}}}
  end

  # View mode switches
  def event_to_msg(%Event.Key{key: "n"}, _state), do: {:msg, {:view_mode, :nodes}}
  def event_to_msg(%Event.Key{key: "g"}, _state), do: {:msg, {:view_mode, :globals}}
  def event_to_msg(%Event.Key{key: "p"}, _state), do: {:msg, {:view_mode, :pg}}
  def event_to_msg(%Event.Key{key: "e"}, _state), do: {:msg, {:view_mode, :events}}
  def event_to_msg(%Event.Key{key: "i"}, _state), do: {:msg, :inspect_node}
  def event_to_msg(%Event.Key{key: "r"}, _state), do: {:msg, :refresh}

  # Test actions
  def event_to_msg(%Event.Key{key: "G"}, _state), do: {:msg, :spawn_global}
  def event_to_msg(%Event.Key{key: "P"}, _state), do: {:msg, :join_pg}

  # Quit
  def event_to_msg(%Event.Key{key: key}, _state) when key in ["q", "Q"], do: {:msg, :quit}

  # Tick for auto-refresh
  def event_to_msg(%Event.Tick{}, _state), do: {:msg, :tick}

  def event_to_msg(_event, _state), do: :ignore

  @doc """
  Update state based on messages.
  """
  def update({:dashboard_event, event}, state) do
    {:ok, dashboard} = ClusterDashboard.handle_event(event, state.dashboard)
    {%{state | dashboard: dashboard}, []}
  end

  def update({:view_mode, mode}, state) do
    # Create a key event to switch view mode
    key = case mode do
      :nodes -> "n"
      :globals -> "g"
      :pg -> "p"
      :events -> "e"
    end
    event = %Event.Key{key: key}
    {:ok, dashboard} = ClusterDashboard.handle_event(event, state.dashboard)
    message = case mode do
      :nodes -> "Nodes view"
      :globals -> "Global names view"
      :pg -> "PG groups view"
      :events -> "Events view"
    end
    {%{state | dashboard: dashboard, message: message}, []}
  end

  def update(:inspect_node, state) do
    event = %Event.Key{key: "i"}
    {:ok, dashboard} = ClusterDashboard.handle_event(event, state.dashboard)
    {%{state | dashboard: dashboard, message: "Inspecting node..."}, []}
  end

  def update(:refresh, state) do
    {:ok, dashboard} = ClusterDashboard.refresh(state.dashboard)
    {%{state | dashboard: dashboard, message: "Refreshed"}, []}
  end

  def update(:spawn_global, state) do
    spawn_global_process()
    {:ok, dashboard} = ClusterDashboard.refresh(state.dashboard)
    {%{state | dashboard: dashboard, message: "Registered global process"}, []}
  end

  def update(:join_pg, state) do
    join_pg_group()
    {:ok, dashboard} = ClusterDashboard.refresh(state.dashboard)
    {%{state | dashboard: dashboard, message: "Joined :pg group"}, []}
  end

  def update(:tick, state) do
    # Check if dashboard needs refresh based on its update interval
    {:ok, dashboard} = ClusterDashboard.handle_info(:refresh, state.dashboard)
    {%{state | dashboard: dashboard}, []}
  end

  def update(:quit, state) do
    {state, [:quit]}
  end

  @doc """
  Render the current state to a render tree.
  """
  def view(state) do
    area = %{x: 0, y: 0, width: 100, height: 25}
    dashboard_view = ClusterDashboard.render(state.dashboard, area)

    # Pad message to ensure full display (avoid truncation)
    padded_message = String.pad_trailing(state.message, 120)

    stack(:vertical, [
      text("ClusterDashboard Widget Example", Style.new(fg: :cyan, attrs: [:bold])),
      text(padded_message, Style.new(fg: :yellow)),
      text("", nil),
      dashboard_view,
      text("", nil),
      render_controls()
    ])
  end

  # ----------------------------------------------------------------------------
  # Private Helpers
  # ----------------------------------------------------------------------------

  defp render_controls do
    box_width = 55
    inner_width = box_width - 2

    top_border = "┌─ Controls " <> String.duplicate("─", inner_width - 12) <> "─┐"
    bottom_border = "└" <> String.duplicate("─", inner_width) <> "┘"

    stack(:vertical, [
      text(top_border, Style.new(fg: :yellow)),
      text("│" <> String.pad_trailing("  n/g/p/e  Switch views", inner_width) <> "│", nil),
      text("│" <> String.pad_trailing("  Up/Down  Navigate list", inner_width) <> "│", nil),
      text("│" <> String.pad_trailing("  Enter    Toggle details panel", inner_width) <> "│", nil),
      text("│" <> String.pad_trailing("  i        Inspect selected node", inner_width) <> "│", nil),
      text("│" <> String.pad_trailing("  r        Refresh now", inner_width) <> "│", nil),
      text("│" <> String.pad_trailing("  G        Register test global process", inner_width) <> "│", nil),
      text("│" <> String.pad_trailing("  P        Join test PG group", inner_width) <> "│", nil),
      text("│" <> String.pad_trailing("  Escape   Close details / clear alerts", inner_width) <> "│", nil),
      text("│" <> String.pad_trailing("  q        Quit", inner_width) <> "│", nil),
      text(bottom_border, Style.new(fg: :yellow))
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

  # ----------------------------------------------------------------------------
  # Public API
  # ----------------------------------------------------------------------------

  @doc """
  Run the example application.

  ## Examples

      # Run interactively
      ClusterDashboardExample.App.run()

  """
  def run do
    TermUI.Runtime.run(root: __MODULE__)
  end
end
