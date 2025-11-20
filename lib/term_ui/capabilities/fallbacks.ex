defmodule TermUI.Capabilities.Fallbacks do
  @moduledoc """
  Graceful degradation utilities for terminal capabilities.

  Provides fallback chains for:
  - Colors: true-color → 256-color → 16-color → monochrome
  - Characters: Unicode box-drawing → ASCII art
  """

  # Standard 16 ANSI colors as RGB
  @ansi_colors %{
    0 => {0, 0, 0},         # Black
    1 => {128, 0, 0},       # Red
    2 => {0, 128, 0},       # Green
    3 => {128, 128, 0},     # Yellow
    4 => {0, 0, 128},       # Blue
    5 => {128, 0, 128},     # Magenta
    6 => {0, 128, 128},     # Cyan
    7 => {192, 192, 192},   # White
    8 => {128, 128, 128},   # Bright Black
    9 => {255, 0, 0},       # Bright Red
    10 => {0, 255, 0},      # Bright Green
    11 => {255, 255, 0},    # Bright Yellow
    12 => {0, 0, 255},      # Bright Blue
    13 => {255, 0, 255},    # Bright Magenta
    14 => {0, 255, 255},    # Bright Cyan
    15 => {255, 255, 255}   # Bright White
  }

  # Box-drawing character fallbacks
  @box_drawing_fallbacks %{
    # Single line box drawing
    "─" => "-",
    "│" => "|",
    "┌" => "+",
    "┐" => "+",
    "└" => "+",
    "┘" => "+",
    "├" => "+",
    "┤" => "+",
    "┬" => "+",
    "┴" => "+",
    "┼" => "+",
    # Double line box drawing
    "═" => "=",
    "║" => "|",
    "╔" => "+",
    "╗" => "+",
    "╚" => "+",
    "╝" => "+",
    "╠" => "+",
    "╣" => "+",
    "╦" => "+",
    "╩" => "+",
    "╬" => "+",
    # Rounded corners
    "╭" => "+",
    "╮" => "+",
    "╯" => "+",
    "╰" => "+",
    # Block elements
    "█" => "#",
    "▀" => "^",
    "▄" => "_",
    "▌" => "|",
    "▐" => "|",
    "░" => ".",
    "▒" => ":",
    "▓" => "#",
    # Arrows
    "←" => "<",
    "→" => ">",
    "↑" => "^",
    "↓" => "v",
    # Other symbols
    "•" => "*",
    "·" => ".",
    "…" => "...",
    "×" => "x",
    "÷" => "/",
    "≠" => "!=",
    "≤" => "<=",
    "≥" => ">=",
    "✓" => "[x]",
    "✗" => "[ ]"
  }

  @doc """
  Converts an RGB color to the nearest 256-color palette index.

  Returns an integer 0-255.
  """
  @spec rgb_to_256(non_neg_integer(), non_neg_integer(), non_neg_integer()) :: 0..255
  def rgb_to_256(r, g, b) when r in 0..255 and g in 0..255 and b in 0..255 do
    # Check grayscale first (232-255)
    if grayscale?(r, g, b) do
      gray_index = round((r + g + b) / 3 / 255 * 23)
      232 + min(23, gray_index)
    else
      # Use 6x6x6 color cube (16-231)
      r_idx = color_to_cube_index(r)
      g_idx = color_to_cube_index(g)
      b_idx = color_to_cube_index(b)
      16 + (36 * r_idx) + (6 * g_idx) + b_idx
    end
  end

  @doc """
  Converts an RGB color to the nearest 16-color ANSI index.

  Returns an integer 0-15.
  """
  @spec rgb_to_16(non_neg_integer(), non_neg_integer(), non_neg_integer()) :: 0..15
  def rgb_to_16(r, g, b) when r in 0..255 and g in 0..255 and b in 0..255 do
    {best_index, _distance} =
      @ansi_colors
      |> Enum.map(fn {index, {ar, ag, ab}} ->
        distance = color_distance(r, g, b, ar, ag, ab)
        {index, distance}
      end)
      |> Enum.min_by(fn {_index, distance} -> distance end)

    best_index
  end

  @doc """
  Converts a 256-color index to the nearest 16-color ANSI index.

  Returns an integer 0-15.
  """
  @spec color_256_to_16(0..255) :: 0..15
  def color_256_to_16(index) when index in 0..15 do
    # Already a 16-color index
    index
  end

  def color_256_to_16(index) when index in 16..231 do
    # 6x6x6 color cube
    cube_index = index - 16
    r = rem(div(cube_index, 36), 6) * 51
    g = rem(div(cube_index, 6), 6) * 51
    b = rem(cube_index, 6) * 51
    rgb_to_16(r, g, b)
  end

  def color_256_to_16(index) when index in 232..255 do
    # Grayscale ramp
    gray = (index - 232) * 10 + 8
    rgb_to_16(gray, gray, gray)
  end

  @doc """
  Converts a Unicode character to its ASCII fallback.

  Returns the original character if no fallback is defined.
  """
  @spec unicode_to_ascii(String.t()) :: String.t()
  def unicode_to_ascii(char) do
    Map.get(@box_drawing_fallbacks, char, char)
  end

  @doc """
  Converts a string containing Unicode to ASCII-safe version.

  Replaces all known Unicode characters with their ASCII fallbacks.
  """
  @spec string_to_ascii(String.t()) :: String.t()
  def string_to_ascii(string) do
    string
    |> String.graphemes()
    |> Enum.map_join(&unicode_to_ascii/1)
  end

  @doc """
  Returns the appropriate color based on terminal capabilities.

  Automatically degrades RGB to 256 to 16 based on capability.
  """
  @spec degrade_color(
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer(),
          TermUI.Capabilities.color_mode()
        ) ::
          {:rgb, non_neg_integer(), non_neg_integer(), non_neg_integer()}
          | {:index_256, 0..255}
          | {:index_16, 0..15}
          | :none
  def degrade_color(r, g, b, color_mode) do
    case color_mode do
      :true_color ->
        {:rgb, r, g, b}

      :color_256 ->
        {:index_256, rgb_to_256(r, g, b)}

      :color_16 ->
        {:index_16, rgb_to_16(r, g, b)}

      :monochrome ->
        :none
    end
  end

  # Private helpers

  defp grayscale?(r, g, b) do
    # Consider it grayscale if all components are within 8 of each other
    max_val = max(r, max(g, b))
    min_val = min(r, min(g, b))
    max_val - min_val <= 8
  end

  defp color_to_cube_index(value) do
    # Map 0-255 to 0-5 for the 6x6x6 color cube
    cond do
      value < 48 -> 0
      value < 115 -> 1
      value < 155 -> 2
      value < 195 -> 3
      value < 235 -> 4
      true -> 5
    end
  end

  defp color_distance(r1, g1, b1, r2, g2, b2) do
    # Euclidean distance in RGB space
    dr = r1 - r2
    dg = g1 - g2
    db = b1 - b2
    dr * dr + dg * dg + db * db
  end
end
