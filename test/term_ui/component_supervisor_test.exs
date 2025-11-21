defmodule TermUI.ComponentSupervisorTest do
  use ExUnit.Case, async: false

  alias TermUI.ComponentSupervisor
  alias TermUI.ComponentRegistry

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

  setup do
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
end
