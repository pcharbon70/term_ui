defmodule TermUI.TerminalOutput do
  @moduledoc false

  @suppress_key :suppress_terminal_output
  @allow_key :term_ui_allow_terminal_output

  @spec write(iodata()) :: :ok
  def write(data) do
    if enabled?() do
      IO.write(data)
    else
      :ok
    end
  rescue
    _ -> :ok
  end

  @spec enabled?() :: boolean()
  def enabled? do
    if Application.get_env(:term_ui, @suppress_key, false) do
      Process.get(@allow_key, false) or not standard_io_group_leader?()
    else
      true
    end
  end

  @spec allow_current_process() :: true
  def allow_current_process do
    Process.put(@allow_key, true)
  end

  @spec disallow_current_process() :: true | nil
  def disallow_current_process do
    Process.delete(@allow_key)
  end

  defp standard_io_group_leader? do
    case Process.info(self(), :group_leader) do
      {:group_leader, leader} ->
        standard = Process.whereis(:standard_io) || Process.whereis(:user)

        case standard do
          nil -> false
          _ -> leader == standard
        end

      _ ->
        false
    end
  end
end
