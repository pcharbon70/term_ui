defmodule TermUITest do
  use ExUnit.Case

  alias TermUI.Terminal

  setup do
    # Clean up any existing Terminal process
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
          assert reason in [:not_a_terminal, :enotsup] or
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

  describe "iex_mode?/0" do
    test "returns false when not in IEx (default)" do
      # We're not running in IEx during tests
      refute TermUI.iex_mode?()
    end

    test "returns true when config forces IEx-compatible mode" do
      # Set config to force IEx mode
      Application.put_env(:term_ui, :iex_compatible, true)

      try do
        assert TermUI.iex_mode?() == true
      after
        # Clean up
        Application.delete_env(:term_ui, :iex_compatible)
      end
    end

    test "returns false when config forces standalone mode" do
      # Set config to force standalone mode
      Application.put_env(:term_ui, :iex_compatible, false)

      try do
        # Even if we were in IEx, config forces standalone
        assert TermUI.iex_mode?() == false
      after
        # Clean up
        Application.delete_env(:term_ui, :iex_compatible)
      end
    end

    test "environment variable override works" do
      # Set environment variable to force IEx mode
      System.put_env("TERM_UI_IEX_MODE", "true")

      try do
        assert TermUI.iex_mode?() == true
      after
        # Clean up
        System.delete_env("TERM_UI_IEX_MODE")
      end
    end

    test "environment variable '1' also forces IEx mode" do
      System.put_env("TERM_UI_IEX_MODE", "1")

      try do
        assert TermUI.iex_mode?() == true
      after
        System.delete_env("TERM_UI_IEX_MODE")
      end
    end

    test "environment variable 'yes' also forces IEx mode" do
      System.put_env("TERM_UI_IEX_MODE", "yes")

      try do
        assert TermUI.iex_mode?() == true
      after
        System.delete_env("TERM_UI_IEX_MODE")
      end
    end

    test "environment variable 'false' forces standalone mode" do
      System.put_env("TERM_UI_IEX_MODE", "false")

      try do
        # Even with config set to true, env var takes precedence
        Application.put_env(:term_ui, :iex_compatible, true)
        assert TermUI.iex_mode?() == false
      after
        System.delete_env("TERM_UI_IEX_MODE")
        Application.delete_env(:term_ui, :iex_compatible)
      end
    end

    test "environment variable takes precedence over config" do
      System.put_env("TERM_UI_IEX_MODE", "true")
      Application.put_env(:term_ui, :iex_compatible, false)

      try do
        # Env var should override config
        assert TermUI.iex_mode?() == true
      after
        System.delete_env("TERM_UI_IEX_MODE")
        Application.delete_env(:term_ui, :iex_compatible)
      end
    end
  end

  describe "running_mode/0" do
    test "returns :standalone when not in IEx" do
      assert TermUI.running_mode() == :standalone
    end

    test "returns :iex when config forces IEx-compatible mode" do
      Application.put_env(:term_ui, :iex_compatible, true)

      try do
        assert TermUI.running_mode() == :iex
      after
        Application.delete_env(:term_ui, :iex_compatible)
      end
    end

    test "returns :iex when environment variable forces IEx mode" do
      System.put_env("TERM_UI_IEX_MODE", "true")

      try do
        assert TermUI.running_mode() == :iex
      after
        System.delete_env("TERM_UI_IEX_MODE")
      end
    end
  end
end
