defmodule TermUI.TerminalTest do
  use ExUnit.Case

  alias TermUI.Terminal
  alias TermUI.Terminal.State

  setup do
    # Start a fresh Terminal GenServer for each test
    case Process.whereis(Terminal) do
      nil ->
        :ok

      pid ->
        ref = Process.monitor(pid)
        Process.exit(pid, :shutdown)

        receive do
          {:DOWN, ^ref, :process, ^pid, _} -> :ok
        after
          100 -> :ok
        end
    end

    {:ok, pid} = Terminal.start_link()

    on_exit(fn ->
      case Process.whereis(Terminal) do
        nil ->
          :ok

        pid when is_pid(pid) ->
          if Process.alive?(pid) do
            ref = Process.monitor(pid)
            Process.exit(pid, :shutdown)

            receive do
              {:DOWN, ^ref, :process, ^pid, _} -> :ok
            after
              100 -> :ok
            end
          end
      end
    end)

    {:ok, pid: pid}
  end

  describe "start_link/1" do
    test "starts the GenServer" do
      # Already started in setup, verify it's running
      assert Process.whereis(Terminal) != nil
    end

    test "sets trap_exit flag" do
      pid = Process.whereis(Terminal)
      {:trap_exit, trap} = Process.info(pid, :trap_exit)
      assert trap == true
    end
  end

  describe "get_state/0" do
    test "returns initial state with default values" do
      state = Terminal.get_state()

      assert %State{} = state
      assert state.raw_mode_active == false
      assert state.alternate_screen_active == false
      assert state.cursor_visible == true
    end
  end

  describe "enable_raw_mode/0" do
    test "returns error when not in a terminal context" do
      # In test environment, we're typically not in a real terminal
      result = Terminal.enable_raw_mode()

      case result do
        {:ok, state} ->
          # If it somehow succeeded (real terminal), verify state
          assert state.raw_mode_active == true
          Terminal.disable_raw_mode()

        {:error, reason} ->
          # Expected in test environment
          assert reason == :not_a_terminal or match?({:otp_version, _}, reason)
      end
    end

    test "is idempotent when already active" do
      # First call
      result1 = Terminal.enable_raw_mode()

      case result1 do
        {:ok, _state} ->
          # Second call should return same state
          {:ok, state2} = Terminal.enable_raw_mode()
          assert state2.raw_mode_active == true
          Terminal.disable_raw_mode()

        {:error, _} ->
          :ok
      end
    end
  end

  describe "disable_raw_mode/0" do
    test "returns ok when raw mode is not active" do
      assert Terminal.disable_raw_mode() == :ok
    end

    test "updates state when disabled" do
      # Try to enable first
      Terminal.enable_raw_mode()
      Terminal.disable_raw_mode()

      state = Terminal.get_state()
      assert state.raw_mode_active == false
    end
  end

  describe "raw_mode?/0" do
    test "returns false when raw mode is not active" do
      assert Terminal.raw_mode?() == false
    end
  end

  describe "enter_alternate_screen/0" do
    test "updates state to track alternate screen is active" do
      :ok = Terminal.enter_alternate_screen()
      state = Terminal.get_state()

      assert state.alternate_screen_active == true
    end

    test "is idempotent" do
      :ok = Terminal.enter_alternate_screen()
      :ok = Terminal.enter_alternate_screen()

      state = Terminal.get_state()
      assert state.alternate_screen_active == true
    end
  end

  describe "leave_alternate_screen/0" do
    test "updates state to track alternate screen is inactive" do
      Terminal.enter_alternate_screen()
      :ok = Terminal.leave_alternate_screen()

      state = Terminal.get_state()
      assert state.alternate_screen_active == false
    end

    test "returns ok when not in alternate screen" do
      assert Terminal.leave_alternate_screen() == :ok
    end
  end

  describe "hide_cursor/0" do
    test "updates state to track cursor is hidden" do
      :ok = Terminal.hide_cursor()
      state = Terminal.get_state()

      assert state.cursor_visible == false
    end
  end

  describe "show_cursor/0" do
    test "updates state to track cursor is visible" do
      Terminal.hide_cursor()
      :ok = Terminal.show_cursor()

      state = Terminal.get_state()
      assert state.cursor_visible == true
    end
  end

  describe "get_terminal_size/0" do
    test "returns size tuple or error" do
      result = Terminal.get_terminal_size()

      case result do
        {:ok, {rows, cols}} ->
          assert is_integer(rows) and rows > 0
          assert is_integer(cols) and cols > 0

        {:error, _reason} ->
          # Expected in test environment without real terminal
          :ok
      end
    end

    test "caches size in state" do
      case Terminal.get_terminal_size() do
        {:ok, {rows, cols}} ->
          state = Terminal.get_state()
          assert state.size == {rows, cols}

        {:error, _} ->
          :ok
      end
    end
  end

  describe "register_resize_callback/1" do
    test "adds pid to callback list" do
      :ok = Terminal.register_resize_callback(self())
      state = Terminal.get_state()

      assert self() in state.resize_callbacks
    end

    test "does not duplicate pids" do
      :ok = Terminal.register_resize_callback(self())
      :ok = Terminal.register_resize_callback(self())

      state = Terminal.get_state()
      assert Enum.count(state.resize_callbacks, &(&1 == self())) == 1
    end
  end

  describe "unregister_resize_callback/1" do
    test "removes pid from callback list" do
      Terminal.register_resize_callback(self())
      :ok = Terminal.unregister_resize_callback(self())

      state = Terminal.get_state()
      refute self() in state.resize_callbacks
    end

    test "handles unregistering non-existent pid" do
      assert :ok = Terminal.unregister_resize_callback(self())
    end
  end

  describe "restore/0" do
    test "resets all terminal state" do
      # Set up some state
      Terminal.enter_alternate_screen()
      Terminal.hide_cursor()
      Terminal.register_resize_callback(self())

      :ok = Terminal.restore()

      state = Terminal.get_state()
      assert state.alternate_screen_active == false
      assert state.cursor_visible == true
      assert state.raw_mode_active == false
    end
  end

  describe "resize notifications" do
    test "sends message to registered callbacks on sigwinch" do
      Terminal.register_resize_callback(self())

      # Simulate SIGWINCH
      send(Process.whereis(Terminal), :sigwinch)

      # May or may not receive message depending on whether size detection works
      receive do
        {:terminal_resize, {rows, cols}} ->
          assert is_integer(rows)
          assert is_integer(cols)
      after
        100 ->
          # No message received is ok in test environment
          :ok
      end
    end
  end

  describe "process exit handling" do
    test "cleans up state on restore call" do
      # Set up state
      Terminal.enter_alternate_screen()
      Terminal.hide_cursor()

      # Verify state is set
      state_before = Terminal.get_state()
      assert state_before.alternate_screen_active == true
      assert state_before.cursor_visible == false

      # Call restore to simulate cleanup
      :ok = Terminal.restore()

      # Verify cleanup occurred
      state = Terminal.get_state()
      assert state.alternate_screen_active == false
      assert state.cursor_visible == true
      assert state.raw_mode_active == false
    end
  end
end
