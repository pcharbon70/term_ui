defmodule TermUI.TerminalOutput do
  @moduledoc false

  # The cleanup result is a fixed-length iolist. Dialyzer cannot express that
  # shape without narrowing the public contract to terminal-specific literals.
  @dialyzer {:nowarn_function, cleanup_sequence: 1}

  @suppress_key :suppress_terminal_output
  @allow_key :term_ui_allow_terminal_output
  @onlcr_key {__MODULE__, :onlcr_active}
  @tty_path ~c"/dev/tty"

  @spec write(iodata()) :: :ok | {:error, term()}
  def write(data) do
    if enabled?() do
      IO.write(maybe_translate_newlines(data))
    else
      :ok
    end
  rescue
    exception -> {:error, exception}
  catch
    kind, reason -> {:error, {kind, reason}}
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
    if enabled?() do
      write_enabled_to_tty(data)
    else
      :ok
    end
  rescue
    _ -> :ok
  catch
    _, _ -> :ok
  end

  @spec cleanup_sequence(keyword()) :: [binary() | []]
  def cleanup_sequence(opts \\ []) do
    [
      if(Keyword.get(opts, :mouse, false), do: "\e[?1006l\e[?1003l\e[?1002l\e[?1000l", else: []),
      if(Keyword.get(opts, :bracketed_paste, false), do: "\e[?2004l", else: []),
      if(Keyword.get(opts, :focus_events, false), do: "\e[?1004l", else: []),
      "\e[?25h",
      "\e[0m",
      if(Keyword.get(opts, :alternate_screen, false), do: "\e[?1049l", else: [])
    ]
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
    _previous = Process.put(@allow_key, true)
    true
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

  defp write_enabled_to_tty(data) do
    binary = IO.iodata_to_binary(data)

    case write(data) do
      :ok ->
        :ok

      {:error, _reason} ->
        cond do
          write_to_tty_device(binary) -> :ok
          write_to_stderr(binary) -> :ok
          true -> :ok
        end
    end
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
