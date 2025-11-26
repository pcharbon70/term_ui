defmodule TermUI.Integration.TerminalLifecycleTest do
  @moduledoc """
  Integration tests for terminal lifecycle management.

  Tests complete initialization, shutdown, crash recovery, and reinitialization
  sequences to ensure robust terminal state management.
  """

  use ExUnit.Case, async: false

  alias TermUI.IntegrationHelpers
  alias TermUI.Terminal

  # These tests require actual terminal access
  @moduletag :integration

  setup do
    # Clean up any existing terminal state
    IntegrationHelpers.stop_terminal()

    on_exit(fn ->
      IntegrationHelpers.cleanup_terminal()
    end)

    :ok
  end

  describe "1.6.1.1 complete initialization sequence" do
    test "initializes terminal in correct order" do
      # Start terminal
      assert {:ok, _pid} = IntegrationHelpers.start_terminal()

      # Verify initial state is clean
      state = Terminal.get_state()
      assert state.raw_mode_active == false
      assert state.alternate_screen_active == false
      assert state.cursor_visible == true
    end

    test "capabilities are detected before raw mode" do
      {:ok, _pid} = IntegrationHelpers.start_terminal()

      # Capabilities should be detectable before enabling raw mode
      caps = TermUI.Capabilities.detect()

      assert is_struct(caps, TermUI.Capabilities)
      assert caps.color_mode in [:monochrome, :color_16, :color_256, :true_color]
    end
  end

  describe "1.6.1.1 tests requiring terminal" do
    setup do
      IntegrationHelpers.stop_terminal()
      on_exit(fn -> IntegrationHelpers.cleanup_terminal() end)
      :ok
    end

    @tag :requires_terminal
    test "full initialization sequence with raw mode" do
      {:ok, _pid} = IntegrationHelpers.start_terminal()

      # Step 1: Detect capabilities
      caps = TermUI.Capabilities.detect()
      assert is_struct(caps, TermUI.Capabilities)

      # Step 2: Enable raw mode
      result = Terminal.enable_raw_mode()
      assert {:ok, state} = result
      assert state.raw_mode_active == true

      # Step 3: Enter alternate screen
      assert :ok = Terminal.enter_alternate_screen()
      assert Terminal.get_state().alternate_screen_active == true

      # Step 4: Hide cursor
      assert :ok = Terminal.hide_cursor()
      assert Terminal.get_state().cursor_visible == false

      # Verify full initialized state
      state = Terminal.get_state()
      assert state.raw_mode_active == true
      assert state.alternate_screen_active == true
      assert state.cursor_visible == false
    end

    test "initialization without terminal returns error" do
      {:ok, _pid} = IntegrationHelpers.start_terminal()

      # In test environment, enable_raw_mode should return error
      result = Terminal.enable_raw_mode()

      # Either succeeds (if in terminal) or fails gracefully
      case result do
        {:ok, _state} -> assert true
        {:error, :not_a_terminal} -> assert true
        {:error, :enotsup} -> assert true
        {:error, {:otp_version, _}} -> assert true
        {:error, reason} -> flunk("Unexpected error: #{inspect(reason)}")
      end
    end
  end

  describe "1.6.1.2 clean shutdown sequence" do
    test "restore returns terminal to clean state" do
      {:ok, _pid} = IntegrationHelpers.start_terminal()

      # Simulate some state changes (without actual terminal ops)
      # We test that restore resets all state flags

      # First restore
      assert :ok = Terminal.restore()

      # Verify clean state
      state = Terminal.get_state()
      assert state.raw_mode_active == false
      assert state.alternate_screen_active == false
      assert state.cursor_visible == true
    end

    test "double restore is idempotent" do
      {:ok, _pid} = IntegrationHelpers.start_terminal()

      # Restore twice should not error
      assert :ok = Terminal.restore()
      assert :ok = Terminal.restore()

      # State should still be clean
      IntegrationHelpers.assert_terminal_clean()
    end
  end

  describe "1.6.1.2 tests requiring terminal" do
    setup do
      IntegrationHelpers.stop_terminal()
      on_exit(fn -> IntegrationHelpers.cleanup_terminal() end)
      :ok
    end

    @tag :requires_terminal
    test "full shutdown sequence reverses initialization" do
      {:ok, _pid} = IntegrationHelpers.start_terminal()

      # Initialize fully
      {:ok, _} = Terminal.enable_raw_mode()
      :ok = Terminal.enter_alternate_screen()
      :ok = Terminal.hide_cursor()

      # Now shutdown in reverse order
      # Step 1: Show cursor
      assert :ok = Terminal.show_cursor()
      assert Terminal.get_state().cursor_visible == true

      # Step 2: Leave alternate screen
      assert :ok = Terminal.leave_alternate_screen()
      assert Terminal.get_state().alternate_screen_active == false

      # Step 3: Disable raw mode
      assert :ok = Terminal.disable_raw_mode()
      assert Terminal.get_state().raw_mode_active == false

      # Verify complete shutdown
      IntegrationHelpers.assert_terminal_clean()
    end
  end

  describe "1.6.1.3 crash recovery" do
    test "genserver traps exit" do
      {:ok, pid} = IntegrationHelpers.start_terminal()

      # Terminal should trap exits
      {:trap_exit, true} = Process.info(pid, :trap_exit)
    end

    test "terminate callback is called on shutdown" do
      {:ok, pid} = IntegrationHelpers.start_terminal()

      # Normal stop should trigger terminate
      GenServer.stop(pid, :normal)

      # Terminal should be gone
      assert Process.whereis(TermUI.Terminal) == nil
    end

    test "restart after crash restores clean state" do
      {:ok, pid} = IntegrationHelpers.start_terminal()

      # Simulate crash and recover
      Process.flag(:trap_exit, true)
      Process.exit(pid, :kill)

      # Wait for process to die
      receive do
        {:EXIT, ^pid, :killed} -> :ok
      after
        1000 -> flunk("Timeout waiting for terminal process to die")
      end

      # Restart the terminal
      case IntegrationHelpers.start_terminal() do
        {:ok, _new_pid} ->
          # Terminal should be back in clean state
          IntegrationHelpers.assert_terminal_clean()

        {:error, reason} ->
          flunk("Crash recovery restart failed: #{inspect(reason)}")
      end
    end

    test "ets table tracks raw mode for crash detection" do
      {:ok, _pid} = IntegrationHelpers.start_terminal()

      # ETS table should exist
      assert :ets.whereis(:term_ui_terminal_state) != :undefined

      # Can lookup values
      case :ets.lookup(:term_ui_terminal_state, :raw_mode_active) do
        [{:raw_mode_active, value}] ->
          assert is_boolean(value)

        [] ->
          # Table exists but no value yet - also valid
          assert true
      end
    end
  end

  describe "1.6.1.4 reinitialization" do
    test "terminal can be restarted after clean shutdown" do
      # First start
      {:ok, pid1} = IntegrationHelpers.start_terminal()
      :ok = Terminal.restore()
      GenServer.stop(pid1, :normal)

      # Second start
      {:ok, pid2} = IntegrationHelpers.start_terminal()

      # Should be different pids
      assert pid1 != pid2

      # State should be clean
      IntegrationHelpers.assert_terminal_clean()
    end

    test "operations work correctly after reinit" do
      # First cycle
      {:ok, _} = IntegrationHelpers.start_terminal()
      size1 = Terminal.get_terminal_size()
      IntegrationHelpers.stop_terminal()

      # Second cycle
      {:ok, _} = IntegrationHelpers.start_terminal()
      size2 = Terminal.get_terminal_size()

      # Terminal size should be consistent
      assert size1 == size2
    end

    test "multiple reinit cycles" do
      for i <- 1..3 do
        {:ok, _} = IntegrationHelpers.start_terminal()

        # Basic operations
        state = Terminal.get_state()
        assert state.raw_mode_active == false, "Cycle #{i}: raw mode should be off"

        IntegrationHelpers.stop_terminal()
      end
    end
  end

  describe "terminal state management" do
    test "get_state returns complete state" do
      {:ok, _pid} = IntegrationHelpers.start_terminal()

      state = Terminal.get_state()

      assert is_struct(state, TermUI.Terminal.State)
      assert Map.has_key?(state, :raw_mode_active)
      assert Map.has_key?(state, :alternate_screen_active)
      assert Map.has_key?(state, :cursor_visible)
      assert Map.has_key?(state, :mouse_tracking)
      assert Map.has_key?(state, :bracketed_paste)
      assert Map.has_key?(state, :size)
    end

    test "terminal size detection" do
      {:ok, _pid} = IntegrationHelpers.start_terminal()

      result = Terminal.get_terminal_size()

      case result do
        {:ok, {rows, cols}} ->
          assert is_integer(rows) and rows > 0
          assert is_integer(cols) and cols > 0

        {:error, _reason} ->
          # In test environment without terminal, this is expected
          assert true
      end
    end

    test "resize callback registration" do
      {:ok, _pid} = IntegrationHelpers.start_terminal()

      # Register for resize events
      assert :ok = Terminal.register_resize_callback(self())

      # Unregister
      assert :ok = Terminal.unregister_resize_callback(self())
    end

    test "resize callback receives notification" do
      {:ok, pid} = IntegrationHelpers.start_terminal()

      # Register for resize events
      assert :ok = Terminal.register_resize_callback(self())

      # Trigger a resize by sending sigwinch to the terminal process
      send(pid, :sigwinch)

      # Should receive resize notification with current terminal size
      # In non-terminal environments, get_terminal_size fails so no notification is sent
      receive do
        {:terminal_resize, {rows, cols}} ->
          assert is_integer(rows) and rows > 0
          assert is_integer(cols) and cols > 0
      after
        100 ->
          # No notification in non-terminal environment is expected
          case Terminal.get_terminal_size() do
            {:ok, _} ->
              flunk("Did not receive resize notification despite terminal being available")

            {:error, _} ->
              :ok
          end
      end

      # Cleanup
      Terminal.unregister_resize_callback(self())
    end

    test "unregistered callback does not receive notification" do
      {:ok, pid} = IntegrationHelpers.start_terminal()

      # Register then unregister
      assert :ok = Terminal.register_resize_callback(self())
      assert :ok = Terminal.unregister_resize_callback(self())

      # Trigger a resize
      send(pid, :sigwinch)

      # Should NOT receive notification
      receive do
        {:terminal_resize, _size} ->
          flunk("Should not receive notification after unregistering")
      after
        100 -> :ok
      end
    end
  end
end
