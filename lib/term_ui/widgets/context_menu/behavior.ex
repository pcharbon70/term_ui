defmodule TermUI.Widgets.ContextMenu.Behavior do
  @moduledoc """
  Shared behavior for context menu variants.

  This module provides common functionality for both positioned (`ContextMenu`)
  and inline (`ContextMenu.Inline`) menu implementations. It extracts shared
  logic for item selection, cursor management, and menu actions to eliminate
  code duplication and ensure consistent behavior across menu types.

  This is not a formal Elixir `@behaviour` but rather a collection of utility
  functions used by multiple menu implementations.

  ## Shared Functionality

  - **Item Selection:** Determining which items can be selected
  - **Cursor Management:** Moving cursor between selectable items
  - **Menu Actions:** Selecting items and closing menus

  ## Usage

  Menu implementations should alias this module and delegate to its functions:

      alias TermUI.Widgets.ContextMenu.Behavior

      def init(props) do
        state = %{
          items: props.items,
          cursor: Behavior.find_first_selectable(props.items),
          # ...
        }
        {:ok, state}
      end

      def handle_event(%Event.Key{key: :down}, state) do
        state = Behavior.move_cursor(state, 1)
        {:ok, state}
      end
  """

  # ----------------------------------------------------------------------------
  # Item Selection
  # ----------------------------------------------------------------------------

  @doc """
  Returns whether an item can be selected.

  An item is selectable if it's an action type and not disabled. Separators
  and disabled action items are not selectable.

  ## Examples

      iex> Behavior.selectable?(%{type: :action, disabled: false})
      true

      iex> Behavior.selectable?(%{type: :action, disabled: true})
      false

      iex> Behavior.selectable?(%{type: :separator})
      false
  """
  @spec selectable?(map()) :: boolean()
  def selectable?(item) do
    item.type == :action and not Map.get(item, :disabled, false)
  end

  @doc """
  Finds the ID of the first selectable item in a list.

  Returns `nil` if no selectable items exist. This is useful for initializing
  the cursor position to the first available action.

  ## Examples

      iex> items = [
      ...>   %{type: :separator},
      ...>   %{type: :action, id: :copy, disabled: false},
      ...>   %{type: :action, id: :paste, disabled: false}
      ...> ]
      iex> Behavior.find_first_selectable(items)
      :copy

      iex> Behavior.find_first_selectable([%{type: :separator}])
      nil
  """
  @spec find_first_selectable([map()]) :: term() | nil
  def find_first_selectable(items) do
    items
    |> Enum.find(&selectable?/1)
    |> case do
      nil -> nil
      item -> item.id
    end
  end

  # ----------------------------------------------------------------------------
  # Cursor Management
  # ----------------------------------------------------------------------------

  @doc """
  Moves the cursor in the specified direction among selectable items.

  Direction is `+1` for next item, `-1` for previous item. Movement is clamped
  at boundaries (does not wrap around). Non-selectable items (separators, disabled
  actions) are automatically skipped.

  ## Parameters

  - `state` - State map containing `:items` and `:cursor` keys
  - `direction` - Integer offset: `-1` for previous, `+1` for next

  ## Returns

  Updated state with new cursor position. If cursor is at a boundary and movement
  would go beyond it, cursor remains unchanged.

  ## Examples

      state = %{
        items: [
          %{type: :action, id: :copy},
          %{type: :action, id: :paste}
        ],
        cursor: :copy
      }

      # Move to next item
      new_state = Behavior.move_cursor(state, 1)
      # new_state.cursor == :paste

      # At boundary, cursor stays in place
      new_state = Behavior.move_cursor(new_state, 1)
      # new_state.cursor == :paste (unchanged)
  """
  @spec move_cursor(map(), integer()) :: map()
  def move_cursor(state, direction) do
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

  # ----------------------------------------------------------------------------
  # Menu Actions
  # ----------------------------------------------------------------------------

  @doc """
  Selects the item at the current cursor position.

  Invokes the `on_select` callback if the item is selectable (action type and
  not disabled), then closes the menu. If the cursor is on a non-selectable
  item, no action is taken.

  ## Parameters

  - `state` - State map containing:
    - `:items` - List of menu items
    - `:cursor` - ID of currently focused item
    - `:on_select` - Callback function `fn id -> ... end` (optional)

  ## Returns

  Updated state with menu closed (`:visible` set to `false`).

  ## Callback Execution

  The `on_select` callback is executed synchronously. If the callback raises an
  exception, the widget process will crash and restart. Callbacks should handle
  their own errors to avoid disrupting the UI.

  ## Examples

      state = %{
        items: [%{type: :action, id: :copy, disabled: false}],
        cursor: :copy,
        on_select: fn id -> IO.puts("Selected: \#{id}") end,
        visible: true
      }

      new_state = Behavior.select_at_cursor(state)
      # Prints: "Selected: copy"
      # new_state.visible == false
  """
  @spec select_at_cursor(map()) :: map()
  def select_at_cursor(state) do
    # Use O(1) map lookup if available, otherwise fall back to O(n) list search
    item = case Map.get(state, :item_map) do
      nil -> Enum.find(state.items, fn item -> item.id == state.cursor end)
      item_map -> Map.get(item_map, state.cursor)
    end

    case item do
      %{type: :action} = item ->
        if state.on_select && not Map.get(item, :disabled, false) do
          state.on_select.(item.id)
        end

        close_menu(state)

      _ ->
        state
    end
  end

  @doc """
  Closes the menu and invokes the `on_close` callback.

  Sets the `:visible` state to `false` and calls the `on_close` callback if
  provided. This is typically called when the menu is dismissed via escape key
  or click outside.

  ## Parameters

  - `state` - State map containing:
    - `:on_close` - Callback function `fn -> ... end` (optional)
    - `:visible` - Current visibility state

  ## Returns

  Updated state with `:visible` set to `false`.

  ## Callback Execution

  The `on_close` callback is executed synchronously before setting visibility.
  If the callback raises an exception, the widget process will crash and restart.

  ## Examples

      state = %{
        on_close: fn -> IO.puts("Menu closed") end,
        visible: true
      }

      new_state = Behavior.close_menu(state)
      # Prints: "Menu closed"
      # new_state.visible == false
  """
  @spec close_menu(map()) :: map()
  def close_menu(state) do
    if state.on_close do
      state.on_close.()
    end

    %{state | visible: false}
  end
end
