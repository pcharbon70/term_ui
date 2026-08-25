defmodule Showcase.Pages.Beam do
  @moduledoc false

  @behaviour Showcase.Page

  alias Showcase.Layout
  alias TermUI.Event
  alias TermUI.Frame
  alias TermUI.Widget.{ClusterDashboard, ProcessMonitor, SupervisionTree, TreeView}

  @views [:processes, :supervision, :cluster]

  @impl true
  def init do
    %{
      active: :processes,
      processes: ProcessMonitor.init(snapshots: process_snapshots()),
      supervision: SupervisionTree.init(nodes: supervision_nodes(), expanded: [:root, :runtime]),
      cluster: ClusterDashboard.init(nodes: cluster_nodes())
    }
  end

  @impl true
  def update(%Event.Key{key: :tab, modifiers: modifiers}, state) do
    delta = if :shift in modifiers, do: -1, else: 1
    {move_view(state, delta), []}
  end

  def update(:tick, state), do: {state, []}

  def update(event, %{active: :processes} = state) do
    {widget, messages} = ProcessMonitor.update(event, state.processes)
    {%{state | processes: widget}, messages}
  end

  def update(event, %{active: :supervision} = state) do
    {widget, messages} = SupervisionTree.update(event, state.supervision)
    {%{state | supervision: widget}, messages}
  end

  def update(event, %{active: :cluster} = state) do
    {widget, messages} = ClusterDashboard.update(event, state.cluster)
    {%{state | cluster: widget}, messages}
  end

  @impl true
  def view(state, {width, height}, theme) do
    selector =
      Layout.selector(
        [processes: "Processes", supervision: "Supervision", cluster: "Cluster"],
        state.active,
        width
      )

    panel_height = max(height - 1, 1)
    inner = {max(width - 2, 1), max(panel_height - 2, 1)}

    {title, content} =
      case state.active do
        :processes ->
          {"Parent-supplied process snapshot", ProcessMonitor.view(state.processes, inner)}

        :supervision ->
          {"Parent-supplied supervision tree", SupervisionTree.view(state.supervision, inner)}

        :cluster ->
          {"Parent-supplied cluster snapshot", ClusterDashboard.view(state.cluster, inner)}
      end

    panel = Layout.panel(content, title, {width, panel_height}, active: true, theme: theme)

    Frame.new(width, height)
    |> Frame.overlay(selector, 1, 1)
    |> Frame.overlay(panel, 1, 2)
  end

  @impl true
  def help, do: "Tab changes snapshots. Widgets never inspect processes or call RPC."

  defp move_view(state, delta) do
    index = Enum.find_index(@views, &(&1 == state.active)) || 0
    next = rem(index + delta + length(@views), length(@views))
    %{state | active: Enum.at(@views, next)}
  end

  defp process_snapshots do
    [
      %{
        pid: "<0.184.0>",
        name: "TermUI.Runtime",
        memory: 148_320,
        reductions: 51_204,
        message_queue_len: 0
      },
      %{
        pid: "<0.185.0>",
        name: "Backend.Manager",
        memory: 92_176,
        reductions: 22_918,
        message_queue_len: 1
      },
      %{
        pid: "<0.186.0>",
        name: "InputReader",
        memory: 18_624,
        reductions: 4_091,
        message_queue_len: 0
      },
      %{
        pid: "<0.187.0>",
        name: "ProducerAdapter",
        memory: 27_040,
        reductions: 9_277,
        message_queue_len: 2
      }
    ]
  end

  defp supervision_nodes do
    [
      TreeView.branch(:root, "TermUI.Showcase.Supervisor", [
        TreeView.branch(:runtime, "TermUI.Runtime", [
          TreeView.leaf(:backend, "TermUI.Backend.Manager"),
          TreeView.leaf(:input, "TermUI.Backend.InputReader")
        ]),
        TreeView.leaf(:producer, "TermUI.Stream.ProducerAdapter")
      ])
    ]
  end

  defp cluster_nodes do
    [
      %{node: "console@local", status: "up", processes: 184, memory: "42 MB", uptime: "2h 14m"},
      %{node: "worker-a@local", status: "up", processes: 231, memory: "81 MB", uptime: "5h 02m"},
      %{node: "worker-b@local", status: "down", processes: 0, memory: "-", uptime: "-"}
    ]
  end
end
