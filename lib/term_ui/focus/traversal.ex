defmodule TermUI.Focus.Traversal do
  @moduledoc """
  Focus traversal utilities for calculating tab order.

  Provides utilities for determining the order in which components
  receive focus during Tab/Shift+Tab navigation.

  ## Tab Order

  Components are ordered by:
  1. Explicit `tab_index` (lower numbers first)
  2. Screen position (top-to-bottom, left-to-right)

  ## Usage

      # Get tab order for components
      order = Traversal.calculate_order(component_ids)

      # Check if component should be skipped
      Traversal.should_skip?(component_id)
  """

  alias TermUI.SpatialIndex

  @doc """
  Calculates the tab order for a list of components.

  Returns components sorted by tab index, then by position.

  ## Parameters

  - `component_ids` - List of component ids
  - `opts` - Options:
    - `:tab_indices` - Map of component_id => tab_index

  ## Returns

  Sorted list of component ids.
  """
  @spec calculate_order([term()], keyword()) :: [term()]
  def calculate_order(component_ids, opts \\ []) do
    tab_indices = Keyword.get(opts, :tab_indices, %{})

    component_ids
    |> Enum.map(fn id ->
      tab_index = Map.get(tab_indices, id)
      position = get_position(id)
      {id, tab_index, position}
    end)
    |> Enum.sort_by(fn {_id, tab_index, {x, y}} ->
      # nil tab_index sorts last
      index = tab_index || 999_999
      {index, y, x}
    end)
    |> Enum.map(fn {id, _, _} -> id end)
  end

  @doc """
  Gets the next component in tab order.

  ## Parameters

  - `ordered_list` - Components in tab order
  - `current` - Currently focused component (or nil)

  ## Returns

  Next component id, wrapping to first if at end.
  """
  @spec next([term()], term() | nil) :: term() | nil
  def next([], _current), do: nil

  def next(ordered_list, nil) do
    List.first(ordered_list)
  end

  def next(ordered_list, current) do
    case Enum.find_index(ordered_list, &(&1 == current)) do
      nil ->
        List.first(ordered_list)

      idx ->
        next_idx = rem(idx + 1, length(ordered_list))
        Enum.at(ordered_list, next_idx)
    end
  end

  @doc """
  Gets the previous component in tab order.

  ## Parameters

  - `ordered_list` - Components in tab order
  - `current` - Currently focused component (or nil)

  ## Returns

  Previous component id, wrapping to last if at beginning.
  """
  @spec prev([term()], term() | nil) :: term() | nil
  def prev([], _current), do: nil

  def prev(ordered_list, nil) do
    List.last(ordered_list)
  end

  def prev(ordered_list, current) do
    case Enum.find_index(ordered_list, &(&1 == current)) do
      nil ->
        List.last(ordered_list)

      0 ->
        List.last(ordered_list)

      idx ->
        Enum.at(ordered_list, idx - 1)
    end
  end

  @doc """
  Checks if a component should be skipped during traversal.

  A component is skipped if:
  - It has `focusable: false`
  - It has `disabled: true`
  - It has a negative `tab_index`

  ## Parameters

  - `component_id` - Component to check
  - `opts` - Options:
    - `:focusable` - Map of component_id => boolean
    - `:disabled` - Map of component_id => boolean
    - `:tab_indices` - Map of component_id => integer

  ## Returns

  Boolean indicating if component should be skipped.
  """
  @spec should_skip?(term(), keyword()) :: boolean()
  def should_skip?(component_id, opts \\ []) do
    focusable_map = Keyword.get(opts, :focusable, %{})
    disabled_map = Keyword.get(opts, :disabled, %{})
    tab_indices = Keyword.get(opts, :tab_indices, %{})

    # Check focusable (default true)
    focusable = Map.get(focusable_map, component_id, true)

    # Check disabled (default false)
    disabled = Map.get(disabled_map, component_id, false)

    # Check negative tab_index
    tab_index = Map.get(tab_indices, component_id)
    negative_tab = is_integer(tab_index) && tab_index < 0

    !focusable || disabled || negative_tab
  end

  @doc """
  Filters a list to only focusable components.

  ## Parameters

  - `component_ids` - List of component ids
  - `opts` - Options passed to `should_skip?/2`

  ## Returns

  Filtered list of focusable component ids.
  """
  @spec filter_focusable([term()], keyword()) :: [term()]
  def filter_focusable(component_ids, opts \\ []) do
    Enum.reject(component_ids, &should_skip?(&1, opts))
  end

  # Private Functions

  defp get_position(component_id) do
    case SpatialIndex.get_bounds(component_id) do
      {:ok, %{x: x, y: y}} -> {x, y}
      _ -> {0, 0}
    end
  end
end
