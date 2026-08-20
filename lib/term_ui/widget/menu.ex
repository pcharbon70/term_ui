defmodule TermUI.Widget.Menu do
  @moduledoc "A pure keyboard menu with actions, separators, and disabled items."

  @behaviour TermUI.Widget

  alias TermUI.{Event, Style}
  alias TermUI.Widget.Helpers

  @type item :: %{
          required(:id) => term(),
          required(:label) => String.t(),
          optional(:disabled) => boolean(),
          optional(:separator) => boolean(),
          optional(:shortcut) => String.t() | nil,
          optional(:message) => term()
        }
  @type t :: %__MODULE__{
          items: [item()],
          cursor: non_neg_integer(),
          title: String.t() | nil,
          visible: boolean()
        }
  @schema Zoi.struct(__MODULE__, %{
            items: Zoi.array() |> Zoi.default([]),
            cursor: Zoi.integer() |> Zoi.non_negative() |> Zoi.default(0),
            title: Zoi.any() |> Zoi.default(nil),
            visible: Zoi.boolean() |> Zoi.default(true)
          })
  @enforce_keys Zoi.Struct.enforce_keys(@schema)
  defstruct Zoi.Struct.struct_fields(@schema)

  @doc "Creates one menu action."
  @spec action(term(), iodata(), keyword()) :: item()
  def action(id, label, opts \\ []) do
    %{
      id: id,
      label: IO.iodata_to_binary(label),
      disabled: Keyword.get(opts, :disabled, false),
      separator: false,
      shortcut: Keyword.get(opts, :shortcut),
      message: Keyword.get(opts, :message, {:selected, id})
    }
  end

  @doc "Creates one separator."
  @spec separator() :: item()
  def separator,
    do: %{id: make_ref(), label: "", disabled: true, separator: true, shortcut: nil, message: nil}

  @impl true
  def init(opts) do
    items = opts |> Keyword.get(:items, []) |> Enum.map(&normalize_item/1)

    %__MODULE__{
      items: items,
      cursor: first_enabled(items),
      title: Keyword.get(opts, :title),
      visible: Keyword.get(opts, :visible, true)
    }
  end

  @impl true
  def update(_event, %{visible: false} = state), do: {state, []}
  def update(%Event.Key{key: :up}, state), do: move(state, -1)
  def update(%Event.Key{key: :down}, state), do: move(state, 1)

  def update(%Event.Key{key: :home}, state),
    do: {%{state | cursor: first_enabled(state.items)}, []}

  def update(%Event.Key{key: :end}, state), do: {%{state | cursor: last_enabled(state.items)}, []}
  def update(%Event.Key{key: key}, state) when key in [:enter, :space], do: activate(state)
  def update(%Event.Text{text: " "}, state), do: activate(state)
  def update(%Event.Key{key: :escape}, state), do: {%{state | visible: false}, [:dismissed]}
  def update(_event, state), do: {state, []}

  @impl true
  def mouse(_event, %{visible: false} = state, _dimensions), do: {state, []}

  def mouse(%Event.Mouse{action: action, button: :left, y: y}, state, {width, height})
      when action in [:press, :release] do
    border_offset = if width > 1 and height > 1, do: 1, else: 0
    index = y - border_offset

    item = if index >= 0, do: Enum.at(state.items, index)

    if enabled?(item) do
      state = %{state | cursor: index}
      if action == :release, do: activate(state), else: {state, []}
    else
      {state, []}
    end
  end

  def mouse(event, state, _dimensions), do: update(event, state)

  @impl true
  def view(%{visible: false}, dimensions), do: Helpers.frame([], dimensions)

  def view(state, {width, height} = dimensions) do
    cursor_style = Style.new(attrs: [:reverse])
    disabled_style = Style.new(fg: :bright_black)
    separator_style = Style.new(fg: :bright_black)
    inner_width = max(width - 2, 1)

    rows =
      state.items
      |> Enum.with_index()
      |> Enum.map(
        &render_item(
          &1,
          inner_width,
          state.cursor,
          cursor_style,
          disabled_style,
          separator_style
        )
      )

    rows = Helpers.border(rows, dimensions, title: state.title)
    Helpers.frame(Enum.take(rows, height), dimensions)
  end

  @doc "Shows the menu."
  @spec show(t()) :: t()
  def show(state), do: %{state | visible: true}

  @doc "Hides the menu."
  @spec hide(t()) :: t()
  def hide(state), do: %{state | visible: false}

  @doc "Returns the current action."
  @spec current(t()) :: item() | nil
  def current(state), do: Enum.at(state.items, state.cursor)

  defp render_item({%{separator: true}, _index}, width, _cursor, _cursor_style, _disabled, style),
    do: [{String.duplicate("─", width), style}]

  defp render_item({item, index}, width, cursor, cursor_style, disabled_style, _separator) do
    shortcut = if item.shortcut, do: " " <> item.shortcut, else: ""
    label_width = max(width - String.length(shortcut) - 2, 1)
    text = "  " <> Helpers.align(item.label, label_width, :left) <> shortcut

    style =
      cond do
        item.disabled -> disabled_style
        index == cursor -> cursor_style
        true -> Style.new()
      end

    [{text, style}]
  end

  defp activate(state) do
    case current(state) do
      %{disabled: false, separator: false, message: message} -> {state, [message]}
      _other -> {state, []}
    end
  end

  defp move(%{items: []} = state, _delta), do: {state, []}

  defp move(state, delta) do
    count = length(state.items)

    cursor =
      1..count
      |> Enum.reduce_while(state.cursor, fn step, _cursor ->
        candidate = rem(state.cursor + delta * step + count * step, count)

        if enabled?(Enum.at(state.items, candidate)),
          do: {:halt, candidate},
          else: {:cont, state.cursor}
      end)

    {%{state | cursor: cursor}, []}
  end

  defp enabled?(%{disabled: false, separator: false}), do: true
  defp enabled?(_item), do: false
  defp first_enabled(items), do: Enum.find_index(items, &enabled?/1) || 0

  defp last_enabled(items),
    do:
      items
      |> Enum.with_index()
      |> Enum.reverse()
      |> Enum.find_value(0, fn {item, index} -> if enabled?(item), do: index end)

  defp normalize_item(%{separator: true} = item), do: item

  defp normalize_item(%{id: _id, label: label} = item),
    do: action(item.id, label, Map.to_list(Map.drop(item, [:id, :label])))

  defp normalize_item({id, label}), do: action(id, label)
  defp normalize_item(label), do: action(label, label)
end
