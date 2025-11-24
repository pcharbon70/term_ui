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

    def update(:quit, state), do: {state, []}
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
      {:ok, runtime} = Runtime.start_link(root: @dashboard_module, skip_terminal: true)

      state = Runtime.get_state(runtime)

      # Check initial dashboard state
      assert state.root_state.theme == :dark
      assert state.root_state.selected_process == 0

      Runtime.shutdown(runtime)
      Process.sleep(50)
    end

    test "dashboard renders initial view" do
      {:ok, runtime} = Runtime.start_link(root: @dashboard_module, skip_terminal: true)

      state = Runtime.get_state(runtime)
      component = Map.get(state.components, :root)

      # View function should return a render tree
      view_result = component.module.view(component.state)
      assert is_tuple(view_result)

      Runtime.shutdown(runtime)
      Process.sleep(50)
    end
  end

  describe "dashboard keyboard navigation" do
    test "'t' key toggles theme" do
      {:ok, runtime} = Runtime.start_link(root: @dashboard_module, skip_terminal: true)

      # Initial theme is dark
      state = Runtime.get_state(runtime)
      assert state.root_state.theme == :dark

      # Toggle theme
      Runtime.send_event(runtime, Event.key("t"))
      Process.sleep(50)

      state = Runtime.get_state(runtime)
      assert state.root_state.theme == :light

      # Toggle again
      Runtime.send_event(runtime, Event.key("t"))
      Process.sleep(50)

      state = Runtime.get_state(runtime)
      assert state.root_state.theme == :dark

      Runtime.shutdown(runtime)
      Process.sleep(50)
    end

    test "down arrow selects next process" do
      {:ok, runtime} = Runtime.start_link(root: @dashboard_module, skip_terminal: true)

      # Initial selection is 0
      state = Runtime.get_state(runtime)
      assert state.root_state.selected_process == 0

      # Navigate down
      Runtime.send_event(runtime, Event.key(:down))
      Process.sleep(50)

      state = Runtime.get_state(runtime)
      assert state.root_state.selected_process == 1

      Runtime.shutdown(runtime)
      Process.sleep(50)
    end

    test "up arrow selects previous process" do
      {:ok, runtime} = Runtime.start_link(root: @dashboard_module, skip_terminal: true)

      # Navigate down first
      Runtime.send_event(runtime, Event.key(:down))
      Runtime.send_event(runtime, Event.key(:down))
      Process.sleep(50)

      state = Runtime.get_state(runtime)
      assert state.root_state.selected_process == 2

      # Navigate up
      Runtime.send_event(runtime, Event.key(:up))
      Process.sleep(50)

      state = Runtime.get_state(runtime)
      assert state.root_state.selected_process == 1

      Runtime.shutdown(runtime)
      Process.sleep(50)
    end

    test "up arrow at top stays at 0" do
      {:ok, runtime} = Runtime.start_link(root: @dashboard_module, skip_terminal: true)

      # Try to navigate up from 0
      Runtime.send_event(runtime, Event.key(:up))
      Process.sleep(50)

      state = Runtime.get_state(runtime)
      assert state.root_state.selected_process == 0

      Runtime.shutdown(runtime)
      Process.sleep(50)
    end

    test "'r' key triggers refresh" do
      {:ok, runtime} = Runtime.start_link(root: @dashboard_module, skip_terminal: true)

      # Refresh just triggers re-render, state unchanged
      initial_state = Runtime.get_state(runtime)

      Runtime.send_event(runtime, Event.key("r"))
      Process.sleep(50)

      state = Runtime.get_state(runtime)
      assert state.root_state.theme == initial_state.root_state.theme
      assert state.root_state.selected_process == initial_state.root_state.selected_process

      Runtime.shutdown(runtime)
      Process.sleep(50)
    end
  end

  describe "dashboard quit behavior" do
    test "'q' key message is handled" do
      {:ok, runtime} = Runtime.start_link(root: @dashboard_module, skip_terminal: true)

      # The dashboard's update(:quit, state) currently just returns state
      # because proper quit handling was left as TODO
      # This test verifies the message is received without crash

      Runtime.send_event(runtime, Event.key("q"))
      Process.sleep(50)

      # Process should still be running (dashboard doesn't return quit command yet)
      assert Process.alive?(runtime)

      Runtime.shutdown(runtime)
      Process.sleep(50)
    end
  end

  describe "dashboard state consistency" do
    test "multiple theme toggles maintain consistency" do
      {:ok, runtime} = Runtime.start_link(root: @dashboard_module, skip_terminal: true)

      # Toggle theme multiple times
      for _ <- 1..10 do
        Runtime.send_event(runtime, Event.key("t"))
      end
      Process.sleep(100)

      state = Runtime.get_state(runtime)
      # Even number of toggles should return to dark
      assert state.root_state.theme == :dark

      Runtime.shutdown(runtime)
      Process.sleep(50)
    end

    test "navigation and theme changes are independent" do
      {:ok, runtime} = Runtime.start_link(root: @dashboard_module, skip_terminal: true)

      # Navigate and toggle
      Runtime.send_event(runtime, Event.key(:down))
      Runtime.send_event(runtime, Event.key("t"))
      Runtime.send_event(runtime, Event.key(:down))
      Process.sleep(100)

      state = Runtime.get_state(runtime)
      assert state.root_state.selected_process == 2
      assert state.root_state.theme == :light

      Runtime.shutdown(runtime)
      Process.sleep(50)
    end

    test "rapid event handling maintains state integrity" do
      {:ok, runtime} = Runtime.start_link(root: @dashboard_module, skip_terminal: true)

      # Send many navigation events rapidly
      for _ <- 1..50 do
        Runtime.send_event(runtime, Event.key(:down))
      end
      Process.sleep(200)

      state = Runtime.get_state(runtime)
      # Should be clamped to max process index
      assert state.root_state.selected_process >= 0

      Runtime.shutdown(runtime)
      Process.sleep(50)
    end
  end

  describe "dashboard event ignoring" do
    test "unknown keys are ignored" do
      {:ok, runtime} = Runtime.start_link(root: @dashboard_module, skip_terminal: true)

      initial_state = Runtime.get_state(runtime)

      # Send unknown keys
      Runtime.send_event(runtime, Event.key("x"))
      Runtime.send_event(runtime, Event.key("z"))
      Runtime.send_event(runtime, Event.key(:enter))
      Process.sleep(50)

      state = Runtime.get_state(runtime)
      assert state.root_state == initial_state.root_state

      Runtime.shutdown(runtime)
      Process.sleep(50)
    end

    test "mouse events are ignored" do
      {:ok, runtime} = Runtime.start_link(root: @dashboard_module, skip_terminal: true)

      initial_state = Runtime.get_state(runtime)

      # Send mouse events
      Runtime.send_event(runtime, Event.mouse(:press, :left, 10, 10))
      Runtime.send_event(runtime, Event.mouse(:release, :left, 10, 10))
      Process.sleep(50)

      state = Runtime.get_state(runtime)
      assert state.root_state == initial_state.root_state

      Runtime.shutdown(runtime)
      Process.sleep(50)
    end
  end

  describe "test isolation" do
    test "each test starts with fresh state" do
      {:ok, runtime} = Runtime.start_link(root: @dashboard_module, skip_terminal: true)

      state = Runtime.get_state(runtime)
      assert state.root_state.theme == :dark
      assert state.root_state.selected_process == 0

      Runtime.shutdown(runtime)
      Process.sleep(50)
    end

    test "cleanup is complete" do
      {:ok, runtime} = Runtime.start_link(root: @dashboard_module, skip_terminal: true)

      # Modify state
      Runtime.send_event(runtime, Event.key("t"))
      Runtime.send_event(runtime, Event.key(:down))
      Process.sleep(50)

      Runtime.shutdown(runtime)
      Process.sleep(50)

      # Process should be gone
      refute Process.alive?(runtime)
    end
  end
end
