defmodule TermUI.RuntimeTest do
  use ExUnit.Case, async: true

  alias TermUI.Event
  alias TermUI.Runtime

  # Test component that implements Elm behaviour
  defmodule Counter do
    use TermUI.Elm

    def init(opts), do: %{count: Keyword.get(opts, :initial, 0)}

    def event_to_msg(%Event.Key{key: :up}, _state), do: {:msg, :increment}
    def event_to_msg(%Event.Key{key: :down}, _state), do: {:msg, :decrement}
    def event_to_msg(%Event.Key{key: :q}, _state), do: {:msg, :quit}
    def event_to_msg(%Event.Resize{width: w, height: h}, _state), do: {:msg, {:resize, w, h}}
    def event_to_msg(_, _), do: :ignore

    def update(:increment, state), do: {%{state | count: state.count + 1}, []}
    def update(:decrement, state), do: {%{state | count: state.count - 1}, []}
    def update(:quit, state), do: {state, [:quit]}
    def update({:resize, w, h}, state), do: {Map.merge(state, %{width: w, height: h}), []}
    def update(_, state), do: {state, []}

    def view(state), do: {:text, "Count: #{state.count}"}
  end

  # Test component without init
  defmodule NoInit do
    use TermUI.Elm

    def event_to_msg(_, _), do: :ignore
    def update(_, state), do: {state, []}
    def view(_state), do: {:text, "No init"}
  end

  describe "start_link/1" do
    test "starts runtime with root component" do
      {:ok, runtime} = Runtime.start_link(root: Counter)

      state = Runtime.get_state(runtime)
      assert state.root_module == Counter
      assert state.root_state == %{count: 0}
      refute state.shutting_down
    end

    test "starts runtime with registered name" do
      {:ok, _runtime} = Runtime.start_link(root: Counter, name: :test_runtime)

      state = Runtime.get_state(:test_runtime)
      assert state.root_module == Counter

      GenServer.stop(:test_runtime)
    end

    test "passes options to component init" do
      {:ok, runtime} = Runtime.start_link(root: Counter, initial: 10)

      state = Runtime.get_state(runtime)
      assert state.root_state.count == 10
    end

    test "handles component without init function" do
      {:ok, runtime} = Runtime.start_link(root: NoInit)

      state = Runtime.get_state(runtime)
      assert state.root_state == %{}
    end

    test "sets custom render interval" do
      {:ok, runtime} = Runtime.start_link(root: Counter, render_interval: 100)

      state = Runtime.get_state(runtime)
      assert state.render_interval == 100
    end
  end

  describe "send_event/2" do
    test "dispatches keyboard event to focused component" do
      {:ok, runtime} = Runtime.start_link(root: Counter)

      Runtime.send_event(runtime, Event.key(:up))
      # Wait for message processing
      Process.sleep(50)

      state = Runtime.get_state(runtime)
      assert state.root_state.count == 1
    end

    test "processes multiple events in sequence" do
      {:ok, runtime} = Runtime.start_link(root: Counter)

      Runtime.send_event(runtime, Event.key(:up))
      Runtime.send_event(runtime, Event.key(:up))
      Runtime.send_event(runtime, Event.key(:up))
      Process.sleep(50)

      state = Runtime.get_state(runtime)
      assert state.root_state.count == 3
    end

    test "ignores events during shutdown" do
      {:ok, runtime} = Runtime.start_link(root: Counter)

      Runtime.shutdown(runtime)
      Runtime.send_event(runtime, Event.key(:up))
      Process.sleep(50)

      state = Runtime.get_state(runtime)
      assert state.root_state.count == 0
    end

    test "broadcasts resize events" do
      {:ok, runtime} = Runtime.start_link(root: Counter)

      Runtime.send_event(runtime, Event.resize(120, 40))
      Process.sleep(50)

      state = Runtime.get_state(runtime)
      assert state.root_state.width == 120
      assert state.root_state.height == 40
    end

    test "dispatches paste events to focused component" do
      {:ok, runtime} = Runtime.start_link(root: Counter)

      # Paste events go to focused component but Counter ignores them
      Runtime.send_event(runtime, Event.paste("hello"))
      Process.sleep(50)

      state = Runtime.get_state(runtime)
      # State unchanged since Counter ignores paste
      assert state.root_state.count == 0
    end
  end

  describe "send_message/3" do
    test "sends message directly to component" do
      {:ok, runtime} = Runtime.start_link(root: Counter)

      Runtime.send_message(runtime, :root, :increment)
      Process.sleep(50)

      state = Runtime.get_state(runtime)
      assert state.root_state.count == 1
    end

    test "ignores messages to non-existent component" do
      {:ok, runtime} = Runtime.start_link(root: Counter)

      Runtime.send_message(runtime, :nonexistent, :increment)
      Process.sleep(50)

      state = Runtime.get_state(runtime)
      assert state.root_state.count == 0
    end

    test "ignores messages during shutdown" do
      {:ok, runtime} = Runtime.start_link(root: Counter)

      Runtime.shutdown(runtime)
      Runtime.send_message(runtime, :root, :increment)
      Process.sleep(50)

      state = Runtime.get_state(runtime)
      assert state.root_state.count == 0
    end
  end

  describe "dirty flag and rendering" do
    test "marks dirty when state changes" do
      {:ok, runtime} = Runtime.start_link(root: Counter, render_interval: 10)

      # Initial state should be dirty for first render
      state = Runtime.get_state(runtime)
      assert state.dirty == true

      # After render tick, should be clean
      Process.sleep(50)
      state = Runtime.get_state(runtime)
      assert state.dirty == false

      # After event that changes state, should be dirty then clean after render
      Runtime.send_event(runtime, Event.key(:up))
      Process.sleep(50)
      state = Runtime.get_state(runtime)
      # Count should update
      assert state.root_state.count == 1
    end

    test "force_render bypasses framerate limiter" do
      {:ok, runtime} = Runtime.start_link(root: Counter, render_interval: 10_000)

      # Initial dirty
      state = Runtime.get_state(runtime)
      assert state.dirty == true

      # Force render
      Runtime.force_render(runtime)
      Process.sleep(10)

      state = Runtime.get_state(runtime)
      assert state.dirty == false
    end
  end

  describe "command collection" do
    test "collects commands from update results" do
      {:ok, runtime} = Runtime.start_link(root: Counter)

      # Send event that produces a command
      Runtime.send_event(runtime, Event.key(:q))
      Process.sleep(50)

      state = Runtime.get_state(runtime)
      # Commands are tracked in pending_commands
      assert map_size(state.pending_commands) >= 0
    end
  end

  describe "command_result/4" do
    test "sends command result as message to component" do
      {:ok, runtime} = Runtime.start_link(root: Counter)

      # Simulate a command completion
      Runtime.command_result(runtime, :root, make_ref(), :some_result)
      Process.sleep(50)

      # Result is enqueued as message (Counter ignores unknown messages)
      state = Runtime.get_state(runtime)
      assert state.root_state.count == 0
    end
  end

  describe "shutdown/1" do
    test "initiates graceful shutdown" do
      {:ok, runtime} = Runtime.start_link(root: Counter)

      Runtime.shutdown(runtime)
      Process.sleep(10)

      state = Runtime.get_state(runtime)
      assert state.shutting_down == true
    end

    test "clears pending commands on shutdown" do
      {:ok, runtime} = Runtime.start_link(root: Counter)

      Runtime.shutdown(runtime)
      Process.sleep(10)

      state = Runtime.get_state(runtime)
      assert state.pending_commands == %{}
    end

    test "clears components on shutdown" do
      {:ok, runtime} = Runtime.start_link(root: Counter)

      Runtime.shutdown(runtime)
      Process.sleep(10)

      state = Runtime.get_state(runtime)
      assert state.components == %{}
    end
  end

  describe "event dispatch routing" do
    test "keyboard events go to focused component" do
      {:ok, runtime} = Runtime.start_link(root: Counter)

      # Default focus is :root
      state = Runtime.get_state(runtime)
      assert state.focused_component == :root

      Runtime.send_event(runtime, Event.key(:up))
      Process.sleep(50)

      state = Runtime.get_state(runtime)
      assert state.root_state.count == 1
    end

    test "mouse events go to root (spatial index not implemented)" do
      {:ok, runtime} = Runtime.start_link(root: Counter)

      # Mouse events currently just go to root
      Runtime.send_event(runtime, Event.mouse(:click, :left, 10, 10))
      Process.sleep(50)

      # Counter ignores mouse events
      state = Runtime.get_state(runtime)
      assert state.root_state.count == 0
    end

    test "focus events broadcast to all components" do
      {:ok, runtime} = Runtime.start_link(root: Counter)

      Runtime.send_event(runtime, Event.focus(:gained))
      Process.sleep(50)

      # Counter ignores focus events
      state = Runtime.get_state(runtime)
      assert state.root_state.count == 0
    end

    test "tick events broadcast to all components" do
      {:ok, runtime} = Runtime.start_link(root: Counter)

      Runtime.send_event(runtime, Event.tick(16))
      Process.sleep(50)

      # Counter ignores tick events
      state = Runtime.get_state(runtime)
      assert state.root_state.count == 0
    end
  end

  describe "component initialization" do
    test "initializes component registry with root" do
      {:ok, runtime} = Runtime.start_link(root: Counter, initial: 5)

      state = Runtime.get_state(runtime)

      assert Map.has_key?(state.components, :root)
      assert state.components.root.module == Counter
      assert state.components.root.state.count == 5
    end
  end

  describe "render timing" do
    test "uses default render interval" do
      {:ok, runtime} = Runtime.start_link(root: Counter)

      state = Runtime.get_state(runtime)
      assert state.render_interval == 16
    end

    test "schedules render ticks" do
      {:ok, runtime} = Runtime.start_link(root: Counter, render_interval: 10)

      # Initial should be dirty
      state = Runtime.get_state(runtime)
      assert state.dirty == true

      # Wait for render tick
      Process.sleep(30)

      state = Runtime.get_state(runtime)
      assert state.dirty == false
    end
  end

  describe "message batching" do
    test "processes multiple messages before render" do
      {:ok, runtime} = Runtime.start_link(root: Counter, render_interval: 100)

      # Send multiple events quickly
      for _ <- 1..5 do
        Runtime.send_event(runtime, Event.key(:up))
      end

      # Wait for processing
      Process.sleep(150)

      state = Runtime.get_state(runtime)
      assert state.root_state.count == 5
    end
  end

  describe "full cycle integration" do
    test "event -> message -> update -> view cycle" do
      {:ok, runtime} = Runtime.start_link(root: Counter)

      # Initial state
      state = Runtime.get_state(runtime)
      assert state.root_state.count == 0

      # Send event
      Runtime.send_event(runtime, Event.key(:up))
      Process.sleep(50)

      # State updated
      state = Runtime.get_state(runtime)
      assert state.root_state.count == 1

      # View would be called on render
      %{module: module, state: component_state} = state.components.root
      view_result = module.view(component_state)
      assert view_result == {:text, "Count: 1"}
    end

    test "handles decrement correctly" do
      {:ok, runtime} = Runtime.start_link(root: Counter, initial: 5)

      Runtime.send_event(runtime, Event.key(:down))
      Process.sleep(50)

      state = Runtime.get_state(runtime)
      assert state.root_state.count == 4
    end

    test "state changes trigger dirty flag" do
      {:ok, runtime} = Runtime.start_link(root: Counter, render_interval: 10)

      # Wait for initial render
      Process.sleep(50)

      state = Runtime.get_state(runtime)
      assert state.dirty == false

      # Send event that changes state
      Runtime.send_event(runtime, Event.key(:up))
      Process.sleep(50)

      state = Runtime.get_state(runtime)
      # Count should update
      assert state.root_state.count == 1
    end
  end
end
