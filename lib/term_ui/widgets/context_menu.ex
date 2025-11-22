defmodule TermUI.Widgets.ContextMenu do
  @moduledoc """
  Context menu widget for displaying floating menus at cursor position.

  Context menu appears at a specific position (usually on right-click) and
  displays a list of actions. It automatically closes on selection, escape,
  or clicking outside.

  ## Usage

      ContextMenu.new(
        items: [
          ContextMenu.action(:cut, "Cut", shortcut: "Ctrl+X"),
          ContextMenu.action(:copy, "Copy", shortcut: "Ctrl+C"),
          ContextMenu.action(:paste, "Paste", shortcut: "Ctrl+V"),
          ContextMenu.separator(),
          ContextMenu.action(:select_all, "Select All", shortcut: "Ctrl+A")
        ],
        position: {x, y},
        on_select: fn id -> handle_action(id) end,
        on_close: fn -> handle_close() end
      )

  ## Features

  - Floating overlay at specified position
  - Keyboard navigation (Up/Down/Enter/Escape)
  - Closes on selection or escape
  - Closes on click outside menu bounds
  - Z-order above other content
  """

  use TermUI.StatefulComponent

  alias TermUI.Event

  # Item constructors

  @doc """
  Creates an action menu item.
  """
  @spec action(term(), String.t(), keyword()) :: map()
  def action(id, label, opts \\ []) do
    %{
      type: :action,
      id: id,
      label: label,
      shortcut: Keyword.get(opts, :shortcut),
      disabled: Keyword.get(opts, :disabled, false)
    }
  end

  @doc """
  Creates a separator.
  """
  @spec separator() :: map()
  def separator do
    %{type: :separator, id: make_ref()}
  end

  @doc """
  Creates new ContextMenu widget props.

  ## Options

  - `:items` - List of menu items (required)
  - `:position` - {x, y} tuple for menu position (required)
  - `:on_select` - Callback when item is selected
  - `:on_close` - Callback when menu is closed
  - `:item_style` - Style for normal items
  - `:selected_style` - Style for focused item
  - `:disabled_style` - Style for disabled items
  """
  @spec new(keyword()) :: map()
  def new(opts) do
    %{
      items: Keyword.fetch!(opts, :items),
      position: Keyword.fetch!(opts, :position),
      on_select: Keyword.get(opts, :on_select),
      on_close: Keyword.get(opts, :on_close),
      item_style: Keyword.get(opts, :item_style),
      selected_style: Keyword.get(opts, :selected_style),
      disabled_style: Keyword.get(opts, :disabled_style)
    }
  end

  @impl true
  def init(props) do
    state = %{
      items: props.items,
      position: props.position,
      cursor: find_first_selectable(props.items),
      on_select: props.on_select,
      on_close: props.on_close,
      item_style: props.item_style,
      selected_style: props.selected_style,
      disabled_style: props.disabled_style,
      visible: true
    }

    {:ok, state}
  end

  @impl true
  def handle_event(%Event.Key{key: :up}, state) do
    state = move_cursor(state, -1)
    {:ok, state}
  end

  def handle_event(%Event.Key{key: :down}, state) do
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

  def handle_event(%Event.Mouse{action: :click, x: x, y: y}, state) do
    {pos_x, pos_y} = state.position
    menu_width = calculate_width(state.items)
    menu_height = length(state.items)

    # Check if click is inside menu bounds
    if x >= pos_x and x < pos_x + menu_width and
       y >= pos_y and y < pos_y + menu_height do
      # Click inside menu - select item
      relative_y = y - pos_y
      item = Enum.at(state.items, relative_y)

      if item && selectable?(item) do
        state = %{state | cursor: item.id}
        state = select_at_cursor(state)
        {:ok, state}
      else
        {:ok, state}
      end
    else
      # Click outside menu - close
      state = close_menu(state)
      {:ok, state}
    end
  end

  def handle_event(_event, state) do
    {:ok, state}
  end

  @impl true
  def render(state, _area) do
    if not state.visible do
      empty()
    else
      {pos_x, pos_y} = state.position
      width = calculate_width(state.items)

      rows =
        Enum.map(state.items, fn item ->
          render_item(state, item, width)
        end)

      content = stack(:vertical, rows)

      # Return overlay structure for positioning
      # The renderer will handle placing this at the specified position
      %{
        type: :overlay,
        content: content,
        x: pos_x,
        y: pos_y,
        z: 100
      }
    end
  end

  # Private functions

  defp find_first_selectable(items) do
    items
    |> Enum.find(fn item -> selectable?(item) end)
    |> case do
      nil -> nil
      item -> item.id
    end
  end

  defp selectable?(item) do
    item.type == :action and not Map.get(item, :disabled, false)
  end

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

  defp close_menu(state) do
    if state.on_close do
      state.on_close.()
    end
    %{state | visible: false}
  end

  defp calculate_width(items) do
    items
    |> Enum.map(fn item ->
      case item.type do
        :separator ->
          3

        _ ->
          label_len = String.length(item.label)
          shortcut_len = String.length(Map.get(item, :shortcut, "") || "")
          # prefix + label + gap + shortcut
          2 + label_len + 2 + shortcut_len
      end
    end)
    |> Enum.max(fn -> 10 end)
  end

  defp render_item(state, item, width) do
    case item.type do
      :separator ->
        text(String.duplicate("─", width))

      _ ->
        render_action_item(state, item, width)
    end
  end

  defp render_action_item(state, item, width) do
    # Main label
    label = "  " <> item.label

    # Shortcut aligned right
    shortcut = Map.get(item, :shortcut, "") || ""
    padding = width - String.length(label) - String.length(shortcut)
    padding = max(1, padding)

    full_text = label <> String.duplicate(" ", padding) <> shortcut

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
      styled(text(full_text), style)
    else
      text(full_text)
    end
  end

  # Public API

  @doc """
  Gets whether the context menu is visible.
  """
  @spec visible?(map()) :: boolean()
  def visible?(state) do
    state.visible
  end

  @doc """
  Shows the context menu.
  """
  @spec show(map()) :: map()
  def show(state) do
    %{state | visible: true}
  end

  @doc """
  Hides the context menu.
  """
  @spec hide(map()) :: map()
  def hide(state) do
    %{state | visible: false}
  end

  @doc """
  Updates the position of the context menu.
  """
  @spec set_position(map(), {non_neg_integer(), non_neg_integer()}) :: map()
  def set_position(state, position) do
    %{state | position: position}
  end

  @doc """
  Gets the currently focused item ID.
  """
  @spec get_cursor(map()) :: term()
  def get_cursor(state) do
    state.cursor
  end
end
