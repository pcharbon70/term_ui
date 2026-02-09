defmodule TermUI.DebugLog do
  @moduledoc false
  # Temporary debug logger that writes directly to a file.
  # Bypasses Erlang IO entirely to work during shutdown.

  @log_path "/tmp/termui_debug.log"

  def log(msg) do
    ts = :os.system_time(:microsecond)
    pid = inspect(self())
    line = "[#{ts}] [#{pid}] #{msg}\n"

    case :file.open(~c"#{@log_path}", [:append, :raw]) do
      {:ok, fd} ->
        :file.write(fd, line)
        :file.close(fd)

      {:error, reason} ->
        IO.write(:standard_error, "DEBUG LOG FAILED: #{inspect(reason)}: #{line}")
    end
  rescue
    _ -> :ok
  catch
    _, _ -> :ok
  end

  def log(label, value) do
    log("#{label}: #{inspect(value)}")
  end

  def clear do
    File.rm(@log_path)
    :ok
  rescue
    _ -> :ok
  end

  def stty_state do
    case System.cmd("stty", ["-a", "-F", "/dev/tty"], stderr_to_stdout: true) do
      {output, 0} -> output |> String.trim()
      {err, code} -> "stty -a failed (#{code}): #{err}"
    end
  rescue
    e -> "stty -a error: #{inspect(e)}"
  end

  def stty_short do
    full = stty_state()
    # Extract key settings
    opost = if String.contains?(full, "-opost"), do: "OFF", else: "ON"
    onlcr = if String.contains?(full, "-onlcr"), do: "OFF", else: "ON"
    echo = if String.contains?(full, " -echo"), do: "OFF", else: "ON"
    icanon = if String.contains?(full, "-icanon"), do: "OFF", else: "ON"
    isig = if String.contains?(full, "-isig"), do: "OFF", else: "ON"
    "opost=#{opost} onlcr=#{onlcr} echo=#{echo} icanon=#{icanon} isig=#{isig}"
  rescue
    _ -> "stty_short failed"
  end
end
