defmodule TermUI.SGR do
  @moduledoc """
  SGR (Select Graphic Rendition) sequence generation for terminal styling.

  This module provides centralized generation of SGR parameters and sequences
  for terminal text styling, including colors and text attributes.

  ## Overview

  SGR sequences control text appearance (colors, bold, italic, etc.) in terminals.
  They follow the format `ESC[<params>m` where params are semicolon-separated numbers.

  ## Two Modes of Operation

  1. **Parameter mode** - Returns parameter strings for combining into sequences
     - Use when building combined sequences like `ESC[1;31;4m`
     - Functions: `color_param/2`, `attr_param/1`

  2. **Sequence mode** - Returns complete escape sequences
     - Use for direct terminal output
     - Functions: `color_sequence/2`, `attr_sequence/1`

  ## Color Types

  - Named colors: `:red`, `:green`, `:blue`, `:cyan`, `:magenta`, `:yellow`, `:black`, `:white`
  - Bright variants: `:bright_red`, `:bright_green`, etc.
  - 256-color palette: Integer 0-255
  - True color RGB: `{r, g, b}` tuple
  - Default: `:default` to reset to terminal default

  ## Attributes

  Supported: `:bold`, `:dim`, `:italic`, `:underline`, `:blink`, `:reverse`,
  `:hidden`, `:strikethrough`

  ## Examples

      # Parameter mode for combining
      iex> SGR.color_param(:fg, :red)
      "31"

      iex> SGR.color_param(:fg, {255, 128, 0})
      "38;2;255;128;0"

      iex> SGR.attr_param(:bold)
      "1"

      # Building combined sequence
      iex> params = [SGR.attr_param(:bold), SGR.color_param(:fg, :red)]
      iex> SGR.build_sequence(params)
      ["\\e[", ["1", ";", "31"], "m"]

      # Sequence mode for direct output
      iex> SGR.color_sequence(:fg, :red) |> IO.iodata_to_binary()
      "\\e[31m"

      iex> SGR.attr_sequence(:bold) |> IO.iodata_to_binary()
      "\\e[1m"
  """

  @csi "\e["

  # ===========================================================================
  # Parameter Mode - Returns strings for combining
  # ===========================================================================

  @doc """
  Returns SGR parameter string for a color.

  Used when building combined sequences like `ESC[1;31;4m`.

  ## Examples

      iex> SGR.color_param(:fg, :red)
      "31"

      iex> SGR.color_param(:bg, :blue)
      "44"

      iex> SGR.color_param(:fg, 196)
      "38;5;196"

      iex> SGR.color_param(:bg, {0, 255, 128})
      "48;2;0;255;128"
  """
  @spec color_param(:fg | :bg, color :: term()) :: String.t() | nil
  # Default colors
  def color_param(:fg, :default), do: "39"
  def color_param(:bg, :default), do: "49"

  # Named foreground colors
  def color_param(:fg, :black), do: "30"
  def color_param(:fg, :red), do: "31"
  def color_param(:fg, :green), do: "32"
  def color_param(:fg, :yellow), do: "33"
  def color_param(:fg, :blue), do: "34"
  def color_param(:fg, :magenta), do: "35"
  def color_param(:fg, :cyan), do: "36"
  def color_param(:fg, :white), do: "37"

  # Bright foreground colors
  def color_param(:fg, :bright_black), do: "90"
  def color_param(:fg, :bright_red), do: "91"
  def color_param(:fg, :bright_green), do: "92"
  def color_param(:fg, :bright_yellow), do: "93"
  def color_param(:fg, :bright_blue), do: "94"
  def color_param(:fg, :bright_magenta), do: "95"
  def color_param(:fg, :bright_cyan), do: "96"
  def color_param(:fg, :bright_white), do: "97"

  # Named background colors
  def color_param(:bg, :black), do: "40"
  def color_param(:bg, :red), do: "41"
  def color_param(:bg, :green), do: "42"
  def color_param(:bg, :yellow), do: "43"
  def color_param(:bg, :blue), do: "44"
  def color_param(:bg, :magenta), do: "45"
  def color_param(:bg, :cyan), do: "46"
  def color_param(:bg, :white), do: "47"

  # Bright background colors
  def color_param(:bg, :bright_black), do: "100"
  def color_param(:bg, :bright_red), do: "101"
  def color_param(:bg, :bright_green), do: "102"
  def color_param(:bg, :bright_yellow), do: "103"
  def color_param(:bg, :bright_blue), do: "104"
  def color_param(:bg, :bright_magenta), do: "105"
  def color_param(:bg, :bright_cyan), do: "106"
  def color_param(:bg, :bright_white), do: "107"

  # 256-color palette
  def color_param(:fg, n) when is_integer(n) and n >= 0 and n <= 255, do: "38;5;#{n}"
  def color_param(:bg, n) when is_integer(n) and n >= 0 and n <= 255, do: "48;5;#{n}"

  # True color RGB
  def color_param(:fg, {r, g, b})
      when is_integer(r) and is_integer(g) and is_integer(b) do
    "38;2;#{r};#{g};#{b}"
  end

  def color_param(:bg, {r, g, b})
      when is_integer(r) and is_integer(g) and is_integer(b) do
    "48;2;#{r};#{g};#{b}"
  end

  # Nil/unknown colors
  def color_param(_type, nil), do: nil
  def color_param(_type, _unknown), do: nil

  @doc """
  Returns SGR parameter string for an attribute.

  Used when building combined sequences.

  ## Examples

      iex> SGR.attr_param(:bold)
      "1"

      iex> SGR.attr_param(:underline)
      "4"
  """
  @spec attr_param(atom()) :: String.t() | nil
  def attr_param(:bold), do: "1"
  def attr_param(:dim), do: "2"
  def attr_param(:italic), do: "3"
  def attr_param(:underline), do: "4"
  def attr_param(:blink), do: "5"
  def attr_param(:reverse), do: "7"
  def attr_param(:hidden), do: "8"
  def attr_param(:strikethrough), do: "9"
  def attr_param(_unknown), do: nil

  @doc """
  Returns SGR parameter string to turn off an attribute.

  Used when removing specific attributes without full reset.

  ## Examples

      iex> SGR.attr_off_param(:bold)
      "22"

      iex> SGR.attr_off_param(:underline)
      "24"
  """
  @spec attr_off_param(atom()) :: String.t() | nil
  def attr_off_param(:bold), do: "22"
  def attr_off_param(:dim), do: "22"
  def attr_off_param(:italic), do: "23"
  def attr_off_param(:underline), do: "24"
  def attr_off_param(:blink), do: "25"
  def attr_off_param(:reverse), do: "27"
  def attr_off_param(:hidden), do: "28"
  def attr_off_param(:strikethrough), do: "29"
  def attr_off_param(_unknown), do: nil

  @doc """
  Builds a combined SGR sequence from a list of parameters.

  ## Examples

      iex> SGR.build_sequence(["1", "31"])
      ["\\e[", ["1", ";", "31"], "m"]

      iex> SGR.build_sequence([])
      []
  """
  @spec build_sequence([String.t()]) :: iodata()
  def build_sequence([]), do: []

  def build_sequence(params) when is_list(params) do
    filtered = Enum.reject(params, &is_nil/1)

    if filtered == [] do
      []
    else
      [@csi, Enum.intersperse(filtered, ";"), "m"]
    end
  end

  # ===========================================================================
  # Sequence Mode - Returns complete escape sequences
  # ===========================================================================

  @doc """
  Returns complete SGR escape sequence for a color.

  Used for direct terminal output.

  ## Examples

      iex> SGR.color_sequence(:fg, :red) |> IO.iodata_to_binary()
      "\\e[31m"

      iex> SGR.color_sequence(:fg, :default) |> IO.iodata_to_binary()
      "\\e[39m"
  """
  @spec color_sequence(:fg | :bg, color :: term()) :: iodata()
  def color_sequence(type, color) do
    case color_param(type, color) do
      nil -> []
      param -> [@csi, param, "m"]
    end
  end

  @doc """
  Returns complete SGR escape sequence for an attribute.

  Used for direct terminal output.

  ## Examples

      iex> SGR.attr_sequence(:bold) |> IO.iodata_to_binary()
      "\\e[1m"
  """
  @spec attr_sequence(atom()) :: iodata()
  def attr_sequence(attr) do
    case attr_param(attr) do
      nil -> []
      param -> [@csi, param, "m"]
    end
  end

  @doc """
  Returns SGR reset sequence.

  Resets all attributes and colors to terminal defaults.
  """
  @spec reset() :: iodata()
  def reset, do: [@csi, "0m"]

  # ===========================================================================
  # Utility Functions
  # ===========================================================================

  @doc """
  Returns all supported named colors.
  """
  @spec named_colors() :: [atom()]
  def named_colors do
    [
      :black,
      :red,
      :green,
      :yellow,
      :blue,
      :magenta,
      :cyan,
      :white,
      :bright_black,
      :bright_red,
      :bright_green,
      :bright_yellow,
      :bright_blue,
      :bright_magenta,
      :bright_cyan,
      :bright_white
    ]
  end

  @doc """
  Returns all supported attributes.
  """
  @spec supported_attrs() :: [atom()]
  def supported_attrs do
    [:bold, :dim, :italic, :underline, :blink, :reverse, :hidden, :strikethrough]
  end

  @doc """
  Checks if a color value is valid.
  """
  @spec valid_color?(term()) :: boolean()
  def valid_color?(:default), do: true

  def valid_color?(color)
      when color in [:black, :red, :green, :yellow, :blue, :magenta, :cyan, :white], do: true

  def valid_color?(color)
      when color in [
             :bright_black,
             :bright_red,
             :bright_green,
             :bright_yellow,
             :bright_blue,
             :bright_magenta,
             :bright_cyan,
             :bright_white
           ], do: true

  def valid_color?(n) when is_integer(n) and n >= 0 and n <= 255, do: true

  def valid_color?({r, g, b})
      when is_integer(r) and is_integer(g) and is_integer(b) and r >= 0 and r <= 255 and g >= 0 and
             g <= 255 and b >= 0 and b <= 255, do: true

  def valid_color?(_), do: false

  @doc """
  Checks if an attribute is valid.
  """
  @spec valid_attr?(term()) :: boolean()
  def valid_attr?(attr), do: attr in supported_attrs()
end
