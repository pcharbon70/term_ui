defmodule TermUI do
  @moduledoc """
  TermUI - A direct-mode Terminal UI framework for Elixir/BEAM.

  This module provides the main entry point for terminal operations.
  """

  alias TermUI.Terminal

  # Dialyzer: Functions with unmatched return values
  @dialyzer {:nowarn_function, size: 0}

  @doc """
  Enables raw mode and sets up the terminal for TUI operation.

  This is a convenience function that:
  1. Starts the Terminal GenServer if needed
  2. Enables raw mode
  3. Enters the alternate screen
  4. Hides the cursor

  Returns `{:ok, state}` on success or `{:error, reason}` on failure.
  """
  @spec init() :: {:ok, Terminal.State.t()} | {:error, term()}
  def init do
    with {:ok, _pid} <- ensure_terminal_started(),
         {:ok, state} <- Terminal.enable_raw_mode(),
         :ok <- Terminal.enter_alternate_screen(),
         :ok <- Terminal.hide_cursor() do
      {:ok, state}
    end
  end

  @doc """
  Restores the terminal to its original state.

  This is a convenience function that performs complete terminal restoration.
  """
  @spec shutdown() :: :ok
  def shutdown do
    Terminal.restore()
  end

  @doc """
  Gets the current terminal size.

  Returns `{:ok, {rows, cols}}` or `{:error, reason}`.
  """
  @spec size() :: {:ok, {pos_integer(), pos_integer()}} | {:error, term()}
  def size do
    ensure_terminal_started()
    Terminal.get_terminal_size()
  end

  @doc """
  Returns whether the application is running inside IEx.

  This function checks multiple indicators to determine if the code is
  executing within an IEx session:

  1. Whether the IEx module is loaded
  2. Whether the current process is an IEx evaluator
  3. Configuration overrides (config or environment variable)

  The result can be overridden by:
  - Setting `config :term_ui, iex_compatible: true` in config
  - Setting the `TERM_UI_IEX_MODE` environment variable to `"true"` or `"false"`

  ## Examples

      iex> TermUI.iex_mode?()
      true

      # In a standalone script:
      TermUI.iex_mode?()
      false

  ## Configuration

  To force IEx-compatible mode (useful for testing):

      # config/config.exs
      config :term_ui, iex_compatible: true

  To override via environment variable:

      export TERM_UI_IEX_MODE=true

  """
  @spec iex_mode?() :: boolean()
  def iex_mode? do
    cond do
      # Environment variable override takes precedence
      env_var = System.get_env("TERM_UI_IEX_MODE") ->
        env_var in ["true", "1", "yes"]

      # Config override
      config = Application.get_env(:term_ui, :iex_compatible) ->
        config == true

      # Auto-detection
      true ->
        iex_running?()
    end
  end

  @doc """
  Returns the current execution mode.

  Returns `:iex` if running inside IEx, `:standalone` otherwise.

  ## Examples

      iex> TermUI.running_mode()
      :iex

      # In a standalone script:
      TermUI.running_mode()
      :standalone

  """
  @spec running_mode() :: :iex | :standalone
  def running_mode do
    if iex_mode?(), do: :iex, else: :standalone
  end

  # Check if IEx is actually running (not just loaded)
  defp iex_running? do
    # Check if IEx module is available and loaded
    # Check if we're in an IEx evaluator process
    Code.ensure_loaded?(IEx) and
      iex_evaluator_process?()
  end

  # Check if current process or any ancestor is an IEx evaluator
  defp iex_evaluator_process? do
    # Get the current process's dictionary and check for IEx-specific keys
    # IEx evaluator processes have the :iex_server key in their dictionary
    Process.info(self(), :dictionary)
    |> case do
      {:dictionary, dictionary} ->
        # Check for IEx evaluator indicator
        Enum.any?(dictionary, fn
          {:iex_server, _} -> true
          _ -> false
        end)

      _ ->
        false
    end
  end

  defp ensure_terminal_started do
    case Process.whereis(Terminal) do
      nil ->
        Terminal.start_link()

      pid ->
        {:ok, pid}
    end
  end
end
