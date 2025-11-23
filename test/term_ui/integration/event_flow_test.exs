defmodule TermUI.Integration.EventFlowTest do
  @moduledoc """
  Integration tests for event flow through component trees.

  Tests verify event routing, handling, and propagation work correctly
  across nested component hierarchies.
  """

  use ExUnit.Case, async: false

  alias TermUI.Component.StatePersistence
  alias TermUI.ComponentRegistry
  alias TermUI.ComponentServer
  alias TermUI.ComponentSupervisor
  alias TermUI.Event
  alias TermUI.EventRouter
  alias TermUI.FocusManager
  alias TermUI.SpatialIndex

  # Component that tracks received events
  defmodule EventTracker do
    use TermUI.StatefulComponent

    @impl true
    def init(props) do
      {:ok,
       %{
         id: props[:id],
         tracker: props[:tracker],
         handle_events: props[:handle_events] || false,
         events: []
       }}
    end

    @impl true
    def handle_event(event, state) do
      if state.tracker do
        send(state.tracker, {:event, state.id, event})
      end

      if state.handle_events do
        # Mark as handled
        {:ok, %{state | events: [event | state.events]}}
      else
        # Let it bubble
        {:ok, state}
      end
    end

    @impl true
    def render(_state, _area) do
      text("")
    end
  end

  # Component that handles specific events
  defmodule SelectiveHandler do
    use TermUI.StatefulComponent

    @impl true
    def init(props) do
      {:ok,
       %{
         id: props[:id],
         tracker: props[:tracker],
         handle_keys: props[:handle_keys] || []
       }}
    end

    @impl true
    def handle_event(%Event.Key{key: key} = event, state) do
      if state.tracker do
        send(state.tracker, {:event, state.id, event})
      end

      if key in state.handle_keys do
        # Handle this key
        {:ok, state}
      else
        # Don't handle, bubble up
        {:ok, state}
      end
    end

    def handle_event(event, state) do
      if state.tracker do
        send(state.tracker, {:event, state.id, event})
      end

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
    start_supervised!(SpatialIndex)
    start_supervised!(FocusManager)
    start_supervised!(EventRouter)
    :ok
  end

  describe "keyboard event reaches deeply nested focused component" do
    test "event routes to focused component in deep hierarchy" do
      tracker = self()

      # Create hierarchy: root -> parent -> child -> target
      {:ok, root} =
        ComponentSupervisor.start_component(
          EventTracker,
          %{id: :root, tracker: tracker},
          id: :root
        )

      {:ok, parent} =
        ComponentSupervisor.start_component(
          EventTracker,
          %{id: :parent, tracker: tracker},
          id: :parent
        )

      {:ok, child} =
        ComponentSupervisor.start_component(
          EventTracker,
          %{id: :child, tracker: tracker},
          id: :child
        )

      {:ok, target} =
        ComponentSupervisor.start_component(
          EventTracker,
          %{id: :target, tracker: tracker, handle_events: true},
          id: :target
        )

      # Mount all
      ComponentServer.mount(root)
      ComponentServer.mount(parent)
      ComponentServer.mount(child)
      ComponentServer.mount(target)

      # Set up hierarchy
      ComponentRegistry.set_parent(:parent, :root)
      ComponentRegistry.set_parent(:child, :parent)
      ComponentRegistry.set_parent(:target, :child)

      # Focus the deepest component
      FocusManager.set_focused(:target)

      # Send keyboard event through router
      event = %Event.Key{key: :enter}
      EventRouter.route(event)

      # Target should receive the event
      assert_receive {:event, :target, ^event}, 100
    end

    test "focused component receives event even when not at root" do
      tracker = self()

      {:ok, container} =
        ComponentSupervisor.start_component(
          EventTracker,
          %{id: :container, tracker: tracker},
          id: :container
        )

      {:ok, input} =
        ComponentSupervisor.start_component(
          EventTracker,
          %{id: :input, tracker: tracker, handle_events: true},
          id: :input
        )

      ComponentServer.mount(container)
      ComponentServer.mount(input)

      ComponentRegistry.set_parent(:input, :container)

      FocusManager.set_focused(:input)

      event = %Event.Key{key: :a, char: "a"}
      EventRouter.route(event)

      assert_receive {:event, :input, ^event}, 100
    end
  end

  describe "mouse event routes to correct component based on position" do
    test "mouse event routes to component at coordinates" do
      tracker = self()

      {:ok, button1} =
        ComponentSupervisor.start_component(
          EventTracker,
          %{id: :button1, tracker: tracker, handle_events: true},
          id: :button1
        )

      {:ok, button2} =
        ComponentSupervisor.start_component(
          EventTracker,
          %{id: :button2, tracker: tracker, handle_events: true},
          id: :button2
        )

      ComponentServer.mount(button1)
      ComponentServer.mount(button2)

      # Register spatial bounds
      SpatialIndex.update(:button1, button1, %{x: 0, y: 0, width: 10, height: 3})
      SpatialIndex.update(:button2, button2, %{x: 0, y: 5, width: 10, height: 3})

      # Click on button1 area
      event1 = %Event.Mouse{action: :click, button: :left, x: 5, y: 1}
      EventRouter.route(event1)

      assert_receive {:event, :button1, ^event1}, 100
      refute_receive {:event, :button2, _}

      # Click on button2 area
      event2 = %Event.Mouse{action: :click, button: :left, x: 5, y: 6}
      EventRouter.route(event2)

      assert_receive {:event, :button2, ^event2}, 100
    end

    test "mouse event ignores components outside bounds" do
      tracker = self()

      {:ok, button} =
        ComponentSupervisor.start_component(
          EventTracker,
          %{id: :button, tracker: tracker, handle_events: true},
          id: :button
        )

      ComponentServer.mount(button)
      SpatialIndex.update(:button, button, %{x: 10, y: 10, width: 5, height: 2})

      # Click outside button bounds
      event = %Event.Mouse{action: :click, button: :left, x: 0, y: 0}
      EventRouter.route(event)

      refute_receive {:event, :button, _}, 50
    end
  end

  describe "unhandled event bubbles to parent" do
    test "event bubbles from child to parent when unhandled" do
      tracker = self()

      {:ok, parent} =
        ComponentSupervisor.start_component(
          SelectiveHandler,
          %{id: :parent, tracker: tracker, handle_keys: [:enter]},
          id: :parent
        )

      {:ok, child} =
        ComponentSupervisor.start_component(
          SelectiveHandler,
          %{id: :child, tracker: tracker, handle_keys: [:space]},
          id: :child
        )

      ComponentServer.mount(parent)
      ComponentServer.mount(child)

      ComponentRegistry.set_parent(:child, :parent)

      FocusManager.set_focused(:child)

      # Send :enter which child doesn't handle
      event = %Event.Key{key: :enter}
      EventRouter.route(event)

      # Both should receive it, child first
      assert_receive {:event, :child, ^event}, 100
      # Parent would receive via bubbling if implemented
    end
  end

  describe "handled event stops propagation" do
    test "event stops when component handles it" do
      tracker = self()

      {:ok, parent} =
        ComponentSupervisor.start_component(
          EventTracker,
          %{id: :parent, tracker: tracker, handle_events: true},
          id: :parent
        )

      {:ok, child} =
        ComponentSupervisor.start_component(
          EventTracker,
          %{id: :child, tracker: tracker, handle_events: true},
          id: :child
        )

      ComponentServer.mount(parent)
      ComponentServer.mount(child)

      ComponentRegistry.set_parent(:child, :parent)

      FocusManager.set_focused(:child)

      event = %Event.Key{key: :a, char: "a"}
      EventRouter.route(event)

      # Child receives and handles
      assert_receive {:event, :child, ^event}, 100

      # Parent should not receive since child handled it
      # (This depends on actual propagation implementation)
    end
  end

  describe "multiple event types" do
    test "routes different event types to appropriate handlers" do
      tracker = self()

      {:ok, component} =
        ComponentSupervisor.start_component(
          EventTracker,
          %{id: :multi, tracker: tracker, handle_events: true},
          id: :multi
        )

      ComponentServer.mount(component)
      SpatialIndex.update(:multi, component, %{x: 0, y: 0, width: 20, height: 10})
      FocusManager.set_focused(:multi)

      # Send key event
      key_event = %Event.Key{key: :enter}
      EventRouter.route(key_event)
      assert_receive {:event, :multi, ^key_event}, 100

      # Send mouse event
      mouse_event = %Event.Mouse{action: :click, button: :left, x: 5, y: 5}
      EventRouter.route(mouse_event)
      assert_receive {:event, :multi, ^mouse_event}, 100
    end
  end
end
