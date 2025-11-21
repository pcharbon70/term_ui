defmodule TermUI.FocusManager do
  @moduledoc """
  Central focus management for TermUI components.

  The FocusManager tracks which component receives keyboard input,
  provides focus traversal (Tab/Shift+Tab), and manages focus
  trapping for modal contexts.

  ## Usage

      # Get current focus
      {:ok, component_id} = FocusManager.get_focused()

      # Set focus to component
      :ok = FocusManager.set_focused(:my_input)

      # Tab navigation
      :ok = FocusManager.focus_next()
      :ok = FocusManager.focus_prev()

      # Focus trapping for modals
      :ok = FocusManager.trap_focus(:modal_group)
      :ok = FocusManager.release_focus()

  ## Focus Stack

  The FocusManager maintains a focus stack for modal contexts.
  When a modal opens, it pushes the current focus and sets new focus.
  When closed, focus pops back to the previous component.
  """

  use GenServer

  alias TermUI.Event
  alias TermUI.EventRouter
  alias TermUI.ComponentRegistry
  alias TermUI.SpatialIndex

  # Client API

  @doc """
  Starts the focus manager.
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Gets the currently focused component.

  ## Returns

  - `{:ok, component_id}` - The focused component
  - `{:ok, nil}` - No component focused
  """
  @spec get_focused() :: {:ok, term() | nil}
  def get_focused do
    GenServer.call(__MODULE__, :get_focused)
  end

  @doc """
  Sets focus to a specific component.

  Sends blur event to the previously focused component and
  focus event to the new component.

  ## Parameters

  - `component_id` - Component to focus, or nil to clear focus

  ## Returns

  - `:ok` - Focus changed successfully
  - `{:error, :not_focusable}` - Component cannot receive focus
  - `{:error, :not_found}` - Component not registered
  """
  @spec set_focused(term() | nil) :: :ok | {:error, atom()}
  def set_focused(component_id) do
    GenServer.call(__MODULE__, {:set_focused, component_id})
  end

  @doc """
  Clears the current focus.
  """
  @spec clear_focus() :: :ok
  def clear_focus do
    set_focused(nil)
    :ok
  end

  @doc """
  Moves focus to the next focusable component in tab order.

  ## Returns

  - `:ok` - Focus moved to next component
  - `{:error, :no_focusable}` - No focusable components available
  """
  @spec focus_next() :: :ok | {:error, atom()}
  def focus_next do
    GenServer.call(__MODULE__, :focus_next)
  end

  @doc """
  Moves focus to the previous focusable component in tab order.

  ## Returns

  - `:ok` - Focus moved to previous component
  - `{:error, :no_focusable}` - No focusable components available
  """
  @spec focus_prev() :: :ok | {:error, atom()}
  def focus_prev do
    GenServer.call(__MODULE__, :focus_prev)
  end

  @doc """
  Pushes current focus to stack and sets new focus.

  Useful for modal dialogs that need to restore focus when closed.

  ## Parameters

  - `component_id` - Component to focus
  """
  @spec push_focus(term()) :: :ok | {:error, atom()}
  def push_focus(component_id) do
    GenServer.call(__MODULE__, {:push_focus, component_id})
  end

  @doc """
  Pops focus from stack, restoring previous focus.

  ## Returns

  - `:ok` - Focus restored
  - `{:error, :empty_stack}` - No focus to restore
  """
  @spec pop_focus() :: :ok | {:error, atom()}
  def pop_focus do
    GenServer.call(__MODULE__, :pop_focus)
  end

  @doc """
  Registers a focus group for focus trapping.

  ## Parameters

  - `group_id` - Unique identifier for the group
  - `component_ids` - List of component ids in the group
  """
  @spec register_group(term(), [term()]) :: :ok
  def register_group(group_id, component_ids) do
    GenServer.call(__MODULE__, {:register_group, group_id, component_ids})
  end

  @doc """
  Unregisters a focus group.
  """
  @spec unregister_group(term()) :: :ok
  def unregister_group(group_id) do
    GenServer.call(__MODULE__, {:unregister_group, group_id})
  end

  @doc """
  Traps focus within a group.

  Tab navigation will cycle within the group instead of
  escaping to other components.

  ## Parameters

  - `group_id` - Group to trap focus within
  """
  @spec trap_focus(term()) :: :ok | {:error, atom()}
  def trap_focus(group_id) do
    GenServer.call(__MODULE__, {:trap_focus, group_id})
  end

  @doc """
  Releases the current focus trap.
  """
  @spec release_focus() :: :ok
  def release_focus do
    GenServer.call(__MODULE__, :release_focus)
  end

  @doc """
  Checks if a component is currently focused.
  """
  @spec is_focused?(term()) :: boolean()
  def is_focused?(component_id) do
    case get_focused() do
      {:ok, ^component_id} -> true
      _ -> false
    end
  end

  @doc """
  Requests auto-focus for a component on mount.

  Should be called from component mount if auto_focus prop is true.
  """
  @spec request_auto_focus(term()) :: :ok
  def request_auto_focus(component_id) do
    GenServer.cast(__MODULE__, {:request_auto_focus, component_id})
  end

  @doc """
  Gets all registered focus groups.
  """
  @spec get_groups() :: %{term() => [term()]}
  def get_groups do
    GenServer.call(__MODULE__, :get_groups)
  end

  @doc """
  Gets the current focus stack.
  """
  @spec get_stack() :: [term()]
  def get_stack do
    GenServer.call(__MODULE__, :get_stack)
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    state = %{
      current: nil,
      stack: [],
      groups: %{},
      trapped_group: nil
    }

    {:ok, state}
  end

  @impl true
  def handle_call(:get_focused, _from, state) do
    {:reply, {:ok, state.current}, state}
  end

  @impl true
  def handle_call({:set_focused, component_id}, _from, state) do
    case do_set_focused(component_id, state) do
      {:ok, new_state} ->
        {:reply, :ok, new_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call(:focus_next, _from, state) do
    case do_focus_next(state) do
      {:ok, new_state} ->
        {:reply, :ok, new_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call(:focus_prev, _from, state) do
    case do_focus_prev(state) do
      {:ok, new_state} ->
        {:reply, :ok, new_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:push_focus, component_id}, _from, state) do
    # Push current to stack
    new_stack =
      if state.current do
        [state.current | state.stack]
      else
        state.stack
      end

    state = %{state | stack: new_stack}

    case do_set_focused(component_id, state) do
      {:ok, new_state} ->
        {:reply, :ok, new_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call(:pop_focus, _from, state) do
    case state.stack do
      [] ->
        {:reply, {:error, :empty_stack}, state}

      [prev | rest] ->
        state = %{state | stack: rest}

        case do_set_focused(prev, state) do
          {:ok, new_state} ->
            {:reply, :ok, new_state}

          {:error, _reason} ->
            # If we can't restore focus, just clear it
            {:reply, :ok, %{state | current: nil}}
        end
    end
  end

  @impl true
  def handle_call({:register_group, group_id, component_ids}, _from, state) do
    groups = Map.put(state.groups, group_id, component_ids)
    {:reply, :ok, %{state | groups: groups}}
  end

  @impl true
  def handle_call({:unregister_group, group_id}, _from, state) do
    groups = Map.delete(state.groups, group_id)

    # Release trap if we're removing the trapped group
    trapped =
      if state.trapped_group == group_id do
        nil
      else
        state.trapped_group
      end

    {:reply, :ok, %{state | groups: groups, trapped_group: trapped}}
  end

  @impl true
  def handle_call({:trap_focus, group_id}, _from, state) do
    if Map.has_key?(state.groups, group_id) do
      {:reply, :ok, %{state | trapped_group: group_id}}
    else
      {:reply, {:error, :group_not_found}, state}
    end
  end

  @impl true
  def handle_call(:release_focus, _from, state) do
    {:reply, :ok, %{state | trapped_group: nil}}
  end

  @impl true
  def handle_call(:get_groups, _from, state) do
    {:reply, state.groups, state}
  end

  @impl true
  def handle_call(:get_stack, _from, state) do
    {:reply, state.stack, state}
  end

  @impl true
  def handle_cast({:request_auto_focus, component_id}, state) do
    # Only auto-focus if nothing is currently focused
    if state.current == nil do
      case do_set_focused(component_id, state) do
        {:ok, new_state} -> {:noreply, new_state}
        {:error, _} -> {:noreply, state}
      end
    else
      {:noreply, state}
    end
  end

  # Private Functions

  defp do_set_focused(nil, state) do
    old_focus = state.current

    # Send blur to old
    if old_focus do
      send_focus_event(old_focus, :lost)
    end

    # Update EventRouter
    EventRouter.set_focus(nil)

    {:ok, %{state | current: nil}}
  end

  defp do_set_focused(component_id, state) do
    # Check if component exists and is focusable
    case ComponentRegistry.lookup(component_id) do
      {:ok, _pid} ->
        # Check focusable property
        if is_focusable?(component_id) do
          old_focus = state.current

          # Only update if focus is actually changing
          if component_id != old_focus do
            # Update EventRouter - this sends focus events
            EventRouter.set_focus(component_id)
          end

          {:ok, %{state | current: component_id}}
        else
          {:error, :not_focusable}
        end

      {:error, :not_found} ->
        {:error, :not_found}
    end
  end

  defp do_focus_next(state) do
    focusable = get_focusable_list(state)

    case focusable do
      [] ->
        {:error, :no_focusable}

      list ->
        next = find_next(list, state.current)
        do_set_focused(next, state)
    end
  end

  defp do_focus_prev(state) do
    focusable = get_focusable_list(state)

    case focusable do
      [] ->
        {:error, :no_focusable}

      list ->
        prev = find_prev(list, state.current)
        do_set_focused(prev, state)
    end
  end

  defp get_focusable_list(state) do
    # If trapped, only include group components
    components =
      if state.trapped_group do
        Map.get(state.groups, state.trapped_group, [])
        |> Enum.filter(&component_exists?/1)
      else
        ComponentRegistry.list_all()
        |> Enum.map(& &1.id)
      end

    # Filter to focusable and sort by tab order
    components
    |> Enum.filter(&is_focusable?/1)
    |> sort_by_tab_order()
  end

  defp sort_by_tab_order(component_ids) do
    component_ids
    |> Enum.map(fn id ->
      {tab_index, position} = get_tab_info(id)
      {id, tab_index, position}
    end)
    |> Enum.sort_by(fn {_id, tab_index, {x, y}} ->
      # Sort by tab_index first (nil = max), then by position (y, x)
      {tab_index || 999_999, y, x}
    end)
    |> Enum.map(fn {id, _, _} -> id end)
  end

  defp get_tab_info(component_id) do
    # Get tab_index from component props if available
    # Get position from spatial index
    tab_index = get_component_tab_index(component_id)

    position =
      case SpatialIndex.get_bounds(component_id) do
        {:ok, %{x: x, y: y}} -> {x, y}
        _ -> {0, 0}
      end

    {tab_index, position}
  end

  defp get_component_tab_index(_component_id) do
    # TODO: Get tab_index from component props
    # For now, return nil to use position-based ordering
    nil
  end

  defp find_next([], _current), do: nil

  defp find_next(list, nil) do
    # No current focus, return first
    List.first(list)
  end

  defp find_next(list, current) do
    case Enum.find_index(list, &(&1 == current)) do
      nil ->
        List.first(list)

      idx ->
        next_idx = rem(idx + 1, length(list))
        Enum.at(list, next_idx)
    end
  end

  defp find_prev([], _current), do: nil

  defp find_prev(list, nil) do
    # No current focus, return last
    List.last(list)
  end

  defp find_prev(list, current) do
    case Enum.find_index(list, &(&1 == current)) do
      nil ->
        List.last(list)

      0 ->
        List.last(list)

      idx ->
        Enum.at(list, idx - 1)
    end
  end

  defp is_focusable?(component_id) do
    # Check if component is focusable
    # Components are focusable by default unless explicitly disabled
    # TODO: Check component props for focusable and disabled
    component_exists?(component_id)
  end

  defp component_exists?(component_id) do
    case ComponentRegistry.lookup(component_id) do
      {:ok, _} -> true
      _ -> false
    end
  end

  defp send_focus_event(component_id, action) do
    case ComponentRegistry.lookup(component_id) do
      {:ok, pid} ->
        event = Event.focus(action)

        try do
          GenServer.call(pid, {:event, event}, 5000)
        catch
          :exit, _ -> :ok
        end

      {:error, _} ->
        :ok
    end
  end
end
