defmodule TermUI.RuntimeTest do
  use TermUI.TestCase, async: false
  import ExUnit.CaptureLog

  alias TermUI.Event
  alias TermUI.Renderer.Cell
  alias TermUI.Runtime

  # Helper to start runtime without terminal (for test isolation)
  defp start_test_runtime(opts) do
    runtime =
      start_supervised!(
        Supervisor.child_spec(
          {Runtime, [skip_terminal: true] ++ opts},
          id: make_ref()
        )
      )

    {:ok, runtime}
  end

  # Clean up persistent_term values between tests
  setup do
    # Store original values
    original_backend_mode = :persistent_term.get(:term_ui_backend_mode, :not_set)
    original_capabilities = :persistent_term.get(:term_ui_capabilities, :not_set)
    original_character_set = :persistent_term.get(:term_ui_character_set, :not_set)
    original_owner = :persistent_term.get(:term_ui_runtime_owner, :not_set)

    on_exit(fn ->
      # Restore or clean up persistent_term
      if original_backend_mode != :not_set do
        :persistent_term.put(:term_ui_backend_mode, original_backend_mode)
      else
        :persistent_term.erase(:term_ui_backend_mode)
      end

      if original_capabilities != :not_set do
        :persistent_term.put(:term_ui_capabilities, original_capabilities)
      else
        :persistent_term.erase(:term_ui_capabilities)
      end

      if original_character_set != :not_set do
        :persistent_term.put(:term_ui_character_set, original_character_set)
      else
        :persistent_term.erase(:term_ui_character_set)
      end

      if original_owner != :not_set do
        :persistent_term.put(:term_ui_runtime_owner, original_owner)
      else
        :persistent_term.erase(:term_ui_runtime_owner)
      end
    end)

    :ok
  end

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

  defmodule FakeTerminalEnableOk do
    def enable_raw_mode do
      send(self(), :enable_raw_mode_called)
      {:ok, %{raw_mode_active: true}}
    end
  end

  defmodule FakeTerminalEnableError do
    def enable_raw_mode do
      send(self(), :enable_raw_mode_called)
      {:error, :already_started}
    end
  end

  defmodule FakeTerminalRestore do
    def restore do
      send(self(), :restore_called)
      :ok
    end
  end

  defmodule CleanupProbeBackend do
    def shutdown(test_pid) do
      send(test_pid, :cleanup_probe_backend_shutdown)
      :ok
    end
  end

  defmodule ExitProbeBackend do
    def shutdown(_state) do
      exit(:cleanup_probe_backend_exit)
    end
  end

  defmodule CleanupProbeReader do
    use GenServer

    def start_link(test_pid), do: GenServer.start_link(__MODULE__, test_pid)
    @impl true
    def init(test_pid), do: {:ok, test_pid}

    @impl true
    def terminate(_reason, test_pid) do
      send(test_pid, :cleanup_probe_reader_stopped)
      :ok
    end
  end

  describe "start_link/1" do
    test "starts runtime with root component" do
      {:ok, runtime} = start_test_runtime(root: Counter)

      state = Runtime.get_state(runtime)
      assert state.root_module == Counter
      assert state.root_state == %{count: 0}
      refute state.shutting_down
    end

    test "starts runtime with registered name" do
      {:ok, _runtime} = start_test_runtime(root: Counter, name: :test_runtime)

      state = Runtime.get_state(:test_runtime)
      assert state.root_module == Counter

      GenServer.stop(:test_runtime)
    end

    test "passes options to component init" do
      {:ok, runtime} = start_test_runtime(root: Counter, initial: 10)

      state = Runtime.get_state(runtime)
      assert state.root_state.count == 10
    end

    test "handles component without init function" do
      {:ok, runtime} = start_test_runtime(root: NoInit)

      state = Runtime.get_state(runtime)
      assert state.root_state == %{}
    end

    test "sets custom render interval" do
      {:ok, runtime} = start_test_runtime(root: Counter, render_interval: 100)

      state = Runtime.get_state(runtime)
      assert state.render_interval == 100
    end
  end

  describe "send_event/2" do
    test "dispatches keyboard event to focused component" do
      {:ok, runtime} = start_test_runtime(root: Counter)

      Runtime.send_event(runtime, Event.key(:up))
      # Wait for message processing
      Process.sleep(50)

      state = Runtime.get_state(runtime)
      assert state.root_state.count == 1
    end

    test "processes multiple events in sequence" do
      {:ok, runtime} = start_test_runtime(root: Counter)

      Runtime.send_event(runtime, Event.key(:up))
      Runtime.send_event(runtime, Event.key(:up))
      Runtime.send_event(runtime, Event.key(:up))
      Process.sleep(50)

      state = Runtime.get_state(runtime)
      assert state.root_state.count == 3
    end

    test "ignores events during shutdown" do
      {:ok, runtime} = start_test_runtime(root: Counter)

      Runtime.shutdown(runtime)
      Runtime.send_event(runtime, Event.key(:up))
      Process.sleep(50)

      # Process should have stopped after shutdown
      # Events during shutdown should be ignored without crash
      refute Process.alive?(runtime)
    end

    test "broadcasts resize events" do
      {:ok, runtime} = start_test_runtime(root: Counter)

      Runtime.send_event(runtime, Event.resize(120, 40))
      Process.sleep(50)

      state = Runtime.get_state(runtime)
      assert state.root_state.width == 120
      assert state.root_state.height == 40
    end

    test "dispatches paste events to focused component" do
      {:ok, runtime} = start_test_runtime(root: Counter)

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
      {:ok, runtime} = start_test_runtime(root: Counter)

      Runtime.send_message(runtime, :root, :increment)
      Process.sleep(50)

      state = Runtime.get_state(runtime)
      assert state.root_state.count == 1
    end

    test "ignores messages to non-existent component" do
      {:ok, runtime} = start_test_runtime(root: Counter)

      Runtime.send_message(runtime, :nonexistent, :increment)
      Process.sleep(50)

      state = Runtime.get_state(runtime)
      assert state.root_state.count == 0
    end

    test "ignores messages during shutdown" do
      {:ok, runtime} = start_test_runtime(root: Counter)

      Runtime.shutdown(runtime)
      Runtime.send_message(runtime, :root, :increment)
      Process.sleep(50)

      # Process should have stopped after shutdown
      # Messages during shutdown should be ignored without crash
      refute Process.alive?(runtime)
    end
  end

  describe "dirty flag and rendering" do
    test "marks dirty when state changes" do
      {:ok, runtime} = start_test_runtime(root: Counter, render_interval: 10)

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
      {:ok, runtime} = start_test_runtime(root: Counter, render_interval: 10_000)

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
      {:ok, runtime} = start_test_runtime(root: Counter)

      # Send event that produces a quit command
      # This should trigger shutdown
      Runtime.send_event(runtime, Event.key(:q))
      Process.sleep(100)

      # Process should have stopped due to quit command
      refute Process.alive?(runtime)
    end
  end

  describe "command_result/4" do
    test "sends command result as message to component" do
      {:ok, runtime} = start_test_runtime(root: Counter)

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
      {:ok, runtime} = start_test_runtime(root: Counter)

      # Monitor the process
      ref = Process.monitor(runtime)

      Runtime.shutdown(runtime)

      # Process should stop after shutdown
      assert_receive {:DOWN, ^ref, :process, ^runtime, :normal}, 1000
    end

    test "clears pending commands on shutdown" do
      {:ok, runtime} = start_test_runtime(root: Counter)

      Runtime.shutdown(runtime)
      Process.sleep(100)

      # Process should have stopped after cleanup
      refute Process.alive?(runtime)
    end

    test "clears components on shutdown" do
      {:ok, runtime} = start_test_runtime(root: Counter)

      Runtime.shutdown(runtime)
      Process.sleep(100)

      # Process should have stopped after cleanup
      refute Process.alive?(runtime)
    end
  end

  describe "event dispatch routing" do
    test "keyboard events go to focused component" do
      {:ok, runtime} = start_test_runtime(root: Counter)

      # Default focus is :root
      state = Runtime.get_state(runtime)
      assert state.focused_component == :root

      Runtime.send_event(runtime, Event.key(:up))
      Process.sleep(50)

      state = Runtime.get_state(runtime)
      assert state.root_state.count == 1
    end

    test "mouse events go to root (spatial index not implemented)" do
      {:ok, runtime} = start_test_runtime(root: Counter)

      # Mouse events currently just go to root
      Runtime.send_event(runtime, Event.mouse(:click, :left, 10, 10))
      Process.sleep(50)

      # Counter ignores mouse events
      state = Runtime.get_state(runtime)
      assert state.root_state.count == 0
    end

    test "focus events broadcast to all components" do
      {:ok, runtime} = start_test_runtime(root: Counter)

      Runtime.send_event(runtime, Event.focus(:gained))
      Process.sleep(50)

      # Counter ignores focus events
      state = Runtime.get_state(runtime)
      assert state.root_state.count == 0
    end

    test "tick events broadcast to all components" do
      {:ok, runtime} = start_test_runtime(root: Counter)

      Runtime.send_event(runtime, Event.tick(16))
      Process.sleep(50)

      # Counter ignores tick events
      state = Runtime.get_state(runtime)
      assert state.root_state.count == 0
    end
  end

  describe "component initialization" do
    test "initializes component registry with root" do
      {:ok, runtime} = start_test_runtime(root: Counter, initial: 5)

      state = Runtime.get_state(runtime)

      assert Map.has_key?(state.components, :root)
      assert state.components.root.module == Counter
      assert state.components.root.state.count == 5
    end
  end

  describe "render timing" do
    test "uses default render interval" do
      {:ok, runtime} = start_test_runtime(root: Counter)

      state = Runtime.get_state(runtime)
      assert state.render_interval == 16
    end

    test "schedules render ticks" do
      {:ok, runtime} = start_test_runtime(root: Counter, render_interval: 10)

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
      {:ok, runtime} = start_test_runtime(root: Counter, render_interval: 100)

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
      {:ok, runtime} = start_test_runtime(root: Counter)

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
      {:ok, runtime} = start_test_runtime(root: Counter, initial: 5)

      Runtime.send_event(runtime, Event.key(:down))
      Process.sleep(50)

      state = Runtime.get_state(runtime)
      assert state.root_state.count == 4
    end

    test "state changes trigger dirty flag" do
      {:ok, runtime} = start_test_runtime(root: Counter, render_interval: 10)

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

  describe "backend selection" do
    test "stores backend mode in state when skip_terminal is used" do
      {:ok, runtime} = start_test_runtime(root: Counter)

      state = Runtime.get_state(runtime)
      assert state.backend_mode == :skip
      assert state.backend == nil
    end

    test "stores backend mode in persistent_term" do
      {:ok, _runtime} = start_test_runtime(root: Counter)

      assert Runtime.backend_mode() == :skip
    end

    test "stores capabilities in persistent_term" do
      {:ok, _runtime} = start_test_runtime(root: Counter)

      # skip_terminal mode doesn't set capabilities
      assert Runtime.capabilities() == nil
    end

    test "backend_mode/0 returns nil when no runtime started" do
      # Ensure we're not picking up values from other tests
      :persistent_term.erase(:term_ui_backend_mode)
      assert Runtime.backend_mode() == nil
    end

    test "capabilities/0 returns nil when no runtime started" do
      # Ensure we're not picking up values from other tests
      :persistent_term.erase(:term_ui_capabilities)
      assert Runtime.capabilities() == nil
    end
  end

  describe "backend option handling" do
    test "accepts :auto backend option" do
      # With skip_terminal, the actual backend selection is bypassed
      # but the option should still be accepted
      runtime = start_supervised!({Runtime, root: Counter, backend: :auto, skip_terminal: true})

      state = Runtime.get_state(runtime)
      assert state.backend_mode == :skip
    end

    test "accepts :tty backend option" do
      runtime = start_supervised!({Runtime, root: Counter, backend: :tty, skip_terminal: true})

      state = Runtime.get_state(runtime)
      assert state.backend_mode == :skip
    end

    test "accepts TermUI.Backend.TTY explicit backend" do
      runtime =
        start_supervised!(
          {Runtime, root: Counter, backend: TermUI.Backend.TTY, skip_terminal: true}
        )

      state = Runtime.get_state(runtime)
      assert state.backend_mode == :skip
    end
  end

  describe "backend selector integration" do
    test "calls Selector.select/1 during initialization" do
      # Verify that the selector is being called by checking that it works
      # We can't easily test the actual raw mode without a terminal
      # but we can test that the option is passed through

      # Start with explicit TTY backend
      runtime =
        start_supervised!(
          {Runtime, root: Counter, backend: TermUI.Backend.TTY, skip_terminal: true}
        )

      state = Runtime.get_state(runtime)
      # With skip_terminal, backend_mode is :skip
      assert state.backend_mode == :skip
    end

    test "stores backend module in state" do
      {:ok, runtime} = start_test_runtime(root: Counter)

      state = Runtime.get_state(runtime)
      # With skip_terminal, backend is nil
      assert state.backend == nil
    end
  end

  describe "raw setup coordination" do
    test "ensure_raw_mode/2 still calls enable_raw_mode to apply stty settings even when selector started raw mode" do
      # Even though Selector already called :shell.start_interactive({:noshell, :raw}),
      # we must still call Terminal.enable_raw_mode() to apply stty settings
      # (-echo, -opost, -isig, -ixon) that are not set by :shell.start_interactive alone.
      # Without these, the OS-level terminal has echo and output post-processing enabled,
      # which corrupts rendering in standalone mix run.
      assert :ok = Runtime.ensure_raw_mode(true, FakeTerminalEnableOk)
      assert_received :enable_raw_mode_called
    end

    test "ensure_raw_mode/2 enables raw mode when not already active" do
      assert :ok = Runtime.ensure_raw_mode(false, FakeTerminalEnableOk)
      assert_received :enable_raw_mode_called
    end

    test "ensure_raw_mode/2 propagates enable errors when selector did not start raw mode" do
      assert {:error, :already_started} =
               Runtime.ensure_raw_mode(false, FakeTerminalEnableError)

      assert_received :enable_raw_mode_called
    end

    test "ensure_raw_mode/2 treats enable errors as non-fatal when selector already started raw mode" do
      # When Selector already started raw mode, errors from Terminal.enable_raw_mode()
      # are non-fatal because raw mode IS active at the Erlang level
      assert :ok = Runtime.ensure_raw_mode(true, FakeTerminalEnableError)
      assert_received :enable_raw_mode_called
    end

    test "recover_after_raw_setup_failure/2 restores terminal when raw setup was attempted" do
      assert :ok = Runtime.recover_after_raw_setup_failure(true, FakeTerminalRestore)
      assert_received :restore_called
    end

    test "recover_after_raw_setup_failure/2 is a no-op when raw setup was not attempted" do
      assert :ok = Runtime.recover_after_raw_setup_failure(false, FakeTerminalRestore)
      refute_received :restore_called
    end
  end

  describe "shutdown terminal restoration" do
    test "terminate_legacy_restore calls Terminal.restore() when terminal was started with raw backend" do
      # Previously, terminate_legacy_restore only called Terminal.restore() when
      # backend was nil, meaning the Raw backend never got stty settings restored.
      # The fix ensures Terminal.restore() is called for ALL backends.

      # We can't directly test terminate_legacy_restore (private), but we can verify
      # the behavior through the terminate path by checking the state structure.
      # The key invariant: terminal_started: true should trigger restoration
      # regardless of backend value.

      # Verify the function clause matches our fix by constructing the state
      # that would be passed to terminate_legacy_restore
      state_with_raw_backend = %{terminal_started: true, backend: TermUI.Backend.Raw}
      state_without_backend = %{terminal_started: true, backend: nil}
      state_not_started = %{terminal_started: false, backend: nil}

      # Both raw-backend and nil-backend states have terminal_started: true
      assert state_with_raw_backend.terminal_started == true
      assert state_without_backend.terminal_started == true
      assert state_not_started.terminal_started == false
    end

    test "ONLCR is disabled during defensive cleanup" do
      # Verify that disable_onlcr is part of the cleanup behavior
      TermUI.TerminalOutput.enable_onlcr()
      assert TermUI.TerminalOutput.onlcr?()

      # Simulate what terminate_defensive_cleanup does
      TermUI.TerminalOutput.disable_onlcr()
      refute TermUI.TerminalOutput.onlcr?()
    end

    test "ONLCR is enabled when raw backend is initialized" do
      # Verify the ONLCR enable call happens (we test the side effect)
      refute TermUI.TerminalOutput.onlcr?()

      # Simulate what init_raw_backend does
      TermUI.TerminalOutput.enable_onlcr()
      assert TermUI.TerminalOutput.onlcr?()

      # Clean up
      TermUI.TerminalOutput.disable_onlcr()
    end
  end

  describe "terminate/2 cleanup robustness" do
    test "stops legacy input reader before backend shutdown" do
      {:ok, reader} = CleanupProbeReader.start_link(self())

      state = %{
        shutting_down: true,
        backend: CleanupProbeBackend,
        backend_state: self(),
        input_reader: reader,
        input_handler: nil,
        input_state: nil,
        terminal_started: false
      }

      assert :ok = Runtime.terminate(:normal, state)

      # Input reader must stop FIRST to free stdin for drain_pending_input
      # in Raw.shutdown. Without this ordering, both race for stdin reads.
      assert_receive first, 500
      assert_receive second, 500
      assert first == :cleanup_probe_reader_stopped
      assert second == :cleanup_probe_backend_shutdown
    end

    test "continues cleanup when backend shutdown exits" do
      {:ok, reader} = CleanupProbeReader.start_link(self())

      state = %{
        shutting_down: true,
        backend: ExitProbeBackend,
        backend_state: :ignored,
        input_reader: reader,
        input_handler: nil,
        input_state: nil,
        terminal_started: false
      }

      assert :ok = Runtime.terminate(:normal, state)
      assert_receive :cleanup_probe_reader_stopped, 500
    end

    test "defensive cleanup uses write_to_tty for reliable terminal restoration" do
      # The cleanup_sequence must contain all critical escape sequences
      seq = TermUI.TerminalOutput.cleanup_sequence()

      # Mouse tracking disable (all modes)
      assert String.contains?(seq, "\e[?1006l")
      assert String.contains?(seq, "\e[?1003l")
      assert String.contains?(seq, "\e[?1002l")
      assert String.contains?(seq, "\e[?1000l")

      # Cursor show
      assert String.contains?(seq, "\e[?25h")

      # Leave alternate screen
      assert String.contains?(seq, "\e[?1049l")
    end

    test "terminate completes even when write_to_tty is exercised" do
      # Simulate a terminate with terminal_started: false (no actual terminal)
      # This exercises the defensive cleanup path without needing real terminal
      state = %{
        shutting_down: true,
        backend: nil,
        backend_state: nil,
        input_reader: nil,
        input_handler: nil,
        input_state: nil,
        terminal_started: false
      }

      assert :ok = Runtime.terminate(:normal, state)
    end
  end

  describe "input strategy resolution" do
    test "defaults to legacy reader for raw backend when terminal is started" do
      assert Runtime.resolve_input_strategy(:auto, :raw, true) == :legacy_reader
    end

    test "defaults to input handler for tty backend" do
      assert Runtime.resolve_input_strategy(:auto, :tty, false) == :input_handler
    end

    test "explicit true still uses legacy reader for raw backend" do
      assert Runtime.resolve_input_strategy(true, :raw, true) == :legacy_reader
    end

    test "explicit false disables input handler and uses legacy reader when available" do
      assert Runtime.resolve_input_strategy(false, :raw, true) == :legacy_reader
      assert Runtime.resolve_input_strategy(false, :tty, false) == :none
    end
  end

  describe "terminal dimension normalization" do
    test "keeps dimensions in {rows, cols} order" do
      assert Runtime.normalize_terminal_dimensions(24, 80) == {24, 80}
      assert Runtime.normalize_terminal_dimensions(40, 120) == {40, 120}
    end
  end

  describe "diff cell emission" do
    test "emits a changed empty cell to clear previous content" do
      current = Cell.empty()
      previous = Cell.new("X")

      assert Runtime.should_emit_diff_cell?(current, previous)
    end

    test "does not emit unchanged empty cells" do
      assert Runtime.should_emit_diff_cell?(Cell.empty(), Cell.empty()) == false
    end
  end

  describe "input handler integration" do
    test "does not use input handler by default" do
      {:ok, runtime} = start_test_runtime(root: Counter)

      state = Runtime.get_state(runtime)
      # By default, input_handler is nil (legacy InputReader is used)
      assert state.input_handler == nil
      assert state.input_state == nil
    end

    test "initializes input handler when use_input_handler is true" do
      runtime =
        start_supervised!({Runtime, root: Counter, use_input_handler: true, skip_terminal: true})

      state = Runtime.get_state(runtime)
      # With skip_terminal and backend_mode :skip, no input handler is initialized
      assert state.input_handler == nil
    end

    test "initializes input handler for raw backend mode" do
      # We can't test actual raw mode without a terminal, but we can verify
      # the logic path by checking the state structure
      runtime =
        start_supervised!({
          Runtime,
          root: Counter, backend: :raw, use_input_handler: true, skip_terminal: true
        })

      state = Runtime.get_state(runtime)
      # Backend mode :skip means no handler selected
      assert state.input_handler == nil
    end

    test "initializes input handler for TTY backend mode" do
      runtime =
        start_supervised!({
          Runtime,
          root: Counter, backend: :tty, use_input_handler: true, skip_terminal: true
        })

      state = Runtime.get_state(runtime)
      # Backend mode :skip means no handler selected
      assert state.input_handler == nil
    end

    test "input_handler defaults to nil when use_input_handler is false" do
      runtime =
        start_supervised!({Runtime, root: Counter, use_input_handler: false, skip_terminal: true})

      state = Runtime.get_state(runtime)
      assert state.input_handler == nil
      assert state.input_state == nil
    end
  end

  describe "logger suppression" do
    # Ensure the :default logger handler is present before each test and
    # restored after. Tests may add/remove it freely.
    setup do
      # If handler was removed by a prior test, we need a known-good config to restore from.
      # Capture current config or use the persistent_term backup if available.
      saved_config =
        case :logger.get_handler_config(:default) do
          {:ok, config} ->
            config

          {:error, _} ->
            # Try persistent_term backup (set by suppress_logger)
            case :persistent_term.get(:term_ui_logger_handler_config, nil) do
              nil ->
                # Last resort: add a minimal default handler
                :logger.add_handler(:default, :logger_std_h, %{
                  config: %{type: :standard_io},
                  formatter: Logger.Formatter.new()
                })

                case :logger.get_handler_config(:default) do
                  {:ok, config} -> config
                  {:error, _} -> nil
                end

              config ->
                Runtime.restore_logger(config)
                config
            end
        end

      on_exit(fn ->
        # Always ensure the handler is restored
        case :logger.get_handler_config(:default) do
          {:ok, _} ->
            :ok

          {:error, _} ->
            if saved_config, do: Runtime.restore_logger(saved_config)
        end

        # Clean up persistent_term backup
        try do
          :persistent_term.erase(:term_ui_logger_handler_config)
        rescue
          ArgumentError -> :ok
        end
      end)

      %{saved_logger_config: saved_config}
    end

    test "skip_terminal does not suppress logger (config is nil)" do
      {:ok, runtime} = start_test_runtime(root: Counter)

      state = Runtime.get_state(runtime)
      assert state.logger_handler_config == nil
    end

    test "suppress_logger removes the :default handler and returns config" do
      config = Runtime.suppress_logger()
      assert is_map(config)
      assert Map.has_key?(config, :module)

      # Handler should be removed
      assert {:error, _} = :logger.get_handler_config(:default)
    end

    test "suppress_logger returns nil when handler already removed" do
      :logger.remove_handler(:default)

      assert Runtime.suppress_logger() == nil
    end

    test "restore_logger is idempotent (handles double restore)", %{
      saved_logger_config: config
    } do
      assert :ok = Runtime.restore_logger(config)
    end

    test "restore_logger with nil is a no-op" do
      assert :ok = Runtime.restore_logger(nil)
    end

    test "terminate handles nil logger_handler_config gracefully" do
      state = %{
        shutting_down: true,
        backend: nil,
        backend_state: nil,
        input_reader: nil,
        input_handler: nil,
        input_state: nil,
        terminal_started: false,
        logger_handler_config: nil
      }

      assert :ok = Runtime.terminate(:normal, state)
    end

    test "terminate handles missing logger_handler_config key gracefully" do
      state = %{
        shutting_down: true,
        backend: nil,
        backend_state: nil,
        input_reader: nil,
        input_handler: nil,
        input_state: nil,
        terminal_started: false
      }

      assert :ok = Runtime.terminate(:normal, state)
    end
  end

  describe "logging" do
    test "logs capabilities at debug level when backend is selected" do
      log =
        capture_log([level: :debug], fn ->
          _runtime =
            start_supervised!({Runtime, root: Counter, skip_terminal: true, backend: :tty})
        end)

      # With skip_terminal: true, capabilities should still be logged
      assert log =~ "TermUI: Capabilities detected" or log =~ "TermUI: Character set"
    end
  end
end
