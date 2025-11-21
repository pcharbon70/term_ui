defmodule TermUI.Event.PropagationTest do
  use ExUnit.Case

  alias TermUI.Event
  alias TermUI.Event.Propagation
  alias TermUI.ComponentRegistry

  # Test component that handles events
  defmodule HandlingComponent do
    use GenServer

    def start_link(opts) do
      test_pid = Keyword.fetch!(opts, :test_pid)
      id = Keyword.fetch!(opts, :id)
      GenServer.start_link(__MODULE__, %{test_pid: test_pid, id: id})
    end

    @impl true
    def init(state), do: {:ok, state}

    @impl true
    def handle_call({:event, event}, _from, state) do
      send(state.test_pid, {:handled_by, state.id, event})
      {:reply, :handled, state}
    end
  end

  # Test component that doesn't handle events (bubbles)
  defmodule BubblingComponent do
    use GenServer

    def start_link(opts) do
      test_pid = Keyword.fetch!(opts, :test_pid)
      id = Keyword.fetch!(opts, :id)
      GenServer.start_link(__MODULE__, %{test_pid: test_pid, id: id})
    end

    @impl true
    def init(state), do: {:ok, state}

    @impl true
    def handle_call({:event, event}, _from, state) do
      send(state.test_pid, {:bubbled_through, state.id, event})
      {:reply, :unhandled, state}
    end
  end

  # Component that stops propagation
  defmodule StoppingComponent do
    use GenServer

    def start_link(opts) do
      test_pid = Keyword.fetch!(opts, :test_pid)
      id = Keyword.fetch!(opts, :id)
      GenServer.start_link(__MODULE__, %{test_pid: test_pid, id: id})
    end

    @impl true
    def init(state), do: {:ok, state}

    @impl true
    def handle_call({:event, event}, _from, state) do
      send(state.test_pid, {:stopped_at, state.id, event})
      {:reply, :stopped, state}
    end
  end

  setup do
    start_supervised!(ComponentRegistry)
    :ok
  end

  describe "set_parent/2 and get_parent/1" do
    test "sets and retrieves parent" do
      :ok = Propagation.set_parent(:child, :parent)

      assert {:ok, :parent} = ComponentRegistry.get_parent(:child)
    end

    test "returns not_found for component without parent set" do
      assert {:error, :not_found} = ComponentRegistry.get_parent(:orphan)
    end

    test "nil parent indicates root component" do
      :ok = Propagation.set_parent(:root, nil)

      assert {:ok, nil} = ComponentRegistry.get_parent(:root)
    end
  end

  describe "get_parent_chain/1" do
    test "returns empty for root component" do
      :ok = Propagation.set_parent(:root, nil)

      assert [] = Propagation.get_parent_chain(:root)
    end

    test "returns single parent" do
      :ok = Propagation.set_parent(:child, :parent)
      :ok = Propagation.set_parent(:parent, nil)

      assert [:parent] = Propagation.get_parent_chain(:child)
    end

    test "returns full chain from child to root" do
      :ok = Propagation.set_parent(:button, :panel)
      :ok = Propagation.set_parent(:panel, :container)
      :ok = Propagation.set_parent(:container, :root)
      :ok = Propagation.set_parent(:root, nil)

      assert [:panel, :container, :root] = Propagation.get_parent_chain(:button)
    end
  end

  describe "get_children/1" do
    test "returns children of component" do
      :ok = Propagation.set_parent(:child1, :parent)
      :ok = Propagation.set_parent(:child2, :parent)
      :ok = Propagation.set_parent(:other, :other_parent)

      children = ComponentRegistry.get_children(:parent)

      assert length(children) == 2
      assert :child1 in children
      assert :child2 in children
    end

    test "returns empty list for no children" do
      assert [] = ComponentRegistry.get_children(:leaf)
    end
  end

  describe "bubble/3" do
    test "delivers event to target component" do
      {:ok, pid} = HandlingComponent.start_link(test_pid: self(), id: :button)
      :ok = ComponentRegistry.register(:button, pid, HandlingComponent)
      :ok = Propagation.set_parent(:button, nil)

      event = Event.key(:enter)
      assert :handled = Propagation.bubble(event, :button)

      assert_receive {:handled_by, :button, ^event}
    end

    test "bubbles event to parent when unhandled" do
      {:ok, child_pid} = BubblingComponent.start_link(test_pid: self(), id: :button)
      {:ok, parent_pid} = HandlingComponent.start_link(test_pid: self(), id: :panel)

      :ok = ComponentRegistry.register(:button, child_pid, BubblingComponent)
      :ok = ComponentRegistry.register(:panel, parent_pid, HandlingComponent)
      :ok = Propagation.set_parent(:button, :panel)
      :ok = Propagation.set_parent(:panel, nil)

      event = Event.key(:enter)
      assert :handled = Propagation.bubble(event, :button)

      assert_receive {:bubbled_through, :button, ^event}
      assert_receive {:handled_by, :panel, ^event}
    end

    test "continues bubbling until handled" do
      {:ok, pid1} = BubblingComponent.start_link(test_pid: self(), id: :button)
      {:ok, pid2} = BubblingComponent.start_link(test_pid: self(), id: :panel)
      {:ok, pid3} = HandlingComponent.start_link(test_pid: self(), id: :root)

      :ok = ComponentRegistry.register(:button, pid1, BubblingComponent)
      :ok = ComponentRegistry.register(:panel, pid2, BubblingComponent)
      :ok = ComponentRegistry.register(:root, pid3, HandlingComponent)

      :ok = Propagation.set_parent(:button, :panel)
      :ok = Propagation.set_parent(:panel, :root)
      :ok = Propagation.set_parent(:root, nil)

      event = Event.key(:enter)
      assert :handled = Propagation.bubble(event, :button)

      assert_receive {:bubbled_through, :button, ^event}
      assert_receive {:bubbled_through, :panel, ^event}
      assert_receive {:handled_by, :root, ^event}
    end

    test "returns unhandled when no component handles event" do
      {:ok, pid1} = BubblingComponent.start_link(test_pid: self(), id: :button)
      {:ok, pid2} = BubblingComponent.start_link(test_pid: self(), id: :panel)

      :ok = ComponentRegistry.register(:button, pid1, BubblingComponent)
      :ok = ComponentRegistry.register(:panel, pid2, BubblingComponent)

      :ok = Propagation.set_parent(:button, :panel)
      :ok = Propagation.set_parent(:panel, nil)

      event = Event.key(:enter)
      assert :unhandled = Propagation.bubble(event, :button)
    end

    test "stops propagation when component returns :stopped" do
      {:ok, pid1} = BubblingComponent.start_link(test_pid: self(), id: :button)
      {:ok, pid2} = StoppingComponent.start_link(test_pid: self(), id: :stopper)
      {:ok, pid3} = HandlingComponent.start_link(test_pid: self(), id: :root)

      :ok = ComponentRegistry.register(:button, pid1, BubblingComponent)
      :ok = ComponentRegistry.register(:stopper, pid2, StoppingComponent)
      :ok = ComponentRegistry.register(:root, pid3, HandlingComponent)

      :ok = Propagation.set_parent(:button, :stopper)
      :ok = Propagation.set_parent(:stopper, :root)
      :ok = Propagation.set_parent(:root, nil)

      event = Event.key(:enter)
      assert :stopped = Propagation.bubble(event, :button)

      assert_receive {:bubbled_through, :button, ^event}
      assert_receive {:stopped_at, :stopper, ^event}
      refute_receive {:handled_by, :root, _}
    end

    test "skip_start option skips the starting component" do
      {:ok, pid1} = HandlingComponent.start_link(test_pid: self(), id: :button)
      {:ok, pid2} = HandlingComponent.start_link(test_pid: self(), id: :panel)

      :ok = ComponentRegistry.register(:button, pid1, HandlingComponent)
      :ok = ComponentRegistry.register(:panel, pid2, HandlingComponent)

      :ok = Propagation.set_parent(:button, :panel)
      :ok = Propagation.set_parent(:panel, nil)

      event = Event.key(:enter)
      assert :handled = Propagation.bubble(event, :button, skip_start: true)

      refute_receive {:handled_by, :button, _}
      assert_receive {:handled_by, :panel, ^event}
    end
  end

  describe "capture/2" do
    test "propagates from root to target" do
      {:ok, pid1} = BubblingComponent.start_link(test_pid: self(), id: :button)
      {:ok, pid2} = BubblingComponent.start_link(test_pid: self(), id: :panel)
      {:ok, pid3} = BubblingComponent.start_link(test_pid: self(), id: :root)

      :ok = ComponentRegistry.register(:button, pid1, BubblingComponent)
      :ok = ComponentRegistry.register(:panel, pid2, BubblingComponent)
      :ok = ComponentRegistry.register(:root, pid3, BubblingComponent)

      :ok = Propagation.set_parent(:button, :panel)
      :ok = Propagation.set_parent(:panel, :root)
      :ok = Propagation.set_parent(:root, nil)

      event = Event.key(:enter)
      Propagation.capture(event, :button)

      # Should receive in order: root, panel, button
      assert_receive {:bubbled_through, :root, ^event}
      assert_receive {:bubbled_through, :panel, ^event}
      assert_receive {:bubbled_through, :button, ^event}
    end

    test "stops at first handler" do
      {:ok, pid1} = BubblingComponent.start_link(test_pid: self(), id: :button)
      {:ok, pid2} = HandlingComponent.start_link(test_pid: self(), id: :panel)
      {:ok, pid3} = BubblingComponent.start_link(test_pid: self(), id: :root)

      :ok = ComponentRegistry.register(:button, pid1, BubblingComponent)
      :ok = ComponentRegistry.register(:panel, pid2, HandlingComponent)
      :ok = ComponentRegistry.register(:root, pid3, BubblingComponent)

      :ok = Propagation.set_parent(:button, :panel)
      :ok = Propagation.set_parent(:panel, :root)
      :ok = Propagation.set_parent(:root, nil)

      event = Event.key(:enter)
      assert :handled = Propagation.capture(event, :button)

      assert_receive {:bubbled_through, :root, ^event}
      assert_receive {:handled_by, :panel, ^event}
      refute_receive {:bubbled_through, :button, _}
    end
  end

  describe "with_phase/2" do
    test "adds propagation phase to event" do
      event = Event.key(:enter)
      result = Propagation.with_phase(event, :bubble)

      assert result.propagation_phase == :bubble
    end

    test "works with all phases" do
      event = Event.key(:enter)

      assert Propagation.with_phase(event, :capture).propagation_phase == :capture
      assert Propagation.with_phase(event, :target).propagation_phase == :target
      assert Propagation.with_phase(event, :bubble).propagation_phase == :bubble
    end
  end

  describe "stopped?/1" do
    test "returns true for :stopped" do
      assert Propagation.stopped?(:stopped)
    end

    test "returns true for :stop" do
      assert Propagation.stopped?(:stop)
    end

    test "returns false for other values" do
      refute Propagation.stopped?(:handled)
      refute Propagation.stopped?(:unhandled)
      refute Propagation.stopped?(nil)
    end
  end
end
