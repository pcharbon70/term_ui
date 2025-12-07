defmodule TermUI.Widgets.ContextMenu.Inline do
  @moduledoc """
  Inline context menu variant for keyboard-only environments.

  Unlike the standard ContextMenu which appears at a mouse position, the Inline
  variant renders in place with numbered items for direct selection. This makes
  it ideal for TTY mode where mouse positioning may not be available.

  ## Usage

      ContextMenu.Inline.new(
        items: [
          ContextMenu.action(:copy, "Copy"),
          ContextMenu.action(:paste, "Paste"),
          ContextMenu.action(:delete, "Delete")
        ],
        on_select: fn id -> handle_action(id) end,
        on_close: fn -> handle_close() end
      )

  ## Rendering

  Items are rendered with numbered prefixes:

      [1] Copy  [2] Paste  [3] Delete

  In vertical orientation:

      [1] Copy
      [2] Paste
      [3] Delete

  ## Keyboard Controls

  - **Number keys (1-9)**: Directly select the numbered item
  - **Up/Down** (vertical) or **Left/Right** (horizontal): Navigate between items
  - **Enter/Space**: Select the currently focused item
  - **Escape**: Close the menu without selecting

  ## Notes

  - Separators and disabled items are not numbered
  - Maximum of 9 items can be numbered (items 10+ require arrow navigation)
  - Only selectable items (non-disabled actions) get numbers
  """

  use TermUI.StatefulComponent

  alias TermUI.Event

  @type orientation :: :horizontal | :vertical

  # ----------------------------------------------------------------------------
  # Props
  # ----------------------------------------------------------------------------

  @doc """
  Creates new ContextMenu.Inline widget props.

  ## Options

  - `:items` - List of menu items (required). Use `ContextMenu.action/3` and
    `ContextMenu.separator/0` to create items.
  - `:on_select` - Callback when item is selected: `fn id -> ... end`
  - `:on_close` - Callback when menu is closed without selection: `fn -> ... end`
  - `:orientation` - `:horizontal` (side by side) or `:vertical` (stacked).
    Default: `:horizontal`
  - `:item_style` - Style for normal items
  - `:selected_style` - Style for focused item
  - `:disabled_style` - Style for disabled items
  - `:number_style` - Style for the `[n]` prefix
  """
  @spec new(keyword()) :: map()
  def new(opts) do
    %{
      items: Keyword.fetch!(opts, :items),
      on_select: Keyword.get(opts, :on_select),
      on_close: Keyword.get(opts, :on_close),
      orientation: Keyword.get(opts, :orientation, :horizontal),
      item_style: Keyword.get(opts, :item_style),
      selected_style: Keyword.get(opts, :selected_style),
      disabled_style: Keyword.get(opts, :disabled_style),
      number_style: Keyword.get(opts, :number_style)
    }
  end

  # ----------------------------------------------------------------------------
  # StatefulComponent Callbacks
  # ----------------------------------------------------------------------------

  @impl true
  def init(props) do
    # Build number-to-item mapping for selectable items (1-9 only)
    {number_map, _} = build_number_map(props.items)

    state = %{
      items: props.items,
      cursor: find_first_selectable(props.items),
      on_select: props.on_select,
      on_close: props.on_close,
      orientation: props.orientation,
      item_style: props.item_style,
      selected_style: props.selected_style,
      disabled_style: props.disabled_style,
      number_style: props.number_style,
      number_map: number_map,
      visible: true
    }

    {:ok, state}
  end

  @impl true
  def handle_event(%Event.Key{key: key}, state)
      when key in [:up, :left] do
    state = move_cursor(state, -1)
    {:ok, state}
  end

  def handle_event(%Event.Key{key: key}, state)
      when key in [:down, :right] do
    state = move_cursor(state, 1)
    {:ok, state}
  end

  def handle_event(%Event.Key{key: key}, state) when key in [:enter, " "] do
    state = select_at_cursor(state)
    {:ok, state}
  end

  def handle_event(%Event.Key{key: :escape}, state) do
    state = close_menu(state)
    {:ok, state}
  end

  # Handle number keys 1-9 for direct selection
  def handle_event(%Event.Key{key: key}, state)
      when key in ["1", "2", "3", "4", "5", "6", "7", "8", "9"] do
    number = String.to_integer(key)
    state = select_by_number(state, number)
    {:ok, state}
  end

  def handle_event(_event, state) do
    {:ok, state}
  end

  @impl true
  def render(state, _area) do
    if state.visible do
      {number_map, _} = build_number_map(state.items)

      items_with_numbers =
        state.items
        |> Enum.map(fn item ->
          number = find_number_for_item(number_map, item)
          render_item(state, item, number)
        end)

      case state.orientation do
        :horizontal ->
          # Join items with spacing
          spaced_items =
            items_with_numbers
            |> Enum.intersperse(text("  "))
            |> List.flatten()

          stack(:horizontal, spaced_items)

        :vertical ->
          stack(:vertical, items_with_numbers)
      end
    else
      empty()
    end
  end

  # ----------------------------------------------------------------------------
  # Public API
  # ----------------------------------------------------------------------------

  @doc """
  Gets whether the menu is visible.
  """
  @spec visible?(map()) :: boolean()
  def visible?(state) do
    state.visible
  end

  @doc """
  Shows the menu.
  """
  @spec show(map()) :: map()
  def show(state) do
    %{state | visible: true}
  end

  @doc """
  Hides the menu.
  """
  @spec hide(map()) :: map()
  def hide(state) do
    %{state | visible: false}
  end

  @doc """
  Gets the currently focused item ID.
  """
  @spec get_cursor(map()) :: term()
  def get_cursor(state) do
    state.cursor
  end

  # ----------------------------------------------------------------------------
  # Private: Number Mapping
  # ----------------------------------------------------------------------------

  # Builds a map from number (1-9) to item ID for selectable items
  @spec build_number_map([map()]) :: {%{pos_integer() => term()}, pos_integer()}
  defp build_number_map(items) do
    items
    |> Enum.reduce({%{}, 1}, fn item, {map, num} ->
      if selectable?(item) and num <= 9 do
        {Map.put(map, num, item.id), num + 1}
      else
        {map, num}
      end
    end)
  end

  # Finds the number assigned to an item (or nil if not numbered)
  @spec find_number_for_item(%{pos_integer() => term()}, map()) :: pos_integer() | nil
  defp find_number_for_item(number_map, item) do
    number_map
    |> Enum.find(fn {_num, id} -> id == item.id end)
    |> case do
      {num, _id} -> num
      nil -> nil
    end
  end

  # ----------------------------------------------------------------------------
  # Private: Selection
  # ----------------------------------------------------------------------------

  @spec selectable?(map()) :: boolean()
  defp selectable?(item) do
    item.type == :action and not Map.get(item, :disabled, false)
  end

  @spec find_first_selectable([map()]) :: term() | nil
  defp find_first_selectable(items) do
    items
    |> Enum.find(&selectable?/1)
    |> case do
      nil -> nil
      item -> item.id
    end
  end

  @spec move_cursor(map(), integer()) :: map()
  defp move_cursor(state, direction) do
    selectable_items = Enum.filter(state.items, &selectable?/1)

    case Enum.find_index(selectable_items, fn item -> item.id == state.cursor end) do
      nil ->
        state

      current_idx ->
        new_idx = current_idx + direction
        new_idx = max(0, min(new_idx, length(selectable_items) - 1))
        item = Enum.at(selectable_items, new_idx)
        %{state | cursor: item.id}
    end
  end

  @spec select_at_cursor(map()) :: map()
  defp select_at_cursor(state) do
    case Enum.find(state.items, fn item -> item.id == state.cursor end) do
      %{type: :action} = item ->
        if state.on_select && not Map.get(item, :disabled, false) do
          state.on_select.(item.id)
        end

        close_menu(state)

      _ ->
        state
    end
  end

  @spec select_by_number(map(), pos_integer()) :: map()
  defp select_by_number(state, number) do
    case Map.get(state.number_map, number) do
      nil ->
        # Number not mapped to any item
        state

      item_id ->
        # Find and select the item
        case Enum.find(state.items, fn item -> item.id == item_id end) do
          %{type: :action} = item ->
            if state.on_select && not Map.get(item, :disabled, false) do
              state.on_select.(item.id)
            end

            close_menu(state)

          _ ->
            state
        end
    end
  end

  @spec close_menu(map()) :: map()
  defp close_menu(state) do
    if state.on_close do
      state.on_close.()
    end

    %{state | visible: false}
  end

  # ----------------------------------------------------------------------------
  # Private: Rendering
  # ----------------------------------------------------------------------------

  @spec render_item(map(), map(), pos_integer() | nil) :: term()
  defp render_item(state, item, number) do
    case item.type do
      :separator ->
        render_separator(state)

      _ ->
        render_action_item(state, item, number)
    end
  end

  defp render_separator(state) do
    case state.orientation do
      :horizontal -> text("|")
      :vertical -> text("───")
    end
  end

  defp render_action_item(state, item, number) do
    # Build the number prefix
    prefix =
      if number do
        "[#{number}] "
      else
        "    "
      end

    label = prefix <> item.label

    # Determine style
    style =
      cond do
        Map.get(item, :disabled, false) ->
          state.disabled_style

        item.id == state.cursor ->
          state.selected_style

        true ->
          state.item_style
      end

    if style do
      styled(text(label), style)
    else
      text(label)
    end
  end
end
