defmodule TermUI.Platform.Windows do
  @moduledoc """
  Windows-specific terminal handling stubs.

  Full Windows support requires NIFs or ports to call Win32 APIs.
  This module provides stubs with clear error messages for future implementation.

  ## Requirements for Full Support
  - Windows 10 build 1511+ for VT sequence support
  - SetConsoleMode with ENABLE_VIRTUAL_TERMINAL_PROCESSING
  - SetConsoleMode with ENABLE_VIRTUAL_TERMINAL_INPUT
  - GetConsoleScreenBufferInfo for terminal size
  - Console event handling for resize/focus

  ## Future Implementation
  Would require NIF wrapping:
  - kernel32.dll SetConsoleMode
  - kernel32.dll GetConsoleMode
  - kernel32.dll GetConsoleScreenBufferInfo
  - Console event loop for input
  """

  @doc """
  Returns Windows-specific terminal information.

  Note: Currently returns stub data as full implementation requires NIFs.
  """
  @spec info() :: map()
  def info do
    %{
      platform: :windows,
      vt_support: :unknown,
      console_mode: :unknown,
      supports_signals: false,
      supports_pty: false,
      implementation_status: :stub,
      notes: "Full Windows support requires NIF implementation"
    }
  end

  @doc """
  Checks if Windows VT sequence support is available.

  Note: Currently a stub. Would need to call GetConsoleMode to check.
  """
  @spec vt_support_available?() :: boolean()
  def vt_support_available? do
    # Stub - would need NIF to check actual console mode
    # For now, assume Windows 10+ has VT support
    case windows_version() do
      {major, _, _} when major >= 10 -> true
      _ -> false
    end
  end

  @doc """
  Returns the Windows version.
  """
  @spec windows_version() :: {non_neg_integer(), non_neg_integer(), non_neg_integer()} | nil
  def windows_version do
    case :os.version() do
      {major, minor, build} -> {major, minor, build}
      _ -> nil
    end
  end

  @doc """
  Enables VT sequence processing for the console.

  Note: Stub implementation. Would need NIF to call SetConsoleMode.
  """
  @spec enable_vt_processing() :: {:ok, :stub} | {:error, String.t()}
  def enable_vt_processing do
    if vt_support_available?() do
      {:ok, :stub}
    else
      {:error, "Windows VT support requires Windows 10 build 1511 or later"}
    end
  end

  @doc """
  Disables VT sequence processing.

  Note: Stub implementation.
  """
  @spec disable_vt_processing() :: :ok
  def disable_vt_processing do
    :ok
  end

  @doc """
  Returns hints for Windows-specific capability detection.
  """
  @spec capability_hints() :: map()
  def capability_hints do
    %{
      supports_mouse: vt_support_available?(),
      supports_bracketed_paste: vt_support_available?(),
      supports_focus_events: vt_support_available?(),
      supports_alternate_screen: vt_support_available?(),
      requires_vt_mode: true,
      notes: "Windows Terminal recommended for best experience"
    }
  end

  @doc """
  Returns terminal size on Windows.

  Note: Stub using Erlang's :io module. For accurate results,
  would need GetConsoleScreenBufferInfo via NIF.
  """
  @spec terminal_size() :: {pos_integer(), pos_integer()}
  def terminal_size do
    rows =
      case :io.rows() do
        {:ok, r} -> r
        _ -> 24
      end

    cols =
      case :io.columns() do
        {:ok, c} -> c
        _ -> 80
      end

    {rows, cols}
  end

  @doc """
  Returns the minimum Windows version required for full support.
  """
  @spec minimum_version() :: {non_neg_integer(), non_neg_integer(), non_neg_integer()}
  def minimum_version do
    # Windows 10 version 1511, build 10586
    {10, 0, 10_586}
  end

  @doc """
  Checks if the current Windows version meets minimum requirements.
  """
  @spec meets_minimum_version?() :: boolean()
  def meets_minimum_version? do
    case windows_version() do
      {major, minor, build} ->
        compare_versions({major, minor, build}, minimum_version())

      nil ->
        false
    end
  end

  defp compare_versions({major, minor, build}, {min_major, min_minor, min_build}) do
    {major, minor, build} >= {min_major, min_minor, min_build}
  end
end
