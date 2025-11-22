defmodule TermUI.Mouse.Router do
  @moduledoc """
  Routes mouse events to components based on position.

  The router uses component bounds to determine which component
  should receive a mouse event, handles z-order for overlapping
  components, and transforms coordinates to component-local space.

  ## Usage

      # Find component at position
      {component_id, local_x, local_y} = Router.hit_test(components, x, y)

      # Route event to component
      {target_id, transformed_event} = Router.route(components, mouse_event)
  """

  alias TermUI.Event

  @type bounds :: %{x: integer(), y: integer(), width: integer(), height: integer()}
  @type component_entry :: %{bounds: bounds(), z_index: integer()}
  @type components :: %{atom() => component_entry()}

  @doc """
  Finds the component at the given position.

  Returns `{component_id, local_x, local_y}` or `nil` if no component at position.

  When multiple components overlap, returns the one with highest z_index.
  """
  @spec hit_test(components(), integer(), integer()) :: {atom(), integer(), integer()} | nil
  def hit_test(components, x, y) do
    components
    |> Enum.filter(fn {_id, entry} -> point_in_bounds?(x, y, entry.bounds) end)
    |> Enum.max_by(fn {_id, entry} -> Map.get(entry, :z_index, 0) end, fn -> nil end)
    |> case do
      nil ->
        nil

      {id, entry} ->
        local_x = x - entry.bounds.x
        local_y = y - entry.bounds.y
        {id, local_x, local_y}
    end
  end

  @doc """
  Routes a mouse event to the appropriate component.

  Returns `{component_id, transformed_event}` where the event has
  coordinates transformed to component-local space.

  Returns `nil` if no component at the event position.
  """
  @spec route(components(), Event.Mouse.t()) :: {atom(), Event.Mouse.t()} | nil
  def route(components, %Event.Mouse{x: x, y: y} = event) do
    case hit_test(components, x, y) do
      nil ->
        nil

      {id, local_x, local_y} ->
        transformed = %{event | x: local_x, y: local_y}
        {id, transformed}
    end
  end

  @doc """
  Finds all components at the given position, ordered by z-index (highest first).

  Useful for event bubbling through overlapping components.
  """
  @spec hit_test_all(components(), integer(), integer()) :: [{atom(), integer(), integer()}]
  def hit_test_all(components, x, y) do
    components
    |> Enum.filter(fn {_id, entry} -> point_in_bounds?(x, y, entry.bounds) end)
    |> Enum.sort_by(fn {_id, entry} -> Map.get(entry, :z_index, 0) end, :desc)
    |> Enum.map(fn {id, entry} ->
      local_x = x - entry.bounds.x
      local_y = y - entry.bounds.y
      {id, local_x, local_y}
    end)
  end

  @doc """
  Transforms global coordinates to component-local coordinates.
  """
  @spec to_local(bounds(), integer(), integer()) :: {integer(), integer()}
  def to_local(bounds, x, y) do
    {x - bounds.x, y - bounds.y}
  end

  @doc """
  Transforms component-local coordinates to global coordinates.
  """
  @spec to_global(bounds(), integer(), integer()) :: {integer(), integer()}
  def to_global(bounds, local_x, local_y) do
    {local_x + bounds.x, local_y + bounds.y}
  end

  @doc """
  Checks if a point is within bounds.
  """
  @spec point_in_bounds?(integer(), integer(), bounds()) :: boolean()
  def point_in_bounds?(x, y, bounds) do
    x >= bounds.x and
      x < bounds.x + bounds.width and
      y >= bounds.y and
      y < bounds.y + bounds.height
  end

  @doc """
  Checks if two bounds overlap.
  """
  @spec bounds_overlap?(bounds(), bounds()) :: boolean()
  def bounds_overlap?(a, b) do
    not (a.x + a.width <= b.x or
           b.x + b.width <= a.x or
           a.y + a.height <= b.y or
           b.y + b.height <= a.y)
  end

  @doc """
  Clips coordinates to be within bounds.
  """
  @spec clip_to_bounds(integer(), integer(), bounds()) :: {integer(), integer()}
  def clip_to_bounds(x, y, bounds) do
    clipped_x = x |> max(bounds.x) |> min(bounds.x + bounds.width - 1)
    clipped_y = y |> max(bounds.y) |> min(bounds.y + bounds.height - 1)
    {clipped_x, clipped_y}
  end
end
