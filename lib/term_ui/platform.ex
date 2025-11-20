defmodule TermUI.Platform do
  @moduledoc """
  Platform detection and abstraction for cross-platform terminal support.

  Provides unified API for platform-specific operations, automatically
  selecting the appropriate implementation for the current OS.
  """

  @type platform :: :linux | :macos | :windows | :freebsd | :unknown
  @type version :: {non_neg_integer(), non_neg_integer(), non_neg_integer()} | nil

  @doc """
  Returns the current platform identifier.

  ## Examples

      iex> TermUI.Platform.platform()
      :linux

      iex> TermUI.Platform.platform()
      :macos
  """
  @spec platform() :: platform()
  def platform do
    case :os.type() do
      {:unix, :linux} -> :linux
      {:unix, :darwin} -> :macos
      {:unix, :freebsd} -> :freebsd
      {:win32, _} -> :windows
      _ -> :unknown
    end
  end

  @doc """
  Returns the OS version as a tuple.

  ## Examples

      iex> TermUI.Platform.os_version()
      {5, 15, 0}

      iex> TermUI.Platform.os_version()
      {14, 0, 0}
  """
  @spec os_version() :: version()
  def os_version do
    case :os.version() do
      {major, minor, patch} ->
        {major, minor, patch}

      version_string when is_list(version_string) ->
        parse_version_string(to_string(version_string))

      _ ->
        nil
    end
  end

  @doc """
  Returns true if running on Unix (Linux, macOS, FreeBSD).
  """
  @spec unix?() :: boolean()
  def unix? do
    platform() in [:linux, :macos, :freebsd]
  end

  @doc """
  Returns true if running on Windows.
  """
  @spec windows?() :: boolean()
  def windows? do
    platform() == :windows
  end

  @doc """
  Returns true if running in Windows Subsystem for Linux (WSL).
  """
  @spec wsl?() :: boolean()
  def wsl? do
    if platform() == :linux do
      check_wsl()
    else
      false
    end
  end

  @doc """
  Returns true if running on macOS.
  """
  @spec macos?() :: boolean()
  def macos? do
    platform() == :macos
  end

  @doc """
  Returns true if running on Linux (native, not WSL).
  """
  @spec linux?() :: boolean()
  def linux? do
    platform() == :linux and not wsl?()
  end

  @doc """
  Returns the terminal size as {rows, cols}.

  Falls back to default {24, 80} if unable to detect.
  """
  @spec terminal_size() :: {pos_integer(), pos_integer()}
  def terminal_size do
    rows = get_terminal_rows()
    cols = get_terminal_cols()
    {rows, cols}
  end

  # Platform feature support matrix
  @unix_features MapSet.new([:signals, :pty, :terminfo, :vt_sequences])
  @windows_features MapSet.new([:vt_sequences])

  @doc """
  Returns true if the platform supports the given feature.

  ## Features
  - `:signals` - POSIX signal handling
  - `:pty` - Pseudo-terminal support
  - `:terminfo` - Terminfo database
  - `:vt_sequences` - VT escape sequences
  """
  @spec supports_feature?(atom()) :: boolean()
  def supports_feature?(feature) do
    current_platform = platform()

    cond do
      current_platform in [:linux, :macos, :freebsd] ->
        MapSet.member?(@unix_features, feature)

      current_platform == :windows ->
        MapSet.member?(@windows_features, feature)

      true ->
        false
    end
  end

  @doc """
  Returns platform-specific information as a map.
  """
  @spec info() :: map()
  def info do
    %{
      platform: platform(),
      os_version: os_version(),
      unix: unix?(),
      windows: windows?(),
      wsl: wsl?(),
      terminal_size: terminal_size()
    }
  end

  # Private functions

  defp check_wsl do
    # Check /proc/version for WSL indicators
    case File.read("/proc/version") do
      {:ok, content} ->
        content = String.downcase(content)
        String.contains?(content, "microsoft") or String.contains?(content, "wsl")

      {:error, _} ->
        false
    end
  end

  defp parse_version_string(version_string) do
    # Parse version strings like "5.15.0-generic" or "14.0.0"
    case Regex.run(~r/^(\d+)\.(\d+)(?:\.(\d+))?/, version_string) do
      [_, major, minor, patch] ->
        {String.to_integer(major), String.to_integer(minor), String.to_integer(patch)}

      [_, major, minor] ->
        {String.to_integer(major), String.to_integer(minor), 0}

      _ ->
        nil
    end
  end

  defp get_terminal_rows do
    case :io.rows() do
      {:ok, rows} -> rows
      _ -> 24
    end
  end

  defp get_terminal_cols do
    case :io.columns() do
      {:ok, cols} -> cols
      _ -> 80
    end
  end
end
