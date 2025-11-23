defmodule TermUI.Component.IntrospectionTest do
  use ExUnit.Case, async: false

  alias TermUI.Component.Introspection
  alias TermUI.Component.StatePersistence
  alias TermUI.ComponentSupervisor
  alias TermUI.ComponentRegistry
  alias TermUI.ComponentServer

  # Simple test component
  defmodule TestComponent do
    use TermUI.StatefulComponent

    @impl true
    def init(props) do
      {:ok, %{value: props[:initial] || 0}}
    end

    @impl true
    def handle_event(_event, state) do
      {:ok, state}
    end

    @impl true
    def render(_state, _area) do
      text("")
    end
  end

  setup do
    start_supervised!(StatePersistence)
    start_supervised!(ComponentRegistry)
    start_supervised!(ComponentSupervisor)
    :ok
  end

  describe "get_component_tree/0" do
    test "returns empty list when no components" do
      assert [] = Introspection.get_component_tree()
    end

    test "returns single component as root" do
      {:ok, pid} = ComponentSupervisor.start_component(TestComponent, %{initial: 42}, id: :root)
      ComponentServer.mount(pid)

      tree = Introspection.get_component_tree()
      assert length(tree) == 1

      [node] = tree
      assert node.id == :root
      assert node.pid == pid
      assert node.module == TestComponent
      assert node.children == []
    end

    test "returns multiple root components" do
      {:ok, pid1} = ComponentSupervisor.start_component(TestComponent, %{}, id: :comp1)
      {:ok, pid2} = ComponentSupervisor.start_component(TestComponent, %{}, id: :comp2)
      ComponentServer.mount(pid1)
      ComponentServer.mount(pid2)

      tree = Introspection.get_component_tree()
      assert length(tree) == 2

      ids = Enum.map(tree, & &1.id)
      assert :comp1 in ids
      assert :comp2 in ids
    end

    test "builds hierarchy with parent-child relationships" do
      {:ok, parent_pid} = ComponentSupervisor.start_component(TestComponent, %{}, id: :parent)
      {:ok, child_pid} = ComponentSupervisor.start_component(TestComponent, %{}, id: :child)

      ComponentServer.mount(parent_pid)
      ComponentServer.mount(child_pid)

      # Set up parent-child relationship
      ComponentRegistry.set_parent(:child, :parent)

      tree = Introspection.get_component_tree()
      assert length(tree) == 1

      [parent] = tree
      assert parent.id == :parent
      assert length(parent.children) == 1

      [child] = parent.children
      assert child.id == :child
      assert child.pid == child_pid
    end
  end

  describe "get_component_info/1" do
    test "returns detailed component information" do
      {:ok, pid} =
        ComponentSupervisor.start_component(TestComponent, %{initial: 42}, id: :test_comp)

      ComponentServer.mount(pid)

      assert {:ok, info} = Introspection.get_component_info(:test_comp)
      assert info.id == :test_comp
      assert info.pid == pid
      assert info.module == TestComponent
      assert info.state == %{value: 42}
      assert info.props == %{initial: 42}
      assert info.lifecycle == :mounted
      assert info.restart_count == 0
      assert info.child_count == 0
      assert is_integer(info.uptime_ms)
    end

    test "returns :error for non-existent component" do
      assert {:error, :not_found} = Introspection.get_component_info(:nonexistent)
    end
  end

  describe "get_metrics/1" do
    test "returns component metrics" do
      {:ok, pid} = ComponentSupervisor.start_component(TestComponent, %{}, id: :test_comp)
      ComponentServer.mount(pid)

      assert {:ok, metrics} = Introspection.get_metrics(:test_comp)
      assert metrics.restart_count == 0
      assert metrics.child_count == 0
      assert is_integer(metrics.uptime_ms)
      assert is_integer(metrics.memory_bytes)
      assert is_integer(metrics.message_queue_len)
      assert is_integer(metrics.reductions)
      assert is_atom(metrics.status)
    end

    test "returns :error for non-existent component" do
      assert {:error, :not_found} = Introspection.get_metrics(:nonexistent)
    end
  end

  describe "format_tree/0" do
    test "returns empty message when no components" do
      output = Introspection.format_tree()
      assert output =~ "no components"
    end

    test "formats single component" do
      {:ok, pid} = ComponentSupervisor.start_component(TestComponent, %{}, id: :root)
      ComponentServer.mount(pid)

      output = Introspection.format_tree()
      assert output =~ "root"
      assert output =~ "TestComponent"
    end
  end

  describe "aggregate_stats/0" do
    test "returns aggregate statistics" do
      {:ok, pid1} = ComponentSupervisor.start_component(TestComponent, %{}, id: :comp1)
      {:ok, pid2} = ComponentSupervisor.start_component(TestComponent, %{}, id: :comp2)
      ComponentServer.mount(pid1)
      ComponentServer.mount(pid2)

      stats = Introspection.aggregate_stats()
      assert stats.component_count == 2
      assert stats.total_restarts == 0
      assert is_integer(stats.total_memory_bytes)
      assert stats.persisted_state_count == 0
    end

    test "returns zeros when no components" do
      stats = Introspection.aggregate_stats()
      assert stats.component_count == 0
      assert stats.total_restarts == 0
    end
  end

  describe "find_by_module/1" do
    test "returns components matching module" do
      {:ok, pid1} = ComponentSupervisor.start_component(TestComponent, %{}, id: :comp1)
      {:ok, pid2} = ComponentSupervisor.start_component(TestComponent, %{}, id: :comp2)
      ComponentServer.mount(pid1)
      ComponentServer.mount(pid2)

      results = Introspection.find_by_module(TestComponent)
      assert length(results) == 2
    end

    test "returns empty list when no matches" do
      assert [] = Introspection.find_by_module(NonExistentModule)
    end
  end

  describe "find_unstable/1" do
    test "returns empty list when no restarts" do
      {:ok, pid} = ComponentSupervisor.start_component(TestComponent, %{}, id: :stable)
      ComponentServer.mount(pid)

      assert [] = Introspection.find_unstable()
    end

    test "returns components with restarts above threshold" do
      {:ok, pid} = ComponentSupervisor.start_component(TestComponent, %{}, id: :unstable)
      ComponentServer.mount(pid)

      # Simulate restarts
      StatePersistence.record_restart(:unstable)
      StatePersistence.record_restart(:unstable)

      results = Introspection.find_unstable(2)
      assert length(results) == 1
      assert hd(results).id == :unstable
      assert hd(results).restart_count == 2
    end

    test "sorts by restart count descending" do
      {:ok, pid1} = ComponentSupervisor.start_component(TestComponent, %{}, id: :comp1)
      {:ok, pid2} = ComponentSupervisor.start_component(TestComponent, %{}, id: :comp2)
      ComponentServer.mount(pid1)
      ComponentServer.mount(pid2)

      StatePersistence.record_restart(:comp1)
      StatePersistence.record_restart(:comp2)
      StatePersistence.record_restart(:comp2)

      results = Introspection.find_unstable(1)
      assert length(results) == 2
      assert hd(results).id == :comp2
      assert hd(results).restart_count == 2
    end
  end
end
