defmodule TermUI.Integration.DashboardTest do
  @moduledoc """
  Integration tests for the Dashboard example application.

  Tests the dashboard component behavior including keyboard navigation,
  theme switching, and event handling.

  These tests use a mock Dashboard component since the actual Dashboard.App
  is in the examples directory and not compiled with the main test suite.
  """

  use ExUnit.Case, async: false

  alias TermUI.Runtime
  alias TermUI.Event

  # Helper to start runtime with automatic cleanup on test exit
  defp start_test_runtime(component) do
    {:ok, runtime} = Runtime.start_link(root: component, skip_terminal: true)

    on_exit(fn ->
      if Process.alive?(runtime), do: Runtime.shutdown(runtime)
    end)

    runtime
  end

  # Mock Dashboard component that mimics Dashboard.App behavior
  defmodule MockDashboard do
    @behaviour TermUI.Elm

    def init(_opts) do
      %{
        theme: :dark,
        selected_process: 0
      }
    end

    def event_to_msg(%Event.Key{key: "q"}, _state), do: {:msg, :quit}
    def event_to_msg(%Event.Key{key: "r"}, _state), do: {:msg, :refresh}
    def event_to_msg(%Event.Key{key: "t"}, _state), do: {:msg, :toggle_theme}
    def event_to_msg(%Event.Key{key: :down}, _state), do: {:msg, :select_next}
    def event_to_msg(%Event.Key{key: :up}, _state), do: {:msg, :select_prev}
    def event_to_msg(_, _state), do: :ignore

    def update(:quit, state), do: {state, [TermUI.Command.quit()]}
    def update(:refresh, state), do: {state, []}

    def update(:toggle_theme, state) do
      new_theme = if state.theme == :dark, do: :light, else: :dark
      {%{state | theme: new_theme}, []}
    end

    def update(:select_next, state) do
      # Limit to 10 processes for testing
      new_selected = min(state.selected_process + 1, 9)
      {%{state | selected_process: new_selected}, []}
    end

    def update(:select_prev, state) do
      new_selected = max(state.selected_process - 1, 0)
      {%{state | selected_process: new_selected}, []}
    end

    def update(_msg, state), do: {state, []}

    def view(state) do
      {:text, "Dashboard - Theme: #{state.theme}, Selected: #{state.selected_process}"}
    end
  end

  @dashboard_module MockDashboard

  describe "dashboard initialization" do
    test "dashboard starts with initial state" do
      runtime = start_test_runtime(@dashboard_module)

      state = Runtime.get_state(runtime)

      # Check initial dashboard state
      assert state.root_state.theme == :dark
      assert state.root_state.selected_process == 0
    end

    test "dashboard renders initial view" do
      runtime = start_test_runtime(@dashboard_module)

      state = Runtime.get_state(runtime)
      component = Map.get(state.components, :root)

      # View function should return a render tree
      view_result = component.module.view(component.state)
      assert is_tuple(view_result)
    end
  end

  describe "dashboard keyboard navigation" do
    test "'t' key toggles theme" do
      runtime = start_test_runtime(@dashboard_module)

      # Initial theme is dark
      state = Runtime.get_state(runtime)
      assert state.root_state.theme == :dark

      # Toggle theme
      Runtime.send_event(runtime, Event.key("t"))
      Runtime.sync(runtime)

      state = Runtime.get_state(runtime)
      assert state.root_state.theme == :light

      # Toggle again
      Runtime.send_event(runtime, Event.key("t"))
      Runtime.sync(runtime)

      state = Runtime.get_state(runtime)
      assert state.root_state.theme == :dark
    end

    test "down arrow selects next process" do
      runtime = start_test_runtime(@dashboard_module)

      # Initial selection is 0
      state = Runtime.get_state(runtime)
      assert state.root_state.selected_process == 0

      # Navigate down
      Runtime.send_event(runtime, Event.key(:down))
      Runtime.sync(runtime)

      state = Runtime.get_state(runtime)
      assert state.root_state.selected_process == 1
    end

    test "up arrow selects previous process" do
      runtime = start_test_runtime(@dashboard_module)

      # Navigate down first
      Runtime.send_event(runtime, Event.key(:down))
      Runtime.send_event(runtime, Event.key(:down))
      Runtime.sync(runtime)

      state = Runtime.get_state(runtime)
      assert state.root_state.selected_process == 2

      # Navigate up
      Runtime.send_event(runtime, Event.key(:up))
      Runtime.sync(runtime)

      state = Runtime.get_state(runtime)
      assert state.root_state.selected_process == 1
    end

    test "up arrow at top stays at 0" do
      runtime = start_test_runtime(@dashboard_module)

      # Try to navigate up from 0
      Runtime.send_event(runtime, Event.key(:up))
      Runtime.sync(runtime)

      state = Runtime.get_state(runtime)
      assert state.root_state.selected_process == 0
    end

    test "'r' key triggers refresh" do
      runtime = start_test_runtime(@dashboard_module)

      # Refresh just triggers re-render, state unchanged
      initial_state = Runtime.get_state(runtime)

      Runtime.send_event(runtime, Event.key("r"))
      Runtime.sync(runtime)

      state = Runtime.get_state(runtime)
      assert state.root_state.theme == initial_state.root_state.theme
      assert state.root_state.selected_process == initial_state.root_state.selected_process
    end
  end

  describe "dashboard quit behavior" do
    test "'q' key quits the dashboard" do
      {:ok, runtime} = Runtime.start_link(root: @dashboard_module, skip_terminal: true)

      # Monitor for termination
      ref = Process.monitor(runtime)

      # Send quit key
      Runtime.send_event(runtime, Event.key("q"))

      # Should terminate
      assert_receive {:DOWN, ^ref, :process, ^runtime, :normal}, 1000
    end
  end

  describe "dashboard state consistency" do
    test "multiple theme toggles maintain consistency" do
      runtime = start_test_runtime(@dashboard_module)

      # Toggle theme multiple times
      for _ <- 1..10 do
        Runtime.send_event(runtime, Event.key("t"))
      end
      Runtime.sync(runtime)

      state = Runtime.get_state(runtime)
      # Even number of toggles should return to dark
      assert state.root_state.theme == :dark
    end

    test "navigation and theme changes are independent" do
      runtime = start_test_runtime(@dashboard_module)

      # Navigate and toggle
      Runtime.send_event(runtime, Event.key(:down))
      Runtime.send_event(runtime, Event.key("t"))
      Runtime.send_event(runtime, Event.key(:down))
      Runtime.sync(runtime)

      state = Runtime.get_state(runtime)
      assert state.root_state.selected_process == 2
      assert state.root_state.theme == :light
    end

    test "rapid event handling maintains state integrity" do
      runtime = start_test_runtime(@dashboard_module)

      # Send many navigation events rapidly
      for _ <- 1..50 do
        Runtime.send_event(runtime, Event.key(:down))
      end
      Runtime.sync(runtime)

      state = Runtime.get_state(runtime)
      # Should be clamped to max process index
      assert state.root_state.selected_process == 9
    end
  end

  describe "dashboard event ignoring" do
    test "unknown keys are ignored" do
      runtime = start_test_runtime(@dashboard_module)

      initial_state = Runtime.get_state(runtime)

      # Send unknown keys
      Runtime.send_event(runtime, Event.key("x"))
      Runtime.send_event(runtime, Event.key("z"))
      Runtime.send_event(runtime, Event.key(:enter))
      Runtime.sync(runtime)

      state = Runtime.get_state(runtime)
      assert state.root_state == initial_state.root_state
    end

    test "mouse events are ignored" do
      runtime = start_test_runtime(@dashboard_module)

      initial_state = Runtime.get_state(runtime)

      # Send mouse events
      Runtime.send_event(runtime, Event.mouse(:press, :left, 10, 10))
      Runtime.send_event(runtime, Event.mouse(:release, :left, 10, 10))
      Runtime.sync(runtime)

      state = Runtime.get_state(runtime)
      assert state.root_state == initial_state.root_state
    end
  end

  describe "test isolation" do
    test "each test starts with fresh state" do
      runtime = start_test_runtime(@dashboard_module)

      state = Runtime.get_state(runtime)
      assert state.root_state.theme == :dark
      assert state.root_state.selected_process == 0
    end

    test "cleanup is complete" do
      {:ok, runtime} = Runtime.start_link(root: @dashboard_module, skip_terminal: true)

      # Modify state
      Runtime.send_event(runtime, Event.key("t"))
      Runtime.send_event(runtime, Event.key(:down))
      Runtime.sync(runtime)

      # Monitor for termination
      ref = Process.monitor(runtime)

      Runtime.shutdown(runtime)

      # Wait for process to terminate
      assert_receive {:DOWN, ^ref, :process, ^runtime, :normal}, 1000
    end
  end
end
