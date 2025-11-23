defmodule TermUI.Capabilities do
  @moduledoc """
  Terminal capability detection and management.

  Detects terminal capabilities through multiple methods:
  - Environment variables ($TERM, $COLORTERM, $TERM_PROGRAM, $LANG)
  - Terminfo database queries
  - Conservative VT100 fallbacks

  Results are cached in ETS for fast concurrent access.
  """

  @type color_mode :: :true_color | :color_256 | :color_16 | :monochrome

  @type t :: %__MODULE__{
          color_mode: color_mode(),
          max_colors: non_neg_integer(),
          unicode: boolean(),
          mouse: boolean(),
          bracketed_paste: boolean(),
          focus_events: boolean(),
          alternate_screen: boolean(),
          terminal_type: String.t() | nil,
          terminal_program: String.t() | nil
        }

  defstruct color_mode: :color_16,
            max_colors: 16,
            unicode: false,
            mouse: false,
            bracketed_paste: false,
            focus_events: false,
            alternate_screen: true,
            terminal_type: nil,
            terminal_program: nil

  @ets_table :term_ui_capabilities

  # Known terminal emulators with their capabilities
  @true_color_terminals ~w(iTerm.app vscode WezTerm kitty Alacritty Hyper)
  @color_256_terminals ~w(Apple_Terminal gnome-terminal konsole xfce4-terminal)

  # Terminal type patterns for color detection
  @term_patterns [
    {"truecolor", :true_color, 16_777_216},
    {"24bit", :true_color, 16_777_216},
    {"256color", :color_256, 256}
  ]

  @term_prefixes [
    {"xterm", :color_256, 256},
    {"screen", :color_256, 256},
    {"tmux", :color_256, 256}
  ]

  @doc """
  Detects terminal capabilities and caches them in ETS.

  Returns the detected capabilities struct.
  """
  @spec detect() :: t()
  def detect do
    capabilities = do_detect()
    cache_capabilities(capabilities)
    capabilities
  end

  @doc """
  Returns cached capabilities, detecting if not yet cached.
  """
  @spec get() :: t()
  def get do
    case get_cached() do
      nil -> detect()
      caps -> caps
    end
  end

  @doc """
  Clears the cached capabilities.
  """
  @spec clear_cache() :: :ok
  def clear_cache do
    ensure_table_exists()

    try do
      :ets.delete(@ets_table, :capabilities)
    rescue
      ArgumentError -> :ok
    end

    :ok
  end

  # Capability accessors

  @doc """
  Returns true if terminal supports true-color (24-bit RGB).
  """
  @spec supports_true_color?() :: boolean()
  def supports_true_color? do
    get().color_mode == :true_color
  end

  @doc """
  Returns true if terminal supports 256 colors or better.
  """
  @spec supports_256_color?() :: boolean()
  def supports_256_color? do
    get().color_mode in [:true_color, :color_256]
  end

  @doc """
  Returns true if terminal supports mouse tracking.
  """
  @spec supports_mouse?() :: boolean()
  def supports_mouse? do
    get().mouse
  end

  @doc """
  Returns true if terminal supports bracketed paste mode.
  """
  @spec supports_bracketed_paste?() :: boolean()
  def supports_bracketed_paste? do
    get().bracketed_paste
  end

  @doc """
  Returns true if terminal supports focus event reporting.
  """
  @spec supports_focus_events?() :: boolean()
  def supports_focus_events? do
    get().focus_events
  end

  @doc """
  Returns true if terminal supports Unicode.
  """
  @spec supports_unicode?() :: boolean()
  def supports_unicode? do
    get().unicode
  end

  @doc """
  Returns true if terminal supports alternate screen buffer.
  """
  @spec supports_alternate_screen?() :: boolean()
  def supports_alternate_screen? do
    get().alternate_screen
  end

  @doc """
  Returns the maximum number of colors supported.
  """
  @spec max_colors() :: non_neg_integer()
  def max_colors do
    get().max_colors
  end

  @doc """
  Returns the color mode.
  """
  @spec color_mode() :: color_mode()
  def color_mode do
    get().color_mode
  end

  # Private implementation

  defp do_detect do
    # Start with VT100 baseline
    base = %__MODULE__{
      color_mode: :color_16,
      max_colors: 16,
      unicode: false,
      mouse: false,
      bracketed_paste: false,
      focus_events: false,
      alternate_screen: true,
      terminal_type: nil,
      terminal_program: nil
    }

    base
    |> detect_from_term()
    |> detect_from_colorterm()
    |> detect_from_term_program()
    |> detect_unicode()
    |> detect_from_terminfo()
    |> finalize_capabilities()
  end

  defp detect_from_term(caps) do
    case System.get_env("TERM") do
      nil ->
        caps

      term ->
        caps = %{caps | terminal_type: term}
        detect_term_colors(caps, term)
    end
  end

  defp detect_term_colors(caps, term) do
    # Check for exact matches first
    case term do
      "linux" -> %{caps | color_mode: :color_16, max_colors: 16}
      "dumb" -> %{caps | color_mode: :monochrome, max_colors: 2}
      _ -> detect_term_patterns(caps, term)
    end
  end

  defp detect_term_patterns(caps, term) do
    # Check patterns (contains)
    pattern_match =
      Enum.find(@term_patterns, fn {pattern, _mode, _colors} ->
        String.contains?(term, pattern)
      end)

    case pattern_match do
      {_, mode, colors} ->
        update_color_mode(caps, mode, colors)

      nil ->
        detect_term_prefixes(caps, term)
    end
  end

  defp detect_term_prefixes(caps, term) do
    # Check prefixes (starts_with)
    prefix_match =
      Enum.find(@term_prefixes, fn {prefix, _mode, _colors} ->
        String.starts_with?(term, prefix)
      end)

    case prefix_match do
      {_, mode, colors} -> update_color_mode(caps, mode, colors)
      nil -> caps
    end
  end

  defp detect_from_colorterm(caps) do
    case System.get_env("COLORTERM") do
      nil ->
        caps

      colorterm ->
        if colorterm in ["truecolor", "24bit"] do
          %{caps | color_mode: :true_color, max_colors: 16_777_216}
        else
          caps
        end
    end
  end

  defp detect_from_term_program(caps) do
    case System.get_env("TERM_PROGRAM") do
      nil ->
        caps

      program ->
        caps = %{caps | terminal_program: program}

        cond do
          program in @true_color_terminals ->
            %{
              caps
              | color_mode: :true_color,
                max_colors: 16_777_216,
                mouse: true,
                bracketed_paste: true,
                focus_events: true
            }

          program in @color_256_terminals ->
            caps = update_color_mode(caps, :color_256, 256)
            %{caps | mouse: true, bracketed_paste: true}

          true ->
            caps
        end
    end
  end

  defp detect_unicode(caps) do
    lang = System.get_env("LC_ALL") || System.get_env("LC_CTYPE") || System.get_env("LANG") || ""

    unicode =
      String.contains?(String.downcase(lang), "utf-8") or
        String.contains?(String.downcase(lang), "utf8")

    %{caps | unicode: unicode}
  end

  defp detect_from_terminfo(caps) do
    case query_terminfo_colors() do
      {:ok, colors} when colors >= 16_777_216 ->
        update_color_mode(caps, :true_color, colors)

      {:ok, colors} when colors >= 256 ->
        update_color_mode(caps, :color_256, colors)

      {:ok, colors} when colors >= 16 ->
        update_color_mode(caps, :color_16, colors)

      {:ok, colors} when colors >= 8 ->
        # Only update max_colors, keep existing mode
        %{caps | max_colors: max(caps.max_colors, colors)}

      _ ->
        caps
    end
  end

  defp query_terminfo_colors do
    case System.cmd("infocmp", ["-1"], stderr_to_stdout: true) do
      {output, 0} ->
        parse_terminfo_colors(output)

      _ ->
        :error
    end
  rescue
    _ -> :error
  end

  defp parse_terminfo_colors(output) do
    # Look for colors#N or colors=N pattern
    case Regex.run(~r/colors[#=](\d+)/, output) do
      [_, count] ->
        {:ok, String.to_integer(count)}

      nil ->
        :error
    end
  end

  defp finalize_capabilities(caps) do
    # Enable features for any terminal with 256+ colors
    # as these are typically modern terminals
    if caps.max_colors >= 256 do
      %{
        caps
        | mouse: caps.mouse || true,
          bracketed_paste: caps.bracketed_paste || true,
          focus_events: caps.focus_events || caps.max_colors >= 16_777_216
      }
    else
      caps
    end
  end

  defp update_color_mode(caps, new_mode, new_colors) do
    # Only upgrade color mode, never downgrade
    current_rank = color_mode_rank(caps.color_mode)
    new_rank = color_mode_rank(new_mode)

    if new_rank > current_rank do
      %{caps | color_mode: new_mode, max_colors: max(caps.max_colors, new_colors)}
    else
      %{caps | max_colors: max(caps.max_colors, new_colors)}
    end
  end

  defp color_mode_rank(:monochrome), do: 0
  defp color_mode_rank(:color_16), do: 1
  defp color_mode_rank(:color_256), do: 2
  defp color_mode_rank(:true_color), do: 3

  defp ensure_table_exists do
    if :ets.whereis(@ets_table) == :undefined do
      :ets.new(@ets_table, [:named_table, :public, :set, read_concurrency: true])
    end
  end

  defp cache_capabilities(capabilities) do
    ensure_table_exists()
    :ets.insert(@ets_table, {:capabilities, capabilities})
  end

  defp get_cached do
    ensure_table_exists()

    case :ets.lookup(@ets_table, :capabilities) do
      [{:capabilities, caps}] -> caps
      [] -> nil
    end
  end
end
