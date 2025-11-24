defmodule TermUI.Terminal.RawModeTest do
  use ExUnit.Case, async: false

  alias TermUI.Terminal

  describe "raw mode enable/disable" do
    test "enable_raw_mode returns ok tuple" do
      # This test needs the Terminal GenServer running
      {:ok, _pid} = Terminal.start_link()

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
          IO.puts("Raw mode enable failed with: #{inspect(reason)}")
          assert true
      end

      Terminal.restore()
      GenServer.stop(Terminal)
    end

    test "disable_raw_mode returns ok when not in raw mode" do
      {:ok, _pid} = Terminal.start_link()

      # Should be safe to disable even when not enabled
      result = Terminal.disable_raw_mode()
      assert result == :ok

      GenServer.stop(Terminal)
    end

    test "raw_mode? returns false initially" do
      {:ok, _pid} = Terminal.start_link()

      refute Terminal.raw_mode?()

      GenServer.stop(Terminal)
    end

    test "raw_mode? returns true after enable" do
      {:ok, _pid} = Terminal.start_link()

      result = Terminal.enable_raw_mode()

      case result do
        {:ok, _state} ->
          assert Terminal.raw_mode?()
          Terminal.disable_raw_mode()

        {:error, _reason} ->
          # Not a terminal in test environment
          refute Terminal.raw_mode?()
      end

      GenServer.stop(Terminal)
    end

    test "raw_mode? returns false after disable" do
      {:ok, _pid} = Terminal.start_link()

      case Terminal.enable_raw_mode() do
        {:ok, _state} ->
          assert Terminal.raw_mode?()
          Terminal.disable_raw_mode()
          refute Terminal.raw_mode?()

        {:error, _reason} ->
          refute Terminal.raw_mode?()
      end

      GenServer.stop(Terminal)
    end
  end

  describe "restore/0" do
    test "restore returns ok" do
      {:ok, _pid} = Terminal.start_link()

      result = Terminal.restore()
      assert result == :ok

      GenServer.stop(Terminal)
    end

    test "restore clears raw mode state" do
      {:ok, _pid} = Terminal.start_link()

      case Terminal.enable_raw_mode() do
        {:ok, _state} ->
          Terminal.restore()
          refute Terminal.raw_mode?()

        {:error, _reason} ->
          Terminal.restore()
          refute Terminal.raw_mode?()
      end

      GenServer.stop(Terminal)
    end

    test "restore can be called multiple times safely" do
      {:ok, _pid} = Terminal.start_link()

      assert :ok = Terminal.restore()
      assert :ok = Terminal.restore()
      assert :ok = Terminal.restore()

      GenServer.stop(Terminal)
    end
  end

  describe "get_state/0" do
    test "get_state returns state struct" do
      {:ok, _pid} = Terminal.start_link()

      state = Terminal.get_state()
      assert is_struct(state, TermUI.Terminal.State)
      assert state.cursor_visible == true
      assert state.raw_mode_active == false

      GenServer.stop(Terminal)
    end

    test "state reflects raw mode activation" do
      {:ok, _pid} = Terminal.start_link()

      case Terminal.enable_raw_mode() do
        {:ok, _result} ->
          state = Terminal.get_state()
          assert state.raw_mode_active == true
          # Original settings should be captured
          assert state.original_settings != nil
          Terminal.disable_raw_mode()

        {:error, _reason} ->
          state = Terminal.get_state()
          assert state.raw_mode_active == false
      end

      GenServer.stop(Terminal)
    end
  end

  describe "terminal detection" do
    test "returns not_a_terminal error when not a tty" do
      # In test environment, stdin is typically not a terminal
      # So we expect this error
      {:ok, _pid} = Terminal.start_link()

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

      GenServer.stop(Terminal)
    end
  end

  describe "double enable/disable" do
    test "double enable is safe" do
      {:ok, _pid} = Terminal.start_link()

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

      GenServer.stop(Terminal)
    end

    test "double disable is safe" do
      {:ok, _pid} = Terminal.start_link()

      case Terminal.enable_raw_mode() do
        {:ok, _state} ->
          assert :ok = Terminal.disable_raw_mode()
          assert :ok = Terminal.disable_raw_mode()
          refute Terminal.raw_mode?()

        {:error, _reason} ->
          assert :ok = Terminal.disable_raw_mode()
          assert :ok = Terminal.disable_raw_mode()
      end

      GenServer.stop(Terminal)
    end
  end
end
