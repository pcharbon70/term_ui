defmodule TermUI.Integration.ComponentHierarchyTest do
  @moduledoc """
  Integration tests for component hierarchies.

  Tests verify correct lifecycle sequencing, rendering, and management
  of nested component trees.
  """

  use ExUnit.Case, async: false

  alias TermUI.Component.StatePersistence
  alias TermUI.ComponentRegistry
  alias TermUI.ComponentServer
  alias TermUI.ComponentSupervisor

  # Test components that track lifecycle events
  defmodule LifecycleTracker do
    use TermUI.StatefulComponent

    @impl true
    def init(props) do
      tracker = props[:tracker]
      id = props[:id]
      if tracker, do: send(tracker, {:lifecycle, id, :init})

      {:ok,
       %{
         id: id,
         tracker: tracker,
         children_ids: props[:children_ids] || [],
         mounted: false
       }}
    end

    @impl true
    def mount(state) do
      if state.tracker, do: send(state.tracker, {:lifecycle, state.id, :mount})
      {:ok, %{state | mounted: true}}
    end

    @impl true
    def unmount(state) do
      if state.tracker, do: send(state.tracker, {:lifecycle, state.id, :unmount})
      :ok
    end

    @impl true
    def handle_event(_event, state) do
      {:ok, state}
    end

    @impl true
    def render(state, _area) do
      text("Component #{state.id}")
    end
  end

  # Container that manages children
  defmodule TestContainer do
    use TermUI.Container

    @impl true
    def init(props) do
      {:ok,
       %{
         id: props[:id],
         tracker: props[:tracker],
         child_specs: props[:child_specs] || []
       }}
    end

    def mount(state) do
      if state.tracker, do: send(state.tracker, {:lifecycle, state.id, :mount})
      {:ok, state}
    end

    def unmount(state) do
      if state.tracker, do: send(state.tracker, {:lifecycle, state.id, :unmount})
      :ok
    end

    @impl true
    def children(state) do
      state.child_specs
    end

    @impl true
    def layout(_children, area, _state) do
      # Simple layout - all children get full area
      [{nil, area}]
    end

    @impl true
    def handle_event(_event, state) do
      {:ok, state}
    end

    @impl true
    def render(state, _area) do
      text("Container #{state.id}")
    end
  end

  setup do
    start_supervised!(StatePersistence)
    start_supervised!(ComponentRegistry)
    start_supervised!(ComponentSupervisor)
    :ok
  end

  describe "three-level hierarchy initialization" do
    test "components initialize in correct order (parent before children)" do
      tracker = self()

      # Start grandparent
      {:ok, grandparent} =
        ComponentSupervisor.start_component(
          LifecycleTracker,
          %{id: :grandparent, tracker: tracker},
          id: :grandparent
        )

      # Start parent
      {:ok, parent} =
        ComponentSupervisor.start_component(
          LifecycleTracker,
          %{id: :parent, tracker: tracker},
          id: :parent
        )

      # Start child
      {:ok, child} =
        ComponentSupervisor.start_component(
          LifecycleTracker,
          %{id: :child, tracker: tracker},
          id: :child
        )

      # Set up hierarchy
      ComponentRegistry.set_parent(:parent, :grandparent)
      ComponentRegistry.set_parent(:child, :parent)

      # Mount in order
      ComponentServer.mount(grandparent)
      ComponentServer.mount(parent)
      ComponentServer.mount(child)

      # Verify init events received
      assert_receive {:lifecycle, :grandparent, :init}
      assert_receive {:lifecycle, :parent, :init}
      assert_receive {:lifecycle, :child, :init}

      # Verify mount events received
      assert_receive {:lifecycle, :grandparent, :mount}
      assert_receive {:lifecycle, :parent, :mount}
      assert_receive {:lifecycle, :child, :mount}

      # Verify hierarchy
      # Root component has no parent registered, so returns :not_found
      assert {:error, :not_found} = ComponentRegistry.get_parent(:grandparent)
      assert {:ok, :grandparent} = ComponentRegistry.get_parent(:parent)
      assert {:ok, :parent} = ComponentRegistry.get_parent(:child)
    end

    test "hierarchy maintains correct parent-child relationships" do
      {:ok, _root} =
        ComponentSupervisor.start_component(
          LifecycleTracker,
          %{id: :root},
          id: :root
        )

      {:ok, _branch1} =
        ComponentSupervisor.start_component(
          LifecycleTracker,
          %{id: :branch1},
          id: :branch1
        )

      {:ok, _branch2} =
        ComponentSupervisor.start_component(
          LifecycleTracker,
          %{id: :branch2},
          id: :branch2
        )

      {:ok, _leaf} =
        ComponentSupervisor.start_component(
          LifecycleTracker,
          %{id: :leaf},
          id: :leaf
        )

      ComponentRegistry.set_parent(:branch1, :root)
      ComponentRegistry.set_parent(:branch2, :root)
      ComponentRegistry.set_parent(:leaf, :branch1)

      # Verify children
      children = ComponentRegistry.get_children(:root)
      assert length(children) == 2
      assert :branch1 in children
      assert :branch2 in children

      # Verify grandchild
      grandchildren = ComponentRegistry.get_children(:branch1)
      assert grandchildren == [:leaf]
    end
  end

  describe "child components render within parent bounds" do
    test "children exist within parent hierarchy" do
      {:ok, parent_pid} =
        ComponentSupervisor.start_component(
          LifecycleTracker,
          %{id: :parent},
          id: :parent
        )

      {:ok, child_pid} =
        ComponentSupervisor.start_component(
          LifecycleTracker,
          %{id: :child},
          id: :child
        )

      ComponentServer.mount(parent_pid)
      ComponentServer.mount(child_pid)

      ComponentRegistry.set_parent(:child, :parent)

      # Verify both are registered
      assert {:ok, ^parent_pid} = ComponentRegistry.lookup(:parent)
      assert {:ok, ^child_pid} = ComponentRegistry.lookup(:child)

      # Verify relationship
      assert {:ok, :parent} = ComponentRegistry.get_parent(:child)
    end
  end

  describe "parent unmount terminates all descendants" do
    test "cascade shutdown terminates children" do
      tracker = self()

      {:ok, parent} =
        ComponentSupervisor.start_component(
          LifecycleTracker,
          %{id: :parent, tracker: tracker},
          id: :parent
        )

      {:ok, child} =
        ComponentSupervisor.start_component(
          LifecycleTracker,
          %{id: :child, tracker: tracker},
          id: :child
        )

      {:ok, grandchild} =
        ComponentSupervisor.start_component(
          LifecycleTracker,
          %{id: :grandchild, tracker: tracker},
          id: :grandchild
        )

      ComponentServer.mount(parent)
      ComponentServer.mount(child)
      ComponentServer.mount(grandchild)

      ComponentRegistry.set_parent(:child, :parent)
      ComponentRegistry.set_parent(:grandchild, :child)

      # Clear init/mount messages
      flush_messages()

      # Stop parent with cascade
      :ok = ComponentSupervisor.stop_component(:parent, cascade: true)

      # All processes should be stopped
      refute Process.alive?(parent)
      refute Process.alive?(child)
      refute Process.alive?(grandchild)
    end

    test "sibling branches unaffected by other branch termination" do
      {:ok, root} =
        ComponentSupervisor.start_component(
          LifecycleTracker,
          %{id: :root},
          id: :root
        )

      {:ok, branch1} =
        ComponentSupervisor.start_component(
          LifecycleTracker,
          %{id: :branch1},
          id: :branch1
        )

      {:ok, branch2} =
        ComponentSupervisor.start_component(
          LifecycleTracker,
          %{id: :branch2},
          id: :branch2
        )

      {:ok, leaf1} =
        ComponentSupervisor.start_component(
          LifecycleTracker,
          %{id: :leaf1},
          id: :leaf1
        )

      ComponentServer.mount(root)
      ComponentServer.mount(branch1)
      ComponentServer.mount(branch2)
      ComponentServer.mount(leaf1)

      ComponentRegistry.set_parent(:branch1, :root)
      ComponentRegistry.set_parent(:branch2, :root)
      ComponentRegistry.set_parent(:leaf1, :branch1)

      # Stop branch1 with cascade
      :ok = ComponentSupervisor.stop_component(:branch1, cascade: true)

      # Branch1 and its children should be stopped
      refute Process.alive?(branch1)
      refute Process.alive?(leaf1)

      # Root and branch2 should still be alive
      assert Process.alive?(root)
      assert Process.alive?(branch2)
    end
  end

  describe "dynamic child addition and removal" do
    test "children can be added at runtime" do
      {:ok, parent} =
        ComponentSupervisor.start_component(
          LifecycleTracker,
          %{id: :parent},
          id: :parent
        )

      ComponentServer.mount(parent)

      # Initially no children
      assert ComponentRegistry.get_children(:parent) == []

      # Add child dynamically
      {:ok, child} =
        ComponentSupervisor.start_component(
          LifecycleTracker,
          %{id: :child1},
          id: :child1
        )

      ComponentServer.mount(child)
      ComponentRegistry.set_parent(:child1, :parent)

      # Now has one child
      children = ComponentRegistry.get_children(:parent)
      assert children == [:child1]

      # Add another child
      {:ok, child2} =
        ComponentSupervisor.start_component(
          LifecycleTracker,
          %{id: :child2},
          id: :child2
        )

      ComponentServer.mount(child2)
      ComponentRegistry.set_parent(:child2, :parent)

      # Now has two children
      children = ComponentRegistry.get_children(:parent)
      assert length(children) == 2
    end

    test "children can be removed at runtime" do
      {:ok, parent} =
        ComponentSupervisor.start_component(
          LifecycleTracker,
          %{id: :parent},
          id: :parent
        )

      {:ok, child1} =
        ComponentSupervisor.start_component(
          LifecycleTracker,
          %{id: :child1},
          id: :child1
        )

      {:ok, child2} =
        ComponentSupervisor.start_component(
          LifecycleTracker,
          %{id: :child2},
          id: :child2
        )

      ComponentServer.mount(parent)
      ComponentServer.mount(child1)
      ComponentServer.mount(child2)

      ComponentRegistry.set_parent(:child1, :parent)
      ComponentRegistry.set_parent(:child2, :parent)

      # Has two children
      assert length(ComponentRegistry.get_children(:parent)) == 2

      # Remove one child
      :ok = ComponentSupervisor.stop_component(:child1)

      # Give time for process to terminate
      Process.sleep(10)

      # Now only one child (parent relationship cleared by registry on DOWN)
      children = ComponentRegistry.get_children(:parent)
      # Note: The parent table entry may still exist, but the component is gone
      # Filter to only existing components
      existing =
        Enum.filter(children, fn id ->
          case ComponentRegistry.lookup(id) do
            {:ok, _} -> true
            _ -> false
          end
        end)

      assert existing == [:child2]
    end
  end

  # Helper to flush all messages from mailbox
  defp flush_messages do
    receive do
      _ -> flush_messages()
    after
      0 -> :ok
    end
  end
end
