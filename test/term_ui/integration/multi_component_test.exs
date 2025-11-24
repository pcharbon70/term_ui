defmodule TermUI.Integration.MultiComponentTest do
  @moduledoc """
  Integration tests for multi-component applications.

  Tests event flow, focus management, and message passing between
  multiple interactive components.
  """

  use TermUI.RuntimeTestCase

  # Root component that manages child components
  defmodule MultiRoot do
    use TermUI.Elm

    def init(_opts) do
      %{
        focused: :child_a,
        child_a: %{count: 0},
        child_b: %{count: 0},
        broadcasts_received: 0
      }
    end

    def event_to_msg(%Event.Key{key: :tab}, _state), do: {:msg, :toggle_focus}
    def event_to_msg(%Event.Key{key: :up}, state), do: {:msg, {:increment, state.focused}}
    def event_to_msg(%Event.Key{key: :down}, state), do: {:msg, {:decrement, state.focused}}
    def event_to_msg(%Event.Resize{}, _state), do: {:msg, :resize_received}
    def event_to_msg(%Event.Mouse{x: x}, _state) when x < 40, do: {:msg, :focus_a}
    def event_to_msg(%Event.Mouse{x: x}, _state) when x >= 40, do: {:msg, :focus_b}
    def event_to_msg(_, _), do: :ignore

    def update(:toggle_focus, state) do
      new_focused = if state.focused == :child_a, do: :child_b, else: :child_a
      {%{state | focused: new_focused}, []}
    end

    def update({:increment, :child_a}, state) do
      child_a = %{state.child_a | count: state.child_a.count + 1}
      {%{state | child_a: child_a}, []}
    end

    def update({:increment, :child_b}, state) do
      child_b = %{state.child_b | count: state.child_b.count + 1}
      {%{state | child_b: child_b}, []}
    end

    def update({:decrement, :child_a}, state) do
      child_a = %{state.child_a | count: state.child_a.count - 1}
      {%{state | child_a: child_a}, []}
    end

    def update({:decrement, :child_b}, state) do
      child_b = %{state.child_b | count: state.child_b.count - 1}
      {%{state | child_b: child_b}, []}
    end

    def update(:focus_a, state) do
      {%{state | focused: :child_a}, []}
    end

    def update(:focus_b, state) do
      {%{state | focused: :child_b}, []}
    end

    def update(:resize_received, state) do
      {%{state | broadcasts_received: state.broadcasts_received + 1}, []}
    end

    def update(_msg, state), do: {state, []}

    def view(state) do
      {:text, "A: #{state.child_a.count}, B: #{state.child_b.count}, Focus: #{state.focused}"}
    end
  end

  # Component that tracks messages from parent
  defmodule MessageTracker do
    use TermUI.Elm

    def init(_opts) do
      %{
        messages: [],
        results: []
      }
    end

    def event_to_msg(%Event.Key{key: "m"}, _state), do: {:msg, :send_message}
    def event_to_msg(_, _), do: :ignore

    def update(:send_message, state) do
      {%{state | messages: [:sent | state.messages]}, []}
    end

    def update({:result, value}, state) do
      {%{state | results: [value | state.results]}, []}
    end

    def update(_msg, state), do: {state, []}

    def view(state) do
      {:text, "Messages: #{length(state.messages)}, Results: #{length(state.results)}"}
    end
  end

  describe "focus management" do
    test "keyboard events go to focused component" do
      runtime = start_test_runtime(MultiRoot)

      # Initial focus is child_a
      state = Runtime.get_state(runtime)
      assert state.root_state.focused == :child_a

      # Increment should affect child_a
      Runtime.send_event(runtime, Event.key(:up))
      Runtime.sync(runtime)

      state = Runtime.get_state(runtime)
      assert state.root_state.child_a.count == 1
      assert state.root_state.child_b.count == 0
    end

    test "tab toggles focus between components" do
      runtime = start_test_runtime(MultiRoot)

      # Toggle focus
      Runtime.send_event(runtime, Event.key(:tab))
      Runtime.sync(runtime)

      state = Runtime.get_state(runtime)
      assert state.root_state.focused == :child_b

      # Toggle again
      Runtime.send_event(runtime, Event.key(:tab))
      Runtime.sync(runtime)

      state = Runtime.get_state(runtime)
      assert state.root_state.focused == :child_a
    end

    test "focus change routes keyboard to new component" do
      runtime = start_test_runtime(MultiRoot)

      # Increment child_a
      Runtime.send_event(runtime, Event.key(:up))
      Runtime.sync(runtime)

      # Toggle to child_b
      Runtime.send_event(runtime, Event.key(:tab))
      Runtime.sync(runtime)

      # Increment should now affect child_b
      Runtime.send_event(runtime, Event.key(:up))
      Runtime.send_event(runtime, Event.key(:up))
      Runtime.sync(runtime)

      state = Runtime.get_state(runtime)
      assert state.root_state.child_a.count == 1
      assert state.root_state.child_b.count == 2
    end

    test "mouse click can change focus" do
      runtime = start_test_runtime(MultiRoot)

      # Click on right side (x >= 40) to focus child_b
      Runtime.send_event(runtime, Event.mouse(:press, :left, 50, 10))
      Runtime.sync(runtime)

      state = Runtime.get_state(runtime)
      assert state.root_state.focused == :child_b

      # Click on left side (x < 40) to focus child_a
      Runtime.send_event(runtime, Event.mouse(:press, :left, 20, 10))
      Runtime.sync(runtime)

      state = Runtime.get_state(runtime)
      assert state.root_state.focused == :child_a
    end
  end

  describe "broadcast events" do
    test "resize events reach component" do
      runtime = start_test_runtime(MultiRoot)

      # Send resize events
      Runtime.send_event(runtime, Event.resize(120, 40))
      Runtime.send_event(runtime, Event.resize(80, 24))
      Runtime.sync(runtime)

      state = Runtime.get_state(runtime)
      assert state.root_state.broadcasts_received == 2
    end
  end

  describe "message passing" do
    test "direct messages update component state" do
      runtime = start_test_runtime(MessageTracker)

      # Send direct message
      Runtime.send_message(runtime, :root, :send_message)
      Runtime.sync(runtime)

      state = Runtime.get_state(runtime)
      assert length(state.root_state.messages) == 1
    end

    test "multiple messages are processed in order" do
      runtime = start_test_runtime(MessageTracker)

      # Send multiple messages
      Runtime.send_message(runtime, :root, :send_message)
      Runtime.send_message(runtime, :root, :send_message)
      Runtime.send_message(runtime, :root, :send_message)
      Runtime.sync(runtime)

      state = Runtime.get_state(runtime)
      assert length(state.root_state.messages) == 3
    end

    test "command results return to component" do
      runtime = start_test_runtime(MessageTracker)

      # Simulate command result
      Runtime.command_result(runtime, :root, make_ref(), {:result, :success})
      Runtime.sync(runtime)

      state = Runtime.get_state(runtime)
      assert length(state.root_state.results) == 1
    end
  end

  describe "component isolation" do
    test "components maintain independent state" do
      runtime = start_test_runtime(MultiRoot)

      # Increment child_a twice
      Runtime.send_event(runtime, Event.key(:up))
      Runtime.send_event(runtime, Event.key(:up))
      Runtime.sync(runtime)

      state = Runtime.get_state(runtime)
      assert state.root_state.child_a.count == 2
      assert state.root_state.child_b.count == 0

      # Toggle to child_b and increment once
      Runtime.send_event(runtime, Event.key(:tab))
      Runtime.sync(runtime)

      Runtime.send_event(runtime, Event.key(:up))
      Runtime.sync(runtime)

      state = Runtime.get_state(runtime)
      assert state.root_state.child_a.count == 2
      assert state.root_state.child_b.count == 1

      # Decrement child_b
      Runtime.send_event(runtime, Event.key(:down))
      Runtime.sync(runtime)

      state = Runtime.get_state(runtime)
      assert state.root_state.child_a.count == 2
      assert state.root_state.child_b.count == 0
    end
  end

  describe "complex interactions" do
    test "rapid focus changes and events" do
      runtime = start_test_runtime(MultiRoot)

      # Rapid interactions
      for _ <- 1..10 do
        Runtime.send_event(runtime, Event.key(:up))
        Runtime.send_event(runtime, Event.key(:tab))
      end
      Runtime.sync(runtime)

      state = Runtime.get_state(runtime)
      # After 10 iterations: each component gets incremented when focused
      # Tab toggles focus, so alternating increments
      total = state.root_state.child_a.count + state.root_state.child_b.count
      assert total == 10
    end

    test "mixed event types in sequence" do
      runtime = start_test_runtime(MultiRoot)

      # Mix of keyboard, mouse, and resize events
      # Initial focus is child_a
      Runtime.send_event(runtime, Event.key(:up))  # child_a: 1
      Runtime.sync(runtime)

      Runtime.send_event(runtime, Event.mouse(:press, :left, 50, 10))  # focus child_b
      Runtime.sync(runtime)

      Runtime.send_event(runtime, Event.key(:up))  # child_b: 1
      Runtime.sync(runtime)

      Runtime.send_event(runtime, Event.resize(100, 50))  # broadcast
      Runtime.sync(runtime)

      Runtime.send_event(runtime, Event.key(:tab))  # focus child_a
      Runtime.sync(runtime)

      Runtime.send_event(runtime, Event.key(:up))  # child_a: 2
      Runtime.sync(runtime)

      state = Runtime.get_state(runtime)
      assert state.root_state.child_a.count == 2
      assert state.root_state.child_b.count == 1
      assert state.root_state.broadcasts_received == 1
    end
  end
end
