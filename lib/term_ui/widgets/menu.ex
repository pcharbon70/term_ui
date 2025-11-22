defmodule TermUI.Widgets.Menu do
  @moduledoc """
  Menu widget for displaying hierarchical actions.

  Menu displays a list of items that can be actions, submenus, separators,
  or checkboxes. Supports keyboard navigation and shortcut display.

  ## Usage

      Menu.new(
        items: [
          Menu.action(:new, "New File", shortcut: "Ctrl+N"),
          Menu.action(:open, "Open...", shortcut: "Ctrl+O"),
          Menu.separator(),
          Menu.submenu(:recent, "Recent Files", [
            Menu.action(:file1, "document.txt"),
            Menu.action(:file2, "notes.md")
          ]),
          Menu.separator(),
          Menu.checkbox(:autosave, "Auto Save", checked: true),
          Menu.action(:exit, "Exit", shortcut: "Ctrl+Q")
        ],
        on_select: fn id -> handle_menu_action(id) end
      )

  ## Item Types

  - `:action` - Selectable menu item
  - `:submenu` - Item with nested menu items
  - `:separator` - Visual divider
  - `:checkbox` - Toggleable item with check state

  ## Keyboard Navigation

  - Up/Down: Move between items
  - Enter/Space: Select item or expand submenu
  - Left: Collapse submenu
  - Right: Expand submenu
  - Escape: Close menu
  """

  use TermUI.StatefulComponent

  alias TermUI.Event

  @type item_type :: :action | :submenu | :separator | :checkbox

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
  Creates a submenu item.
  """
  @spec submenu(term(), String.t(), [map()]) :: map()
  def submenu(id, label, children) do
    %{
      type: :submenu,
      id: id,
      label: label,
      children: children
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
  Creates a checkbox item.
  """
  @spec checkbox(term(), String.t(), keyword()) :: map()
  def checkbox(id, label, opts \\ []) do
    %{
      type: :checkbox,
      id: id,
      label: label,
      checked: Keyword.get(opts, :checked, false),
      disabled: Keyword.get(opts, :disabled, false)
    }
  end

  @doc """
  Creates new Menu widget props.

  ## Options

  - `:items` - List of menu items (required)
  - `:on_select` - Callback when item is selected
  - `:on_toggle` - Callback when checkbox is toggled
  - `:width` - Menu width (default: auto)
  - `:item_style` - Style for normal items
  - `:selected_style` - Style for focused item
  - `:disabled_style` - Style for disabled items
  """
  @spec new(keyword()) :: map()
  def new(opts) do
    %{
      items: Keyword.fetch!(opts, :items),
      on_select: Keyword.get(opts, :on_select),
      on_toggle: Keyword.get(opts, :on_toggle),
      width: Keyword.get(opts, :width),
      item_style: Keyword.get(opts, :item_style),
      selected_style: Keyword.get(opts, :selected_style),
      disabled_style: Keyword.get(opts, :disabled_style)
    }
  end

  @impl true
  def init(props) do
    flat_items = flatten_items(props.items)

    state = %{
      items: props.items,
      flat_items: flat_items,
      cursor: find_first_selectable(flat_items),
      expanded: MapSet.new(),
      on_select: props.on_select,
      on_toggle: props.on_toggle,
      width: props.width,
      item_style: props.item_style,
      selected_style: props.selected_style,
      disabled_style: props.disabled_style
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

  def handle_event(%Event.Key{key: :right}, state) do
    # Expand submenu
    state = expand_at_cursor(state)
    {:ok, state}
  end

  def handle_event(%Event.Key{key: :left}, state) do
    # Collapse submenu
    state = collapse_at_cursor(state)
    {:ok, state}
  end

  def handle_event(%Event.Key{key: key}, state) when key in [:enter, " "] do
    state = select_at_cursor(state)
    {:ok, state}
  end

  def handle_event(%Event.Key{key: :escape}, state) do
    # Signal to close menu
    {:ok, state, [{:send, self(), :menu_close}]}
  end

  def handle_event(%Event.Mouse{action: :click, y: y}, state) do
    # Select item at y position
    visible = get_visible_items(state)

    if y >= 0 and y < length(visible) do
      {item, _depth} = Enum.at(visible, y)
      state = %{state | cursor: item.id}
      state = select_at_cursor(state)
      {:ok, state}
    else
      {:ok, state}
    end
  end

  def handle_event(_event, state) do
    {:ok, state}
  end

  @impl true
  def render(state, _area) do
    visible = get_visible_items(state)
    width = state.width || calculate_width(visible)

    rows =
      Enum.map(visible, fn {item, depth} ->
        render_item(state, item, depth, width)
      end)

    stack(:vertical, rows)
  end

  # Private functions

  defp flatten_items(items, depth \\ 0) do
    Enum.flat_map(items, fn item ->
      case item.type do
        :submenu ->
          [{item, depth} | flatten_items(item.children, depth + 1)]

        _ ->
          [{item, depth}]
      end
    end)
  end

  defp find_first_selectable(flat_items) do
    flat_items
    |> Enum.find(fn {item, _} -> selectable?(item) end)
    |> case do
      nil -> nil
      {item, _} -> item.id
    end
  end

  defp selectable?(item) do
    item.type in [:action, :submenu, :checkbox] and not Map.get(item, :disabled, false)
  end

  defp move_cursor(state, direction) do
    visible = get_visible_items(state)
    selectable_items = Enum.filter(visible, fn {item, _} -> selectable?(item) end)

    case Enum.find_index(selectable_items, fn {item, _} -> item.id == state.cursor end) do
      nil ->
        state

      current_idx ->
        new_idx = current_idx + direction
        new_idx = max(0, min(new_idx, length(selectable_items) - 1))
        {item, _} = Enum.at(selectable_items, new_idx)
        %{state | cursor: item.id}
    end
  end

  defp expand_at_cursor(state) do
    case find_item(state.items, state.cursor) do
      %{type: :submenu} = _item ->
        %{state | expanded: MapSet.put(state.expanded, state.cursor)}

      _ ->
        state
    end
  end

  defp collapse_at_cursor(state) do
    %{state | expanded: MapSet.delete(state.expanded, state.cursor)}
  end

  defp select_at_cursor(state) do
    case find_item(state.items, state.cursor) do
      %{type: :action} = item ->
        if state.on_select && not Map.get(item, :disabled, false) do
          state.on_select.(item.id)
        end
        state

      %{type: :submenu} ->
        expand_at_cursor(state)

      %{type: :checkbox} = item ->
        if not Map.get(item, :disabled, false) do
          toggle_checkbox(state, item.id)
        else
          state
        end

      _ ->
        state
    end
  end

  defp toggle_checkbox(state, item_id) do
    items = update_item(state.items, item_id, fn item ->
      %{item | checked: not item.checked}
    end)

    if state.on_toggle do
      new_item = find_item(items, item_id)
      state.on_toggle.(item_id, new_item.checked)
    end

    flat_items = flatten_items(items)
    %{state | items: items, flat_items: flat_items}
  end

  defp find_item(items, id) do
    Enum.find_value(items, fn item ->
      cond do
        item.id == id -> item
        item.type == :submenu -> find_item(item.children, id)
        true -> nil
      end
    end)
  end

  defp update_item(items, id, update_fn) do
    Enum.map(items, fn item ->
      cond do
        item.id == id ->
          update_fn.(item)

        item.type == :submenu ->
          %{item | children: update_item(item.children, id, update_fn)}

        true ->
          item
      end
    end)
  end

  defp get_visible_items(state) do
    get_visible_items(state.items, state.expanded, 0)
  end

  defp get_visible_items(items, expanded, depth) do
    Enum.flat_map(items, fn item ->
      case item.type do
        :submenu ->
          if MapSet.member?(expanded, item.id) do
            [{item, depth} | get_visible_items(item.children, expanded, depth + 1)]
          else
            [{item, depth}]
          end

        _ ->
          [{item, depth}]
      end
    end)
  end

  defp calculate_width(visible) do
    visible
    |> Enum.map(fn {item, depth} ->
      case item.type do
        :separator ->
          3

        _ ->
          label_len = String.length(item.label)
          shortcut_len = String.length(Map.get(item, :shortcut, "") || "")
          indent = depth * 2
          # prefix (checkbox/arrow) + label + gap + shortcut
          4 + indent + label_len + 2 + shortcut_len
      end
    end)
    |> Enum.max(fn -> 10 end)
  end

  defp render_item(state, item, depth, width) do
    case item.type do
      :separator ->
        text(String.duplicate("─", width))

      _ ->
        render_selectable_item(state, item, depth, width)
    end
  end

  defp render_selectable_item(state, item, depth, width) do
    indent = String.duplicate("  ", depth)

    # Prefix: checkbox state or submenu arrow
    prefix =
      case item.type do
        :checkbox ->
          if item.checked, do: "[×] ", else: "[ ] "

        :submenu ->
          if MapSet.member?(state.expanded, item.id), do: "▼ ", else: "▶ "

        _ ->
          "  "
      end

    # Main label
    label = indent <> prefix <> item.label

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
  Gets the currently focused item ID.
  """
  @spec get_cursor(map()) :: term()
  def get_cursor(state) do
    state.cursor
  end

  @doc """
  Expands a submenu by ID.
  """
  @spec expand(map(), term()) :: map()
  def expand(state, submenu_id) do
    %{state | expanded: MapSet.put(state.expanded, submenu_id)}
  end

  @doc """
  Collapses a submenu by ID.
  """
  @spec collapse(map(), term()) :: map()
  def collapse(state, submenu_id) do
    %{state | expanded: MapSet.delete(state.expanded, submenu_id)}
  end

  @doc """
  Checks if a submenu is expanded.
  """
  @spec expanded?(map(), term()) :: boolean()
  def expanded?(state, submenu_id) do
    MapSet.member?(state.expanded, submenu_id)
  end

  @doc """
  Gets checkbox state.
  """
  @spec checked?(map(), term()) :: boolean()
  def checked?(state, item_id) do
    case find_item(state.items, item_id) do
      %{type: :checkbox, checked: checked} -> checked
      _ -> false
    end
  end
end
