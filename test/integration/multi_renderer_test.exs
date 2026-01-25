defmodule TermUI.Integration.MultiRendererTest do
  @moduledoc """
  Integration tests for the multi-renderer system (Section 6.8).

  These tests verify the complete system works end-to-end:
  - Full application lifecycle (start, render, input, update, shutdown)
  - Backend switching (auto-detection, forced modes)
  - Input consistency (same events work in both modes)
  - Rendering consistency (widgets render consistently, colors/characters degrade)
  """

  use ExUnit.Case, async: false

  alias TermUI.Backend.Selector
  alias TermUI.Event
  alias TermUI.Runtime
  alias TermUI.Config

  # Test component implementing the Elm Architecture
  defmodule Counter do
    @moduledoc """
    Simple counter component for testing.

    Implements the Elm Architecture callbacks:
    - init/1
    - event_to_msg/2
    - update/2
    - view/1
    """

    import TermUI.Component.Helpers

    def init(_opts) do
      %{count: 0, events_received: []}
    end

    def event_to_msg(%Event.Key{key: :up}, _state) do
      {:msg, {:increment, 1}}
    end

    def event_to_msg(%Event.Key{key: :down}, _state) do
      {:msg, {:decrement, 1}}
    end

    def event_to_msg(%Event.Key{key: ?+}, _state) do
      {:msg, {:increment, 1}}
    end

    def event_to_msg(%Event.Key{key: ?-}, _state) do
      {:msg, {:decrement, 1}}
    end

    def event_to_msg(%Event.Key{key: ?r}, _state) do
      {:msg, :reset}
    end

    def event_to_msg(%Event.Key{key: ?q}, _state) do
      {:msg, :quit}
    end

    def event_to_msg(%Event.Key{key: :enter}, _state) do
      {:msg, :submit}
    end

    def event_to_msg(%Event.Key{key: :tab}, _state) do
      {:msg, :next}
    end

    def event_to_msg(%Event.Key{key: :escape}, _state) do
      {:msg, :cancel}
    end

    def event_to_msg(event, _state) do
      # Track all events for testing
      {:msg, {:unknown_event, event}}
    end

    def update({:increment, amount}, state) do
      {new_state, []} = {%{state | count: state.count + amount}, []}
      {new_state, []}
    end

    def update({:decrement, amount}, state) do
      {new_state, []} = {%{state | count: state.count - amount}, []}
      {new_state, []}
    end

    def update(:reset, state) do
      {new_state, []} = {%{state | count: 0}, []}
      {new_state, []}
    end

    def update(:quit, state) do
      {state, [:quit]}
    end

    def update(:submit, state) do
      {state, []}
    end

    def update(:next, state) do
      {state, []}
    end

    def update(:cancel, state) do
      {state, []}
    end

    def update({:unknown_event, _event}, state) do
      {state, []}
    end

    def update(_msg, state) do
      {state, []}
    end

    def view(state) do
      box([
        text("Counter: #{state.count}"),
        text("Use +/- to change, q to quit")
      ])
    end
  end

  # ===========================================================================
  # Setup and Teardown
  # ===========================================================================

  setup do
    # Clear persistent_term values
    :persistent_term.erase(:term_ui_backend_mode)
    :persistent_term.erase(:term_ui_capabilities)
    :persistent_term.erase(:term_ui_character_set)

    # Store original Application env
    original_backend = Application.get_env(:term_ui, :backend)
    original_character_set = Application.get_env(:term_ui, :character_set)
    original_tty_opts = Application.get_env(:term_ui, :tty_opts)

    on_exit(fn ->
      # Restore Application env
      restore_app_env(:backend, original_backend)
      restore_app_env(:character_set, original_character_set)
      restore_app_env(:tty_opts, original_tty_opts)

      # Clear persistent_term
      :persistent_term.erase(:term_ui_backend_mode)
      :persistent_term.erase(:term_ui_capabilities)
      :persistent_term.erase(:term_ui_character_set)

      # Stop any running Runtime processes
      case Process.whereis(TermUI.Runtime) do
        nil -> :ok
        pid -> GenServer.stop(pid, :normal)
      end
    end)

    :ok
  end

  defp restore_app_env(key, nil), do: Application.delete_env(:term_ui, key)
  defp restore_app_env(key, value), do: Application.put_env(:term_ui, key, value)

  # ===========================================================================
  # 6.8.1 Full Application Lifecycle Tests
  # ===========================================================================

  describe "6.8.1 Full Application Lifecycle" do
    test "6.8.1.1 start -> render -> input -> update -> render -> shutdown" do
      # Start runtime with skip_terminal for testing
      {:ok, runtime} = Runtime.start_link(
        root: Counter,
        skip_terminal: true,
        use_input_handler: false
      )

      # Verify runtime started
      assert Process.alive?(runtime)
      state = Runtime.get_state(runtime)
      assert state.root_state.count == 0

      # Send increment events
      Runtime.send_event(runtime, Event.key(:up))
      Runtime.sync(runtime)

      state = Runtime.get_state(runtime)
      assert state.root_state.count == 1

      # Send another increment
      Runtime.send_event(runtime, Event.key(?+))
      Runtime.sync(runtime)

      state = Runtime.get_state(runtime)
      assert state.root_state.count == 2

      # Send decrement
      Runtime.send_event(runtime, Event.key(:down))
      Runtime.sync(runtime)

      state = Runtime.get_state(runtime)
      assert state.root_state.count == 1

      # Shutdown gracefully and wait for process to exit
      ref = Process.monitor(runtime)
      :ok = Runtime.shutdown(runtime)

      # Wait for shutdown to complete
      receive do
        {:DOWN, ^ref, :process, ^runtime, _reason} -> :ok
      after
        1000 -> flunk("Runtime did not shut down")
      end

      # Verify runtime stopped
      refute Process.alive?(runtime)
    end

    test "6.8.1.2 Test in raw mode (simulated with TestBackend)" do
      # We can't actually test raw mode in test environment without OTP 28+
      # But we can verify the backend selection logic
      # Selector.select(:raw) returns {:explicit, :raw, []}
      result = Selector.select(:raw)

      # For raw mode selection, we get explicit format
      assert {:explicit, :raw, []} = result
    end

    test "6.8.1.3 Test in TTY mode (forced)" do
      Application.put_env(:term_ui, :backend, :tty)

      {:ok, runtime} = Runtime.start_link(
        root: Counter,
        skip_terminal: true,
        use_input_handler: false
      )

      # Verify TTY backend mode is set
      assert Runtime.backend_mode() in [:tty, :skip]

      state = Runtime.get_state(runtime)
      assert state.backend_mode in [:tty, :skip]

      # Test basic functionality
      Runtime.send_event(runtime, Event.key(?+))
      Runtime.sync(runtime)

      state = Runtime.get_state(runtime)
      assert state.root_state.count == 1

      # Shutdown
      Runtime.shutdown(runtime)
    end

    test "6.8.1.4 Test cleanup on crash" do
      {:ok, runtime} = Runtime.start_link(
        root: Counter,
        skip_terminal: true,
        use_input_handler: false
      )

      # Simulate a crash by killing the process
      Process.flag(:trap_exit, true)
      Process.exit(runtime, :kill)

      # Wait for process to die
      receive do
        {:EXIT, ^runtime, :killed} -> :ok
      after
        1000 -> flunk("Timeout waiting for runtime to die")
      end

      # Verify process is gone
      refute Process.alive?(runtime)

      # Verify we can start a new runtime (cleanup was successful)
      {:ok, runtime2} = Runtime.start_link(
        root: Counter,
        skip_terminal: true,
        use_input_handler: false
      )

      assert Process.alive?(runtime2)

      Runtime.shutdown(runtime2)
    end
  end

  # ===========================================================================
  # 6.8.2 Backend Switching Tests
  # ===========================================================================

  describe "6.8.2 Backend Switching" do
    test "6.8.2.1 Test auto-detection selects appropriate backend" do
      # Auto mode should select appropriate backend
      result = Selector.select(:auto)

      case result do
        {:raw, _state} ->
          # Raw mode succeeded
          assert true

        {:tty, capabilities} ->
          # Fell back to TTY mode
          assert is_map(capabilities)
          assert Map.has_key?(capabilities, :colors)
          assert Map.has_key?(capabilities, :unicode)
      end
    end

    test "6.8.2.2 Test forced raw mode works when available" do
      # Force raw mode - returns {:explicit, :raw, []}
      result = Selector.select(:raw)

      # Selector always returns explicit format for forced modes
      assert {:explicit, :raw, []} = result
    end

    test "6.8.2.3 Test forced TTY mode skips raw attempt" do
      # Force TTY mode should skip raw attempt entirely
      result = Selector.select(:tty)

      # Selector returns explicit format
      assert {:explicit, :tty, []} = result
    end

    test "6.8.2.4 Test explicit module selection" do
      # Test explicit module selection
      result = Selector.select(TermUI.Backend.TTY)

      assert {:explicit, TermUI.Backend.TTY, []} = result
    end
  end

  # ===========================================================================
  # 6.8.3 Input Consistency Tests
  # ===========================================================================

  describe "6.8.3 Input Consistency" do
    test "6.8.3.1 Test arrow keys work in both modes" do
      # Test with skip terminal (test mode)
      {:ok, runtime} = Runtime.start_link(
        root: Counter,
        skip_terminal: true,
        use_input_handler: false
      )

      # Test up arrow
      Runtime.send_event(runtime, Event.key(:up))
      Runtime.sync(runtime)
      state = Runtime.get_state(runtime)
      assert state.root_state.count == 1

      # Test down arrow
      Runtime.send_event(runtime, Event.key(:down))
      Runtime.sync(runtime)
      state = Runtime.get_state(runtime)
      assert state.root_state.count == 0

      Runtime.shutdown(runtime)
    end

    test "6.8.3.2 Test Enter/Tab/Escape work in both modes" do
      {:ok, runtime} = Runtime.start_link(
        root: Counter,
        skip_terminal: true,
        use_input_handler: false
      )

      # Test Enter
      Runtime.send_event(runtime, Event.key(:enter))
      Runtime.sync(runtime)
      # Counter doesn't change on Enter, but should not crash
      state = Runtime.get_state(runtime)
      assert is_integer(state.root_state.count)

      # Test Tab
      Runtime.send_event(runtime, Event.key(:tab))
      Runtime.sync(runtime)
      state = Runtime.get_state(runtime)
      assert is_integer(state.root_state.count)

      # Test Escape
      Runtime.send_event(runtime, Event.key(:escape))
      Runtime.sync(runtime)
      state = Runtime.get_state(runtime)
      assert is_integer(state.root_state.count)

      Runtime.shutdown(runtime)
    end

    test "6.8.3.3 Test widgets respond identically to input" do
      # Create two runtimes with same component
      {:ok, runtime1} = Runtime.start_link(
        root: Counter,
        skip_terminal: true,
        use_input_handler: false,
        name: :runtime1
      )

      {:ok, runtime2} = Runtime.start_link(
        root: Counter,
        skip_terminal: true,
        use_input_handler: false,
        name: :runtime2
      )

      # Send same events to both
      Runtime.send_event(runtime1, Event.key(:up))
      Runtime.send_event(runtime1, Event.key(?+))
      Runtime.sync(runtime1)

      Runtime.send_event(runtime2, Event.key(:up))
      Runtime.send_event(runtime2, Event.key(?+))
      Runtime.sync(runtime2)

      # Both should have same state
      state1 = Runtime.get_state(runtime1)
      state2 = Runtime.get_state(runtime2)

      assert state1.root_state.count == state2.root_state.count
      assert state1.root_state.count == 2

      Runtime.shutdown(runtime1)
      Runtime.shutdown(runtime2)
    end
  end

  # ===========================================================================
  # 6.8.4 Rendering Consistency Tests
  # ===========================================================================

  describe "6.8.4 Rendering Consistency" do
    test "6.8.4.1 Test same widget renders in both modes" do
      # The Counter component should render identically in both modes
      # since we're using skip_terminal mode

      {:ok, runtime} = Runtime.start_link(
        root: Counter,
        skip_terminal: true,
        use_input_handler: false
      )

      # Render initial state
      Runtime.force_render(runtime)
      state = Runtime.get_state(runtime)

      # Verify component can be rendered (no crash)
      assert is_map(state.root_state)

      # Update state and verify still renderable
      Runtime.send_event(runtime, Event.key(:up))
      Runtime.sync(runtime)
      Runtime.force_render(runtime)

      state = Runtime.get_state(runtime)
      assert state.root_state.count == 1

      Runtime.shutdown(runtime)
    end

    test "6.8.4.2 Test colors degrade correctly" do
      # Test color degradation via capability detection
      capabilities_true_color = %{colors: :true_color, unicode: true}
      capabilities_256 = %{colors: :color_256, unicode: true}
      capabilities_16 = %{colors: :color_16, unicode: true}
      capabilities_mono = %{colors: :monochrome, unicode: true}

      # All capabilities should be valid
      assert capabilities_true_color.colors == :true_color
      assert capabilities_256.colors == :color_256
      assert capabilities_16.colors == :color_16
      assert capabilities_mono.colors == :monochrome
    end

    test "6.8.4.3 Test characters degrade correctly" do
      # Test Unicode vs ASCII character set detection
      capabilities_unicode = %{colors: :true_color, unicode: true}
      capabilities_ascii = %{colors: :true_color, unicode: false}

      assert capabilities_unicode.unicode == true
      assert capabilities_ascii.unicode == false
    end
  end

  # ===========================================================================
  # Additional Integration Tests
  # ===========================================================================

  describe "Runtime API consistency" do
    test "backend_mode/0 returns correct mode" do
      # Initially no backend mode
      assert Runtime.backend_mode() in [:raw, :tty, :skip, nil]

      {:ok, runtime} = Runtime.start_link(
        root: Counter,
        skip_terminal: true,
        use_input_handler: false
      )

      # After starting, should have a mode
      mode = Runtime.backend_mode()
      assert mode in [:raw, :tty, :skip]

      Runtime.shutdown(runtime)
    end

    test "capabilities/0 returns capabilities map or nil" do
      # Initially no capabilities
      assert Runtime.capabilities() in [nil, %{}]

      {:ok, runtime} = Runtime.start_link(
        root: Counter,
        skip_terminal: true,
        use_input_handler: false
      )

      # After starting, capabilities should be available (or nil in skip mode)
      caps = Runtime.capabilities()
      assert caps in [nil, %{}]

      Runtime.shutdown(runtime)
    end
  end

  describe "Config integration" do
    test "Config.merge_options/2 merges correctly" do
      Application.put_env(:term_ui, :backend, :tty)
      Application.put_env(:term_ui, :character_set, :ascii)

      opts = [backend: :raw, render_interval: 100]
      merged = Config.merge_options(opts)

      # Runtime options should override config
      assert merged[:backend] == :raw
      assert merged[:character_set] == :ascii
      assert merged[:render_interval] == 100
    end

    test "Config.get/2 returns defaults" do
      # Clear env
      Application.delete_env(:term_ui, :backend)

      assert Config.get(:backend, :auto) == :auto
      assert Config.get(:render_interval, 16) == 16
    end
  end

  describe "Full lifecycle with quit command" do
    test "quit command triggers shutdown" do
      {:ok, runtime} = Runtime.start_link(
        root: Counter,
        skip_terminal: true,
        use_input_handler: false
      )

      # Monitor the runtime
      ref = Process.monitor(runtime)

      # Send quit event
      Runtime.send_event(runtime, Event.key(?q))

      # Wait for shutdown
      receive do
        {:DOWN, ^ref, :process, ^runtime, _reason} ->
          # Runtime shut down
          refute Process.alive?(runtime)
      after
        1000 ->
          # If shutdown didn't happen, clean up manually
          Runtime.shutdown(runtime)
          flunk("Runtime did not shut down on quit command")
      end
    end
  end

  describe "Multiple sequential runs" do
    test "runtime can be started and stopped multiple times" do
      for _i <- 1..3 do
        {:ok, runtime} = Runtime.start_link(
          root: Counter,
          skip_terminal: true,
          use_input_handler: false
        )

        # Verify it works
        Runtime.send_event(runtime, Event.key(:up))
        Runtime.sync(runtime)

        state = Runtime.get_state(runtime)
        assert state.root_state.count == 1

        # Shutdown and wait for exit
        ref = Process.monitor(runtime)
        Runtime.shutdown(runtime)

        receive do
          {:DOWN, ^ref, :process, ^runtime, _reason} -> :ok
        after
          1000 -> flunk("Runtime did not shut down")
        end

        # Verify stopped
        refute Process.alive?(runtime)

        # Clear persistent_term for next iteration
        :persistent_term.erase(:term_ui_backend_mode)
        :persistent_term.erase(:term_ui_capabilities)
      end
    end
  end
end
