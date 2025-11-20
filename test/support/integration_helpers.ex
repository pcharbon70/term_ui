defmodule TermUI.IntegrationHelpers do
  @moduledoc """
  Helper functions for integration tests.

  Provides utilities for setting up and tearing down terminal state,
  capturing output, and simulating input.
  """

  alias TermUI.Terminal

  @doc """
  Starts the Terminal GenServer for integration tests.

  Returns `{:ok, pid}` or `{:error, reason}`.
  """
  @spec start_terminal() :: {:ok, pid()} | {:error, term()}
  def start_terminal do
    case Terminal.start_link([]) do
      {:ok, pid} -> {:ok, pid}
      {:error, {:already_started, pid}} -> {:ok, pid}
      error -> error
    end
  end

  @doc """
  Stops the Terminal GenServer.
  """
  @spec stop_terminal() :: :ok
  def stop_terminal do
    pid = Process.whereis(TermUI.Terminal)

    if pid && Process.alive?(pid) do
      # Ensure terminal is restored before stopping
      try do
        Terminal.restore()
        GenServer.stop(TermUI.Terminal, :normal)
      catch
        :exit, _ -> :ok
      end
    end

    :ok
  end

  @doc """
  Sets up terminal environment for testing.

  Returns `:ok` on success.
  """
  @spec setup_terminal() :: :ok | {:error, term()}
  def setup_terminal do
    case start_terminal() do
      {:ok, _pid} -> :ok
      error -> error
    end
  end

  @doc """
  Cleans up terminal environment after testing.

  Ensures terminal is restored to a clean state.
  """
  @spec cleanup_terminal() :: :ok
  def cleanup_terminal do
    stop_terminal()
  end

  @doc """
  Executes a function with terminal setup and automatic cleanup.

  ## Example

      with_terminal(fn ->
        Terminal.enable_raw_mode()
        # test code
      end)
  """
  @spec with_terminal(function()) :: term()
  def with_terminal(fun) when is_function(fun, 0) do
    case setup_terminal() do
      :ok ->
        try do
          fun.()
        after
          cleanup_terminal()
        end

      error ->
        error
    end
  end

  @doc """
  Asserts that the terminal state is in a clean (default) state.

  Returns `:ok` if clean, raises on failure.
  """
  @spec assert_terminal_clean() :: :ok
  def assert_terminal_clean do
    state = Terminal.get_state()

    unless state.raw_mode_active == false do
      raise "Terminal raw mode should be inactive, got: #{state.raw_mode_active}"
    end

    unless state.alternate_screen_active == false do
      raise "Terminal alternate screen should be inactive, got: #{state.alternate_screen_active}"
    end

    unless state.cursor_visible == true do
      raise "Terminal cursor should be visible, got: #{state.cursor_visible}"
    end

    :ok
  end

  @doc """
  Asserts that the terminal state matches expected values.
  """
  @spec assert_terminal_state(keyword()) :: :ok
  def assert_terminal_state(expected) do
    state = Terminal.get_state()

    for {key, expected_value} <- expected do
      actual_value = Map.get(state, key)

      unless actual_value == expected_value do
        raise "Expected terminal #{key} to be #{inspect(expected_value)}, got: #{inspect(actual_value)}"
      end
    end

    :ok
  end

  @doc """
  Checks if running in a terminal environment.

  Returns true if stdin/stdout are connected to a terminal.
  """
  @spec terminal_available?() :: boolean()
  def terminal_available? do
    case :io.getopts(:standard_io) do
      {:ok, opts} ->
        Keyword.has_key?(opts, :terminal)

      _ ->
        # Fallback: check if it's a TTY
        case System.cmd("test", ["-t", "1"], stderr_to_stdout: true) do
          {_, 0} -> true
          _ -> false
        end
    end
  rescue
    _ -> false
  end

  @doc """
  Checks if OTP 28+ raw mode is available.
  """
  @spec raw_mode_available?() :: boolean()
  def raw_mode_available? do
    function_exported?(:shell, :start_interactive, 1)
  end

  @doc """
  Checks if PTY support is available (Unix only).
  """
  @spec pty_available?() :: boolean()
  def pty_available? do
    case :os.type() do
      {:unix, _} -> true
      _ -> false
    end
  end

  @doc """
  Gets the current terminal size or default if not available.
  """
  @spec get_terminal_size_or_default() :: {pos_integer(), pos_integer()}
  def get_terminal_size_or_default do
    case Terminal.get_terminal_size() do
      {:ok, size} -> size
      {:error, _} -> {24, 80}
    end
  end

  @doc """
  Simulates a crash of the terminal GenServer and verifies recovery.
  """
  @spec simulate_crash_and_recover() :: :ok | {:error, term()}
  def simulate_crash_and_recover do
    pid = Process.whereis(TermUI.Terminal)

    if pid do
      # Set up monitor before killing to avoid race condition
      ref = Process.monitor(pid)

      # Kill the process
      Process.exit(pid, :kill)

      # Wait for it to die
      receive do
        {:DOWN, ^ref, :process, ^pid, _reason} -> :ok
      after
        1000 -> {:error, :timeout_waiting_for_crash}
      end

      # Restart the terminal
      case start_terminal() do
        {:ok, _} -> :ok
        error -> error
      end
    else
      {:error, :terminal_not_running}
    end
  end

  @doc """
  Sets environment variables for testing capabilities.
  """
  @spec with_env(map(), function()) :: term()
  def with_env(env_vars, fun) when is_map(env_vars) and is_function(fun, 0) do
    # Save original values
    originals =
      for {key, _value} <- env_vars, into: %{} do
        {key, System.get_env(key)}
      end

    # Set new values
    for {key, value} <- env_vars do
      if value do
        System.put_env(key, value)
      else
        System.delete_env(key)
      end
    end

    try do
      fun.()
    after
      # Restore original values
      for {key, original} <- originals do
        if original do
          System.put_env(key, original)
        else
          System.delete_env(key)
        end
      end
    end
  end

  @doc """
  Creates a mock terminal environment with specific capabilities.
  """
  @spec mock_terminal_env(atom()) :: map()
  def mock_terminal_env(:xterm_256color) do
    %{
      "TERM" => "xterm-256color",
      "COLORTERM" => nil,
      "TERM_PROGRAM" => nil
    }
  end

  def mock_terminal_env(:truecolor) do
    %{
      "TERM" => "xterm-256color",
      "COLORTERM" => "truecolor",
      "TERM_PROGRAM" => nil
    }
  end

  def mock_terminal_env(:basic) do
    %{
      "TERM" => "xterm",
      "COLORTERM" => nil,
      "TERM_PROGRAM" => nil
    }
  end

  def mock_terminal_env(:iterm2) do
    %{
      "TERM" => "xterm-256color",
      "COLORTERM" => nil,
      "TERM_PROGRAM" => "iTerm.app"
    }
  end

  def mock_terminal_env(:windows_terminal) do
    %{
      "TERM" => nil,
      "COLORTERM" => nil,
      "WT_SESSION" => "true",
      "TERM_PROGRAM" => nil
    }
  end
end
