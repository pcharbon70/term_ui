defmodule TermUI.Widget.Tabs do
  @moduledoc "A pure tab strip with optional frame or row content."

  @behaviour TermUI.Widget

  alias TermUI.{Event, Frame, Style}
  alias TermUI.Widget.Helpers

  @type tab :: %{
          required(:id) => term(),
          required(:label) => String.t(),
          optional(:content) => term(),
          optional(:disabled) => boolean()
        }
  @type t :: %__MODULE__{tabs: [tab()], selected: non_neg_integer(), focused: non_neg_integer()}
  @schema Zoi.struct(__MODULE__, %{
            tabs: Zoi.array() |> Zoi.default([]),
            selected: Zoi.integer() |> Zoi.non_negative() |> Zoi.default(0),
            focused: Zoi.integer() |> Zoi.non_negative() |> Zoi.default(0)
          })
  @enforce_keys Zoi.Struct.enforce_keys(@schema)
  defstruct Zoi.Struct.struct_fields(@schema)

  @impl true
  def init(opts) do
    tabs = opts |> Keyword.get(:tabs, []) |> Enum.map(&normalize_tab/1)
    selected = selected_index(tabs, Keyword.get(opts, :selected), 0)
    %__MODULE__{tabs: tabs, selected: selected, focused: selected}
  end

  @impl true
  def update(%Event.Key{key: :left}, state), do: move(state, -1)
  def update(%Event.Key{key: :right}, state), do: move(state, 1)
  def update(%Event.Key{key: :home}, state), do: focus_index(state, 0)
  def update(%Event.Key{key: :end}, state), do: focus_index(state, length(state.tabs) - 1)
  def update(%Event.Key{key: key}, state) when key in [:enter, :space], do: select_focused(state)
  def update(%Event.Text{text: " "}, state), do: select_focused(state)
  def update(_event, state), do: {state, []}

  @impl true
  def mouse(%Event.Mouse{action: action, button: :left, x: x, y: 0}, state, _dimensions)
      when action in [:press, :release] do
    case tab_at(state.tabs, x) do
      nil ->
        {state, []}

      index ->
        state = %{state | focused: index}
        if action == :release, do: select_focused(state), else: {state, []}
    end
  end

  def mouse(event, state, _dimensions), do: update(event, state)

  @impl true
  def view(state, {width, height}) do
    normal = Style.new(fg: :bright_black)
    active = Style.new(fg: :cyan, attrs: [:bold, :underline])
    focused = Style.new(attrs: [:reverse])

    header =
      state.tabs
      |> Enum.with_index()
      |> Enum.flat_map(fn {tab, index} ->
        style =
          cond do
            index == state.focused -> focused
            index == state.selected -> active
            true -> normal
          end

        [{" " <> tab.label <> " ", style}, " "]
      end)

    base = Frame.from_rows([header], width, height)

    case Enum.at(state.tabs, state.selected) do
      nil -> base
      tab -> overlay_content(base, Map.get(tab, :content), width, max(height - 1, 1))
    end
  end

  @doc "Returns the selected tab or nil."
  @spec selected(t()) :: tab() | nil
  def selected(state), do: Enum.at(state.tabs, state.selected)

  @doc "Selects a tab by id."
  @spec select(t(), term()) :: t()
  def select(state, id) do
    index = selected_index(state.tabs, id, state.selected)
    %{state | selected: index, focused: index}
  end

  defp move(%{tabs: []} = state, _delta), do: {state, []}

  defp move(state, delta) do
    count = length(state.tabs)
    next = rem(state.focused + delta + count, count)
    focus_index(state, next)
  end

  defp focus_index(state, index) do
    index = Helpers.clamp(index, 0, max(length(state.tabs) - 1, 0))
    {%{state | focused: index}, [{:focused, Enum.at(state.tabs, index)}]}
  end

  defp select_focused(state) do
    tab = Enum.at(state.tabs, state.focused)

    if tab && not Map.get(tab, :disabled, false),
      do: {%{state | selected: state.focused}, [{:selected, tab.id}]},
      else: {state, []}
  end

  defp overlay_content(base, %Frame{} = content, _width, _height),
    do: Frame.overlay(base, content, 1, 2)

  defp overlay_content(base, content, width, height) do
    rows =
      cond do
        is_binary(content) -> String.split(content, "\n", trim: false)
        is_list(content) -> content
        is_nil(content) -> []
        true -> [to_string(content)]
      end

    Frame.overlay(base, Helpers.frame(rows, {width, height}), 1, 2)
  end

  defp normalize_tab(%{id: _id, label: label} = tab), do: %{tab | label: to_string(label)}
  defp normalize_tab({id, label}), do: %{id: id, label: to_string(label)}
  defp normalize_tab(label), do: %{id: label, label: to_string(label)}

  defp tab_at(tabs, x) when x >= 0 do
    tabs
    |> Enum.with_index()
    |> Enum.reduce_while({:after, 0}, fn {tab, index}, {:after, start} ->
      next = start + Helpers.text_width(" " <> tab.label <> " ") + 1

      if x < next,
        do: {:halt, {:found, index}},
        else: {:cont, {:after, next}}
    end)
    |> case do
      {:found, index} -> index
      {:after, _end} -> nil
    end
  end

  defp tab_at(_tabs, _x), do: nil

  defp selected_index(tabs, nil, fallback),
    do: Helpers.clamp(fallback, 0, max(length(tabs) - 1, 0))

  defp selected_index(tabs, id, fallback),
    do: Enum.find_index(tabs, &(&1.id == id)) || selected_index(tabs, nil, fallback)
end
