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

  @doc """
  Enables ONLCR (output newline to carriage-return + linefeed) translation.

  In OTP 28 raw mode, both prim_tty and stty disable OPOST, meaning bare
  `\\n` is written as LF only (no CR). This causes "staircase" rendering
  where each line starts at the column the previous line ended. Enabling
  ONLCR translates bare `\\n` to `\\r\\n` at the output chokepoint, matching
  what ncurses does internally.

  This is safe because `\\n` (0x0A) never appears inside well-formed CSI
  escape sequences (parameter bytes are 0x30-0x3F, intermediates 0x20-0x2F).

  This flag is process-independent (VM-global), so it applies consistently
  across runtime, terminal, and helper processes.
  """
  @spec enable_onlcr() :: :ok
  def enable_onlcr do
    :persistent_term.put(@onlcr_key, true)
    :ok
  end

  @doc """
  Disables ONLCR translation.
  """
  @spec disable_onlcr() :: :ok
  def disable_onlcr do
    :persistent_term.erase(@onlcr_key)
    :persistent_term.erase({__MODULE__, :needs_hard_reset})
    :ok
  rescue
    _ -> :ok
  end

  @doc """
  Returns whether ONLCR translation is active.
  """
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

  @doc """
  Writes data directly to the terminal device, bypassing the Erlang IO
  system's group leader routing.

  This is essential for terminal cleanup during shutdown because
  `:shell.start_interactive({:noshell, :cooked})` may reconfigure or replace
  the IO handler process that the group leader points to. After that
  transition, `IO.write` through the group leader silently fails (errors
  caught by rescue), and critical cleanup sequences (mouse-off, cursor-show)
  never reach the actual terminal.

  Write path (first success wins):
  1. Raw file write to `/dev/tty` — most reliable on Unix
  2. `IO.write(:standard_error, ...)` — bypasses group leader, writes to fd 2
  3. `IO.write(data)` via group leader — least reliable during shutdown
  """
  @spec write_to_tty(iodata()) :: :ok
  def write_to_tty(data) do
    alias TermUI.DebugLog, as: D
    binary = IO.iodata_to_binary(data)

    D.log(
      "write_to_tty: #{byte_size(binary)} bytes, escape_seqs=#{inspect(binary |> String.replace("\e", "ESC"))}"
    )

    tty_ok = write_to_tty_device(binary)
    D.log("  /dev/tty write: #{tty_ok}")

    if tty_ok do
      :ok
    else
      stderr_ok = write_to_stderr(binary)
      D.log("  stderr write: #{stderr_ok}")

      if stderr_ok do
        :ok
      else
        D.log("  falling back to IO.write")
        write(data)
      end
    end
  rescue
    e ->
      TermUI.DebugLog.log("write_to_tty RESCUED: #{inspect(e)}")
      :ok
  catch
    kind, reason ->
      TermUI.DebugLog.log("write_to_tty CAUGHT: #{kind} #{inspect(reason)}")
      :ok
  end

  @doc """
  Returns the comprehensive terminal cleanup sequence as a single binary.

  This includes all escape sequences needed to restore the terminal to a
  normal state after a TUI session: disable all mouse tracking modes,
  show cursor, reset SGR attributes, and leave alternate screen.

  On ConPTY/WSL environments, individual DEC private mode reset sequences
  (e.g. `\\e[?1003l`) are silently ignored by ConPTY's VT parser. In these
  environments, a full RIS (`\\ec` — Reset to Initial State) is appended
  as the only reliable way to clear mouse tracking state.
  """
  @spec cleanup_sequence() :: binary()
  def cleanup_sequence do
    # Disable ALL mouse tracking modes (defensive — covers any mode that was enabled)
    # Show cursor (DECTCEM on)
    # Reset SGR attributes
    # Leave alternate screen (no-op if not in alt screen)
    base =
      "\e[?1006l\e[?1003l\e[?1002l\e[?1000l" <>
        "\e[?25h" <>
        "\e[0m" <>
        "\e[?1049l"

    if needs_hard_reset?() do
      # ConPTY ignores individual mouse-off sequences. RIS is the nuclear
      # option but it's the only thing that works. The screen will be cleared
      # but the shell redraws its prompt immediately after.
      base <> "\ec"
    else
      base
    end
  end

  @doc """
  Returns true when running under ConPTY/WSL where individual DEC private
  mode reset sequences for mouse tracking are silently ignored.

  Detection checks for WSL environment variables. This is cached via
  persistent_term after the first call for efficiency.
  """
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
    # WSL2 sets these environment variables
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

  # Translates bare \n to \r\n when ONLCR is active.
  # Avoids double-translation: \r\n is left unchanged.
  @spec maybe_translate_newlines(iodata()) :: iodata()
  defp maybe_translate_newlines(data) do
    if onlcr?() do
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

  # Writes directly to /dev/tty using raw file I/O, bypassing the Erlang IO
  # server protocol entirely. This is the most direct path to the terminal.
  @spec write_to_tty_device(binary()) :: boolean()
  defp write_to_tty_device(binary) do
    case :file.open(@tty_path, [:write, :raw]) do
      {:ok, fd} ->
        result = :file.write(fd, binary)
        :file.close(fd)
        result == :ok

      {:error, _} ->
        false
    end
  rescue
    _ -> false
  end

  # Writes to :standard_error, which bypasses the group leader and writes
  # directly to fd 2. On terminals, stderr goes to the same pty as stdout.
  @spec write_to_stderr(binary()) :: boolean()
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
