defmodule TermUI.EventRouterTest do
  use ExUnit.Case

  alias TermUI.Event
  alias TermUI.EventRouter
  alias TermUI.SpatialIndex
  alias TermUI.ComponentRegistry

  # Test component that tracks received events
  defmodule TestComponent do
    use GenServer

    def start_link(opts) do
      test_pid = Keyword.fetch!(opts, :test_pid)
      GenServer.start_link(__MODULE__, %{test_pid: test_pid})
    end

    @impl true
    def init(state), do: {:ok, state}

    @impl true
    def handle_call({:event, event}, _from, state) do
      send(state.test_pid, {:event_received, event})
      {:reply, :handled, state}
    end
  end

  # Component that doesn't handle events
  defmodule UnhandlingComponent do
    use GenServer

    def start_link(_opts) do
      GenServer.start_link(__MODULE__, %{})
    end

    @impl true
    def init(state), do: {:ok, state}

    @impl true
    def handle_call({:event, _event}, _from, state) do
      {:reply, :unhandled, state}
    end
  end

  setup do
    start_supervised!(ComponentRegistry)
    start_supervised!(SpatialIndex)
    start_supervised!(EventRouter)
    :ok
  end

  describe "focus management" do
    test "set_focus changes focused component" do
      {:ok, pid} = TestComponent.start_link(test_pid: self())
      :ok = ComponentRegistry.register(:input, pid, TestComponent)

      :ok = EventRouter.set_focus(:input)
      assert {:ok, :input} = EventRouter.get_focus()
    end

    test "get_focus returns nil when no focus" do
      assert {:ok, nil} = EventRouter.get_focus()
    end

    test "clear_focus clears the focus" do
      {:ok, pid} = TestComponent.start_link(test_pid: self())
      :ok = ComponentRegistry.register(:input, pid, TestComponent)

      :ok = EventRouter.set_focus(:input)
      :ok = EventRouter.clear_focus()

      assert {:ok, nil} = EventRouter.get_focus()
    end

    test "set_focus sends focus events to old and new" do
      {:ok, pid1} = TestComponent.start_link(test_pid: self())
      {:ok, pid2} = TestComponent.start_link(test_pid: self())

      :ok = ComponentRegistry.register(:input1, pid1, TestComponent)
      :ok = ComponentRegistry.register(:input2, pid2, TestComponent)

      :ok = EventRouter.set_focus(:input1)
      assert_receive {:event_received, %Event.Focus{action: :gained}}

      :ok = EventRouter.set_focus(:input2)
      assert_receive {:event_received, %Event.Focus{action: :lost}}
      assert_receive {:event_received, %Event.Focus{action: :gained}}
    end

    test "set_focus to same component doesn't send events" do
      {:ok, pid} = TestComponent.start_link(test_pid: self())
      :ok = ComponentRegistry.register(:input, pid, TestComponent)

      :ok = EventRouter.set_focus(:input)
      assert_receive {:event_received, %Event.Focus{action: :gained}}

      :ok = EventRouter.set_focus(:input)
      refute_receive {:event_received, _}
    end
  end

  describe "keyboard routing" do
    test "routes keyboard event to focused component" do
      {:ok, pid} = TestComponent.start_link(test_pid: self())
      :ok = ComponentRegistry.register(:input, pid, TestComponent)
      :ok = EventRouter.set_focus(:input)

      # Clear focus event
      assert_receive {:event_received, %Event.Focus{}}

      event = Event.key(:enter)
      assert :handled = EventRouter.route(event)

      assert_receive {:event_received, ^event}
    end

    test "returns unhandled when no focus" do
      event = Event.key(:enter)
      assert :unhandled = EventRouter.route(event)
    end

    test "returns unhandled when focused component not found" do
      :ok = EventRouter.set_focus(:nonexistent)

      event = Event.key(:enter)
      assert :unhandled = EventRouter.route(event)
    end

    test "returns unhandled when component doesn't handle event" do
      {:ok, pid} = UnhandlingComponent.start_link([])
      :ok = ComponentRegistry.register(:input, pid, UnhandlingComponent)
      :ok = EventRouter.set_focus(:input)

      event = Event.key(:enter)
      assert :unhandled = EventRouter.route(event)
    end
  end

  describe "mouse routing" do
    test "routes mouse event to component at position" do
      {:ok, pid} = TestComponent.start_link(test_pid: self())
      :ok = ComponentRegistry.register(:button, pid, TestComponent)

      bounds = %{x: 10, y: 5, width: 20, height: 3}
      :ok = SpatialIndex.update(:button, pid, bounds)

      event = Event.mouse(:click, :left, 15, 6)
      assert :handled = EventRouter.route(event)

      assert_receive {:event_received, ^event}
    end

    test "returns unhandled when no component at position" do
      event = Event.mouse(:click, :left, 100, 100)
      assert :unhandled = EventRouter.route(event)
    end

    test "routes to highest z-index component" do
      {:ok, pid1} = TestComponent.start_link(test_pid: self())
      {:ok, pid2} = TestComponent.start_link(test_pid: self())

      :ok = ComponentRegistry.register(:background, pid1, TestComponent)
      :ok = ComponentRegistry.register(:modal, pid2, TestComponent)

      bounds = %{x: 0, y: 0, width: 10, height: 10}
      :ok = SpatialIndex.update(:background, pid1, bounds, z_index: 0)
      :ok = SpatialIndex.update(:modal, pid2, bounds, z_index: 100)

      event = Event.mouse(:click, :left, 5, 5)
      assert :handled = EventRouter.route(event)

      # Modal should receive the event
      assert_receive {:event_received, ^event}
    end
  end

  describe "broadcast/1" do
    test "sends event to all registered components" do
      {:ok, pid1} = TestComponent.start_link(test_pid: self())
      {:ok, pid2} = TestComponent.start_link(test_pid: self())

      :ok = ComponentRegistry.register(:comp1, pid1, TestComponent)
      :ok = ComponentRegistry.register(:comp2, pid2, TestComponent)

      event = {:resize, 80, 24}
      assert {:ok, 2} = EventRouter.broadcast(event)

      assert_receive {:event_received, ^event}
      assert_receive {:event_received, ^event}
    end

    test "returns count of components broadcast to" do
      {:ok, pid} = TestComponent.start_link(test_pid: self())
      :ok = ComponentRegistry.register(:single, pid, TestComponent)

      assert {:ok, 1} = EventRouter.broadcast(:test)
    end

    test "returns zero when no components registered" do
      assert {:ok, 0} = EventRouter.broadcast(:test)
    end
  end

  describe "route_to/2" do
    test "routes directly to specific component" do
      {:ok, pid} = TestComponent.start_link(test_pid: self())
      :ok = ComponentRegistry.register(:target, pid, TestComponent)

      event = Event.key(:enter)
      assert :handled = EventRouter.route_to(:target, event)

      assert_receive {:event_received, ^event}
    end

    test "returns error when component not found" do
      event = Event.key(:enter)
      assert {:error, :not_found} = EventRouter.route_to(:nonexistent, event)
    end
  end

  describe "fallback handler" do
    test "calls fallback handler for unrouted events" do
      test_pid = self()

      handler = fn event ->
        send(test_pid, {:fallback, event})
        :ok
      end

      :ok = EventRouter.set_fallback_handler(handler)

      event = Event.key(:enter)
      assert :unhandled = EventRouter.route(event)

      assert_receive {:fallback, ^event}
    end

    test "clear_fallback_handler removes handler" do
      test_pid = self()

      handler = fn event ->
        send(test_pid, {:fallback, event})
        :ok
      end

      :ok = EventRouter.set_fallback_handler(handler)
      :ok = EventRouter.clear_fallback_handler()

      event = Event.key(:enter)
      EventRouter.route(event)

      refute_receive {:fallback, _}
    end
  end

  describe "custom event routing" do
    test "routes custom events to focused component" do
      {:ok, pid} = TestComponent.start_link(test_pid: self())
      :ok = ComponentRegistry.register(:form, pid, TestComponent)
      :ok = EventRouter.set_focus(:form)

      # Clear focus event
      assert_receive {:event_received, %Event.Focus{}}

      event = Event.custom(:submit, %{data: "test"})
      assert :handled = EventRouter.route(event)

      assert_receive {:event_received, ^event}
    end
  end
end
