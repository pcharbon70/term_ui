defmodule TermUI.TerminalOutput do
  @moduledoc false

  @suppress_key :suppress_terminal_output
  @allow_key :term_ui_allow_terminal_output
  @onlcr_key :term_ui_onlcr_active

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

  @doc """
  Enables ONLCR (output newline to carriage-return + linefeed) translation
  for the current process.

  In OTP 28 raw mode, both prim_tty and stty disable OPOST, meaning bare
  `\\n` is written as LF only (no CR). This causes "staircase" rendering
  where each line starts at the column the previous line ended. Enabling
  ONLCR translates bare `\\n` to `\\r\\n` at the output chokepoint, matching
  what ncurses does internally.

  This is safe because `\\n` (0x0A) never appears inside well-formed CSI
  escape sequences (parameter bytes are 0x30-0x3F, intermediates 0x20-0x2F).
  """
  @spec enable_onlcr() :: :ok
  def enable_onlcr do
    Process.put(@onlcr_key, true)
    :ok
  end

  @doc """
  Disables ONLCR translation for the current process.
  """
  @spec disable_onlcr() :: :ok
  def disable_onlcr do
    Process.delete(@onlcr_key)
    :ok
  end

  @doc """
  Returns whether ONLCR translation is active for the current process.
  """
  @spec onlcr?() :: boolean()
  def onlcr? do
    Process.get(@onlcr_key, false) == true
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

  # Translates bare \n to \r\n when ONLCR is active.
  # Avoids double-translation: \r\n is left unchanged.
  @spec maybe_translate_newlines(iodata()) :: iodata()
  defp maybe_translate_newlines(data) do
    if Process.get(@onlcr_key, false) do
      translate_lf(data)
    else
      data
    end
  end

  # Translates bare LF to CRLF in iodata, leaving existing CRLF intact.
  # Works on both binaries and iolists without flattening the full iolist
  # (only flattens when a bare LF is detected and needs translation).
  @spec translate_lf(iodata()) :: iodata()
  defp translate_lf(data) when is_binary(data) do
    if String.contains?(data, "\n") do
      # Replace \n with \r\n, but avoid creating \r\r\n from existing \r\n.
      # First normalize any \r\n to a placeholder, then replace bare \n, then restore.
      # More efficient: use a single-pass regex.
      String.replace(data, ~r/\r?\n/, "\r\n")
    else
      data
    end
  end

  defp translate_lf(data) when is_list(data) do
    # For iolists, flatten to binary only if it may contain \n.
    # This is a pragmatic trade-off: iolists in TUI rendering are typically
    # small per-frame batches, and the cost of flattening is negligible
    # compared to the terminal I/O itself.
    bin = IO.iodata_to_binary(data)
    translate_lf(bin)
  end

  defp translate_lf(data) when is_integer(data) do
    if data == ?\n, do: "\r\n", else: data
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
