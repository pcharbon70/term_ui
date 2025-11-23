defmodule TermUI.EventRouter do
  @moduledoc """
  Central event routing for TermUI components.

  The EventRouter manages event distribution to components based on:
  - Focus state for keyboard events
  - Spatial index for mouse events
  - Broadcast for system events (resize)

  ## Usage

      # Route a keyboard event to focused component
      EventRouter.route(%Event.Key{key: :enter})

      # Route a mouse event to component at position
      EventRouter.route(%Event.Mouse{action: :click, x: 10, y: 5})

      # Set focused component
      EventRouter.set_focus(:my_input)

      # Broadcast to all components
      EventRouter.broadcast({:resize, 80, 24})

  ## Event Flow

  1. Event received by router
  2. Router determines target based on event type
  3. Event delivered to target component
  4. If unhandled, event bubbles to parent (if propagation enabled)
  """

  use GenServer

  alias TermUI.Event
  alias TermUI.SpatialIndex
  alias TermUI.ComponentRegistry

  @type route_result :: :handled | :unhandled | {:error, term()}

  # Client API

  @doc """
  Starts the event router.
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Routes an event to the appropriate component.

  Keyboard and focus events go to the focused component.
  Mouse events go to the component at the mouse position.

  ## Returns

  - `:handled` - Event was processed by a component
  - `:unhandled` - No component handled the event
  - `{:error, reason}` - Routing failed
  """
  @spec route(Event.Key.t() | Event.Mouse.t() | Event.Focus.t() | Event.Custom.t()) ::
          route_result()
  def route(event) do
    GenServer.call(__MODULE__, {:route, event})
  end

  @doc """
  Sets the currently focused component.

  Sends focus lost event to previous focus and focus gained to new focus.

  ## Parameters

  - `component_id` - The component to focus, or nil to clear focus
  """
  @spec set_focus(term() | nil) :: :ok
  def set_focus(component_id) do
    GenServer.call(__MODULE__, {:set_focus, component_id})
  end

  @doc """
  Gets the currently focused component.

  ## Returns

  - `{:ok, component_id}` - The focused component
  - `{:ok, nil}` - No component focused
  """
  @spec get_focus() :: {:ok, term() | nil}
  def get_focus do
    GenServer.call(__MODULE__, :get_focus)
  end

  @doc """
  Clears the current focus.
  """
  @spec clear_focus() :: :ok
  def clear_focus do
    set_focus(nil)
  end

  @doc """
  Broadcasts an event to all registered components.

  Useful for system-wide events like resize.

  ## Returns

  - `{:ok, count}` - Number of components that received the event
  """
  @spec broadcast(term()) :: {:ok, non_neg_integer()}
  def broadcast(event) do
    GenServer.call(__MODULE__, {:broadcast, event})
  end

  @doc """
  Routes an event directly to a specific component by id.

  ## Returns

  - `:handled` - Component handled the event
  - `:unhandled` - Component did not handle the event
  - `{:error, :not_found}` - Component not found
  """
  @spec route_to(term(), term()) :: route_result()
  def route_to(component_id, event) do
    GenServer.call(__MODULE__, {:route_to, component_id, event})
  end

  @doc """
  Registers a global event handler for events that no component handles.

  The handler receives unhandled events and can process them as needed.

  ## Parameters

  - `handler` - Function that receives events: `fn event -> :ok end`
  """
  @spec set_fallback_handler((term() -> :ok)) :: :ok
  def set_fallback_handler(handler) when is_function(handler, 1) do
    GenServer.call(__MODULE__, {:set_fallback_handler, handler})
  end

  @doc """
  Clears the fallback handler.
  """
  @spec clear_fallback_handler() :: :ok
  def clear_fallback_handler do
    GenServer.call(__MODULE__, :clear_fallback_handler)
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    state = %{
      focus: nil,
      fallback_handler: nil
    }

    {:ok, state}
  end

  @impl true
  def handle_call({:route, event}, _from, state) do
    result = do_route(event, state)
    {:reply, result, state}
  end

  @impl true
  def handle_call({:set_focus, component_id}, _from, state) do
    old_focus = state.focus

    # Send focus lost to old component
    if old_focus && old_focus != component_id do
      send_focus_event(old_focus, :lost)
    end

    # Send focus gained to new component
    if component_id && component_id != old_focus do
      send_focus_event(component_id, :gained)
    end

    {:reply, :ok, %{state | focus: component_id}}
  end

  @impl true
  def handle_call(:get_focus, _from, state) do
    {:reply, {:ok, state.focus}, state}
  end

  @impl true
  def handle_call({:broadcast, event}, _from, state) do
    components = ComponentRegistry.list_all()
    count = length(components)

    Enum.each(components, fn %{pid: pid} ->
      send_event(pid, event)
    end)

    {:reply, {:ok, count}, state}
  end

  @impl true
  def handle_call({:route_to, component_id, event}, _from, state) do
    result =
      case ComponentRegistry.lookup(component_id) do
        {:ok, pid} ->
          send_event(pid, event)

        {:error, :not_found} ->
          {:error, :not_found}
      end

    {:reply, result, state}
  end

  @impl true
  def handle_call({:set_fallback_handler, handler}, _from, state) do
    {:reply, :ok, %{state | fallback_handler: handler}}
  end

  @impl true
  def handle_call(:clear_fallback_handler, _from, state) do
    {:reply, :ok, %{state | fallback_handler: nil}}
  end

  # Private Functions

  defp do_route(%Event.Key{} = event, state) do
    route_to_focus(event, state)
  end

  defp do_route(%Event.Focus{} = event, state) do
    route_to_focus(event, state)
  end

  defp do_route(%Event.Mouse{} = event, state) do
    route_to_position(event, state)
  end

  defp do_route(%Event.Custom{} = event, state) do
    # Custom events go to focused component by default
    route_to_focus(event, state)
  end

  defp route_to_focus(event, state) do
    case state.focus do
      nil ->
        handle_unrouted(event, state)

      component_id ->
        case ComponentRegistry.lookup(component_id) do
          {:ok, pid} ->
            send_event(pid, event)

          {:error, :not_found} ->
            handle_unrouted(event, state)
        end
    end
  end

  defp route_to_position(%Event.Mouse{x: x, y: y} = event, state) do
    case SpatialIndex.find_at(x, y) do
      {:ok, {_id, pid}} ->
        send_event(pid, event)

      {:error, :not_found} ->
        handle_unrouted(event, state)
    end
  end

  defp handle_unrouted(event, %{fallback_handler: handler}) when is_function(handler) do
    handler.(event)
    :unhandled
  end

  defp handle_unrouted(_event, _state) do
    :unhandled
  end

  defp send_event(pid, event) do
    try do
      case GenServer.call(pid, {:event, event}, 5000) do
        :handled -> :handled
        :unhandled -> :unhandled
        {:ok, _} -> :handled
        _ -> :unhandled
      end
    catch
      :exit, _ -> {:error, :component_unavailable}
    end
  end

  defp send_focus_event(component_id, action) do
    case ComponentRegistry.lookup(component_id) do
      {:ok, pid} ->
        event = Event.focus(action)
        send_event(pid, event)

      {:error, :not_found} ->
        :ok
    end
  end
end
