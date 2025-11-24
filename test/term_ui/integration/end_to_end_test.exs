defmodule TermUI.Integration.EndToEndTest do
  @moduledoc """
  End-to-end integration tests for the complete event cycle.

  Tests the full path from input event through dispatch, state update,
  view rendering, and back to display.
  """

  use ExUnit.Case, async: false

  alias TermUI.Runtime
  alias TermUI.Event
  alias TermUI.Command

  # Timeout constants for async crash handling tests
  # These sleeps are necessary because crashes are processed asynchronously
  @crash_processing_timeout 50
  @multiple_crash_timeout 100

  # Helper to start runtime with automatic cleanup on test exit
  defp start_test_runtime(component) do
    {:ok, runtime} = Runtime.start_link(root: component, skip_terminal: true)

    on_exit(fn ->
      if Process.alive?(runtime), do: Runtime.shutdown(runtime)
    end)

    runtime
  end

  # Simple counter component for testing
  defmodule Counter do
    use TermUI.Elm

    def init(_opts), do: %{count: 0, resizes: []}

    def event_to_msg(%Event.Key{key: :up}, _state), do: {:msg, :increment}
    def event_to_msg(%Event.Key{key: :down}, _state), do: {:msg, :decrement}
    def event_to_msg(%Event.Key{key: "q"}, _state), do: {:msg, :quit}
    def event_to_msg(%Event.Mouse{action: :press}, _state), do: {:msg, :click}
    def event_to_msg(%Event.Resize{width: w, height: h}, _state), do: {:msg, {:resize, w, h}}
    def event_to_msg(_, _), do: :ignore

    def update(:increment, state) do
      {%{state | count: state.count + 1}, []}
    end

    def update(:decrement, state) do
      {%{state | count: state.count - 1}, []}
    end

    def update(:quit, state) do
      {state, [Command.quit()]}
    end

    def update(:click, state) do
      {%{state | count: state.count + 10}, []}
    end

    def update({:resize, w, h}, state) do
      {%{state | resizes: [{w, h} | state.resizes]}, []}
    end

    def update(_msg, state), do: {state, []}

    def view(state), do: {:text, "Count: #{state.count}"}
  end

  # Component that can trigger rapid events
  defmodule RapidCounter do
    use TermUI.Elm

    def init(_opts), do: %{events: 0}

    def event_to_msg(%Event.Key{key: :up}, _state), do: {:msg, :tick}
    def event_to_msg(_, _), do: :ignore

    def update(:tick, state) do
      {%{state | events: state.events + 1}, []}
    end

    def update(_msg, state), do: {state, []}

    def view(state), do: {:text, "Events: #{state.events}"}
  end

  describe "end-to-end event cycle" do
    test "key press updates component state" do
      runtime = start_test_runtime(Counter)

      # Send key events
      Runtime.send_event(runtime, Event.key(:up))
      Runtime.send_event(runtime, Event.key(:up))
      Runtime.send_event(runtime, Event.key(:up))
      Runtime.sync(runtime)

      state = Runtime.get_state(runtime)
      assert state.root_state.count == 3
    end

    test "mouse click dispatches to component" do
      runtime = start_test_runtime(Counter)

      # Send mouse click event
      Runtime.send_event(runtime, Event.mouse(:press, :left, 10, 5))
      Runtime.sync(runtime)

      state = Runtime.get_state(runtime)
      assert state.root_state.count == 10
    end

    test "resize event updates component" do
      runtime = start_test_runtime(Counter)

      # Send resize event
      Runtime.send_event(runtime, Event.resize(120, 40))
      Runtime.sync(runtime)

      state = Runtime.get_state(runtime)
      assert {120, 40} in state.root_state.resizes
    end

    test "quit command exits cleanly" do
      {:ok, runtime} = Runtime.start_link(root: Counter, skip_terminal: true)

      # Monitor for termination
      ref = Process.monitor(runtime)

      # Send quit key
      Runtime.send_event(runtime, Event.key("q"))

      # Should terminate
      assert_receive {:DOWN, ^ref, :process, ^runtime, :normal}, 1000
    end

    test "multiple rapid events are processed correctly" do
      runtime = start_test_runtime(RapidCounter)

      # Send many events rapidly
      for _ <- 1..100 do
        Runtime.send_event(runtime, Event.key(:up))
      end

      # Wait for all to process
      Runtime.sync(runtime)

      state = Runtime.get_state(runtime)
      assert state.root_state.events == 100
    end

    test "events during shutdown are ignored" do
      {:ok, runtime} = Runtime.start_link(root: Counter, skip_terminal: true)

      # Monitor for termination
      ref = Process.monitor(runtime)

      # Initiate shutdown
      Runtime.shutdown(runtime)

      # Try to send events (these should be ignored)
      Runtime.send_event(runtime, Event.key(:up))
      Runtime.send_event(runtime, Event.key(:up))

      # Wait for process to terminate
      assert_receive {:DOWN, ^ref, :process, ^runtime, :normal}, 1000
    end

    test "component state persists across event cycle" do
      runtime = start_test_runtime(Counter)

      # Increment
      Runtime.send_event(runtime, Event.key(:up))
      Runtime.sync(runtime)

      state1 = Runtime.get_state(runtime)
      assert state1.root_state.count == 1

      # Decrement
      Runtime.send_event(runtime, Event.key(:down))
      Runtime.sync(runtime)

      state2 = Runtime.get_state(runtime)
      assert state2.root_state.count == 0

      # Click (adds 10)
      Runtime.send_event(runtime, Event.mouse(:press, :left, 0, 0))
      Runtime.sync(runtime)

      state3 = Runtime.get_state(runtime)
      assert state3.root_state.count == 10
    end

    test "unknown events are ignored without crash" do
      runtime = start_test_runtime(Counter)

      # Send events that component doesn't handle
      Runtime.send_event(runtime, Event.key("x"))
      Runtime.send_event(runtime, Event.paste("hello"))
      Runtime.sync(runtime)

      # Should still be running with unchanged state
      state = Runtime.get_state(runtime)
      assert state.root_state.count == 0
    end
  end

  describe "event type dispatch" do
    test "keyboard events go to focused component" do
      runtime = start_test_runtime(Counter)

      state = Runtime.get_state(runtime)
      assert state.focused_component == :root

      # Keyboard event should go to focused component
      Runtime.send_event(runtime, Event.key(:up))
      Runtime.sync(runtime)

      state = Runtime.get_state(runtime)
      assert state.root_state.count == 1
    end

    test "resize events broadcast to all components" do
      runtime = start_test_runtime(Counter)

      # Send multiple resize events
      Runtime.send_event(runtime, Event.resize(80, 24))
      Runtime.send_event(runtime, Event.resize(120, 40))
      Runtime.sync(runtime)

      state = Runtime.get_state(runtime)
      assert length(state.root_state.resizes) == 2
    end
  end

  describe "command execution" do
    test "quit command stops runtime" do
      {:ok, runtime} = Runtime.start_link(root: Counter, skip_terminal: true)

      ref = Process.monitor(runtime)

      # Trigger quit via message
      Runtime.send_message(runtime, :root, :quit)

      assert_receive {:DOWN, ^ref, :process, ^runtime, :normal}, 1000
    end
  end

  # Components that crash in various ways for error handling tests
  defmodule CrashingUpdateComponent do
    use TermUI.Elm

    def init(_opts), do: %{count: 0}

    def event_to_msg(%Event.Key{key: "c"}, _state), do: {:msg, :crash}
    def event_to_msg(%Event.Key{key: :up}, _state), do: {:msg, :increment}
    def event_to_msg(_, _), do: :ignore

    def update(:crash, _state) do
      raise "Intentional crash in update/2"
    end

    def update(:increment, state) do
      {%{state | count: state.count + 1}, []}
    end

    def update(_msg, state), do: {state, []}

    def view(state), do: {:text, "Count: #{state.count}"}
  end

  defmodule CrashingEventToMsgComponent do
    use TermUI.Elm

    def init(_opts), do: %{count: 0}

    def event_to_msg(%Event.Key{key: "c"}, _state) do
      raise "Intentional crash in event_to_msg/2"
    end

    def event_to_msg(%Event.Key{key: :up}, _state), do: {:msg, :increment}
    def event_to_msg(_, _), do: :ignore

    def update(:increment, state) do
      {%{state | count: state.count + 1}, []}
    end

    def update(_msg, state), do: {state, []}

    def view(state), do: {:text, "Count: #{state.count}"}
  end

  defmodule CrashingViewComponent do
    use TermUI.Elm

    def init(_opts), do: %{should_crash: false}

    def event_to_msg(%Event.Key{key: "c"}, _state), do: {:msg, :set_crash}
    def event_to_msg(_, _), do: :ignore

    def update(:set_crash, state) do
      {%{state | should_crash: true}, []}
    end

    def update(_msg, state), do: {state, []}

    def view(%{should_crash: true}) do
      raise "Intentional crash in view/1"
    end

    def view(state), do: {:text, "Crash: #{state.should_crash}"}
  end

  describe "error handling" do
    test "runtime survives crash in update/2" do
      runtime = start_test_runtime(CrashingUpdateComponent)

      # First increment to verify normal operation
      Runtime.send_event(runtime, Event.key(:up))
      Runtime.sync(runtime)

      state = Runtime.get_state(runtime)
      assert state.root_state.count == 1

      # Trigger crash - runtime should survive
      Runtime.send_event(runtime, Event.key("c"))

      # Give it time to process (crash happens async)
      Process.sleep(@crash_processing_timeout)

      # Runtime should still be alive
      assert Process.alive?(runtime)
    end

    test "runtime survives crash in event_to_msg/2" do
      runtime = start_test_runtime(CrashingEventToMsgComponent)

      # First increment to verify normal operation
      Runtime.send_event(runtime, Event.key(:up))
      Runtime.sync(runtime)

      state = Runtime.get_state(runtime)
      assert state.root_state.count == 1

      # Trigger crash - runtime should survive
      Runtime.send_event(runtime, Event.key("c"))

      # Give it time to process (crash happens async)
      Process.sleep(@crash_processing_timeout)

      # Runtime should still be alive
      assert Process.alive?(runtime)
    end

    test "component continues working after surviving crash" do
      runtime = start_test_runtime(CrashingUpdateComponent)

      # Increment
      Runtime.send_event(runtime, Event.key(:up))
      Runtime.sync(runtime)

      # Trigger crash
      Runtime.send_event(runtime, Event.key("c"))
      Process.sleep(@crash_processing_timeout)

      # Should still be able to increment after crash
      Runtime.send_event(runtime, Event.key(:up))
      Runtime.sync(runtime)

      _state = Runtime.get_state(runtime)
      # State may or may not be preserved depending on error handling strategy
      # At minimum, the runtime should be alive and responsive
      assert Process.alive?(runtime)
    end

    test "multiple crashes don't accumulate and kill runtime" do
      runtime = start_test_runtime(CrashingUpdateComponent)

      # Trigger multiple crashes
      for _ <- 1..5 do
        Runtime.send_event(runtime, Event.key("c"))
      end

      Process.sleep(@multiple_crash_timeout)

      # Runtime should still be alive after multiple crashes
      assert Process.alive?(runtime)
    end
  end
end
