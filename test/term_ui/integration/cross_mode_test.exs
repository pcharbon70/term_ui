defmodule TermUI.Integration.CrossModeTest do
  @moduledoc """
  Integration tests for cross-mode consistency.

  Tests that applications work identically in IEx and standalone modes:
  - Same app works identically in IEx and standalone
  - Raw backend still works when not in IEx
  - Switching between IEx and standalone modes

  These tests verify that the IEx compatibility layer maintains
  behavioral consistency with standalone mode.
  """

  use ExUnit.Case, async: false

  alias TermUI.Command
  alias TermUI.Event
  alias TermUI.Runtime

  # Test component that tracks all events and state changes
  defmodule StateTracker do
    @moduledoc """
    Test component that tracks all events and state changes.

    Used to verify that behavior is consistent across modes.
    """

    use TermUI.Elm

    @impl true
    def init(_opts) do
      %{
        count: 0,
        events: [],
        last_event: nil
      }
    end

    @impl true
    def event_to_msg(%Event.Key{key: key}, _state), do: {:msg, {:key, key}}
    def event_to_msg(%Event.Mouse{action: action}, _state), do: {:msg, {:mouse, action}}
    def event_to_msg(%Event.Resize{width: w, height: h}, _state), do: {:msg, {:resize, w, h}}
    def event_to_msg(_, _), do: :ignore

    @impl true
    def update({:key, :up}, state) do
      {%{state | count: state.count + 1, events: [:up | state.events], last_event: :up}, []}
    end

    def update({:key, :down}, state) do
      {%{state | count: state.count - 1, events: [:down | state.events], last_event: :down}, []}
    end

    def update({:key, "r"}, state) do
      {%{state | count: 0, events: [:reset | state.events], last_event: :reset}, []}
    end

    def update({:key, "q"}, state) do
      {state, [Command.quit()]}
    end

    def update({:mouse, :press}, state) do
      {%{state | count: state.count + 10, events: [:mouse_press | state.events], last_event: :mouse_press}, []}
    end

    def update({:resize, w, h}, state) do
      {%{state | events: [{:resize, w, h} | state.events], last_event: {:resize, w, h}}, []}
    end

    def update(_msg, state), do: {state, []}

    @impl true
    def view(state), do: {:text, "Count: #{state.count}, Last: #{inspect(state.last_event)}"}
  end

  # Component that renders differently based on mode
  defmodule ModeAwareComponent do
    @moduledoc """
    Component that displays the current execution mode.

    Used to verify that mode detection works correctly.
    """

    use TermUI.Elm

    @impl true
    def init(_opts) do
      %{
        mode: TermUI.running_mode(),
        iex_mode: TermUI.iex_mode?()
      }
    end

    @impl true
    def event_to_msg(%Event.Key{key: "q"}, _state), do: {:msg, :quit}
    def event_to_msg(%Event.Key{key: "r"}, _state), do: {:msg, :refresh_mode}
    def event_to_msg(_, _), do: :ignore

    @impl true
    def update(:quit, state) do
      {state, [Command.quit()]}
    end

    def update(:refresh_mode, state) do
      {%{
         state |
         mode: TermUI.running_mode(),
         iex_mode: TermUI.iex_mode?()
       }, []}
    end

    def update(_msg, state), do: {state, []}

    @impl true
    def view(state) do
      mode_str =
        case state.mode do
          :iex -> "IEx"
          :standalone -> "Standalone"
          other -> inspect(other)
        end

      iex_str = if state.iex_mode, do: "true", else: "false"
      {:text, "Mode: #{mode_str}, iex_mode?: #{iex_str}"}
    end
  end

  describe "7.6.2.1: same app works identically in IEx and standalone" do
    setup do
      # Save original environment
      original_env = Application.get_env(:term_ui, :iex_compatible)
      original_iex_env = System.get_env("TERM_UI_IEX_MODE")

      on_exit(fn ->
        # Restore original environment
        case original_env do
          nil -> Application.delete_env(:term_ui, :iex_compatible)
          val -> Application.put_env(:term_ui, :iex_compatible, val)
        end

        case original_iex_env do
          nil -> System.delete_env("TERM_UI_IEX_MODE")
          val -> System.put_env("TERM_UI_IEX_MODE", val)
        end
      end)

      :ok
    end

    test "app produces same state transitions in both modes" do
      # Test in standalone mode
      Application.put_env(:term_ui, :iex_compatible, false)

      {:ok, runtime1} = Runtime.start_link(root: StateTracker, skip_terminal: true)

      # Send same sequence of events
      events = [
        Event.key(:up),
        Event.key(:up),
        Event.key(:down),
        Event.mouse(:press, :left, 0, 0),
        Event.key(:up)
      ]

      Enum.each(events, &Runtime.send_event(runtime1, &1))
      Runtime.sync(runtime1)

      state1 = Runtime.get_state(runtime1)

      Runtime.shutdown(runtime1)

      # Now test in IEx mode
      Application.put_env(:term_ui, :iex_compatible, true)

      {:ok, runtime2} = Runtime.start_link(root: StateTracker, skip_terminal: true)

      # Send same sequence of events
      Enum.each(events, &Runtime.send_event(runtime2, &1))
      Runtime.sync(runtime2)

      state2 = Runtime.get_state(runtime2)

      Runtime.shutdown(runtime2)

      # State should be identical
      assert state1.root_state.count == state2.root_state.count
      assert length(state1.root_state.events) == length(state2.root_state.events)

      # Event sequence should match (reversed due to prepending)
      assert state1.root_state.events == state2.root_state.events
    end

    test "app renders consistently in both modes" do
      # Test in standalone mode first
      Application.put_env(:term_ui, :iex_compatible, false)

      {:ok, runtime1} = Runtime.start_link(root: StateTracker, skip_terminal: true)

      Runtime.send_event(runtime1, Event.key(:up))
      Runtime.sync(runtime1)

      state1 = Runtime.get_state(runtime1)

      Runtime.shutdown(runtime1)

      # Now test in IEx mode
      Application.put_env(:term_ui, :iex_compatible, true)

      {:ok, runtime2} = Runtime.start_link(root: StateTracker, skip_terminal: true)

      Runtime.send_event(runtime2, Event.key(:up))
      Runtime.sync(runtime2)

      state2 = Runtime.get_state(runtime2)

      Runtime.shutdown(runtime2)

      # Render state should be identical
      assert state1.root_state.count == state2.root_state.count
      assert state1.root_state.last_event == state2.root_state.last_event
    end

    test "mode detection is reflected in component state" do
      # Test in standalone mode
      Application.put_env(:term_ui, :iex_compatible, false)

      {:ok, runtime1} = Runtime.start_link(root: ModeAwareComponent, skip_terminal: true)

      state1 = Runtime.get_state(runtime1)

      assert state1.root_state.mode == :standalone
      refute state1.root_state.iex_mode

      Runtime.shutdown(runtime1)

      # Test in IEx mode
      Application.put_env(:term_ui, :iex_compatible, true)

      {:ok, runtime2} = Runtime.start_link(root: ModeAwareComponent, skip_terminal: true)

      state2 = Runtime.get_state(runtime2)

      assert state2.root_state.mode == :iex
      assert state2.root_state.iex_mode

      Runtime.shutdown(runtime2)
    end
  end

  describe "7.6.2.2: Raw backend still works when not in IEx" do
    setup do
      # Save original environment
      original_env = Application.get_env(:term_ui, :iex_compatible)
      original_iex_env = System.get_env("TERM_UI_IEX_MODE")

      # Ensure standalone mode
      Application.put_env(:term_ui, :iex_compatible, false)

      on_exit(fn ->
        # Restore original environment
        case original_env do
          nil -> Application.delete_env(:term_ui, :iex_compatible)
          val -> Application.put_env(:term_ui, :iex_compatible, val)
        end

        case original_iex_env do
          nil -> System.delete_env("TERM_UI_IEX_MODE")
          val -> System.put_env("TERM_UI_IEX_MODE", val)
        end
      end)

      :ok
    end

    test "runtime works with auto backend in standalone mode" do
      # In standalone mode with auto backend, should work normally
      {:ok, runtime} = Runtime.start_link(root: StateTracker, skip_terminal: true)

      on_exit(fn ->
        if Process.alive?(runtime), do: Runtime.shutdown(runtime)
      end)

      # Verify IEx mode is not active
      refute TermUI.iex_mode?()
      assert TermUI.running_mode() == :standalone

      # Send events and verify they work
      Runtime.send_event(runtime, Event.key(:up))
      Runtime.send_event(runtime, Event.key(:up))
      Runtime.sync(runtime)

      state = Runtime.get_state(runtime)
      assert state.root_state.count == 2
    end

    test "runtime can be explicitly set to use raw backend" do
      # Explicitly request raw backend (may not actually activate in test env)
      {:ok, runtime} =
        Runtime.start_link(root: StateTracker, backend: :raw, skip_terminal: true)

      on_exit(fn ->
        if Process.alive?(runtime), do: Runtime.shutdown(runtime)
      end)

      # Should still be functional
      Runtime.send_event(runtime, Event.key(:up))
      Runtime.sync(runtime)

      state = Runtime.get_state(runtime)
      assert state.root_state.count == 1
    end

    test "runtime with TTY backend works in standalone mode" do
      {:ok, runtime} =
        Runtime.start_link(root: StateTracker, backend: :tty, skip_terminal: true)

      on_exit(fn ->
        if Process.alive?(runtime), do: Runtime.shutdown(runtime)
      end)

      # Should work the same as raw backend for basic events
      Runtime.send_event(runtime, Event.key(:up))
      Runtime.send_event(runtime, Event.key(:down))
      Runtime.sync(runtime)

      state = Runtime.get_state(runtime)
      assert state.root_state.count == 0  # +1 -1 = 0
    end
  end

  describe "7.6.2.3: switching between IEx and standalone modes" do
    setup do
      # Save original environment
      original_env = Application.get_env(:term_ui, :iex_compatible)
      original_iex_env = System.get_env("TERM_UI_IEX_MODE")

      on_exit(fn ->
        # Restore original environment
        case original_env do
          nil -> Application.delete_env(:term_ui, :iex_compatible)
          val -> Application.put_env(:term_ui, :iex_compatible, val)
        end

        case original_iex_env do
          nil -> System.delete_env("TERM_UI_IEX_MODE")
          val -> System.put_env("TERM_UI_IEX_MODE", val)
        end
      end)

      :ok
    end

    test "can switch from standalone to IEx mode between runtimes" do
      # Start in standalone mode
      Application.put_env(:term_ui, :iex_compatible, false)

      {:ok, runtime1} = Runtime.start_link(root: StateTracker, skip_terminal: true)

      refute TermUI.iex_mode?()

      Runtime.send_event(runtime1, Event.key(:up))
      Runtime.sync(runtime1)

      state1 = Runtime.get_state(runtime1)
      assert state1.root_state.count == 1

      Runtime.shutdown(runtime1)

      # Switch to IEx mode
      Application.put_env(:term_ui, :iex_compatible, true)

      {:ok, runtime2} = Runtime.start_link(root: StateTracker, skip_terminal: true)

      assert TermUI.iex_mode?()

      Runtime.send_event(runtime2, Event.key(:up))
      Runtime.sync(runtime2)

      state2 = Runtime.get_state(runtime2)
      assert state2.root_state.count == 1

      Runtime.shutdown(runtime2)
    end

    test "can switch from IEx to standalone mode between runtimes" do
      # Start in IEx mode
      Application.put_env(:term_ui, :iex_compatible, true)

      {:ok, runtime1} = Runtime.start_link(root: StateTracker, skip_terminal: true)

      assert TermUI.iex_mode?()

      Runtime.send_event(runtime1, Event.key(:up))
      Runtime.sync(runtime1)

      state1 = Runtime.get_state(runtime1)
      assert state1.root_state.count == 1

      Runtime.shutdown(runtime1)

      # Switch to standalone mode
      Application.put_env(:term_ui, :iex_compatible, false)

      {:ok, runtime2} = Runtime.start_link(root: StateTracker, skip_terminal: true)

      refute TermUI.iex_mode?()

      Runtime.send_event(runtime2, Event.key(:up))
      Runtime.sync(runtime2)

      state2 = Runtime.get_state(runtime2)
      assert state2.root_state.count == 1

      Runtime.shutdown(runtime2)
    end

    test "mode changes are detected by mode-aware component" do
      # Start in standalone mode
      Application.put_env(:term_ui, :iex_compatible, false)

      {:ok, runtime1} = Runtime.start_link(root: ModeAwareComponent, skip_terminal: true)

      state1 = Runtime.get_state(runtime1)
      assert state1.root_state.mode == :standalone

      Runtime.shutdown(runtime1)

      # Switch to IEx mode
      Application.put_env(:term_ui, :iex_compatible, true)

      {:ok, runtime2} = Runtime.start_link(root: ModeAwareComponent, skip_terminal: true)

      state2 = Runtime.get_state(runtime2)
      assert state2.root_state.mode == :iex

      # Refresh mode via event
      Runtime.send_event(runtime2, Event.key("r"))
      Runtime.sync(runtime2)

      state3 = Runtime.get_state(runtime2)
      assert state3.root_state.mode == :iex
      assert state3.root_state.iex_mode

      Runtime.shutdown(runtime2)
    end

    test "multiple mode switches work correctly" do
      # Test multiple transitions between modes
      modes = [false, true, false, true, false]

      final_count =
        Enum.map(modes, fn iex_mode ->
          Application.put_env(:term_ui, :iex_compatible, iex_mode)

          {:ok, runtime} = Runtime.start_link(root: StateTracker, skip_terminal: true)

          # Do some work
          Runtime.send_event(runtime, Event.key(:up))
          Runtime.sync(runtime)

          state = Runtime.get_state(runtime)
          count = state.root_state.count

          Runtime.shutdown(runtime)

          # Verify mode detection matches
          if iex_mode do
            assert TermUI.iex_mode?()
          else
            refute TermUI.iex_mode?()
          end

          count
        end)
        |> Enum.sum()

      # All modes should have produced count = 1
      assert final_count == length(modes)
    end
  end

  describe "cross-mode event handling consistency" do
    setup do
      original_env = Application.get_env(:term_ui, :iex_compatible)

      on_exit(fn ->
        case original_env do
          nil -> Application.delete_env(:term_ui, :iex_compatible)
          val -> Application.put_env(:term_ui, :iex_compatible, val)
        end
      end)

      :ok
    end

    test "keyboard events work consistently in both modes" do
      test_keys = [:up, :down, :up, :up, :down]

      # Test in both modes
      for iex_mode <- [false, true] do
        Application.put_env(:term_ui, :iex_compatible, iex_mode)

        {:ok, runtime} = Runtime.start_link(root: StateTracker, skip_terminal: true)

        Enum.each(test_keys, &Runtime.send_event(runtime, Event.key(&1)))
        Runtime.sync(runtime)

        state = Runtime.get_state(runtime)
        # up=+1, down=-1: +1 -1 +1 +1 -1 = +1
        assert state.root_state.count == 1

        Runtime.shutdown(runtime)
      end
    end

    test "mouse events work consistently in both modes" do
      # Test in both modes
      for iex_mode <- [false, true] do
        Application.put_env(:term_ui, :iex_compatible, iex_mode)

        {:ok, runtime} = Runtime.start_link(root: StateTracker, skip_terminal: true)

        Runtime.send_event(runtime, Event.mouse(:press, :left, 10, 5))
        Runtime.sync(runtime)

        state = Runtime.get_state(runtime)
        assert state.root_state.count == 10
        assert state.root_state.last_event == :mouse_press

        Runtime.shutdown(runtime)
      end
    end

    test "resize events work consistently in both modes" do
      # Test in both modes
      for iex_mode <- [false, true] do
        Application.put_env(:term_ui, :iex_compatible, iex_mode)

        {:ok, runtime} = Runtime.start_link(root: StateTracker, skip_terminal: true)

        Runtime.send_event(runtime, Event.resize(80, 24))
        Runtime.sync(runtime)

        state = Runtime.get_state(runtime)
        assert state.root_state.last_event == {:resize, 80, 24}

        Runtime.shutdown(runtime)
      end
    end
  end

  describe "backend selection across modes" do
    setup do
      original_env = Application.get_env(:term_ui, :iex_compatible)

      on_exit(fn ->
        case original_env do
          nil -> Application.delete_env(:term_ui, :iex_compatible)
          val -> Application.put_env(:term_ui, :iex_compatible, val)
        end
      end)

      :ok
    end

    test "auto backend works in both modes" do
      for iex_mode <- [false, true] do
        Application.put_env(:term_ui, :iex_compatible, iex_mode)

        {:ok, runtime} = Runtime.start_link(root: StateTracker, backend: :auto, skip_terminal: true)

        # Should be functional regardless of mode
        Runtime.send_event(runtime, Event.key(:up))
        Runtime.sync(runtime)

        state = Runtime.get_state(runtime)
        assert state.root_state.count == 1

        Runtime.shutdown(runtime)
      end
    end

    test "TTY backend works in both modes" do
      for iex_mode <- [false, true] do
        Application.put_env(:term_ui, :iex_compatible, iex_mode)

        {:ok, runtime} = Runtime.start_link(root: StateTracker, backend: :tty, skip_terminal: true)

        # Should be functional regardless of mode
        Runtime.send_event(runtime, Event.key(:up))
        Runtime.sync(runtime)

        state = Runtime.get_state(runtime)
        assert state.root_state.count == 1

        Runtime.shutdown(runtime)
      end
    end
  end
end
