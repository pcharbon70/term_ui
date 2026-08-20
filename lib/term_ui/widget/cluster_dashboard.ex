defmodule TermUI.Widget.ClusterDashboard do
  @moduledoc "A pure cluster snapshot dashboard. It performs no RPC or node monitoring."

  @behaviour TermUI.Widget

  alias TermUI.Event
  alias TermUI.Widget.{Table, Tabs}
  alias TermUI.Widget.Table.Column

  @type snapshot :: %{
          required(:node) => term(),
          optional(:status) => term(),
          optional(:processes) => non_neg_integer(),
          optional(:memory) => non_neg_integer(),
          optional(:uptime) => term()
        }
  @type t :: %__MODULE__{nodes: [snapshot()], tabs: Tabs.t(), table: Table.t()}
  @schema Zoi.struct(__MODULE__, %{
            nodes: Zoi.array() |> Zoi.default([]),
            tabs: Zoi.struct(Tabs) |> Zoi.default(%Tabs{}),
            table: Zoi.struct(Table) |> Zoi.default(%Table{})
          })
  @enforce_keys Zoi.Struct.enforce_keys(@schema)
  defstruct Zoi.Struct.struct_fields(@schema)

  @impl true
  def init(opts) do
    nodes = Keyword.get(opts, :nodes, [])

    %__MODULE__{
      nodes: nodes,
      tabs: Tabs.init(tabs: [{:nodes, "Nodes"}, {:help, "Help"}], selected: :nodes),
      table: table(nodes)
    }
  end

  @impl true
  def update(%Event.Text{text: "r"}, state), do: {state, [:refresh_requested]}

  def update(event, state) do
    {tabs, tab_messages} = Tabs.update(event, state.tabs)
    {table, table_messages} = Table.update(event, state.table)
    {%{state | tabs: tabs, table: table}, tab_messages ++ table_messages}
  end

  @impl true
  def view(state, {width, height}) do
    case Tabs.selected(state.tabs) do
      %{id: :help} ->
        TermUI.Frame.from_rows(
          ["R: request refresh", "Arrows: move", "Enter: select node"],
          width,
          height
        )

      _tab ->
        Table.view(state.table, {width, height})
    end
  end

  @doc "Replaces cluster snapshots supplied by the parent."
  @spec set_nodes(t(), [snapshot()]) :: t()
  def set_nodes(state, nodes),
    do: %{state | nodes: nodes, table: Table.set_rows(state.table, nodes)}

  defp table(nodes),
    do:
      Table.init(
        columns: [
          Column.new(:node, "Node"),
          Column.new(:status, "Status", width: 10),
          Column.new(:processes, "Processes", align: :right),
          Column.new(:memory, "Memory", align: :right),
          Column.new(:uptime, "Uptime", align: :right)
        ],
        rows: nodes
      )
end
