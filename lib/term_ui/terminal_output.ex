defmodule TermUI.TerminalOutput do
  @moduledoc false

  @suppress_key :suppress_terminal_output
  @allow_key :term_ui_allow_terminal_output
  @onlcr_key {__MODULE__, :onlcr_active}
  @tty_path ~c"/dev/tty"

  @spec write(iodata()) :: :ok
  def write(data) do
    if enabled?() do
      IO.write(maybe_translate_newlines(data))
    else
      :ok
    end
  rescue
    _ -> :ok
  end

  @spec enable_onlcr() :: :ok
  def enable_onlcr do
    :persistent_term.put(@onlcr_key, true)
    :ok
  end

  @spec disable_onlcr() :: :ok
  def disable_onlcr do
    :persistent_term.erase(@onlcr_key)
    :persistent_term.erase({__MODULE__, :needs_hard_reset})
    :ok
  rescue
    _ -> :ok
  end

  @spec onlcr?() :: boolean()
  def onlcr? do
    :persistent_term.get(@onlcr_key, false) == true
  end

  @spec enabled?() :: boolean()
  def enabled? do
    if Application.get_env(:term_ui, @suppress_key, false) do
      Process.get(@allow_key, false) or not standard_io_group_leader?()
    else
      true
    end
  end

  @spec write_to_tty(iodata()) :: :ok
  def write_to_tty(data) do
    binary = IO.iodata_to_binary(data)

    if write_to_tty_device(binary) do
      :ok
    else
      if write_to_stderr(binary) do
        :ok
      else
        write(data)
      end
    end
  rescue
    _ -> :ok
  catch
    _, _ -> :ok
  end

  @spec cleanup_sequence() :: String.t()
  def cleanup_sequence do
    base =
      "\e[?1006l\e[?1003l\e[?1002l\e[?1000l" <>
        "\e[?25h" <>
        "\e[0m" <>
        "\e[?1049l"

    if needs_hard_reset?() do
      base <> "\ec"
    else
      base
    end
  end

  @spec needs_hard_reset?() :: boolean()
  def needs_hard_reset? do
    key = {__MODULE__, :needs_hard_reset}

    case :persistent_term.get(key, :unset) do
      :unset ->
        result = detect_conpty_environment()
        :persistent_term.put(key, result)
        result

      cached ->
        cached
    end
  end

  defp detect_conpty_environment do
    System.get_env("WSL_DISTRO_NAME") != nil or
      System.get_env("WSL_INTEROP") != nil
  end

  @spec allow_current_process() :: true
  def allow_current_process do
    Process.put(@allow_key, true)
  end

  @spec disallow_current_process() :: true | nil
  def disallow_current_process do
    Process.delete(@allow_key)
  end

  defp maybe_translate_newlines(data) do
    if onlcr?() do
      translate_lf(data)
    else
      data
    end
  end

  defp translate_lf(data) when is_binary(data) do
    if String.contains?(data, "\n") do
      String.replace(data, ~r/\r?\n/, "\r\n")
    else
      data
    end
  end

  defp translate_lf(data) when is_list(data) do
    bin = IO.iodata_to_binary(data)
    translate_lf(bin)
  end

  defp translate_lf(data) when is_integer(data) do
    if data == ?\n, do: "\r\n", else: data
  end

  defp write_to_tty_device(binary) do
    case :file.open(@tty_path, [:write, :raw]) do
      {:ok, fd} ->
        result = :file.write(fd, binary)
        _ = :file.close(fd)
        result == :ok

      {:error, _} ->
        false
    end
  rescue
    _ -> false
  end

  defp write_to_stderr(binary) do
    IO.write(:standard_error, binary)
    true
  rescue
    _ -> false
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
