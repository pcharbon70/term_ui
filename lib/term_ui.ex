defmodule TermUI do
  @moduledoc """
  TermUI - A direct-mode Terminal UI framework for Elixir/BEAM.

  This module provides the main entry point for terminal operations.
  """

  alias TermUI.Terminal

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

  defp ensure_terminal_started do
    case Process.whereis(Terminal) do
      nil ->
        Terminal.start_link()

      pid ->
        {:ok, pid}
    end
  end
end
