defmodule TermUI.Widget.Menu do
  @moduledoc """
  A pure keyboard menu with actions, separators, and disabled items.

  The `:variant` option changes the selected-item style. Use `:plain`, `:line`,
  or `:filled`.
  """

  @behaviour TermUI.Widget

  alias TermUI.{Event, Style}
  alias TermUI.Widget.Helpers

  @type item :: %{
          required(:id) => term(),
          required(:label) => String.t(),
          optional(:disabled) => boolean(),
          optional(:separator) => boolean(),
          optional(:icon) => String.t() | nil,
          optional(:shortcut) => String.t() | nil,
          optional(:message) => term()
        }
  @type t :: %__MODULE__{
          items: [item()],
          cursor: non_neg_integer(),
          title: String.t() | nil,
          visible: boolean(),
          orientation: :vertical | :horizontal,
          variant: :plain | :line | :filled
        }
  @schema Zoi.struct(__MODULE__, %{
            items: Zoi.array() |> Zoi.default([]),
            cursor: Zoi.integer() |> Zoi.non_negative() |> Zoi.default(0),
            title: Zoi.any() |> Zoi.default(nil),
            visible: Zoi.boolean() |> Zoi.default(true),
            orientation: Zoi.enum([:vertical, :horizontal]) |> Zoi.default(:vertical),
            variant: Zoi.enum([:plain, :line, :filled]) |> Zoi.default(:plain)
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
      icon: Keyword.get(opts, :icon),
      shortcut:
        opts
        |> Keyword.get(:shortcut, Keyword.get(opts, :hotkey))
        |> normalize_decoration(),
      message: Keyword.get(opts, :message, {:selected, id})
    }
  end

  @doc "Creates one separator."
  @spec separator() :: item()
  def separator,
    do: %{
      id: make_ref(),
      label: "",
      disabled: true,
      separator: true,
      icon: nil,
      shortcut: nil,
      message: nil
    }

  @impl true
  def init(opts) do
    items = opts |> Keyword.get(:items, []) |> Enum.map(&normalize_item/1)

    %__MODULE__{
      items: items,
      cursor: first_enabled(items),
      title: Keyword.get(opts, :title),
      visible: Keyword.get(opts, :visible, true),
      orientation: Keyword.get(opts, :orientation, :vertical),
      variant: Keyword.get(opts, :variant, :plain)
    }
  end

  @impl true
  def update(_event, %{visible: false} = state), do: {state, []}
  def update(%Event.Key{key: key}, state) when key in [:up, :left], do: move(state, -1)
  def update(%Event.Key{key: key}, state) when key in [:down, :right], do: move(state, 1)

  def update(%Event.Key{key: :home}, state),
    do: {%{state | cursor: first_enabled(state.items)}, []}

  def update(%Event.Key{key: :end}, state), do: {%{state | cursor: last_enabled(state.items)}, []}
  def update(%Event.Key{key: key}, state) when key in [:enter, :space], do: activate(state)
  def update(%Event.Text{text: " "}, state), do: activate(state)
  def update(%Event.Key{key: :escape}, state), do: {%{state | visible: false}, [:dismissed]}
  def update(_event, state), do: {state, []}

  @impl true
  def mouse(_event, %{visible: false} = state, _dimensions), do: {state, []}

  def mouse(%Event.Mouse{action: action, button: :left, x: x, y: y}, state, {width, height})
      when action in [:press, :release] do
    border_offset = if width > 1 and height > 1, do: 1, else: 0

    index = menu_item_at(state, {x, y}, {width, height}, border_offset)

    item = if is_integer(index) and index >= 0, do: Enum.at(state.items, index)

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
    cursor_style = cursor_style(state.variant)
    disabled_style = Style.new(fg: :bright_black)
    separator_style = Style.new(fg: :bright_black)
    inner_width = max(width - 2, 1)

    rows =
      case state.orientation do
        :vertical ->
          state.items
          |> Enum.with_index()
          |> Enum.map(
            &render_vertical_item(
              &1,
              inner_width,
              state.cursor,
              cursor_style,
              disabled_style,
              separator_style
            )
          )

        :horizontal ->
          [
            state.items
            |> Enum.with_index()
            |> Enum.flat_map(
              &render_horizontal_item(
                &1,
                state.cursor,
                cursor_style,
                disabled_style,
                separator_style
              )
            )
            |> Enum.drop(-1)
          ]
      end

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

  defp render_vertical_item(
         {%{separator: true}, _index},
         width,
         _cursor,
         _cursor_style,
         _disabled,
         style
       ),
       do: [{String.duplicate("─", width), style}]

  defp render_vertical_item(
         {item, index},
         width,
         cursor,
         cursor_style,
         disabled_style,
         _separator
       ) do
    shortcut = if item.shortcut, do: " " <> item.shortcut, else: ""
    prefix = item_prefix(item)
    label_width = max(width - Helpers.text_width(shortcut) - Helpers.text_width(prefix), 1)
    text = prefix <> Helpers.align(item.label, label_width, :left) <> shortcut

    style =
      cond do
        item.disabled -> disabled_style
        index == cursor -> cursor_style
        true -> Style.new()
      end

    [{text, style}]
  end

  defp render_horizontal_item(
         {%{separator: true}, _index},
         _cursor,
         _cursor_style,
         _disabled,
         style
       ),
       do: [{"│", style}, " "]

  defp render_horizontal_item(
         {item, index},
         cursor,
         cursor_style,
         disabled_style,
         _separator
       ) do
    style =
      cond do
        item.disabled -> disabled_style
        index == cursor -> cursor_style
        true -> Style.new()
      end

    [{horizontal_item_text(item), style}, "  "]
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

  defp item_prefix(item) do
    case Map.get(item, :icon) do
      nil -> "  "
      "" -> "  "
      icon -> " " <> to_string(icon) <> " "
    end
  end

  defp horizontal_item_text(%{separator: true}), do: "│"

  defp horizontal_item_text(item) do
    icon = if Map.get(item, :icon) in [nil, ""], do: "", else: to_string(item.icon) <> " "
    shortcut = if item.shortcut, do: " " <> item.shortcut, else: ""
    " " <> icon <> item.label <> shortcut <> " "
  end

  defp horizontal_item_at(items, x) when x >= 0 do
    items
    |> Enum.with_index()
    |> Enum.reduce_while({:after, 0}, fn {item, index}, {:after, start} ->
      finish = start + Helpers.text_width(horizontal_item_text(item))

      if x >= start and x < finish,
        do: {:halt, {:found, index}},
        else: {:cont, {:after, finish + horizontal_item_gap(item)}}
    end)
    |> case do
      {:found, index} -> index
      _other -> nil
    end
  end

  defp horizontal_item_at(_items, _x), do: nil

  defp horizontal_item_gap(%{separator: true}), do: 1
  defp horizontal_item_gap(_item), do: 2

  defp menu_item_at(
         %{orientation: :vertical},
         {x, y},
         {width, height},
         border_offset
       ) do
    index = y - border_offset

    if x >= border_offset and x < width - border_offset and index >= 0 and
         y < height - border_offset,
       do: index
  end

  defp menu_item_at(
         %{orientation: :horizontal, items: items},
         {x, y},
         {width, height},
         border_offset
       ) do
    if y == border_offset and x >= border_offset and x < width - border_offset and
         y < height - border_offset,
       do: horizontal_item_at(items, x - border_offset)
  end

  defp cursor_style(:plain), do: Style.new(attrs: [:reverse])
  defp cursor_style(:line), do: Style.new(fg: :cyan, attrs: [:bold, :underline])
  defp cursor_style(:filled), do: Style.new(fg: :black, bg: :cyan, attrs: [:bold])

  defp normalize_decoration(nil), do: nil
  defp normalize_decoration(value) when is_list(value), do: IO.iodata_to_binary(value)
  defp normalize_decoration(value), do: to_string(value)
end
