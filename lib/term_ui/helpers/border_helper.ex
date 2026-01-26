defmodule TermUI.Helpers.BorderHelper do
  @moduledoc """
  Helper functions for rendering borders using CharacterSet.

  This module provides convenience functions for common border rendering
  patterns, eliminating code duplication across widgets that draw borders.

  All functions use the current CharacterSet to ensure correct character
  selection based on terminal capabilities (Unicode or ASCII).

  ## Usage

      import TermUI.Helpers.BorderHelper

      # Draw a horizontal line
      line = horizontal_line(20)
      # => "────────────────────" (Unicode) or "--------------------" (ASCII)

      # Draw a box top
      top = box_top(20)
      # => "┌──────────────────┐" (Unicode) or "+------------------+" (ASCII)

  ## Integration with Widgets

  Widgets can use these helpers to render borders consistently:

      def render_border(state, area) do
        import TermUI.Helpers.BorderHelper

        stack(:vertical, [
          text(box_top(area.width)),
          # ... content ...
          text(box_bottom(area.width))
        ])
      end
  """

  alias TermUI.CharacterSet

  @doc """
  Renders a horizontal line of the specified width.

  Uses the current CharacterSet's horizontal line character.

  ## Parameters

  - `width` - Width of the line in characters

  ## Examples

      iex> horizontal_line(5)
      "─────"  # Unicode mode

      iex> Application.put_env(:term_ui, :character_set, :ascii)
      iex> horizontal_line(5)
      "-----"
  """
  @spec horizontal_line(non_neg_integer()) :: String.t()
  def horizontal_line(width) when is_integer(width) and width >= 0 do
    chars = CharacterSet.current_charset()
    String.duplicate(chars.h_line, width)
  end

  @doc """
  Renders a heavy horizontal line of the specified width.

  Uses the current CharacterSet's heavy horizontal line character.

  ## Parameters

  - `width` - Width of the line in characters

  ## Examples

      iex> horizontal_line_heavy(5)
      "━━━━━"  # Unicode mode
  """
  @spec horizontal_line_heavy(non_neg_integer()) :: String.t()
  def horizontal_line_heavy(width) when is_integer(width) and width >= 0 do
    chars = CharacterSet.current_charset()
    String.duplicate(chars.h_line_heavy, width)
  end

  @doc """
  Renders a vertical line of the specified height.

  Returns a list of strings, one per line.

  ## Parameters

  - `height` - Height of the line in characters

  ## Examples

      iex> vertical_line(3)
      ["│", "│", "│"]  # Unicode mode
  """
  @spec vertical_line(non_neg_integer()) :: [String.t()]
  def vertical_line(height) when is_integer(height) and height >= 0 do
    chars = CharacterSet.current_charset()
    List.duplicate(chars.v_line, height)
  end

  @doc """
  Renders the top border of a box.

  Format: `┌` + horizontal line + `┐`

  ## Parameters

  - `width` - Total width including corners (minimum 2)

  ## Examples

      iex> box_top(10)
      "┌────────┐"  # Unicode mode

      iex> Application.put_env(:term_ui, :character_set, :ascii)
      iex> box_top(10)
      "+--------+"
  """
  @spec box_top(non_neg_integer()) :: String.t()
  def box_top(width) when is_integer(width) and width >= 2 do
    chars = CharacterSet.current_charset()
    inner_width = max(0, width - 2)
    chars.tl <> String.duplicate(chars.h_line, inner_width) <> chars.tr
  end

  def box_top(width) when is_integer(width) and width >= 0 do
    chars = CharacterSet.current_charset()
    String.duplicate(chars.h_line, width)
  end

  @doc """
  Renders the bottom border of a box.

  Format: `└` + horizontal line + `┘`

  ## Parameters

  - `width` - Total width including corners (minimum 2)

  ## Examples

      iex> box_bottom(10)
      "└────────┘"  # Unicode mode

      iex> Application.put_env(:term_ui, :character_set, :ascii)
      iex> box_bottom(10)
      "+--------+"
  """
  @spec box_bottom(non_neg_integer()) :: String.t()
  def box_bottom(width) when is_integer(width) and width >= 2 do
    chars = CharacterSet.current_charset()
    inner_width = max(0, width - 2)
    chars.bl <> String.duplicate(chars.h_line, inner_width) <> chars.br
  end

  def box_bottom(width) when is_integer(width) and width >= 0 do
    chars = CharacterSet.current_charset()
    String.duplicate(chars.h_line, width)
  end

  @doc """
  Renders the top border of a box with rounded corners.

  Format: `╭` + horizontal line + `╮`

  ## Parameters

  - `width` - Total width including corners (minimum 2)

  ## Examples

      iex> box_top_round(10)
      "╭────────╮"  # Unicode mode
  """
  @spec box_top_round(non_neg_integer()) :: String.t()
  def box_top_round(width) when is_integer(width) and width >= 2 do
    chars = CharacterSet.current_charset()
    inner_width = max(0, width - 2)
    chars.tl_round <> String.duplicate(chars.h_line, inner_width) <> chars.tr_round
  end

  def box_top_round(width) when is_integer(width) and width >= 0 do
    chars = CharacterSet.current_charset()
    String.duplicate(chars.h_line, width)
  end

  @doc """
  Renders the bottom border of a box with rounded corners.

  Format: `╰` + horizontal line + `╯`

  ## Parameters

  - `width` - Total width including corners (minimum 2)

  ## Examples

      iex> box_bottom_round(10)
      "╰────────╯"  # Unicode mode
  """
  @spec box_bottom_round(non_neg_integer()) :: String.t()
  def box_bottom_round(width) when is_integer(width) and width >= 2 do
    chars = CharacterSet.current_charset()
    inner_width = max(0, width - 2)
    chars.bl_round <> String.duplicate(chars.h_line, inner_width) <> chars.br_round
  end

  def box_bottom_round(width) when is_integer(width) and width >= 0 do
    chars = CharacterSet.current_charset()
    String.duplicate(chars.h_line, width)
  end

  @doc """
  Renders a left border character with optional content.

  Format: `│` + content

  ## Parameters

  - `content` - Optional content to append after the border (default: "")

  ## Examples

      iex> left_border()
      "│"

      iex> left_border(" Hello")
      "│ Hello"
  """
  @spec left_border(String.t()) :: String.t()
  def left_border(content \\ "") do
    chars = CharacterSet.current_charset()
    chars.v_line <> content
  end

  @doc """
  Renders a right border character with optional content.

  Format: content + `│`

  ## Parameters

  - `content` - Optional content to prepend before the border (default: "")

  ## Examples

      iex> right_border()
      "│"

      iex> right_border("Hello ")
      "Hello │"
  """
  @spec right_border(String.t()) :: String.t()
  def right_border(content \\ "") do
    chars = CharacterSet.current_charset()
    content <> chars.v_line
  end

  @doc """
  Renders a complete row with left and right borders.

  Format: `│` + padded content + `│`

  The content is padded to fill the inner width.

  ## Parameters

  - `content` - Content to display between borders
  - `width` - Total width including borders (minimum 2)
  - `opts` - Options:
    - `:pad` - Padding character (default: " ")
    - `:align` - `:left`, `:right`, or `:center` (default: `:left`)

  ## Examples

      iex> bordered_row("Hello", 12)
      "│Hello     │"

      iex> bordered_row("Hi", 10, align: :center)
      "│   Hi    │"
  """
  @spec bordered_row(String.t(), non_neg_integer(), keyword()) :: String.t()
  def bordered_row(content, width, opts \\ []) when is_integer(width) and width >= 2 do
    chars = CharacterSet.current_charset()
    pad_char = Keyword.get(opts, :pad, " ")
    align = Keyword.get(opts, :align, :left)

    inner_width = max(0, width - 2)
    content_len = String.length(content)
    padding_needed = max(0, inner_width - content_len)

    padded_content =
      case align do
        :left ->
          content <> String.duplicate(pad_char, padding_needed)

        :right ->
          String.duplicate(pad_char, padding_needed) <> content

        :center ->
          left_pad = div(padding_needed, 2)
          right_pad = padding_needed - left_pad
          String.duplicate(pad_char, left_pad) <> content <> String.duplicate(pad_char, right_pad)
      end

    # Truncate if content is too long
    padded_content = String.slice(padded_content, 0, inner_width)

    chars.v_line <> padded_content <> chars.v_line
  end
end
