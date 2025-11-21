defmodule TermUI.Renderer.Style do
  @moduledoc """
  Represents visual styling for text and cells.

  Styles encapsulate colors and text attributes, providing a fluent builder
  API and support for style merging (cascading). Styles can be converted to
  cells for rendering.

  ## Fluent Builder API

      Style.new()
      |> Style.fg(:red)
      |> Style.bg(:black)
      |> Style.bold()
      |> Style.underline()

  ## Style Merging

  Styles can be merged with later styles overriding earlier values:

      base = Style.new() |> Style.fg(:white)
      override = Style.new() |> Style.fg(:red) |> Style.bold()
      merged = Style.merge(base, override)
      # fg: :red, attrs: [:bold]
  """

  alias TermUI.Renderer.Cell

  @type color :: Cell.color()
  @type attribute :: Cell.attribute()

  @type t :: %__MODULE__{
          fg: color() | nil,
          bg: color() | nil,
          attrs: MapSet.t(attribute())
        }

  defstruct fg: nil,
            bg: nil,
            attrs: MapSet.new()

  @valid_attributes [:bold, :dim, :italic, :underline, :blink, :reverse, :hidden, :strikethrough]

  @named_colors [
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

  @doc """
  Creates a new empty style.

  ## Examples

      iex> Style.new()
      %Style{fg: nil, bg: nil, attrs: MapSet.new()}
  """
  @spec new() :: t()
  def new do
    %__MODULE__{}
  end

  @doc """
  Creates a style with initial values.

  ## Examples

      iex> Style.new(fg: :red, attrs: [:bold])
      %Style{fg: :red, bg: nil, attrs: MapSet.new([:bold])}
  """
  @spec new(keyword()) :: t()
  def new(opts) when is_list(opts) do
    fg = Keyword.get(opts, :fg)
    bg = Keyword.get(opts, :bg)
    attrs = Keyword.get(opts, :attrs, [])

    %__MODULE__{
      fg: validate_color!(fg),
      bg: validate_color!(bg),
      attrs: attrs |> Enum.map(&validate_attribute!/1) |> MapSet.new()
    }
  end

  @doc """
  Sets the foreground color.

  ## Examples

      iex> Style.new() |> Style.fg(:red)
      %Style{fg: :red, bg: nil, attrs: MapSet.new()}
  """
  @spec fg(t(), color()) :: t()
  def fg(%__MODULE__{} = style, color) do
    %{style | fg: validate_color!(color)}
  end

  @doc """
  Sets the background color.

  ## Examples

      iex> Style.new() |> Style.bg(:blue)
      %Style{fg: nil, bg: :blue, attrs: MapSet.new()}
  """
  @spec bg(t(), color()) :: t()
  def bg(%__MODULE__{} = style, color) do
    %{style | bg: validate_color!(color)}
  end

  @doc """
  Adds the bold attribute.
  """
  @spec bold(t()) :: t()
  def bold(%__MODULE__{} = style) do
    add_attr(style, :bold)
  end

  @doc """
  Adds the dim attribute.
  """
  @spec dim(t()) :: t()
  def dim(%__MODULE__{} = style) do
    add_attr(style, :dim)
  end

  @doc """
  Adds the italic attribute.
  """
  @spec italic(t()) :: t()
  def italic(%__MODULE__{} = style) do
    add_attr(style, :italic)
  end

  @doc """
  Adds the underline attribute.
  """
  @spec underline(t()) :: t()
  def underline(%__MODULE__{} = style) do
    add_attr(style, :underline)
  end

  @doc """
  Adds the blink attribute.
  """
  @spec blink(t()) :: t()
  def blink(%__MODULE__{} = style) do
    add_attr(style, :blink)
  end

  @doc """
  Adds the reverse attribute.
  """
  @spec reverse(t()) :: t()
  def reverse(%__MODULE__{} = style) do
    add_attr(style, :reverse)
  end

  @doc """
  Adds the hidden attribute.
  """
  @spec hidden(t()) :: t()
  def hidden(%__MODULE__{} = style) do
    add_attr(style, :hidden)
  end

  @doc """
  Adds the strikethrough attribute.
  """
  @spec strikethrough(t()) :: t()
  def strikethrough(%__MODULE__{} = style) do
    add_attr(style, :strikethrough)
  end

  @doc """
  Adds an attribute to the style.
  """
  @spec add_attr(t(), attribute()) :: t()
  def add_attr(%__MODULE__{} = style, attr) do
    %{style | attrs: MapSet.put(style.attrs, validate_attribute!(attr))}
  end

  @doc """
  Removes an attribute from the style.
  """
  @spec remove_attr(t(), attribute()) :: t()
  def remove_attr(%__MODULE__{} = style, attr) do
    %{style | attrs: MapSet.delete(style.attrs, attr)}
  end

  @doc """
  Merges two styles, with the second style overriding the first.

  Only non-nil values from the override style replace values in the base.
  Attributes are combined (union of both sets).

  ## Examples

      iex> base = Style.new(fg: :white, bg: :black)
      iex> override = Style.new(fg: :red, attrs: [:bold])
      iex> merged = Style.merge(base, override)
      iex> merged.fg
      :red
      iex> merged.bg
      :black
      iex> :bold in merged.attrs
      true
  """
  @spec merge(t(), t()) :: t()
  def merge(%__MODULE__{} = base, %__MODULE__{} = override) do
    %__MODULE__{
      fg: override.fg || base.fg,
      bg: override.bg || base.bg,
      attrs: MapSet.union(base.attrs, override.attrs)
    }
  end

  @doc """
  Converts a style to a cell with the given character.

  Applies the style's colors and attributes to create a new cell.
  Uses `:default` for any unset colors.

  ## Examples

      iex> style = Style.new() |> Style.fg(:red) |> Style.bold()
      iex> cell = Style.to_cell(style, "X")
      iex> cell.char
      "X"
      iex> cell.fg
      :red
      iex> cell.bg
      :default
  """
  @spec to_cell(t(), String.t()) :: Cell.t()
  def to_cell(%__MODULE__{} = style, char) when is_binary(char) do
    Cell.new(char,
      fg: style.fg || :default,
      bg: style.bg || :default,
      attrs: MapSet.to_list(style.attrs)
    )
  end

  @doc """
  Applies a style to an existing cell, returning a new cell.

  The style's values override the cell's values where set.

  ## Examples

      iex> cell = Cell.new("A", fg: :white)
      iex> style = Style.new() |> Style.fg(:red)
      iex> new_cell = Style.apply_to_cell(style, cell)
      iex> new_cell.fg
      :red
  """
  @spec apply_to_cell(t(), Cell.t()) :: Cell.t()
  def apply_to_cell(%__MODULE__{} = style, %Cell{} = cell) do
    %Cell{
      char: cell.char,
      fg: style.fg || cell.fg,
      bg: style.bg || cell.bg,
      attrs: MapSet.union(cell.attrs, style.attrs)
    }
  end

  @doc """
  Resets style to default (empty).
  """
  @spec reset(t()) :: t()
  def reset(%__MODULE__{}) do
    new()
  end

  @doc """
  Checks if the style has any properties set.
  """
  @spec empty?(t()) :: boolean()
  def empty?(%__MODULE__{} = style) do
    is_nil(style.fg) and is_nil(style.bg) and MapSet.size(style.attrs) == 0
  end

  @doc """
  Checks if two styles are visually equal.

  Compares foreground color, background color, and all attributes.

  ## Examples

      iex> s1 = Style.new(fg: :red, attrs: [:bold])
      iex> s2 = Style.new(fg: :red, attrs: [:bold])
      iex> Style.equal?(s1, s2)
      true
  """
  @spec equal?(t(), t()) :: boolean()
  def equal?(%__MODULE__{} = a, %__MODULE__{} = b) do
    a.fg == b.fg and a.bg == b.bg and MapSet.equal?(a.attrs, b.attrs)
  end

  # Private validation helpers

  defp validate_color!(nil), do: nil

  defp validate_color!(color) when color in @named_colors, do: color

  defp validate_color!(color) when is_integer(color) and color >= 0 and color <= 255, do: color

  defp validate_color!({r, g, b} = color)
       when is_integer(r) and r >= 0 and r <= 255 and
              is_integer(g) and g >= 0 and g <= 255 and
              is_integer(b) and b >= 0 and b <= 255 do
    color
  end

  defp validate_color!(invalid) do
    raise ArgumentError, "Invalid color: #{inspect(invalid)}"
  end

  defp validate_attribute!(attr) when attr in @valid_attributes, do: attr

  defp validate_attribute!(invalid) do
    raise ArgumentError,
          "Invalid attribute: #{inspect(invalid)}. Valid attributes: #{inspect(@valid_attributes)}"
  end
end
