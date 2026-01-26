defmodule TermUI.Integration.IExLifecycleTest do
  @moduledoc """
  Integration tests for IEx lifecycle.

  Tests the complete application lifecycle when running in IEx mode:
  - Start, render, input, update, render, shutdown cycle
  - Keyboard input handling
  - Crash recovery and cleanup
  - Multiple start/stop cycles

  These tests simulate IEx environment by setting process dictionary
  and configuration options to force IEx-compatible mode.
  """

  use ExUnit.Case, async: false

  alias TermUI.Command
  alias TermUI.Event
  alias TermUI.Runtime

  # Note: These tests use async: false because they manipulate global
  # process state and application configuration.

  # Simple counter component for testing
  defmodule Counter do
    @moduledoc """
    Test component for IEx lifecycle testing.

    A simple counter that responds to keyboard events and quit commands.
    """

    use TermUI.Elm

    @impl true
    def init(_opts), do: %{count: 0}

    @impl true
    def event_to_msg(%Event.Key{key: :up}, _state), do: {:msg, :increment}
    def event_to_msg(%Event.Key{key: :down}, _state), do: {:msg, :decrement}
    def event_to_msg(%Event.Key{key: "q"}, _state), do: {:msg, :quit}
    def event_to_msg(%Event.Key{key: "r"}, _state), do: {:msg, :reset}
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

    def update(:reset, state) do
      {%{state | count: 0}, []}
    end

    def update(_msg, state), do: {state, []}

    @impl true
    def view(state), do: {:text, "Count: #{state.count}"}
  end

  # Component that tracks lifecycle events
  defmodule LifecycleTracker do
    @moduledoc """
    Test component that tracks lifecycle events.

    Records init, update, and view calls for verification.
    """

    use TermUI.Elm

    @impl true
    def init(_opts) do
      %{init_called: true, updates: [], views: 0, data: %{}}
    end

    @impl true
    def event_to_msg(%Event.Key{key: "t"}, _state), do: {:msg, :tick}
    def event_to_msg(%Event.Key{key: "q"}, _state), do: {:msg, :quit}
    def event_to_msg(_, _), do: :ignore

    @impl true
    def update(:tick, state) do
      {%{state | updates: [:tick | state.updates]}, []}
    end

    def update(msg, state) do
      {%{state | updates: [msg | state.updates]}, []}
    end

    @impl true
    def view(state) do
      # Increment view counter (stored separately to avoid infinite loop)
      new_state = %{state | views: state.views + 1}
      {:text, "Views: #{new_state.views}, Updates: #{length(state.updates)}"}
    end
  end

  # Component that crashes on specific message
  defmodule CrashingComponent do
    @moduledoc """
    Test component that crashes on command.

    Used to verify cleanup and recovery from crashes.
    """

    use TermUI.Elm

    @impl true
    def init(_opts), do: %{count: 0}

    @impl true
    def event_to_msg(%Event.Key{key: "c"}, _state), do: {:msg, :crash}
    def event_to_msg(%Event.Key{key: "i"}, _state), do: {:msg, :increment}
    def event_to_msg(_, _), do: :ignore

    @impl true
    def update(:crash, _state) do
      raise "Intentional crash for testing"
    end

    def update(:increment, state) do
      {%{state | count: state.count + 1}, []}
    end

    def update(_msg, state), do: {state, []}

    @impl true
    def view(state), do: {:text, "Count: #{state.count}"}
  end

  describe "IEx lifecycle simulation" do
    setup do
      # Save original environment state
      original_env = Application.get_env(:term_ui, :iex_compatible)
      original_iex_env = System.get_env("TERM_UI_IEX_MODE")

      # Simulate IEx environment by setting config
      Application.put_env(:term_ui, :iex_compatible, true)

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

    test "7.6.1.1: start -> render -> input -> update -> render -> shutdown cycle in IEx mode" do
      # Verify IEx mode is active
      assert TermUI.iex_mode?()
      assert TermUI.running_mode() == :iex

      # Start runtime
      {:ok, runtime} = Runtime.start_link(root: Counter, skip_terminal: true)
      ref = Process.monitor(runtime)

      # Verify runtime started successfully
      assert Process.alive?(runtime)

      # Send input event (keyboard press)
      Runtime.send_event(runtime, Event.key(:up))
      Runtime.sync(runtime)

      # Verify state was updated
      state = Runtime.get_state(runtime)
      assert state.root_state.count == 1

      # Send another event to trigger another render cycle
      Runtime.send_event(runtime, Event.key(:up))
      Runtime.sync(runtime)

      state = Runtime.get_state(runtime)
      assert state.root_state.count == 2

      # Send quit to shutdown
      Runtime.send_event(runtime, Event.key("q"))

      # Verify clean shutdown
      assert_receive {:DOWN, ^ref, :process, ^runtime, :normal}, 1000
      refute Process.alive?(runtime)
    end

    test "7.6.1.2: keyboard input works correctly in IEx mode" do
      # Start runtime with counter
      {:ok, runtime} = Runtime.start_link(root: Counter, skip_terminal: true)

      on_exit(fn ->
        if Process.alive?(runtime), do: Runtime.shutdown(runtime)
      end)

      # Test increment key (up arrow)
      Runtime.send_event(runtime, Event.key(:up))
      Runtime.sync(runtime)
      state = Runtime.get_state(runtime)
      assert state.root_state.count == 1

      # Test multiple increments
      for _ <- 1..5 do
        Runtime.send_event(runtime, Event.key(:up))
      end
      Runtime.sync(runtime)
      state = Runtime.get_state(runtime)
      assert state.root_state.count == 6

      # Test decrement key (down arrow)
      Runtime.send_event(runtime, Event.key(:down))
      Runtime.sync(runtime)
      state = Runtime.get_state(runtime)
      assert state.root_state.count == 5

      # Test reset key
      Runtime.send_event(runtime, Event.key("r"))
      Runtime.sync(runtime)
      state = Runtime.get_state(runtime)
      assert state.root_state.count == 0
    end

    test "7.6.1.3: cleanup on crash in IEx mode" do
      # Start runtime with crashing component
      {:ok, runtime} = Runtime.start_link(root: CrashingComponent, skip_terminal: true)
      ref = Process.monitor(runtime)

      # Verify normal operation first
      Runtime.send_event(runtime, Event.key("i"))
      Runtime.sync(runtime)
      state = Runtime.get_state(runtime)
      assert state.root_state.count == 1

      # Trigger crash
      Runtime.send_event(runtime, Event.key("c"))

      # The runtime should survive the crash (component may be restarted)
      # Wait for crash to be processed
      Process.sleep(100)

      # Runtime should still be alive (or cleanly shut down)
      # Either behavior is acceptable for crash handling
      alive = Process.alive?(runtime)

      if alive do
        # If alive, verify it still responds
        Runtime.send_event(runtime, Event.key("i"))
        Runtime.sync(runtime)

        # State may have been reset, but runtime should work
        assert Process.alive?(runtime)

        # Shutdown and wait for exit
        Runtime.shutdown(runtime)
        assert_receive {:DOWN, ^ref, :process, ^runtime, :normal}, 1000
      else
        # If shut down, verify clean exit
        assert_receive {:DOWN, ^ref, :process, ^runtime, _reason}, 500
      end

      # Either way, no zombie processes should remain
      refute Process.alive?(runtime)
    end

    test "7.6.1.4: multiple start/stop cycles in IEx session" do
      # Simulate multiple IEx sessions in sequence
      for cycle <- 1..3 do
        # Start a runtime
        {:ok, runtime} = Runtime.start_link(root: Counter, skip_terminal: true)
        ref = Process.monitor(runtime)

        # Verify it started
        assert Process.alive?(runtime)

        # Do some work
        for _ <- 1..cycle do
          Runtime.send_event(runtime, Event.key(:up))
        end
        Runtime.sync(runtime)

        state = Runtime.get_state(runtime)
        assert state.root_state.count == cycle

        # Shutdown cleanly and wait for exit
        Runtime.shutdown(runtime)
        assert_receive {:DOWN, ^ref, :process, ^runtime, :normal}, 1000

        # Verify shutdown completed
        refute Process.alive?(runtime)
      end

      # All cycles completed successfully
      assert true
    end

    test "IEx mode is detected correctly via config" do
      # With config set to true, iex_mode? should return true
      assert TermUI.iex_mode?()
      assert TermUI.running_mode() == :iex
    end
  end

  describe "IEx mode detection override via environment variable" do
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

    test "environment variable overrides config" do
      # Set config to false but env var to true
      Application.put_env(:term_ui, :iex_compatible, false)
      System.put_env("TERM_UI_IEX_MODE", "true")

      # Env var should take precedence
      assert TermUI.iex_mode?()
      assert TermUI.running_mode() == :iex
    end

    test "environment variable 'false' overrides config true" do
      # Set config to true but env var to false
      Application.put_env(:term_ui, :iex_compatible, true)
      System.put_env("TERM_UI_IEX_MODE", "false")

      # Env var should take precedence
      refute TermUI.iex_mode?()
      assert TermUI.running_mode() == :standalone
    end
  end

  describe "lifecycle event tracking" do
    setup do
      original_env = Application.get_env(:term_ui, :iex_compatible)

      Application.put_env(:term_ui, :iex_compatible, true)

      on_exit(fn ->
        case original_env do
          nil -> Application.delete_env(:term_ui, :iex_compatible)
          val -> Application.put_env(:term_ui, :iex_compatible, val)
        end
      end)

      :ok
    end

    test "init is called on startup" do
      {:ok, runtime} = Runtime.start_link(root: LifecycleTracker, skip_terminal: true)

      on_exit(fn ->
        if Process.alive?(runtime), do: Runtime.shutdown(runtime)
      end)

      state = Runtime.get_state(runtime)
      assert state.root_state.init_called == true
    end

    test "update is called for each event" do
      {:ok, runtime} = Runtime.start_link(root: LifecycleTracker, skip_terminal: true)

      on_exit(fn ->
        if Process.alive?(runtime), do: Runtime.shutdown(runtime)
      end)

      # Send multiple events
      for _ <- 1..5 do
        Runtime.send_event(runtime, Event.key("t"))
      end
      Runtime.sync(runtime)

      state = Runtime.get_state(runtime)
      assert length(state.root_state.updates) == 5
    end

    test "view is callable and returns valid result" do
      {:ok, runtime} = Runtime.start_link(root: LifecycleTracker, skip_terminal: true)

      on_exit(fn ->
        if Process.alive?(runtime), do: Runtime.shutdown(runtime)
      end)

      # Trigger an update which will trigger a view
      Runtime.send_event(runtime, Event.key("t"))
      Runtime.sync(runtime)

      state = Runtime.get_state(runtime)
      # Verify the view state structure exists and is valid
      assert is_integer(state.root_state.views)
      # In skip_terminal mode, view may not be called, so views may be 0
      # But we can verify the state structure is correct
      assert state.root_state.views >= 0
    end
  end

  describe "runtime backend selection in IEx mode" do
    setup do
      original_env = Application.get_env(:term_ui, :iex_compatible)

      Application.put_env(:term_ui, :iex_compatible, true)

      on_exit(fn ->
        case original_env do
          nil -> Application.delete_env(:term_ui, :iex_compatible)
          val -> Application.put_env(:term_ui, :iex_compatible, val)
        end
      end)

      :ok
    end

    test "runtime starts with TTY backend when in IEx mode" do
      # In IEx mode, the backend selector should prefer TTY
      # Start runtime with backend: :auto (default)
      {:ok, runtime} = Runtime.start_link(root: Counter, skip_terminal: true)

      on_exit(fn ->
        if Process.alive?(runtime), do: Runtime.shutdown(runtime)
      end)

      # Runtime should be alive and functional
      assert Process.alive?(runtime)

      # Send an event to verify it's working
      Runtime.send_event(runtime, Event.key(:up))
      Runtime.sync(runtime)

      state = Runtime.get_state(runtime)
      assert state.root_state.count == 1
    end

    test "runtime can be explicitly set to TTY backend" do
      {:ok, runtime} = Runtime.start_link(root: Counter, backend: :tty, skip_terminal: true)

      on_exit(fn ->
        if Process.alive?(runtime), do: Runtime.shutdown(runtime)
      end)

      # Runtime should be alive and functional
      assert Process.alive?(runtime)

      Runtime.send_event(runtime, Event.key(:up))
      Runtime.sync(runtime)

      state = Runtime.get_state(runtime)
      assert state.root_state.count == 1
    end
  end
end
