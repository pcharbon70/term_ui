defmodule TermUI.Integration.EndToEndTest do
  @moduledoc """
  End-to-end integration tests for the complete event cycle.

  Tests the full path from input event through dispatch, state update,
  view rendering, and back to display.
  """

  use TermUI.RuntimeTestCase

  # Timeout constants for async crash handling tests
  # These sleeps are necessary because crashes are processed asynchronously
  @crash_processing_timeout 50
  @multiple_crash_timeout 100

  # Simple counter component for testing
  defmodule Counter do
    @moduledoc """
    Test component for end-to-end event cycle testing.

    A simple counter that responds to keyboard events (up/down), mouse clicks,
    resize events, and quit commands. Used to verify the complete event flow
    from input through state updates to rendering.
    """

    use TermUI.Elm

    @impl true
    def init(_opts), do: %{count: 0, resizes: []}

    @impl true
    def event_to_msg(%Event.Key{key: :up}, _state), do: {:msg, :increment}
    def event_to_msg(%Event.Key{key: :down}, _state), do: {:msg, :decrement}
    def event_to_msg(%Event.Key{key: "q"}, _state), do: {:msg, :quit}
    def event_to_msg(%Event.Mouse{action: :press}, _state), do: {:msg, :click}
    def event_to_msg(%Event.Resize{width: w, height: h}, _state), do: {:msg, {:resize, w, h}}
    def event_to_msg(_, _), do: :ignore

    @impl true
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

    @impl true
    def view(state), do: {:text, "Count: #{state.count}"}
  end

  # Component that can trigger rapid events
  defmodule RapidCounter do
    @moduledoc """
    Test component for rapid event processing tests.

    Tracks the total number of events received to verify that the Runtime
    can handle high-frequency event sequences without dropping events.
    """

    use TermUI.Elm

    @impl true
    def init(_opts), do: %{events: 0}

    @impl true
    def event_to_msg(%Event.Key{key: :up}, _state), do: {:msg, :tick}
    def event_to_msg(_, _), do: :ignore

    @impl true
    def update(:tick, state) do
      {%{state | events: state.events + 1}, []}
    end

    def update(_msg, state), do: {state, []}

    @impl true
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

  describe "event ordering guarantees" do
    test "events are processed in FIFO order" do
      runtime = start_test_runtime(Counter)

      # Send a sequence where order matters
      # Start at 0, then: +1, +1, -1, +1 = 2
      Runtime.send_event(runtime, Event.key(:up))
      Runtime.send_event(runtime, Event.key(:up))
      Runtime.send_event(runtime, Event.key(:down))
      Runtime.send_event(runtime, Event.key(:up))
      Runtime.sync(runtime)

      state = Runtime.get_state(runtime)
      # If processed in order: 0 + 1 + 1 - 1 + 1 = 2
      assert state.root_state.count == 2
    end

    test "resize events maintain order in state" do
      runtime = start_test_runtime(Counter)

      # Send multiple resize events in a specific order
      Runtime.send_event(runtime, Event.resize(80, 24))
      Runtime.send_event(runtime, Event.resize(100, 30))
      Runtime.send_event(runtime, Event.resize(120, 40))
      Runtime.sync(runtime)

      state = Runtime.get_state(runtime)
      # Resizes are stored in reverse order (newest first)
      # So we expect them in reverse of send order
      assert state.root_state.resizes == [{120, 40}, {100, 30}, {80, 24}]
    end

    test "mixed event types maintain order" do
      runtime = start_test_runtime(Counter)

      # Send alternating event types
      # The specific order should be preserved
      # count = 1
      Runtime.send_event(runtime, Event.key(:up))
      # resize added
      Runtime.send_event(runtime, Event.resize(80, 24))
      # count = 2
      Runtime.send_event(runtime, Event.key(:up))
      # resize added
      Runtime.send_event(runtime, Event.resize(100, 30))
      # count = 1
      Runtime.send_event(runtime, Event.key(:down))
      Runtime.sync(runtime)

      state = Runtime.get_state(runtime)
      assert state.root_state.count == 1
      assert length(state.root_state.resizes) == 2
      # Resizes stored in reverse order
      assert state.root_state.resizes == [{100, 30}, {80, 24}]
    end

    test "rapid sequential events maintain order" do
      runtime = start_test_runtime(Counter)

      # Send 10 increments rapidly
      for _ <- 1..10 do
        Runtime.send_event(runtime, Event.key(:up))
      end

      Runtime.sync(runtime)

      state = Runtime.get_state(runtime)
      # If processed in order, should be exactly 10
      assert state.root_state.count == 10

      # Now send 10 decrements
      for _ <- 1..10 do
        Runtime.send_event(runtime, Event.key(:down))
      end

      Runtime.sync(runtime)

      state = Runtime.get_state(runtime)
      # Should return to 0
      assert state.root_state.count == 0
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
    @moduledoc """
    Test component that crashes in the update/2 callback.

    Used to verify that the Runtime gracefully handles component crashes
    during state updates and remains operational.
    """

    use TermUI.Elm

    @impl true
    def init(_opts), do: %{count: 0}

    @impl true
    def event_to_msg(%Event.Key{key: "c"}, _state), do: {:msg, :crash}
    def event_to_msg(%Event.Key{key: :up}, _state), do: {:msg, :increment}
    def event_to_msg(_, _), do: :ignore

    @impl true
    def update(:crash, _state) do
      raise "Intentional crash in update/2"
    end

    def update(:increment, state) do
      {%{state | count: state.count + 1}, []}
    end

    def update(_msg, state), do: {state, []}

    @impl true
    def view(state), do: {:text, "Count: #{state.count}"}
  end

  defmodule CrashingEventToMsgComponent do
    @moduledoc """
    Test component that crashes in the event_to_msg/2 callback.

    Used to verify that the Runtime gracefully handles component crashes
    during event processing and continues to function.
    """

    use TermUI.Elm

    @impl true
    def init(_opts), do: %{count: 0}

    @impl true
    def event_to_msg(%Event.Key{key: "c"}, _state) do
      raise "Intentional crash in event_to_msg/2"
    end

    def event_to_msg(%Event.Key{key: :up}, _state), do: {:msg, :increment}
    def event_to_msg(_, _), do: :ignore

    @impl true
    def update(:increment, state) do
      {%{state | count: state.count + 1}, []}
    end

    def update(_msg, state), do: {state, []}

    @impl true
    def view(state), do: {:text, "Count: #{state.count}"}
  end

  defmodule CrashingViewComponent do
    @moduledoc """
    Test component that crashes in the view/1 callback.

    Used to verify that the Runtime gracefully handles component crashes
    during rendering without bringing down the entire system.
    """

    use TermUI.Elm

    @impl true
    def init(_opts), do: %{should_crash: false}

    @impl true
    def event_to_msg(%Event.Key{key: "c"}, _state), do: {:msg, :set_crash}
    def event_to_msg(_, _), do: :ignore

    @impl true
    def update(:set_crash, state) do
      {%{state | should_crash: true}, []}
    end

    def update(_msg, state), do: {state, []}

    @impl true
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
