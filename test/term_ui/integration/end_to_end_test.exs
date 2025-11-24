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

  # Simple counter component for testing
  defmodule Counter do
    @behaviour TermUI.Elm

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
    @behaviour TermUI.Elm

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
      {:ok, runtime} = Runtime.start_link(root: Counter, skip_terminal: true)

      # Send key events
      Runtime.send_event(runtime, Event.key(:up))
      Runtime.send_event(runtime, Event.key(:up))
      Runtime.send_event(runtime, Event.key(:up))
      Process.sleep(100)

      state = Runtime.get_state(runtime)
      assert state.root_state.count == 3

      Runtime.shutdown(runtime)
      Process.sleep(50)
    end

    test "mouse click dispatches to component" do
      {:ok, runtime} = Runtime.start_link(root: Counter, skip_terminal: true)

      # Send mouse click event
      Runtime.send_event(runtime, Event.mouse(:press, :left, 10, 5))
      Process.sleep(50)

      state = Runtime.get_state(runtime)
      assert state.root_state.count == 10

      Runtime.shutdown(runtime)
      Process.sleep(50)
    end

    test "resize event updates component" do
      {:ok, runtime} = Runtime.start_link(root: Counter, skip_terminal: true)

      # Send resize event
      Runtime.send_event(runtime, Event.resize(120, 40))
      Process.sleep(50)

      state = Runtime.get_state(runtime)
      assert {120, 40} in state.root_state.resizes

      Runtime.shutdown(runtime)
      Process.sleep(50)
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
      {:ok, runtime} = Runtime.start_link(root: RapidCounter, skip_terminal: true)

      # Send many events rapidly
      for _ <- 1..100 do
        Runtime.send_event(runtime, Event.key(:up))
      end

      # Wait for all to process
      Process.sleep(200)

      state = Runtime.get_state(runtime)
      assert state.root_state.events == 100

      Runtime.shutdown(runtime)
      Process.sleep(50)
    end

    test "events during shutdown are ignored" do
      {:ok, runtime} = Runtime.start_link(root: Counter, skip_terminal: true)

      # Initiate shutdown
      Runtime.shutdown(runtime)

      # Try to send events
      Runtime.send_event(runtime, Event.key(:up))
      Runtime.send_event(runtime, Event.key(:up))

      Process.sleep(100)

      # Process should be stopped
      refute Process.alive?(runtime)
    end

    test "component state persists across event cycle" do
      {:ok, runtime} = Runtime.start_link(root: Counter, skip_terminal: true)

      # Increment
      Runtime.send_event(runtime, Event.key(:up))
      Process.sleep(50)

      state1 = Runtime.get_state(runtime)
      assert state1.root_state.count == 1

      # Decrement
      Runtime.send_event(runtime, Event.key(:down))
      Process.sleep(50)

      state2 = Runtime.get_state(runtime)
      assert state2.root_state.count == 0

      # Click (adds 10)
      Runtime.send_event(runtime, Event.mouse(:press, :left, 0, 0))
      Process.sleep(50)

      state3 = Runtime.get_state(runtime)
      assert state3.root_state.count == 10

      Runtime.shutdown(runtime)
      Process.sleep(50)
    end

    test "unknown events are ignored without crash" do
      {:ok, runtime} = Runtime.start_link(root: Counter, skip_terminal: true)

      # Send events that component doesn't handle
      Runtime.send_event(runtime, Event.key("x"))
      Runtime.send_event(runtime, Event.paste("hello"))
      Process.sleep(50)

      # Should still be running with unchanged state
      state = Runtime.get_state(runtime)
      assert state.root_state.count == 0

      Runtime.shutdown(runtime)
      Process.sleep(50)
    end
  end

  describe "event type dispatch" do
    test "keyboard events go to focused component" do
      {:ok, runtime} = Runtime.start_link(root: Counter, skip_terminal: true)

      state = Runtime.get_state(runtime)
      assert state.focused_component == :root

      # Keyboard event should go to focused component
      Runtime.send_event(runtime, Event.key(:up))
      Process.sleep(50)

      state = Runtime.get_state(runtime)
      assert state.root_state.count == 1

      Runtime.shutdown(runtime)
      Process.sleep(50)
    end

    test "resize events broadcast to all components" do
      {:ok, runtime} = Runtime.start_link(root: Counter, skip_terminal: true)

      # Send multiple resize events
      Runtime.send_event(runtime, Event.resize(80, 24))
      Runtime.send_event(runtime, Event.resize(120, 40))
      Process.sleep(100)

      state = Runtime.get_state(runtime)
      assert length(state.root_state.resizes) == 2

      Runtime.shutdown(runtime)
      Process.sleep(50)
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
end
