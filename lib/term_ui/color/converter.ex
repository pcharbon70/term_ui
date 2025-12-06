defmodule TermUI.Color.Converter do
  @moduledoc """
  Color conversion algorithms for terminal color degradation.

  This module provides functions to convert RGB colors to various terminal
  color palettes, enabling graceful degradation from 24-bit true color to
  256-color, 16-color, or monochrome modes.

  ## Color Modes

  | Mode | Colors | Use Case |
  |------|--------|----------|
  | `:true_color` | 16.7M | Modern terminals (24-bit RGB) |
  | `:color_256` | 256 | Most Unix terminals |
  | `:color_16` | 16 | Basic terminal compatibility |
  | `:monochrome` | 2 | Minimal terminals, accessibility |

  ## Conversion Algorithms

  ### RGB to 256-color

  Uses the xterm 256-color palette:
  - Indices 16-231: 6x6x6 color cube
  - Indices 232-255: 24-step grayscale ramp

  Near-grayscale colors are mapped to the grayscale ramp for better fidelity.

  ### RGB to 16-color

  Uses weighted Euclidean distance with perceptual luminance weights:
  - Red: 0.299
  - Green: 0.587
  - Blue: 0.114

  These weights match human eye sensitivity, producing better color matches
  than naive RGB distance.

  ## Examples

      iex> TermUI.Color.Converter.rgb_to_256({255, 0, 0})
      196

      iex> TermUI.Color.Converter.rgb_to_16({255, 0, 0}, :fg)
      91  # bright red foreground

      iex> TermUI.Color.Converter.rgb_to_16({0, 128, 0}, :bg)
      42  # green background
  """

  # ANSI 16-color palette RGB values for distance calculation.
  # Format: {color_code, {r, g, b}}
  @ansi_16_colors [
    # Normal colors (codes 30-37)
    {30, {0, 0, 0}},        # black
    {31, {128, 0, 0}},      # red
    {32, {0, 128, 0}},      # green
    {33, {128, 128, 0}},    # yellow
    {34, {0, 0, 128}},      # blue
    {35, {128, 0, 128}},    # magenta
    {36, {0, 128, 128}},    # cyan
    {37, {192, 192, 192}},  # white (light gray)
    # Bright colors (codes 90-97)
    {90, {128, 128, 128}},  # bright black (dark gray)
    {91, {255, 0, 0}},      # bright red
    {92, {0, 255, 0}},      # bright green
    {93, {255, 255, 0}},    # bright yellow
    {94, {0, 0, 255}},      # bright blue
    {95, {255, 0, 255}},    # bright magenta
    {96, {0, 255, 255}},    # bright cyan
    {97, {255, 255, 255}}   # bright white
  ]

  # Threshold for grayscale detection.
  # If max color channel difference is below this, treat as grayscale.
  @grayscale_threshold 10

  @doc """
  Converts RGB values to a 256-color palette index.

  Uses the xterm 256-color palette:
  - Indices 16-231: 6x6x6 color cube
  - Indices 232-255: 24-step grayscale ramp

  Near-grayscale colors (where R, G, B differ by less than 10) are mapped
  to the grayscale ramp for better fidelity.

  ## Parameters

  - `rgb` - Tuple `{r, g, b}` with values 0-255

  ## Returns

  Integer 0-255 representing the palette index.

  ## Examples

      iex> TermUI.Color.Converter.rgb_to_256({255, 0, 0})
      196

      iex> TermUI.Color.Converter.rgb_to_256({128, 128, 128})
      244  # grayscale

      iex> TermUI.Color.Converter.rgb_to_256({0, 255, 0})
      46
  """
  @spec rgb_to_256({0..255, 0..255, 0..255}) :: 0..255
  def rgb_to_256({r, g, b})
      when is_integer(r) and r >= 0 and r <= 255 and
           is_integer(g) and g >= 0 and g <= 255 and
           is_integer(b) and b >= 0 and b <= 255 do
    # Check if it's close to grayscale
    if abs(r - g) < @grayscale_threshold and
       abs(g - b) < @grayscale_threshold and
       abs(r - b) < @grayscale_threshold do
      # Use grayscale ramp (232-255)
      gray = div(r + g + b, 3)
      232 + div(gray * 23, 255)
    else
      # Use 6x6x6 color cube (16-231)
      r_idx = div(r * 5, 255)
      g_idx = div(g * 5, 255)
      b_idx = div(b * 5, 255)
      16 + 36 * r_idx + 6 * g_idx + b_idx
    end
  end

  @doc """
  Converts RGB values to a 16-color ANSI code.

  Uses perceptually-weighted Euclidean distance to find the closest
  color in the 16-color ANSI palette.

  ## Parameters

  - `rgb` - Tuple `{r, g, b}` with values 0-255
  - `type` - `:fg` for foreground or `:bg` for background

  ## Returns

  Integer representing the ANSI color code:
  - Foreground: 30-37 (normal) or 90-97 (bright)
  - Background: 40-47 (normal) or 100-107 (bright)

  ## Examples

      iex> TermUI.Color.Converter.rgb_to_16({255, 0, 0}, :fg)
      91  # bright red

      iex> TermUI.Color.Converter.rgb_to_16({0, 128, 0}, :bg)
      42  # green background

      iex> TermUI.Color.Converter.rgb_to_16({64, 64, 64}, :fg)
      90  # dark gray (bright black)
  """
  @spec rgb_to_16({0..255, 0..255, 0..255}, :fg | :bg) :: 30..37 | 40..47 | 90..97 | 100..107
  def rgb_to_16({r, g, b}, type)
      when is_integer(r) and r >= 0 and r <= 255 and
           is_integer(g) and g >= 0 and g <= 255 and
           is_integer(b) and b >= 0 and b <= 255 and
           type in [:fg, :bg] do
    {base_code, bright} = find_closest_16_color(r, g, b)

    case type do
      :fg ->
        if bright, do: base_code + 60, else: base_code

      :bg ->
        bg_base = base_code + 10
        if bright, do: bg_base + 60, else: bg_base
    end
  end

  @doc """
  Checks if an RGB color is close to grayscale.

  A color is considered grayscale if the difference between its
  R, G, and B components is less than the grayscale threshold (10).

  ## Parameters

  - `rgb` - Tuple `{r, g, b}` with values 0-255

  ## Returns

  Boolean indicating if the color is near-grayscale.

  ## Examples

      iex> TermUI.Color.Converter.grayscale?({128, 128, 128})
      true

      iex> TermUI.Color.Converter.grayscale?({128, 130, 127})
      true

      iex> TermUI.Color.Converter.grayscale?({255, 0, 0})
      false
  """
  @spec grayscale?({0..255, 0..255, 0..255}) :: boolean()
  def grayscale?({r, g, b})
      when is_integer(r) and r >= 0 and r <= 255 and
           is_integer(g) and g >= 0 and g <= 255 and
           is_integer(b) and b >= 0 and b <= 255 do
    abs(r - g) < @grayscale_threshold and
    abs(g - b) < @grayscale_threshold and
    abs(r - b) < @grayscale_threshold
  end

  @doc """
  Returns the perceptual luminance weights used for color distance.

  These weights match human eye sensitivity:
  - Red: 0.299
  - Green: 0.587
  - Blue: 0.114

  ## Returns

  Tuple `{r_weight, g_weight, b_weight}`.
  """
  @spec luminance_weights() :: {float(), float(), float()}
  def luminance_weights, do: {0.299, 0.587, 0.114}

  # ===========================================================================
  # Private Functions
  # ===========================================================================

  # Finds the closest color in the 16-color palette using weighted distance.
  @spec find_closest_16_color(0..255, 0..255, 0..255) :: {30..37 | 90..97, boolean()}
  defp find_closest_16_color(r, g, b) do
    # Find closest color using weighted Euclidean distance
    # Weights: R=0.299, G=0.587, B=0.114 (perceptual luminance weights)
    {best_code, _best_dist} =
      Enum.reduce(@ansi_16_colors, {30, :infinity}, fn {code, {pr, pg, pb}}, {best, dist} ->
        # Weighted distance calculation
        dr = (r - pr) * 0.299
        dg = (g - pg) * 0.587
        db = (b - pb) * 0.114
        new_dist = dr * dr + dg * dg + db * db

        if new_dist < dist do
          {code, new_dist}
        else
          {best, dist}
        end
      end)

    # Determine if it's a bright color (90-97) or normal (30-37)
    bright = best_code >= 90
    base = if bright, do: best_code - 60, else: best_code

    {base, bright}
  end
end
