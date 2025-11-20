defmodule TermUITest do
  use ExUnit.Case

  alias TermUI.Terminal

  setup do
    # Clean up any existing Terminal process
    case Process.whereis(Terminal) do
      nil -> :ok
      pid ->
        ref = Process.monitor(pid)
        Process.exit(pid, :shutdown)
        receive do
          {:DOWN, ^ref, :process, ^pid, _} -> :ok
        after
          100 -> :ok
        end
    end

    on_exit(fn ->
      case Process.whereis(Terminal) do
        nil -> :ok
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

    :ok
  end

  describe "init/0" do
    test "starts terminal and attempts initialization" do
      result = TermUI.init()

      case result do
        {:ok, state} ->
          # Successfully initialized (real terminal)
          assert state.raw_mode_active == true
          TermUI.shutdown()

        {:error, reason} ->
          # Expected in test environment
          assert reason in [:not_a_terminal] or
                   match?({:otp_version, _}, reason)
      end
    end
  end

  describe "shutdown/0" do
    test "restores terminal state" do
      # Start terminal first
      _result = TermUI.init()
      # Shutdown should work even if init failed (Terminal process still exists)
      case Process.whereis(Terminal) do
        nil -> :ok
        _pid -> assert TermUI.shutdown() == :ok
      end
    end
  end

  describe "size/0" do
    test "returns terminal size or error" do
      result = TermUI.size()

      case result do
        {:ok, {rows, cols}} ->
          assert is_integer(rows) and rows > 0
          assert is_integer(cols) and cols > 0

        {:error, _reason} ->
          # Expected in test environment
          :ok
      end
    end
  end
end
