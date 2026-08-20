defmodule TermUI.Widget.List do
  @moduledoc "A pure, scrollable item list with single or multiple selection."

  @behaviour TermUI.Widget

  alias TermUI.{Event, Style}
  alias TermUI.Widget.Helpers

  @dialyzer {:nowarn_function, set_items: 2}

  @type item :: term()
  @type t :: %__MODULE__{
          items: [item()],
          cursor: non_neg_integer(),
          offset: non_neg_integer(),
          selected: MapSet.t(non_neg_integer()),
          mode: :single | :multiple,
          page_size: pos_integer(),
          marker: String.t(),
          style: Style.t(),
          cursor_style: Style.t(),
          selected_style: Style.t()
        }

  @schema Zoi.struct(__MODULE__, %{
            items: Zoi.array() |> Zoi.default([]),
            cursor: Zoi.integer() |> Zoi.non_negative() |> Zoi.default(0),
            offset: Zoi.integer() |> Zoi.non_negative() |> Zoi.default(0),
            selected: Zoi.map_set() |> Zoi.default(MapSet.new()),
            mode: Zoi.enum([:single, :multiple]) |> Zoi.default(:single),
            page_size: Zoi.integer() |> Zoi.positive() |> Zoi.default(10),
            marker: Zoi.string() |> Zoi.default("> "),
            style: Zoi.struct(Style) |> Zoi.default(%Style{}),
            cursor_style:
              Zoi.struct(Style)
              |> Zoi.default(%Style{fg: :cyan, attrs: MapSet.new([:bold])}),
            selected_style: Zoi.struct(Style) |> Zoi.default(%Style{fg: :green})
          })
  @enforce_keys Zoi.Struct.enforce_keys(@schema)
  defstruct Zoi.Struct.struct_fields(@schema)

  @impl true
  def init(opts) do
    %__MODULE__{
      items: Keyword.get(opts, :items, []),
      cursor: max(Keyword.get(opts, :cursor, 0), 0),
      mode: Keyword.get(opts, :mode, :single),
      page_size: max(Keyword.get(opts, :page_size, 10), 1),
      marker: Keyword.get(opts, :marker, "> "),
      style: Keyword.get(opts, :style, Style.new()),
      cursor_style: Keyword.get(opts, :cursor_style, Style.new(fg: :cyan, attrs: [:bold])),
      selected_style: Keyword.get(opts, :selected_style, Style.new(fg: :green))
    }
    |> normalize_cursor()
  end

  @impl true
  def update(%Event.Key{key: :up}, state), do: move(state, -1)
  def update(%Event.Key{key: :down}, state), do: move(state, 1)
  def update(%Event.Key{key: :home}, state), do: move_to(state, 0)
  def update(%Event.Key{key: :end}, state), do: move_to(state, length(state.items) - 1)
  def update(%Event.Key{key: :page_up}, state), do: move(state, -state.page_size)
  def update(%Event.Key{key: :page_down}, state), do: move(state, state.page_size)
  def update(%Event.Key{key: :space}, %{mode: :multiple} = state), do: toggle(state)
  def update(%Event.Text{text: " "}, %{mode: :multiple} = state), do: toggle(state)
  def update(%Event.Key{key: :enter}, state), do: select(state)
  def update(_event, state), do: {state, []}

  @impl true
  def mouse(%Event.Mouse{action: action, button: :left, y: y}, state, {_width, height})
      when action in [:press, :release] do
    offset = visible_offset(state.cursor, state.offset, height)
    index = offset + y

    if y >= 0 and y < height and index < length(state.items) do
      state = %{state | cursor: index, offset: offset}

      cond do
        action == :press -> {state, []}
        state.mode == :multiple -> toggle(state)
        true -> select(state)
      end
    else
      {state, []}
    end
  end

  def mouse(event, state, _dimensions), do: update(event, state)

  @impl true
  def view(state, {_width, height} = dimensions) do
    offset = visible_offset(state.cursor, state.offset, height)

    rows =
      state.items
      |> Enum.slice(offset, height)
      |> Enum.with_index(offset)
      |> Enum.map(&render_item(&1, state))

    Helpers.frame(rows, dimensions)
  end

  @doc "Replaces all items and keeps the cursor in range."
  @spec set_items(t(), [item()]) :: t()
  def set_items(state, items),
    do: normalize_cursor(%{state | items: items, selected: MapSet.new()})

  @doc "Returns the item under the cursor."
  @spec current(t()) :: item() | nil
  def current(state), do: Enum.at(state.items, state.cursor)

  defp render_item({item, index}, state) do
    cursor? = index == state.cursor
    selected? = MapSet.member?(state.selected, index)

    prefix =
      if cursor?, do: state.marker, else: String.duplicate(" ", String.length(state.marker))

    check = selection_mark(state.mode, selected?)
    style = item_style(state, cursor?, selected?)
    [{prefix <> check <> item_label(item), style}]
  end

  defp selection_mark(:multiple, true), do: "[x] "
  defp selection_mark(:multiple, false), do: "[ ] "
  defp selection_mark(_mode, _selected?), do: ""

  defp item_style(state, true, _selected?), do: state.cursor_style
  defp item_style(state, false, true), do: state.selected_style
  defp item_style(state, false, false), do: state.style

  defp move(state, delta), do: move_to(state, state.cursor + delta)

  defp move_to(state, cursor) do
    state = %{state | cursor: Helpers.clamp(cursor, 0, max(length(state.items) - 1, 0))}
    offset = visible_offset(state.cursor, state.offset, state.page_size)
    {%{state | offset: offset}, []}
  end

  defp select(state) do
    case current(state) do
      nil -> {state, []}
      item -> {%{state | selected: MapSet.new([state.cursor])}, [{:selected, item}]}
    end
  end

  defp toggle(state) do
    selected =
      if MapSet.member?(state.selected, state.cursor),
        do: MapSet.delete(state.selected, state.cursor),
        else: MapSet.put(state.selected, state.cursor)

    item = current(state)
    {%{state | selected: selected}, if(item, do: [{:toggled, item}], else: [])}
  end

  defp normalize_cursor(state),
    do: %{state | cursor: min(state.cursor, max(length(state.items) - 1, 0))}

  defp visible_offset(cursor, offset, _height) when cursor < offset, do: cursor

  defp visible_offset(cursor, offset, height) when cursor >= offset + height,
    do: cursor - height + 1

  defp visible_offset(_cursor, offset, _height), do: offset

  defp item_label(%{label: label}), do: to_string(label)
  defp item_label({_id, label}), do: to_string(label)
  defp item_label(item), do: to_string(item)
end
