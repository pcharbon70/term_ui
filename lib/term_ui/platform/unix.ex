defmodule TermUI.Platform.Unix do
  @moduledoc """
  Unix-specific terminal handling for Linux and macOS.

  Provides platform-specific implementations for:
  - Terminal size detection
  - Signal handling hints
  - Capability detection hints
  """

  @doc """
  Returns Unix-specific terminal information.
  """
  @spec info() :: map()
  def info do
    %{
      platform: detect_unix_variant(),
      kernel_version: kernel_version(),
      terminfo_paths: terminfo_paths(),
      supports_signals: true,
      supports_pty: true
    }
  end

  @doc """
  Returns the Unix variant (linux, macos, freebsd).
  """
  @spec detect_unix_variant() :: :linux | :macos | :freebsd | :unknown
  def detect_unix_variant do
    case :os.type() do
      {:unix, :linux} -> :linux
      {:unix, :darwin} -> :macos
      {:unix, :freebsd} -> :freebsd
      _ -> :unknown
    end
  end

  @doc """
  Returns the kernel version string.
  """
  @spec kernel_version() :: String.t() | nil
  def kernel_version do
    case :os.version() do
      {major, minor, patch} ->
        "#{major}.#{minor}.#{patch}"

      _ ->
        nil
    end
  end

  @doc """
  Returns paths where terminfo database may be found.
  """
  @spec terminfo_paths() :: [String.t()]
  def terminfo_paths do
    base_paths = [
      "/usr/share/terminfo",
      "/usr/lib/terminfo",
      "/lib/terminfo",
      "/etc/terminfo"
    ]

    # Add user terminfo if it exists
    home = System.get_env("HOME")

    user_paths =
      if home do
        [Path.join(home, ".terminfo")]
      else
        []
      end

    user_paths ++ base_paths
  end

  @doc """
  Returns hints for Unix-specific capability detection.
  """
  @spec capability_hints() :: map()
  def capability_hints do
    variant = detect_unix_variant()

    base_hints = %{
      supports_mouse: true,
      supports_bracketed_paste: true,
      supports_focus_events: true,
      supports_alternate_screen: true
    }

    # Add variant-specific hints
    case variant do
      :macos ->
        Map.merge(base_hints, %{
          default_terminal: "Apple_Terminal",
          notes: "iTerm2 recommended for full feature support"
        })

      :linux ->
        Map.merge(base_hints, %{
          default_terminal: "xterm",
          notes: "Most modern terminals fully supported"
        })

      _ ->
        base_hints
    end
  end

  @doc """
  Returns signal names supported on Unix.
  """
  @spec supported_signals() :: [atom()]
  def supported_signals do
    [:sigwinch, :sigterm, :sigint, :sighup, :sigusr1, :sigusr2]
  end

  @doc """
  Checks if a specific signal is available.
  """
  @spec signal_available?(atom()) :: boolean()
  def signal_available?(signal) do
    signal in supported_signals()
  end
end
