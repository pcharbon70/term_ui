defmodule TermUI.Integration.PropertyTest do
  @moduledoc """
  Property-based tests for event sequences using StreamData.

  These tests generate arbitrary event sequences and verify that the Runtime
  maintains invariants regardless of the specific events sent.

  ## Invariants Tested

  1. **Runtime Stability** - Runtime never crashes from any event sequence
  2. **State Consistency** - State transformations are predictable
  3. **Focus Validity** - Focus is always valid in multi-component scenarios
  4. **Clean Shutdown** - No zombie processes after runtime stops

  ## Why Property-Based Testing?

  Traditional unit tests verify specific scenarios, but can miss edge cases.
  Property-based tests generate random inputs to find unexpected failures.
  """

  use TermUI.RuntimeTestCase
  use ExUnitProperties

  # Simple counter component for property testing
  defmodule PropertyCounter do
    @moduledoc """
    Counter component for property-based testing.

    Tracks both count (up/down) and total events received, enabling
    property tests to verify event processing invariants with random
    event sequences.
    """

    use TermUI.Elm

    @impl true
    def init(_opts), do: %{count: 0, events_received: 0}

    @impl true
    def event_to_msg(%Event.Key{key: :up}, _state), do: {:msg, :increment}
    def event_to_msg(%Event.Key{key: :down}, _state), do: {:msg, :decrement}
    def event_to_msg(%Event.Mouse{}, _state), do: {:msg, :mouse}
    def event_to_msg(%Event.Resize{}, _state), do: {:msg, :resize}
    def event_to_msg(_, _state), do: :ignore

    @impl true
    def update(:increment, state) do
      {%{state | count: state.count + 1, events_received: state.events_received + 1}, []}
    end

    def update(:decrement, state) do
      {%{state | count: state.count - 1, events_received: state.events_received + 1}, []}
    end

    def update(:mouse, state) do
      {%{state | events_received: state.events_received + 1}, []}
    end

    def update(:resize, state) do
      {%{state | events_received: state.events_received + 1}, []}
    end

    @impl true
    def view(state), do: {:text, "Count: #{state.count}"}
  end

  # Multi-component for focus testing
  defmodule PropertyMultiRoot do
    @moduledoc """
    Multi-component root for property-based focus testing.

    Manages focus between two children with keyboard (Tab) and mouse
    input. Used to verify focus invariants (always valid) and count
    consistency across random event sequences.
    """

    use TermUI.Elm

    @impl true
    def init(_opts) do
      %{
        focused: :child_a,
        child_a_count: 0,
        child_b_count: 0
      }
    end

    @impl true
    def event_to_msg(%Event.Key{key: :tab}, _state), do: {:msg, :toggle_focus}
    def event_to_msg(%Event.Key{key: :up}, state), do: {:msg, {:increment, state.focused}}
    def event_to_msg(%Event.Mouse{x: x}, _state) when x < 40, do: {:msg, :focus_a}
    def event_to_msg(%Event.Mouse{x: x}, _state) when x >= 40, do: {:msg, :focus_b}
    def event_to_msg(_, _state), do: :ignore

    @impl true
    def update(:toggle_focus, %{focused: :child_a} = state) do
      {%{state | focused: :child_b}, []}
    end

    def update(:toggle_focus, %{focused: :child_b} = state) do
      {%{state | focused: :child_a}, []}
    end

    def update({:increment, :child_a}, state) do
      {%{state | child_a_count: state.child_a_count + 1}, []}
    end

    def update({:increment, :child_b}, state) do
      {%{state | child_b_count: state.child_b_count + 1}, []}
    end

    def update(:focus_a, state), do: {%{state | focused: :child_a}, []}
    def update(:focus_b, state), do: {%{state | focused: :child_b}, []}

    @impl true
    def view(state) do
      {:text, "Focus: #{state.focused}, A: #{state.child_a_count}, B: #{state.child_b_count}"}
    end
  end

  # Event Generators

  defp key_event do
    gen all(key <- one_of([constant(:up), constant(:down), constant(:left), constant(:right)])) do
      Event.key(key)
    end
  end

  defp mouse_event do
    gen all(
          x <- integer(0..79),
          y <- integer(0..23),
          action <- one_of([constant(:press), constant(:release)]),
          button <- one_of([constant(:left), constant(:right)])
        ) do
      Event.mouse(action, button, x, y)
    end
  end

  defp resize_event do
    gen all(
          width <- integer(40..200),
          height <- integer(20..60)
        ) do
      Event.resize(width, height)
    end
  end

  defp any_event do
    one_of([key_event(), mouse_event(), resize_event()])
  end

  defp event_sequence(max_length \\ 50) do
    list_of(any_event(), max_length: max_length)
  end

  # Property Tests

  describe "runtime stability properties" do
    property "runtime survives any event sequence" do
      check all(events <- event_sequence(30)) do
        runtime = start_test_runtime(PropertyCounter)

        # Send all events
        for event <- events do
          Runtime.send_event(runtime, event)
        end

        Runtime.sync(runtime)

        # Runtime should still be alive
        assert Process.alive?(runtime)

        # Should be able to get state
        state = Runtime.get_state(runtime)
        assert is_map(state)
        assert is_map(state.root_state)
      end
    end

    property "all events are processed" do
      check all(events <- event_sequence(20)) do
        runtime = start_test_runtime(PropertyCounter)

        # Send events
        for event <- events do
          Runtime.send_event(runtime, event)
        end

        Runtime.sync(runtime)

        state = Runtime.get_state(runtime)

        # Count how many events should have been processed (not ignored)
        processable_events =
          Enum.count(events, fn
            %Event.Key{key: key} when key in [:up, :down] -> true
            %Event.Mouse{} -> true
            %Event.Resize{} -> true
            _ -> false
          end)

        # All processable events should have been handled
        assert state.root_state.events_received == processable_events
      end
    end
  end

  describe "state consistency properties" do
    property "counter reflects up/down balance" do
      check all(events <- event_sequence(20)) do
        runtime = start_test_runtime(PropertyCounter)

        for event <- events do
          Runtime.send_event(runtime, event)
        end

        Runtime.sync(runtime)

        state = Runtime.get_state(runtime)

        # Count ups and downs
        ups = Enum.count(events, &match?(%Event.Key{key: :up}, &1))
        downs = Enum.count(events, &match?(%Event.Key{key: :down}, &1))

        # Count should equal ups - downs
        assert state.root_state.count == ups - downs
      end
    end

    property "state fields remain valid types" do
      check all(events <- event_sequence(30)) do
        runtime = start_test_runtime(PropertyCounter)

        for event <- events do
          Runtime.send_event(runtime, event)
        end

        Runtime.sync(runtime)

        state = Runtime.get_state(runtime)

        # Type invariants
        assert is_integer(state.root_state.count)
        assert is_integer(state.root_state.events_received)
        assert state.root_state.events_received >= 0
      end
    end
  end

  describe "multi-component focus properties" do
    property "focus is always valid" do
      check all(events <- event_sequence(20)) do
        runtime = start_test_runtime(PropertyMultiRoot)

        for event <- events do
          Runtime.send_event(runtime, event)
        end

        Runtime.sync(runtime)

        state = Runtime.get_state(runtime)

        # Focus must be one of the valid values
        assert state.root_state.focused in [:child_a, :child_b]
      end
    end

    property "component counts are non-negative" do
      check all(events <- event_sequence(25)) do
        runtime = start_test_runtime(PropertyMultiRoot)

        for event <- events do
          Runtime.send_event(runtime, event)
        end

        Runtime.sync(runtime)

        state = Runtime.get_state(runtime)

        # Counts should never go negative (no decrement in this component)
        assert state.root_state.child_a_count >= 0
        assert state.root_state.child_b_count >= 0
      end
    end

    property "total increments match up key presses" do
      check all(events <- event_sequence(20)) do
        runtime = start_test_runtime(PropertyMultiRoot)

        for event <- events do
          Runtime.send_event(runtime, event)
        end

        Runtime.sync(runtime)

        state = Runtime.get_state(runtime)

        # Count total up keys
        up_count = Enum.count(events, &match?(%Event.Key{key: :up}, &1))

        # Total increments should match
        total_increments = state.root_state.child_a_count + state.root_state.child_b_count
        assert total_increments == up_count
      end
    end
  end

  describe "cleanup properties" do
    property "runtime shuts down cleanly after any event sequence" do
      check all(events <- event_sequence(15)) do
        {:ok, runtime} = Runtime.start_link(root: PropertyCounter, skip_terminal: true)
        ref = Process.monitor(runtime)

        for event <- events do
          Runtime.send_event(runtime, event)
        end

        Runtime.sync(runtime)

        # Shutdown
        Runtime.shutdown(runtime)

        # Should terminate
        assert_receive {:DOWN, ^ref, :process, ^runtime, :normal}, 1000

        # Should not be alive
        refute Process.alive?(runtime)
      end
    end
  end
end
