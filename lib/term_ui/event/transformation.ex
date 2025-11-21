defmodule TermUI.Event.Transformation do
  @moduledoc """
  Event transformation utilities.

  Transforms events as they route to components, including:
  - Coordinate transformation (screen to component-local)
  - Event metadata enrichment
  - Event filtering

  ## Usage

      # Transform mouse coordinates to component-local
      local_event = Transformation.to_local(event, component_bounds)

      # Add metadata to event
      enriched = Transformation.with_metadata(event, %{target: :button})
  """

  alias TermUI.Event.Mouse

  @doc """
  Transforms screen coordinates to component-local coordinates.

  For mouse events, subtracts the component's position from the
  event coordinates so the component receives coordinates relative
  to its own origin (0, 0).

  ## Parameters

  - `event` - Mouse event with screen coordinates
  - `bounds` - Component bounds with x, y position

  ## Returns

  Event with transformed coordinates, or unchanged event if not a mouse event.

  ## Example

      event = %Mouse{x: 15, y: 10, ...}
      bounds = %{x: 10, y: 5, width: 20, height: 10}
      local = to_local(event, bounds)
      # local.x = 5, local.y = 5
  """
  @spec to_local(Mouse.t() | term(), map()) :: Mouse.t() | term()
  def to_local(%Mouse{x: x, y: y} = event, %{x: bx, y: by}) do
    %{event | x: x - bx, y: y - by}
  end

  def to_local(event, _bounds), do: event

  @doc """
  Transforms component-local coordinates back to screen coordinates.

  Inverse of `to_local/2`.

  ## Parameters

  - `event` - Mouse event with local coordinates
  - `bounds` - Component bounds with x, y position

  ## Returns

  Event with screen coordinates.
  """
  @spec to_screen(Mouse.t() | term(), map()) :: Mouse.t() | term()
  def to_screen(%Mouse{x: x, y: y} = event, %{x: bx, y: by}) do
    %{event | x: x + bx, y: y + by}
  end

  def to_screen(event, _bounds), do: event

  @doc """
  Adds metadata to an event.

  Creates or updates a `:metadata` field on the event struct.

  ## Parameters

  - `event` - The event to enrich
  - `metadata` - Map of metadata to add

  ## Returns

  Event with metadata merged.

  ## Example

      event = with_metadata(key_event, %{target: :input, phase: :bubble})
  """
  @spec with_metadata(map(), map()) :: map()
  def with_metadata(event, metadata) when is_map(event) and is_map(metadata) do
    existing = Map.get(event, :metadata, %{})
    Map.put(event, :metadata, Map.merge(existing, metadata))
  end

  @doc """
  Gets metadata from an event.

  ## Parameters

  - `event` - The event
  - `key` - Metadata key to get
  - `default` - Default value if key not found

  ## Returns

  The metadata value or default.
  """
  @spec get_metadata(map(), atom(), term()) :: term()
  def get_metadata(event, key, default \\ nil) when is_map(event) do
    event
    |> Map.get(:metadata, %{})
    |> Map.get(key, default)
  end

  @doc """
  Checks if an event matches a filter.

  ## Filter Options

  - `:type` - Event type (:key, :mouse, :focus, :custom)
  - `:key` - Specific key (for key events)
  - `:action` - Specific action (for mouse/focus events)
  - `:button` - Specific button (for mouse events)
  - `:modifiers` - Required modifiers (any or all)
  - `:modifiers_all` - All modifiers must be present
  - `:modifiers_any` - Any modifier must be present

  ## Example

      # Match Ctrl+C
      matches?(event, type: :key, key: :c, modifiers_all: [:ctrl])

      # Match any click
      matches?(event, type: :mouse, action: :click)
  """
  @spec matches?(term(), keyword()) :: boolean()
  def matches?(event, filters) when is_list(filters) do
    Enum.all?(filters, fn {key, value} ->
      matches_filter?(event, key, value)
    end)
  end

  @doc """
  Filters a list of events based on criteria.

  ## Parameters

  - `events` - List of events
  - `filters` - Filter criteria (see `matches?/2`)

  ## Returns

  List of events matching all filters.
  """
  @spec filter(list(), keyword()) :: list()
  def filter(events, filters) when is_list(events) do
    Enum.filter(events, &matches?(&1, filters))
  end

  @doc """
  Creates a standard event envelope with routing metadata.

  ## Parameters

  - `event` - The raw event
  - `opts` - Options:
    - `:source` - Source of the event
    - `:target` - Target component id
    - `:timestamp` - Override timestamp

  ## Returns

  Event with envelope metadata.
  """
  @spec envelope(term(), keyword()) :: map()
  def envelope(event, opts \\ []) when is_map(event) do
    metadata = %{
      source: Keyword.get(opts, :source),
      target: Keyword.get(opts, :target),
      routed_at: Keyword.get(opts, :timestamp, System.monotonic_time(:millisecond))
    }

    with_metadata(event, metadata)
  end

  # Private Functions

  defp matches_filter?(%{__struct__: struct}, :type, type) do
    case type do
      :key -> struct == TermUI.Event.Key
      :mouse -> struct == TermUI.Event.Mouse
      :focus -> struct == TermUI.Event.Focus
      :custom -> struct == TermUI.Event.Custom
      _ -> false
    end
  end

  defp matches_filter?(%{key: event_key}, :key, key) do
    event_key == key
  end

  defp matches_filter?(%{action: event_action}, :action, action) do
    event_action == action
  end

  defp matches_filter?(%{button: event_button}, :button, button) do
    event_button == button
  end

  defp matches_filter?(%{modifiers: event_mods}, :modifiers_all, required) do
    Enum.all?(required, &(&1 in event_mods))
  end

  defp matches_filter?(%{modifiers: event_mods}, :modifiers_any, required) do
    Enum.any?(required, &(&1 in event_mods))
  end

  defp matches_filter?(%{modifiers: event_mods}, :modifiers, required) do
    # Default to all modifiers required
    Enum.all?(required, &(&1 in event_mods))
  end

  defp matches_filter?(_event, _key, _value) do
    # Unknown filter or field not present
    false
  end
end
