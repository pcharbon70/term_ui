defmodule TermUI.CharacterSet do
  @moduledoc """
  Character set definitions for Unicode and ASCII box-drawing characters.

  This module provides character sets for rendering borders, progress bars,
  check marks, and other UI elements. Two character sets are available:

  - `:unicode` - Full Unicode box-drawing characters for modern terminals
  - `:ascii` - ASCII fallback characters for limited terminals

  ## Usage

  Widgets should use `get/1` to retrieve the appropriate character set based
  on terminal capabilities:

      chars = TermUI.CharacterSet.get(:unicode)
      top_border = chars.tl <> String.duplicate(chars.h_line, width - 2) <> chars.tr

  For runtime queries, use `current/0` which reads from application config:

      chars = TermUI.CharacterSet.get(TermUI.CharacterSet.current())

  Or use the convenience function `current_charset/0`:

      chars = TermUI.CharacterSet.current_charset()

  ## Available Characters

  ### Box Drawing
  - `tl`, `tr`, `bl`, `br` - Corners (top-left, top-right, bottom-left, bottom-right)
  - `h_line`, `v_line` - Horizontal and vertical lines
  - `t_up`, `t_down`, `t_left`, `t_right` - T-junctions
  - `cross` - Cross junction (four-way)

  ### Progress/Gauge
  - `bar_full` - Full block for filled progress
  - `bar_empty` - Empty/light block for unfilled progress
  - `bar_levels` - List of characters for fractional progress (8 levels Unicode, 5 ASCII)

  ### Indicators
  - `check` - Check mark for success/selected
  - `cross_mark` - X mark for failure/deselected

  ### Arrows
  - `arrow_up`, `arrow_down`, `arrow_left`, `arrow_right` - Directional arrows

  ## Configuration

  The default character set can be configured in your application:

      config :term_ui, :character_set, :unicode

  Or at runtime:

      Application.put_env(:term_ui, :character_set, :ascii)
  """

  @typedoc """
  Character set type.

  - `:unicode` - Full Unicode box-drawing characters
  - `:ascii` - ASCII fallback characters
  """
  @type charset :: :unicode | :ascii

  @typedoc """
  Character set map containing all box-drawing and special characters.
  """
  @type t :: %{
          # Box corners
          tl: String.t(),
          tr: String.t(),
          bl: String.t(),
          br: String.t(),
          # Lines
          h_line: String.t(),
          v_line: String.t(),
          # T-junctions
          t_up: String.t(),
          t_down: String.t(),
          t_left: String.t(),
          t_right: String.t(),
          # Cross junction
          cross: String.t(),
          # Progress/gauge
          bar_full: String.t(),
          bar_empty: String.t(),
          bar_levels: [String.t()],
          # Check marks
          check: String.t(),
          cross_mark: String.t(),
          # Arrows
          arrow_up: String.t(),
          arrow_down: String.t(),
          arrow_left: String.t(),
          arrow_right: String.t()
        }

  # Define charsets as module attributes for compile-time access
  @unicode_charset %{
    # Box corners (light)
    tl: "┌",
    tr: "┐",
    bl: "└",
    br: "┘",
    # Lines (light)
    h_line: "─",
    v_line: "│",
    # T-junctions (light)
    t_up: "┴",
    t_down: "┬",
    t_left: "┤",
    t_right: "├",
    # Cross junction (light)
    cross: "┼",
    # Progress/gauge characters
    bar_full: "█",
    bar_empty: "░",
    # 8 levels of progress (1/8 to 8/8)
    bar_levels: ["▏", "▎", "▍", "▌", "▋", "▊", "▉", "█"],
    # Check marks
    check: "✓",
    cross_mark: "✗",
    # Arrows
    arrow_up: "↑",
    arrow_down: "↓",
    arrow_left: "←",
    arrow_right: "→"
  }

  @ascii_charset %{
    # Box corners (ASCII)
    tl: "+",
    tr: "+",
    bl: "+",
    br: "+",
    # Lines (ASCII)
    h_line: "-",
    v_line: "|",
    # T-junctions (ASCII)
    t_up: "+",
    t_down: "+",
    t_left: "+",
    t_right: "+",
    # Cross junction (ASCII)
    cross: "+",
    # Progress/gauge characters (ASCII)
    bar_full: "#",
    bar_empty: ".",
    # 5 levels of progress for ASCII
    bar_levels: [" ", ".", ":", "=", "#"],
    # Check marks (ASCII)
    check: "x",
    cross_mark: "X",
    # Arrows (ASCII)
    arrow_up: "^",
    arrow_down: "v",
    arrow_left: "<",
    arrow_right: ">"
  }

  # Derive keys from the actual charset map at compile time
  @charset_keys Map.keys(@unicode_charset)

  @doc """
  Returns the character set for the given type.

  ## Parameters

  - `type` - Either `:unicode` or `:ascii`

  ## Returns

  A map containing all box-drawing and special characters.

  ## Examples

      iex> chars = TermUI.CharacterSet.get(:unicode)
      iex> chars.tl
      "┌"

      iex> chars = TermUI.CharacterSet.get(:ascii)
      iex> chars.tl
      "+"
  """
  @spec get(charset()) :: t()
  def get(:unicode), do: @unicode_charset
  def get(:ascii), do: @ascii_charset

  def get(invalid) do
    raise ArgumentError, "unknown character set #{inspect(invalid)}, expected :unicode or :ascii"
  end

  @doc """
  Returns the currently configured character set type.

  Reads from application config `:term_ui, :character_set`.
  Defaults to `:unicode` if not configured.

  ## Returns

  Either `:unicode` or `:ascii`.

  ## Examples

      iex> TermUI.CharacterSet.current()
      :unicode

      iex> Application.put_env(:term_ui, :character_set, :ascii)
      iex> TermUI.CharacterSet.current()
      :ascii
  """
  @spec current() :: charset()
  def current do
    Application.get_env(:term_ui, :character_set, :unicode)
  end

  @doc """
  Returns the current character set as a map.

  Convenience function that combines `current/0` and `get/1`.

  ## Returns

  A map containing all box-drawing and special characters for the
  currently configured character set.

  ## Examples

      iex> chars = TermUI.CharacterSet.current_charset()
      iex> is_map(chars)
      true

      iex> Application.put_env(:term_ui, :character_set, :ascii)
      iex> TermUI.CharacterSet.current_charset().tl
      "+"
  """
  @spec current_charset() :: t()
  def current_charset do
    get(current())
  end

  @doc """
  Returns the list of all character keys available in a character set.

  Keys are derived from the actual character set map at compile time,
  ensuring they stay in sync with the character set definitions.

  Useful for validation and testing.

  ## Returns

  List of atom keys.

  ## Examples

      iex> :tl in TermUI.CharacterSet.keys()
      true
  """
  @spec keys() :: [atom()]
  def keys, do: @charset_keys
end
