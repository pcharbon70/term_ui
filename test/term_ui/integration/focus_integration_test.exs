defmodule TermUI.Integration.FocusIntegrationTest do
  @moduledoc """
  Integration tests for focus management in realistic UIs.

  Tests verify Tab traversal, focus trapping, and focus restoration
  work correctly with multiple focusable components.
  """

  use ExUnit.Case, async: false

  alias TermUI.ComponentSupervisor
  alias TermUI.ComponentRegistry
  alias TermUI.ComponentServer
  alias TermUI.Component.StatePersistence
  alias TermUI.Event
  alias TermUI.EventRouter
  alias TermUI.SpatialIndex
  alias TermUI.FocusManager

  # Focusable input component
  defmodule FocusableInput do
    use TermUI.StatefulComponent

    @impl true
    def init(props) do
      {:ok,
       %{
         id: props[:id],
         tracker: props[:tracker],
         focusable: Map.get(props, :focusable, true)
       }}
    end

    @impl true
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

  describe "Tab traversal through form with multiple inputs" do
    test "Tab moves focus to next component in order" do
      tracker = self()

      # Create form with 3 inputs
      {:ok, input1} =
        ComponentSupervisor.start_component(
          FocusableInput,
          %{id: :input1, tracker: tracker},
          id: :input1
        )

      {:ok, input2} =
        ComponentSupervisor.start_component(
          FocusableInput,
          %{id: :input2, tracker: tracker},
          id: :input2
        )

      {:ok, input3} =
        ComponentSupervisor.start_component(
          FocusableInput,
          %{id: :input3, tracker: tracker},
          id: :input3
        )

      ComponentServer.mount(input1)
      ComponentServer.mount(input2)
      ComponentServer.mount(input3)

      # Register with spatial positions for tab order (top to bottom)
      SpatialIndex.update(:input1, input1, %{x: 0, y: 0, width: 20, height: 1})
      SpatialIndex.update(:input2, input2, %{x: 0, y: 2, width: 20, height: 1})
      SpatialIndex.update(:input3, input3, %{x: 0, y: 4, width: 20, height: 1})

      # Focus first input
      FocusManager.set_focused(:input1)
      assert {:ok, :input1} = FocusManager.get_focused()

      # Tab to next
      FocusManager.focus_next()
      assert {:ok, :input2} = FocusManager.get_focused()

      # Tab to next
      FocusManager.focus_next()
      assert {:ok, :input3} = FocusManager.get_focused()
    end

    test "Shift+Tab moves focus to previous component" do
      {:ok, input1} =
        ComponentSupervisor.start_component(
          FocusableInput,
          %{id: :input1},
          id: :input1
        )

      {:ok, input2} =
        ComponentSupervisor.start_component(
          FocusableInput,
          %{id: :input2},
          id: :input2
        )

      {:ok, input3} =
        ComponentSupervisor.start_component(
          FocusableInput,
          %{id: :input3},
          id: :input3
        )

      ComponentServer.mount(input1)
      ComponentServer.mount(input2)
      ComponentServer.mount(input3)

      SpatialIndex.update(:input1, input1, %{x: 0, y: 0, width: 20, height: 1})
      SpatialIndex.update(:input2, input2, %{x: 0, y: 2, width: 20, height: 1})
      SpatialIndex.update(:input3, input3, %{x: 0, y: 4, width: 20, height: 1})

      # Focus last input
      FocusManager.set_focused(:input3)
      assert {:ok, :input3} = FocusManager.get_focused()

      # Shift+Tab to previous
      FocusManager.focus_prev()
      assert {:ok, :input2} = FocusManager.get_focused()

      # Shift+Tab to previous
      FocusManager.focus_prev()
      assert {:ok, :input1} = FocusManager.get_focused()
    end

    test "Tab wraps from last to first" do
      {:ok, input1} =
        ComponentSupervisor.start_component(
          FocusableInput,
          %{id: :input1},
          id: :input1
        )

      {:ok, input2} =
        ComponentSupervisor.start_component(
          FocusableInput,
          %{id: :input2},
          id: :input2
        )

      ComponentServer.mount(input1)
      ComponentServer.mount(input2)

      SpatialIndex.update(:input1, input1, %{x: 0, y: 0, width: 20, height: 1})
      SpatialIndex.update(:input2, input2, %{x: 0, y: 2, width: 20, height: 1})

      # Focus last
      FocusManager.set_focused(:input2)

      # Tab should wrap to first
      FocusManager.focus_next()
      assert {:ok, :input1} = FocusManager.get_focused()
    end
  end

  describe "focus trap in modal" do
    test "trap_focus restricts traversal to group" do
      # Create modal components
      {:ok, modal_input1} =
        ComponentSupervisor.start_component(
          FocusableInput,
          %{id: :modal_input1},
          id: :modal_input1
        )

      {:ok, modal_input2} =
        ComponentSupervisor.start_component(
          FocusableInput,
          %{id: :modal_input2},
          id: :modal_input2
        )

      ComponentServer.mount(modal_input1)
      ComponentServer.mount(modal_input2)

      SpatialIndex.update(:modal_input1, modal_input1, %{x: 10, y: 5, width: 20, height: 1})
      SpatialIndex.update(:modal_input2, modal_input2, %{x: 10, y: 7, width: 20, height: 1})

      # Register and trap focus in modal group
      FocusManager.register_group(:modal, [:modal_input1, :modal_input2])
      FocusManager.trap_focus(:modal)
      FocusManager.set_focused(:modal_input1)

      # Tab should stay within modal
      FocusManager.focus_next()
      assert {:ok, :modal_input2} = FocusManager.get_focused()

      # Tab again should wrap within modal
      FocusManager.focus_next()
      assert {:ok, :modal_input1} = FocusManager.get_focused()
    end

    test "release_focus restores normal traversal" do
      {:ok, bg_input} =
        ComponentSupervisor.start_component(
          FocusableInput,
          %{id: :bg_input},
          id: :bg_input
        )

      {:ok, modal_input} =
        ComponentSupervisor.start_component(
          FocusableInput,
          %{id: :modal_input},
          id: :modal_input
        )

      ComponentServer.mount(bg_input)
      ComponentServer.mount(modal_input)

      SpatialIndex.update(:bg_input, bg_input, %{x: 0, y: 0, width: 20, height: 1})
      SpatialIndex.update(:modal_input, modal_input, %{x: 10, y: 5, width: 20, height: 1})

      # Register modal group
      FocusManager.register_group(:modal, [:modal_input])

      # Trap and then release
      FocusManager.trap_focus(:modal)
      FocusManager.set_focused(:modal_input)
      FocusManager.release_focus()

      # Now Tab should work normally
      FocusManager.focus_next()
      # Should be able to access bg_input now
      assert {:ok, :bg_input} = FocusManager.get_focused()
    end
  end

  describe "focus returns to previous component after modal closes" do
    test "focus restores to previous component" do
      {:ok, input} =
        ComponentSupervisor.start_component(
          FocusableInput,
          %{id: :input},
          id: :input
        )

      {:ok, modal_btn} =
        ComponentSupervisor.start_component(
          FocusableInput,
          %{id: :modal_btn},
          id: :modal_btn
        )

      ComponentServer.mount(input)
      ComponentServer.mount(modal_btn)

      SpatialIndex.update(:input, input, %{x: 0, y: 0, width: 20, height: 1})
      SpatialIndex.update(:modal_btn, modal_btn, %{x: 10, y: 5, width: 20, height: 1})

      # Focus input first
      FocusManager.set_focused(:input)
      assert {:ok, :input} = FocusManager.get_focused()

      # Open modal (push focus)
      FocusManager.push_focus(:modal_btn)
      assert {:ok, :modal_btn} = FocusManager.get_focused()

      # Close modal (pop focus)
      FocusManager.pop_focus()
      assert {:ok, :input} = FocusManager.get_focused()
    end

    test "nested modals restore correctly" do
      {:ok, main_input} =
        ComponentSupervisor.start_component(
          FocusableInput,
          %{id: :main_input},
          id: :main_input
        )

      {:ok, modal1_btn} =
        ComponentSupervisor.start_component(
          FocusableInput,
          %{id: :modal1_btn},
          id: :modal1_btn
        )

      {:ok, modal2_btn} =
        ComponentSupervisor.start_component(
          FocusableInput,
          %{id: :modal2_btn},
          id: :modal2_btn
        )

      ComponentServer.mount(main_input)
      ComponentServer.mount(modal1_btn)
      ComponentServer.mount(modal2_btn)

      SpatialIndex.update(:main_input, main_input, %{x: 0, y: 0, width: 20, height: 1})
      SpatialIndex.update(:modal1_btn, modal1_btn, %{x: 10, y: 5, width: 20, height: 1})
      SpatialIndex.update(:modal2_btn, modal2_btn, %{x: 15, y: 8, width: 20, height: 1})

      # Focus main
      FocusManager.set_focused(:main_input)

      # Open modal1
      FocusManager.push_focus(:modal1_btn)

      # Open modal2
      FocusManager.push_focus(:modal2_btn)
      assert {:ok, :modal2_btn} = FocusManager.get_focused()

      # Close modal2
      FocusManager.pop_focus()
      assert {:ok, :modal1_btn} = FocusManager.get_focused()

      # Close modal1
      FocusManager.pop_focus()
      assert {:ok, :main_input} = FocusManager.get_focused()
    end
  end

  describe "programmatic focus change during event handling" do
    test "component can change focus when handling event" do
      tracker = self()

      {:ok, button} =
        ComponentSupervisor.start_component(
          FocusableInput,
          %{id: :button, tracker: tracker},
          id: :button
        )

      {:ok, input} =
        ComponentSupervisor.start_component(
          FocusableInput,
          %{id: :input, tracker: tracker},
          id: :input
        )

      ComponentServer.mount(button)
      ComponentServer.mount(input)

      SpatialIndex.update(:button, button, %{x: 0, y: 0, width: 10, height: 1})
      SpatialIndex.update(:input, input, %{x: 0, y: 2, width: 20, height: 1})

      FocusManager.set_focused(:button)
      assert {:ok, :button} = FocusManager.get_focused()

      # Simulate button click that focuses input
      FocusManager.set_focused(:input)
      assert {:ok, :input} = FocusManager.get_focused()

      # Input should now receive events
      event = %Event.Key{key: :a, char: "a"}
      EventRouter.route(event)

      assert_receive {:event, :input, ^event}, 100
    end

    test "focus change updates correctly" do
      tracker = self()

      {:ok, comp1} =
        ComponentSupervisor.start_component(
          FocusableInput,
          %{id: :comp1, tracker: tracker},
          id: :comp1
        )

      {:ok, comp2} =
        ComponentSupervisor.start_component(
          FocusableInput,
          %{id: :comp2, tracker: tracker},
          id: :comp2
        )

      ComponentServer.mount(comp1)
      ComponentServer.mount(comp2)

      SpatialIndex.update(:comp1, comp1, %{x: 0, y: 0, width: 10, height: 1})
      SpatialIndex.update(:comp2, comp2, %{x: 0, y: 2, width: 10, height: 1})

      FocusManager.set_focused(:comp1)

      # Change focus
      FocusManager.set_focused(:comp2)

      # The new focus should be comp2
      assert {:ok, :comp2} = FocusManager.get_focused()
    end
  end
end
