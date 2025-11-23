defmodule TermUI.Event.Propagation do
  @moduledoc """
  Event propagation utilities for the component tree.

  Handles bubbling and capturing phases of event propagation.
  Events bubble up from target to root until handled.

  ## Propagation Phases

  1. **Capture** - Event travels from root to target (optional)
  2. **Target** - Event delivered to target component
  3. **Bubble** - Event travels from target to root (default)

  ## Usage

      # Propagate event up through parent chain
      Propagation.bubble(event, component_id)

      # Build parent chain for propagation
      parents = Propagation.get_parent_chain(component_id)
  """

  alias TermUI.ComponentRegistry

  @type phase :: :capture | :target | :bubble
  @type propagation_result :: :handled | :unhandled | :stopped

  @doc """
  Bubbles an event up through the parent chain.

  Starts from the given component and propagates up to parents
  until a component handles the event or the root is reached.

  ## Parameters

  - `event` - The event to propagate
  - `start_id` - Component to start bubbling from
  - `opts` - Options:
    - `:skip_start` - Skip the starting component (default: false)

  ## Returns

  - `:handled` - A component handled the event
  - `:unhandled` - No component handled the event
  """
  @spec bubble(term(), term(), keyword()) :: propagation_result()
  def bubble(event, start_id, opts \\ []) do
    skip_start = Keyword.get(opts, :skip_start, false)

    parent_chain = get_parent_chain(start_id)

    chain =
      if skip_start do
        parent_chain
      else
        [start_id | parent_chain]
      end

    propagate_through(event, chain)
  end

  @doc """
  Captures an event down through the parent chain to target.

  Starts from the root and propagates down to the target component.
  Each component can intercept before reaching target.

  ## Parameters

  - `event` - The event to propagate
  - `target_id` - Target component

  ## Returns

  - `:handled` - A component handled the event
  - `:unhandled` - No component handled the event
  """
  @spec capture(term(), term()) :: propagation_result()
  def capture(event, target_id) do
    parent_chain = get_parent_chain(target_id)
    chain = Enum.reverse(parent_chain) ++ [target_id]
    propagate_through(event, chain)
  end

  @doc """
  Gets the parent chain for a component.

  Returns list of parent component ids from immediate parent to root.

  ## Example

      # If component tree is: root -> container -> button
      get_parent_chain(:button)
      # => [:container, :root]
  """
  @spec get_parent_chain(term()) :: [term()]
  def get_parent_chain(component_id) do
    case ComponentRegistry.get_parent(component_id) do
      {:ok, nil} ->
        []

      {:ok, parent_id} ->
        [parent_id | get_parent_chain(parent_id)]

      {:error, :not_found} ->
        []
    end
  end

  @doc """
  Sets the parent for a component.

  Used to build the component tree for propagation.

  ## Parameters

  - `component_id` - Child component
  - `parent_id` - Parent component (or nil for root)
  """
  @spec set_parent(term(), term() | nil) :: :ok
  def set_parent(component_id, parent_id) do
    ComponentRegistry.set_parent(component_id, parent_id)
  end

  @doc """
  Gets children of a component.

  ## Returns

  List of child component ids.
  """
  @spec get_children(term()) :: [term()]
  def get_children(component_id) do
    ComponentRegistry.get_children(component_id)
  end

  @doc """
  Adds metadata about propagation phase to event.

  ## Parameters

  - `event` - The event
  - `phase` - Current propagation phase

  ## Returns

  Event with `:propagation_phase` metadata.
  """
  @spec with_phase(term(), phase()) :: map()
  def with_phase(event, phase) when is_map(event) do
    Map.put(event, :propagation_phase, phase)
  end

  @doc """
  Checks if an event should stop propagating.

  Events can be marked to stop propagation by returning
  `:stop` from handle_event.
  """
  @spec stopped?(term()) :: boolean()
  def stopped?(result) do
    result == :stopped || result == :stop
  end

  # Private Functions

  defp propagate_through(_event, []) do
    :unhandled
  end

  defp propagate_through(event, [component_id | rest]) do
    case send_to_component(component_id, event) do
      :handled ->
        :handled

      :stopped ->
        :stopped

      :unhandled ->
        propagate_through(event, rest)

      {:error, _} ->
        propagate_through(event, rest)
    end
  end

  defp send_to_component(component_id, event) do
    case ComponentRegistry.lookup(component_id) do
      {:ok, pid} -> call_component(pid, event)
      {:error, :not_found} -> {:error, :not_found}
    end
  end

  defp call_component(pid, event) do
    pid
    |> GenServer.call({:event, event}, 5000)
    |> normalize_event_result()
  catch
    :exit, _ -> {:error, :component_unavailable}
  end

  defp normalize_event_result(:handled), do: :handled
  defp normalize_event_result(:stop), do: :stopped
  defp normalize_event_result(:stopped), do: :stopped
  defp normalize_event_result(:unhandled), do: :unhandled
  defp normalize_event_result({:ok, _}), do: :handled
  defp normalize_event_result(_), do: :unhandled
end
