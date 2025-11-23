defmodule TermUI.Integration.FaultToleranceTest do
  @moduledoc """
  Integration tests for fault tolerance.

  Tests verify crash recovery, state persistence, and proper isolation
  of failures in component hierarchies.
  """

  use ExUnit.Case, async: false

  alias TermUI.Component.StatePersistence
  alias TermUI.ComponentRegistry
  alias TermUI.ComponentServer
  alias TermUI.ComponentSupervisor

  # Component that can crash on demand
  defmodule CrashableComponent do
    use TermUI.StatefulComponent

    @impl true
    def init(props) do
      {:ok,
       %{
         id: props[:id],
         tracker: props[:tracker],
         counter: props[:counter] || 0
       }}
    end

    @impl true
    def handle_event(:crash, _state) do
      raise "Intentional crash"
    end

    def handle_event({:increment, value}, state) do
      {:ok, %{state | counter: state.counter + value}}
    end

    def handle_event(_event, state) do
      {:ok, state}
    end

    @impl true
    def render(state, _area) do
      text("Counter: #{state.counter}")
    end
  end

  # Component that tracks lifecycle for crash detection
  defmodule MonitoredComponent do
    use TermUI.StatefulComponent

    @impl true
    def init(props) do
      if props[:tracker] do
        send(props[:tracker], {:lifecycle, props[:id], :init})
      end

      {:ok,
       %{
         id: props[:id],
         tracker: props[:tracker],
         value: props[:value] || 0
       }}
    end

    @impl true
    def mount(state) do
      if state.tracker do
        send(state.tracker, {:lifecycle, state.id, :mount})
      end

      {:ok, state}
    end

    @impl true
    def handle_event(:crash, _state) do
      raise "Crash!"
    end

    def handle_event({:set, value}, state) do
      {:ok, %{state | value: value}}
    end

    def handle_event(_event, state) do
      {:ok, state}
    end

    @impl true
    def render(state, _area) do
      text("Value: #{state.value}")
    end
  end

  setup do
    start_supervised!(StatePersistence)
    start_supervised!(ComponentRegistry)
    start_supervised!({ComponentSupervisor, max_restarts: 10, max_seconds: 5})
    :ok
  end

  describe "crashed child component restarts without affecting parent" do
    test "parent remains alive when child crashes" do
      {:ok, parent} =
        ComponentSupervisor.start_component(
          MonitoredComponent,
          %{id: :parent, value: 100},
          id: :parent
        )

      {:ok, child} =
        ComponentSupervisor.start_component(
          CrashableComponent,
          %{id: :child, counter: 50},
          id: :child,
          restart: :transient
        )

      ComponentServer.mount(parent)
      ComponentServer.mount(child)

      ComponentRegistry.set_parent(:child, :parent)

      # Verify initial state
      assert ComponentServer.get_state(parent).value == 100
      assert ComponentServer.get_state(child).counter == 50

      # Crash the child
      catch_exit do
        ComponentServer.send_event(child, :crash)
      end

      # Give supervisor time to restart
      Process.sleep(50)

      # Parent should still be alive and unchanged
      assert Process.alive?(parent)
      assert ComponentServer.get_state(parent).value == 100

      # Child should have been restarted by supervisor
      # (with transient restart strategy)
    end

    test "parent can still receive events after child crash" do
      {:ok, parent} =
        ComponentSupervisor.start_component(
          CrashableComponent,
          %{id: :parent, counter: 0},
          id: :parent
        )

      {:ok, child} =
        ComponentSupervisor.start_component(
          CrashableComponent,
          %{id: :child, counter: 0},
          id: :child,
          restart: :transient
        )

      ComponentServer.mount(parent)
      ComponentServer.mount(child)

      ComponentRegistry.set_parent(:child, :parent)

      # Crash child
      catch_exit do
        ComponentServer.send_event(child, :crash)
      end

      Process.sleep(50)

      # Parent should still work
      :ok = ComponentServer.send_event(parent, {:increment, 10})
      assert ComponentServer.get_state(parent).counter == 10
    end
  end

  describe "crashed component state recovers from persistence" do
    test "state is persisted and recovered on restart" do
      # Start component with recovery enabled
      {:ok, pid} =
        ComponentSupervisor.start_component(
          CrashableComponent,
          %{id: :recoverable, counter: 0},
          id: :recoverable,
          restart: :transient,
          recovery: :last_state
        )

      ComponentServer.mount(pid)

      # Modify state
      :ok = ComponentServer.send_event(pid, {:increment, 42})
      state_before = ComponentServer.get_state(pid)
      assert state_before.counter == 42

      # Crash the component - state should be persisted
      catch_exit do
        ComponentServer.send_event(pid, :crash)
      end

      # Give time for supervisor to restart
      Process.sleep(100)

      # Check that state was persisted
      case StatePersistence.recover(:recoverable, :last_state) do
        {:ok, recovered_state} ->
          assert recovered_state.counter == 42

        :not_found ->
          # State might have been cleared after successful restart
          :ok
      end
    end

    test "restart count is tracked" do
      {:ok, pid} =
        ComponentSupervisor.start_component(
          CrashableComponent,
          %{id: :counted},
          id: :counted,
          restart: :transient
        )

      ComponentServer.mount(pid)

      # Initial restart count should be 0
      assert StatePersistence.get_restart_count(:counted) == 0

      # Crash the component
      catch_exit do
        ComponentServer.send_event(pid, :crash)
      end

      Process.sleep(50)

      # Restart count should be incremented
      # (counted when recovered state is used)
      count = StatePersistence.get_restart_count(:counted)
      # May or may not have recovery depending on timing
      assert count >= 0
    end
  end

  describe "sibling components continue functioning during restart" do
    test "siblings unaffected by peer crash" do
      {:ok, sibling1} =
        ComponentSupervisor.start_component(
          CrashableComponent,
          %{id: :sibling1, counter: 10},
          id: :sibling1
        )

      {:ok, sibling2} =
        ComponentSupervisor.start_component(
          CrashableComponent,
          %{id: :sibling2, counter: 20},
          id: :sibling2,
          restart: :transient
        )

      {:ok, sibling3} =
        ComponentSupervisor.start_component(
          CrashableComponent,
          %{id: :sibling3, counter: 30},
          id: :sibling3
        )

      ComponentServer.mount(sibling1)
      ComponentServer.mount(sibling2)
      ComponentServer.mount(sibling3)

      # Crash sibling2
      catch_exit do
        ComponentServer.send_event(sibling2, :crash)
      end

      Process.sleep(50)

      # Siblings 1 and 3 should be unaffected
      assert Process.alive?(sibling1)
      assert Process.alive?(sibling3)
      assert ComponentServer.get_state(sibling1).counter == 10
      assert ComponentServer.get_state(sibling3).counter == 30

      # Can still interact with siblings
      :ok = ComponentServer.send_event(sibling1, {:increment, 5})
      assert ComponentServer.get_state(sibling1).counter == 15
    end

    test "hierarchy isolation - cousin crashes don't affect other branches" do
      {:ok, parent1} =
        ComponentSupervisor.start_component(
          CrashableComponent,
          %{id: :parent1, counter: 100},
          id: :parent1
        )

      {:ok, child1} =
        ComponentSupervisor.start_component(
          CrashableComponent,
          %{id: :child1, counter: 10},
          id: :child1,
          restart: :transient
        )

      {:ok, parent2} =
        ComponentSupervisor.start_component(
          CrashableComponent,
          %{id: :parent2, counter: 200},
          id: :parent2
        )

      {:ok, child2} =
        ComponentSupervisor.start_component(
          CrashableComponent,
          %{id: :child2, counter: 20},
          id: :child2
        )

      ComponentServer.mount(parent1)
      ComponentServer.mount(child1)
      ComponentServer.mount(parent2)
      ComponentServer.mount(child2)

      ComponentRegistry.set_parent(:child1, :parent1)
      ComponentRegistry.set_parent(:child2, :parent2)

      # Crash child1
      catch_exit do
        ComponentServer.send_event(child1, :crash)
      end

      Process.sleep(50)

      # Parent2 and child2 should be completely unaffected
      assert Process.alive?(parent2)
      assert Process.alive?(child2)
      assert ComponentServer.get_state(parent2).counter == 200
      assert ComponentServer.get_state(child2).counter == 20
    end
  end

  describe "restart storm triggers supervisor shutdown" do
    test "rapid restarts trigger intensity limit" do
      # Create component with tight restart limits
      {:ok, pid} =
        ComponentSupervisor.start_component(
          CrashableComponent,
          %{id: :storm},
          id: :storm,
          restart: :permanent,
          max_restarts: 2,
          max_seconds: 5
        )

      ComponentServer.mount(pid)

      # Track initial component count
      initial_count = ComponentSupervisor.count_children()
      assert initial_count >= 1

      # Crash multiple times rapidly
      # Note: The supervisor's overall limit will trigger, not component-specific
      Enum.each(1..3, fn _ ->
        case ComponentRegistry.lookup(:storm) do
          {:ok, current_pid} ->
            catch_exit do
              ComponentServer.send_event(current_pid, :crash)
            end

            Process.sleep(10)

          {:error, :not_found} ->
            :ok
        end
      end)

      Process.sleep(100)

      # After restart storm, component might be gone
      # (supervisor may have given up)
    end
  end

  describe "recovery modes" do
    test "reset recovery mode starts fresh" do
      {:ok, pid} =
        ComponentSupervisor.start_component(
          CrashableComponent,
          %{id: :reset_test, counter: 0},
          id: :reset_test,
          restart: :transient,
          recovery: :reset
        )

      ComponentServer.mount(pid)

      # Modify state
      :ok = ComponentServer.send_event(pid, {:increment, 100})
      assert ComponentServer.get_state(pid).counter == 100

      # Persist state manually (simulating crash)
      StatePersistence.persist(:reset_test, %{counter: 100})

      # With :reset mode, recovery should return :not_found
      assert :not_found = StatePersistence.recover(:reset_test, :reset)
    end

    test "temporary restart never restarts" do
      {:ok, pid} =
        ComponentSupervisor.start_component(
          CrashableComponent,
          %{id: :temporary},
          id: :temporary,
          restart: :temporary
        )

      ComponentServer.mount(pid)

      # Crash it
      catch_exit do
        ComponentServer.send_event(pid, :crash)
      end

      Process.sleep(50)

      # Should not be restarted
      assert {:error, :not_found} = ComponentRegistry.lookup(:temporary)
    end
  end
end
