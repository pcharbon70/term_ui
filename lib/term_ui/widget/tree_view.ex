defmodule TermUI.Widget.TreeView do
  @moduledoc "A pure expandable tree with keyboard navigation and selection."

  @behaviour TermUI.Widget

  alias TermUI.{Event, Style}
  alias TermUI.Widget.Helpers

  @type tree_node :: %{
          required(:id) => term(),
          required(:label) => String.t(),
          required(:children) => [tree_node()],
          optional(:disabled) => boolean()
        }
  @type t :: %__MODULE__{
          nodes: [tree_node()],
          cursor: non_neg_integer(),
          offset: non_neg_integer(),
          expanded: MapSet.t(term()),
          selected: MapSet.t(term()),
          page_size: pos_integer()
        }

  @schema Zoi.struct(__MODULE__, %{
            nodes: Zoi.array() |> Zoi.default([]),
            cursor: Zoi.integer() |> Zoi.non_negative() |> Zoi.default(0),
            offset: Zoi.integer() |> Zoi.non_negative() |> Zoi.default(0),
            expanded: Zoi.map_set() |> Zoi.default(MapSet.new()),
            selected: Zoi.map_set() |> Zoi.default(MapSet.new()),
            page_size: Zoi.integer() |> Zoi.positive() |> Zoi.default(10)
          })
  @enforce_keys Zoi.Struct.enforce_keys(@schema)
  defstruct Zoi.Struct.struct_fields(@schema)

  @doc "Creates a tree leaf."
  @spec leaf(term(), iodata(), keyword()) :: tree_node()
  def leaf(id, label, opts \\ []),
    do: %{
      id: id,
      label: IO.iodata_to_binary(label),
      children: [],
      disabled: Keyword.get(opts, :disabled, false)
    }

  @doc "Creates a tree branch."
  @spec branch(term(), iodata(), [tree_node()], keyword()) :: tree_node()
  def branch(id, label, children, opts \\ []),
    do: %{
      id: id,
      label: IO.iodata_to_binary(label),
      children: children,
      disabled: Keyword.get(opts, :disabled, false)
    }

  @impl true
  def init(opts) do
    %__MODULE__{
      nodes: Keyword.get(opts, :nodes, []),
      expanded: MapSet.new(Keyword.get(opts, :expanded, [])),
      selected: MapSet.new(Keyword.get(opts, :selected, [])),
      page_size: max(Keyword.get(opts, :page_size, 10), 1)
    }
  end

  @impl true
  def update(%Event.Key{key: :up}, state), do: move(state, -1)
  def update(%Event.Key{key: :down}, state), do: move(state, 1)
  def update(%Event.Key{key: :home}, state), do: move_to(state, 0)
  def update(%Event.Key{key: :end}, state), do: move_to(state, length(visible(state)) - 1)
  def update(%Event.Key{key: :page_up}, state), do: move(state, -state.page_size)
  def update(%Event.Key{key: :page_down}, state), do: move(state, state.page_size)
  def update(%Event.Key{key: :right}, state), do: expand_current(state)
  def update(%Event.Key{key: :left}, state), do: collapse_current(state)
  def update(%Event.Key{key: :enter}, state), do: toggle_current(state)
  def update(%Event.Key{key: :space}, state), do: select_current(state)
  def update(%Event.Text{text: " "}, state), do: select_current(state)
  def update(_event, state), do: {state, []}

  @impl true
  def mouse(%Event.Mouse{action: action, button: :left, x: x, y: y}, state, {_width, height})
      when action in [:press, :release] do
    nodes = visible(state)
    offset = visible_offset(state.cursor, state.offset, height)
    index = offset + y

    case Enum.at(nodes, index) do
      {node, depth} when y >= 0 and y < height ->
        state = %{state | cursor: index, offset: offset}

        cond do
          action == :press -> {state, []}
          node.children != [] and x <= depth * 2 + 1 -> toggle_current(state)
          true -> select_current(state)
        end

      _other ->
        {state, []}
    end
  end

  def mouse(event, state, _dimensions), do: update(event, state)

  @impl true
  def view(state, {_width, height} = dimensions) do
    visible = visible(state)
    offset = visible_offset(state.cursor, state.offset, height)
    cursor_style = Style.new(attrs: [:reverse])
    selected_style = Style.new(fg: :green)
    branch_style = Style.new(fg: :cyan)

    rows =
      visible
      |> Enum.slice(offset, height)
      |> Enum.with_index(offset)
      |> Enum.map(fn {{node, depth}, index} ->
        branch? = node.children != []

        glyph =
          cond do
            not branch? -> "•"
            MapSet.member?(state.expanded, node.id) -> "▾"
            true -> "▸"
          end

        selected? = MapSet.member?(state.selected, node.id)

        style =
          cond do
            index == state.cursor -> cursor_style
            selected? -> selected_style
            branch? -> branch_style
            true -> Style.new()
          end

        [{String.duplicate("  ", depth) <> glyph <> " " <> node.label, style}]
      end)

    Helpers.frame(rows, dimensions)
  end

  @doc "Returns visible nodes and their depth."
  @spec visible(t()) :: [{tree_node(), non_neg_integer()}]
  def visible(state), do: flatten(state.nodes, state.expanded, 0)

  @doc "Replaces the children of one node without performing I/O."
  @spec set_children(t(), term(), [tree_node()]) :: t()
  def set_children(state, id, children),
    do: %{state | nodes: replace_children(state.nodes, id, children)}

  defp move(state, delta), do: move_to(state, state.cursor + delta)

  defp move_to(state, cursor) do
    cursor = Helpers.clamp(cursor, 0, max(length(visible(state)) - 1, 0))
    offset = visible_offset(cursor, state.offset, state.page_size)
    {%{state | cursor: cursor, offset: offset}, []}
  end

  defp expand_current(state) do
    case current(state) do
      {%{children: [_ | _], id: id}, _depth} ->
        {%{state | expanded: MapSet.put(state.expanded, id)}, [{:expanded, id}]}

      _other ->
        {state, []}
    end
  end

  defp collapse_current(state) do
    case current(state) do
      {%{id: id}, _depth} ->
        {%{state | expanded: MapSet.delete(state.expanded, id)}, [{:collapsed, id}]}

      _other ->
        {state, []}
    end
  end

  defp toggle_current(state) do
    case current(state) do
      {%{children: [_ | _], id: id}, _depth} ->
        if MapSet.member?(state.expanded, id),
          do: collapse_current(state),
          else: expand_current(state)

      {%{id: id} = node, _depth} ->
        {state, [{:activated, id, node}]}

      _other ->
        {state, []}
    end
  end

  defp select_current(state) do
    case current(state) do
      {%{id: id}, _depth} ->
        {%{state | selected: MapSet.put(state.selected, id)}, [{:selected, id}]}

      _other ->
        {state, []}
    end
  end

  defp current(state), do: Enum.at(visible(state), state.cursor)
  defp visible_offset(_cursor, offset, 0), do: offset
  defp visible_offset(cursor, offset, _height) when cursor < offset, do: cursor

  defp visible_offset(cursor, offset, height) when cursor >= offset + height,
    do: cursor - height + 1

  defp visible_offset(_cursor, offset, _height), do: offset

  defp flatten(nodes, expanded, depth) do
    Enum.flat_map(nodes, fn node ->
      children =
        if MapSet.member?(expanded, node.id),
          do: flatten(node.children, expanded, depth + 1),
          else: []

      [{node, depth} | children]
    end)
  end

  defp replace_children(nodes, id, children) do
    Enum.map(nodes, fn node ->
      if node.id == id,
        do: %{node | children: children},
        else: %{node | children: replace_children(node.children, id, children)}
    end)
  end
end
