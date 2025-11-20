defmodule TermUI.Renderer.Cell do
  @moduledoc """
  Represents a single cell in the terminal screen buffer.

  A cell contains a character (grapheme cluster), foreground and background
  colors, and style attributes. Cells are immutable - updates create new
  cells, enabling efficient diffing by reference comparison.

  ## Color Types

  Colors can be specified as:
  - `:default` - Terminal default color
  - Atom - Named color (`:red`, `:green`, `:blue`, etc.)
  - Integer 0-255 - 256-color palette index
  - `{r, g, b}` tuple - True color RGB values (0-255 each)

  ## Attributes

  Supported style attributes:
  - `:bold` - Bold/bright text
  - `:dim` - Dimmed text
  - `:italic` - Italic text
  - `:underline` - Underlined text
  - `:blink` - Blinking text
  - `:reverse` - Reversed colors
  - `:hidden` - Hidden text
  - `:strikethrough` - Strikethrough text
  """

  @type color :: :default | atom() | 0..255 | {0..255, 0..255, 0..255}

  @type attribute ::
          :bold | :dim | :italic | :underline | :blink | :reverse | :hidden | :strikethrough

  @type t :: %__MODULE__{
          char: String.t(),
          fg: color(),
          bg: color(),
          attrs: MapSet.t(attribute())
        }

  defstruct char: " ",
            fg: :default,
            bg: :default,
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
  Creates a new cell with the given character and optional styling.

  ## Examples

      iex> Cell.new("A")
      %Cell{char: "A", fg: :default, bg: :default, attrs: MapSet.new()}

      iex> Cell.new("X", fg: :red, attrs: [:bold])
      %Cell{char: "X", fg: :red, bg: :default, attrs: MapSet.new([:bold])}
  """
  @spec new(String.t(), keyword()) :: t()
  def new(char, opts \\ []) when is_binary(char) do
    fg = Keyword.get(opts, :fg, :default)
    bg = Keyword.get(opts, :bg, :default)
    attrs = Keyword.get(opts, :attrs, [])

    %__MODULE__{
      char: char,
      fg: validate_color!(fg),
      bg: validate_color!(bg),
      attrs: attrs |> Enum.map(&validate_attribute!/1) |> MapSet.new()
    }
  end

  @doc """
  Returns an empty cell with default styling.

  An empty cell contains a space character with default colors and no attributes.

  ## Examples

      iex> Cell.empty()
      %Cell{char: " ", fg: :default, bg: :default, attrs: MapSet.new()}
  """
  @spec empty() :: t()
  def empty do
    %__MODULE__{}
  end

  @doc """
  Compares two cells for equality.

  Returns `true` if both cells have the same character, colors, and attributes.
  Used by the diff algorithm to identify changed cells.

  ## Examples

      iex> Cell.equal?(Cell.empty(), Cell.empty())
      true

      iex> Cell.equal?(Cell.new("A"), Cell.new("B"))
      false
  """
  @spec equal?(t(), t()) :: boolean()
  def equal?(%__MODULE__{} = a, %__MODULE__{} = b) do
    a.char == b.char and
      a.fg == b.fg and
      a.bg == b.bg and
      MapSet.equal?(a.attrs, b.attrs)
  end

  @doc """
  Checks if a cell is empty (space with default styling).

  ## Examples

      iex> Cell.empty?(Cell.empty())
      true

      iex> Cell.empty?(Cell.new("A"))
      false
  """
  @spec empty?(t()) :: boolean()
  def empty?(%__MODULE__{} = cell) do
    cell.char == " " and
      cell.fg == :default and
      cell.bg == :default and
      MapSet.size(cell.attrs) == 0
  end

  @doc """
  Returns a cell with updated character.

  ## Examples

      iex> cell = Cell.new("A", fg: :red)
      iex> Cell.put_char(cell, "B")
      %Cell{char: "B", fg: :red, bg: :default, attrs: MapSet.new()}
  """
  @spec put_char(t(), String.t()) :: t()
  def put_char(%__MODULE__{} = cell, char) when is_binary(char) do
    %{cell | char: char}
  end

  @doc """
  Returns a cell with updated foreground color.
  """
  @spec put_fg(t(), color()) :: t()
  def put_fg(%__MODULE__{} = cell, color) do
    %{cell | fg: validate_color!(color)}
  end

  @doc """
  Returns a cell with updated background color.
  """
  @spec put_bg(t(), color()) :: t()
  def put_bg(%__MODULE__{} = cell, color) do
    %{cell | bg: validate_color!(color)}
  end

  @doc """
  Adds an attribute to the cell.
  """
  @spec add_attr(t(), attribute()) :: t()
  def add_attr(%__MODULE__{} = cell, attr) do
    %{cell | attrs: MapSet.put(cell.attrs, validate_attribute!(attr))}
  end

  @doc """
  Removes an attribute from the cell.
  """
  @spec remove_attr(t(), attribute()) :: t()
  def remove_attr(%__MODULE__{} = cell, attr) do
    %{cell | attrs: MapSet.delete(cell.attrs, attr)}
  end

  @doc """
  Checks if the cell has a specific attribute.
  """
  @spec has_attr?(t(), attribute()) :: boolean()
  def has_attr?(%__MODULE__{} = cell, attr) do
    MapSet.member?(cell.attrs, attr)
  end

  @doc """
  Returns list of valid color names.
  """
  @spec named_colors() :: [atom()]
  def named_colors, do: @named_colors

  @doc """
  Returns list of valid attributes.
  """
  @spec valid_attributes() :: [attribute()]
  def valid_attributes, do: @valid_attributes

  # Private helpers

  defp validate_color!(:default), do: :default

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
