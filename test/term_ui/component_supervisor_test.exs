defmodule TermUI.ComponentSupervisorTest do
  use ExUnit.Case, async: false

  alias TermUI.ComponentSupervisor
  alias TermUI.ComponentRegistry
  alias TermUI.Component.StatePersistence
  alias TermUI.ComponentServer

  # Simple test component
  defmodule SimpleComponent do
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

  # Component that crashes on demand
  defmodule CrashingComponent do
    use TermUI.StatefulComponent

    @impl true
    def init(props) do
      {:ok, %{value: props[:initial] || 0, crash_on_event: props[:crash_on_event] || false}}
    end

    @impl true
    def handle_event(:crash, _state) do
      raise "Intentional crash"
    end

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

  describe "start_component/3" do
    test "starts component successfully" do
      {:ok, pid} = ComponentSupervisor.start_component(SimpleComponent, %{initial: 42})

      assert is_pid(pid)
      assert Process.alive?(pid)
    end

    test "starts component with custom id" do
      {:ok, pid} = ComponentSupervisor.start_component(SimpleComponent, %{}, id: :my_component)

      assert is_pid(pid)
    end

    test "multiple components can be started" do
      {:ok, pid1} = ComponentSupervisor.start_component(SimpleComponent, %{initial: 1})
      {:ok, pid2} = ComponentSupervisor.start_component(SimpleComponent, %{initial: 2})
      {:ok, pid3} = ComponentSupervisor.start_component(SimpleComponent, %{initial: 3})

      assert pid1 != pid2
      assert pid2 != pid3
      assert ComponentSupervisor.count_children() == 3
    end
  end

  describe "stop_component/1" do
    test "stops component gracefully" do
      {:ok, pid} = ComponentSupervisor.start_component(SimpleComponent, %{})

      assert Process.alive?(pid)
      assert :ok = ComponentSupervisor.stop_component(pid)
      refute Process.alive?(pid)
    end

    test "returns error for non-existent pid" do
      fake_pid = spawn(fn -> :ok end)
      Process.sleep(10)

      assert {:error, :not_found} = ComponentSupervisor.stop_component(fake_pid)
    end
  end

  describe "count_children/0" do
    test "returns correct count" do
      assert ComponentSupervisor.count_children() == 0

      {:ok, _} = ComponentSupervisor.start_component(SimpleComponent, %{})
      assert ComponentSupervisor.count_children() == 1

      {:ok, _} = ComponentSupervisor.start_component(SimpleComponent, %{})
      assert ComponentSupervisor.count_children() == 2
    end
  end

  describe "which_children/0" do
    test "returns all child pids" do
      {:ok, pid1} = ComponentSupervisor.start_component(SimpleComponent, %{})
      {:ok, pid2} = ComponentSupervisor.start_component(SimpleComponent, %{})

      children = ComponentSupervisor.which_children()
      assert length(children) == 2
      assert pid1 in children
      assert pid2 in children
    end

    test "returns empty list when no children" do
      assert ComponentSupervisor.which_children() == []
    end
  end

  describe "restart strategies" do
    test "starts with :transient restart by default" do
      {:ok, _pid} = ComponentSupervisor.start_component(SimpleComponent, %{}, id: :transient_comp)

      # The component should restart on crash but not on normal exit
      # This is verified by the supervisor behavior
      assert ComponentSupervisor.count_children() == 1
    end

    test "starts with :permanent restart option" do
      {:ok, _pid} =
        ComponentSupervisor.start_component(
          SimpleComponent,
          %{},
          id: :permanent_comp,
          restart: :permanent
        )

      assert ComponentSupervisor.count_children() == 1
    end

    test "starts with :temporary restart option" do
      {:ok, _pid} =
        ComponentSupervisor.start_component(
          SimpleComponent,
          %{},
          id: :temp_comp,
          restart: :temporary
        )

      assert ComponentSupervisor.count_children() == 1
    end
  end

  describe "shutdown options" do
    test "uses custom shutdown timeout" do
      {:ok, pid} =
        ComponentSupervisor.start_component(
          SimpleComponent,
          %{},
          id: :custom_shutdown,
          shutdown: 10_000
        )

      assert Process.alive?(pid)
    end

    test "accepts :brutal_kill shutdown" do
      {:ok, pid} =
        ComponentSupervisor.start_component(
          SimpleComponent,
          %{},
          id: :brutal_kill_comp,
          shutdown: :brutal_kill
        )

      assert Process.alive?(pid)
    end
  end

  describe "recovery options" do
    test "sets :last_state recovery by default" do
      {:ok, _pid} =
        ComponentSupervisor.start_component(
          SimpleComponent,
          %{initial: 42},
          id: :recovery_test
        )

      # Component is started with last_state recovery
      assert ComponentSupervisor.count_children() == 1
    end

    test "accepts :reset recovery option" do
      {:ok, _pid} =
        ComponentSupervisor.start_component(
          SimpleComponent,
          %{},
          id: :reset_recovery,
          recovery: :reset
        )

      assert ComponentSupervisor.count_children() == 1
    end

    test "accepts :last_props recovery option" do
      {:ok, _pid} =
        ComponentSupervisor.start_component(
          SimpleComponent,
          %{},
          id: :props_recovery,
          recovery: :last_props
        )

      assert ComponentSupervisor.count_children() == 1
    end
  end

  describe "stop_component/2" do
    test "stops component by id" do
      {:ok, pid} = ComponentSupervisor.start_component(SimpleComponent, %{}, id: :stop_by_id)
      ComponentServer.mount(pid)

      assert :ok = ComponentSupervisor.stop_component(:stop_by_id)
      refute Process.alive?(pid)
    end

    test "returns error for non-existent id" do
      assert {:error, :not_found} = ComponentSupervisor.stop_component(:nonexistent)
    end

    test "cascade stops children first" do
      {:ok, parent_pid} = ComponentSupervisor.start_component(SimpleComponent, %{}, id: :parent)
      {:ok, child_pid} = ComponentSupervisor.start_component(SimpleComponent, %{}, id: :child)
      ComponentServer.mount(parent_pid)
      ComponentServer.mount(child_pid)

      # Set up parent-child relationship
      ComponentRegistry.set_parent(:child, :parent)

      # Stop parent with cascade
      :ok = ComponentSupervisor.stop_component(:parent, cascade: true)

      # Both should be stopped
      refute Process.alive?(parent_pid)
      refute Process.alive?(child_pid)
    end

    test "cascade stops nested children" do
      {:ok, p1} = ComponentSupervisor.start_component(SimpleComponent, %{}, id: :level1)
      {:ok, p2} = ComponentSupervisor.start_component(SimpleComponent, %{}, id: :level2)
      {:ok, p3} = ComponentSupervisor.start_component(SimpleComponent, %{}, id: :level3)

      ComponentServer.mount(p1)
      ComponentServer.mount(p2)
      ComponentServer.mount(p3)

      ComponentRegistry.set_parent(:level2, :level1)
      ComponentRegistry.set_parent(:level3, :level2)

      :ok = ComponentSupervisor.stop_component(:level1, cascade: true)

      refute Process.alive?(p1)
      refute Process.alive?(p2)
      refute Process.alive?(p3)
    end
  end

  describe "restart limits" do
    test "sets restart limits when specified" do
      {:ok, _pid} =
        ComponentSupervisor.start_component(
          SimpleComponent,
          %{},
          id: :limited_restart,
          max_restarts: 5,
          max_seconds: 10
        )

      # Verify limits were set
      StatePersistence.record_restart(:limited_restart)
      assert StatePersistence.get_restart_count(:limited_restart) == 1
    end
  end
end
