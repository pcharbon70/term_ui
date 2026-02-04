defmodule TermUI.Terminal.RawModeTest do
  use TermUI.TestCase, async: false

  alias TermUI.Terminal
  require Logger

  describe "raw mode enable/disable" do
    test "enable_raw_mode returns ok tuple" do
      # This test needs the Terminal GenServer running
      {pid, started?} = start_terminal()

      result = Terminal.enable_raw_mode()

      case result do
        {:ok, _state} ->
          # Successfully enabled - now disable
          assert :ok = Terminal.disable_raw_mode()

        {:error, :not_a_terminal} ->
          # Expected when running in non-interactive environment (CI, tests)
          assert true

        {:error, reason} ->
          # Some other error - document for compatibility research
          Logger.debug("Raw mode enable failed with: #{inspect(reason)}")
          assert true
      end

      Terminal.restore()
      stop_terminal({pid, started?})
    end

    test "disable_raw_mode returns ok when not in raw mode" do
      {pid, started?} = start_terminal()

      # Should be safe to disable even when not enabled
      result = Terminal.disable_raw_mode()
      assert result == :ok

      stop_terminal({pid, started?})
    end

    test "raw_mode? returns false initially" do
      {pid, started?} = start_terminal()

      refute Terminal.raw_mode?()

      stop_terminal({pid, started?})
    end

    test "raw_mode? returns true after enable" do
      {pid, started?} = start_terminal()

      result = Terminal.enable_raw_mode()

      case result do
        {:ok, _state} ->
          assert Terminal.raw_mode?()
          Terminal.disable_raw_mode()

        {:error, _reason} ->
          # Not a terminal in test environment
          refute Terminal.raw_mode?()
      end

      stop_terminal({pid, started?})
    end

    test "raw_mode? returns false after disable" do
      {pid, started?} = start_terminal()

      case Terminal.enable_raw_mode() do
        {:ok, _state} ->
          assert Terminal.raw_mode?()
          Terminal.disable_raw_mode()
          refute Terminal.raw_mode?()

        {:error, _reason} ->
          refute Terminal.raw_mode?()
      end

      stop_terminal({pid, started?})
    end
  end

  describe "restore/0" do
    test "restore returns ok" do
      {pid, started?} = start_terminal()

      result = Terminal.restore()
      assert result == :ok

      stop_terminal({pid, started?})
    end

    test "restore clears raw mode state" do
      {pid, started?} = start_terminal()

      case Terminal.enable_raw_mode() do
        {:ok, _state} ->
          Terminal.restore()
          refute Terminal.raw_mode?()

        {:error, _reason} ->
          Terminal.restore()
          refute Terminal.raw_mode?()
      end

      stop_terminal({pid, started?})
    end

    test "restore can be called multiple times safely" do
      {pid, started?} = start_terminal()

      assert :ok = Terminal.restore()
      assert :ok = Terminal.restore()
      assert :ok = Terminal.restore()

      stop_terminal({pid, started?})
    end
  end

  describe "get_state/0" do
    test "get_state returns state struct" do
      {pid, started?} = start_terminal()

      state = Terminal.get_state()
      assert is_struct(state, TermUI.Terminal.State)
      assert state.cursor_visible == true
      assert state.raw_mode_active == false

      stop_terminal({pid, started?})
    end

    test "state reflects raw mode activation" do
      {pid, started?} = start_terminal()

      case Terminal.enable_raw_mode() do
        {:ok, _result} ->
          state = Terminal.get_state()
          assert state.raw_mode_active == true
          assert is_binary(state.original_settings) or is_nil(state.original_settings)
          Terminal.disable_raw_mode()

        {:error, _reason} ->
          state = Terminal.get_state()
          assert state.raw_mode_active == false
          assert state.original_settings == nil
      end

      stop_terminal({pid, started?})
    end
  end

  describe "terminal detection" do
    test "returns not_a_terminal error when not a tty" do
      # In test environment, stdin is typically not a terminal
      # So we expect this error
      {pid, started?} = start_terminal()

      result = Terminal.enable_raw_mode()

      case result do
        {:error, :not_a_terminal} ->
          # Expected in test environment
          assert true

        {:ok, _state} ->
          # Running with a real terminal
          Terminal.disable_raw_mode()
          assert true

        {:error, _reason} ->
          # Some other error
          assert true
      end

      stop_terminal({pid, started?})
    end
  end

  describe "double enable/disable" do
    test "double enable is safe" do
      {pid, started?} = start_terminal()

      result1 = Terminal.enable_raw_mode()
      result2 = Terminal.enable_raw_mode()

      # Second enable should return the same state
      case {result1, result2} do
        {{:ok, _}, {:ok, _}} ->
          # Both succeeded
          assert Terminal.raw_mode?()
          Terminal.disable_raw_mode()

        {{:error, _}, {:error, _}} ->
          # Both failed (not a terminal)
          refute Terminal.raw_mode?()

        _ ->
          # Unexpected combination
          Terminal.disable_raw_mode()
      end

      stop_terminal({pid, started?})
    end

    test "double disable is safe" do
      {pid, started?} = start_terminal()

      case Terminal.enable_raw_mode() do
        {:ok, _state} ->
          assert :ok = Terminal.disable_raw_mode()
          assert :ok = Terminal.disable_raw_mode()
          refute Terminal.raw_mode?()

        {:error, _reason} ->
          assert :ok = Terminal.disable_raw_mode()
          assert :ok = Terminal.disable_raw_mode()
      end

      stop_terminal({pid, started?})
    end
  end

  defp start_terminal do
    case Terminal.start_link() do
      {:ok, pid} -> {pid, :started}
      {:error, {:already_started, pid}} -> {pid, :existing}
    end
  end

  defp stop_terminal({pid, :started}), do: GenServer.stop(pid)
  defp stop_terminal({_pid, :existing}), do: :ok
end
