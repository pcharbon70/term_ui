defmodule TermUI.Widgets.Canvas do
  @moduledoc """
  Canvas widget for custom drawing with direct buffer access.

  Canvas provides a drawing surface with primitives for lines, rectangles,
  text, and Braille graphics. Useful for custom visualizations, charts,
  diagrams, and other graphics that don't fit standard widget patterns.

  ## Usage

      Canvas.new(
        width: 40,
        height: 20,
        on_draw: fn canvas ->
          canvas
          |> Canvas.draw_rect(0, 0, 10, 5, "─", "│", "┌", "┐", "└", "┘")
          |> Canvas.draw_text(2, 2, "Hello")
        end
      )

  ## Features

  - Direct character buffer access
  - Drawing primitives: line, rect, text
  - Braille graphics for sub-character resolution
  - Clear and fill operations
  - Custom render callback

  ## Braille Graphics

  Each character cell contains a 2x4 Braille dot matrix, providing
  higher resolution for plotting and charts.
  """

  use TermUI.StatefulComponent

  # Braille patterns
  @braille_base 0x2800

  # Dot bit positions in Braille character (2 columns x 4 rows)
  @dot_bits %{
    {0, 0} => 0x01,
    {0, 1} => 0x02,
    {0, 2} => 0x04,
    {1, 0} => 0x08,
    {1, 1} => 0x10,
    {1, 2} => 0x20,
    {0, 3} => 0x40,
    {1, 3} => 0x80
  }

  @doc """
  Creates new Canvas widget props.

  ## Options

  - `:width` - Canvas width in characters (default: 40)
  - `:height` - Canvas height in characters (default: 20)
  - `:default_char` - Character to fill canvas (default: " ")
  - `:on_draw` - Callback function to draw on canvas
  """
  @spec new(keyword()) :: map()
  def new(opts) do
    %{
      width: Keyword.get(opts, :width, 40),
      height: Keyword.get(opts, :height, 20),
      default_char: Keyword.get(opts, :default_char, " "),
      on_draw: Keyword.get(opts, :on_draw)
    }
  end

  @impl true
  def init(props) do
    state = %{
      width: props.width,
      height: props.height,
      default_char: props.default_char,
      on_draw: props.on_draw,
      buffer: create_buffer(props.width, props.height, props.default_char),
      braille_buffer: %{}
    }

    {:ok, state}
  end

  @impl true
  def handle_event(_event, state) do
    {:ok, state}
  end

  @impl true
  def render(state, _area) do
    # Apply on_draw callback if provided
    state =
      if state.on_draw do
        state.on_draw.(state)
      else
        state
      end

    # Merge braille buffer into main buffer
    buffer = merge_braille_buffer(state)

    # Convert buffer to render nodes
    lines =
      for y <- 0..(state.height - 1) do
        row =
          for x <- 0..(state.width - 1) do
            Map.get(buffer, {x, y}, state.default_char)
          end

        text(Enum.join(row))
      end

    stack(:vertical, lines)
  end

  # Buffer operations

  defp create_buffer(width, height, char) do
    for x <- 0..(width - 1),
        y <- 0..(height - 1),
        into: %{} do
      {{x, y}, char}
    end
  end

  defp merge_braille_buffer(state) do
    # Convert braille dots to characters and merge with buffer
    braille_chars =
      state.braille_buffer
      |> Enum.group_by(fn {{x, y, _dx, _dy}, _set} -> {div(x, 2), div(y, 4)} end)
      |> Enum.map(fn {{cx, cy}, dots} ->
        # Calculate braille character
        pattern =
          Enum.reduce(dots, 0, fn {{x, y, _dx, _dy}, set}, acc ->
            if set do
              # Use actual position within cell
              actual_x = rem(x, 2)
              actual_y = rem(y, 4)
              bit = Map.get(@dot_bits, {actual_x, actual_y}, 0)
              Bitwise.bor(acc, bit)
            else
              acc
            end
          end)

        char = <<@braille_base + pattern::utf8>>
        {{cx, cy}, char}
      end)
      |> Map.new()

    Map.merge(state.buffer, braille_chars)
  end

  # Drawing primitives

  @doc """
  Clears the canvas with the default character.
  """
  @spec clear(map()) :: map()
  def clear(state) do
    %{
      state
      | buffer: create_buffer(state.width, state.height, state.default_char),
        braille_buffer: %{}
    }
  end

  @doc """
  Fills the canvas with a character.
  """
  @spec fill(map(), String.t()) :: map()
  def fill(state, char) do
    %{state | buffer: create_buffer(state.width, state.height, char), braille_buffer: %{}}
  end

  @doc """
  Sets a character at a position.
  """
  @spec set_char(map(), integer(), integer(), String.t()) :: map()
  def set_char(state, x, y, char) do
    if x >= 0 and x < state.width and y >= 0 and y < state.height do
      %{state | buffer: Map.put(state.buffer, {x, y}, char)}
    else
      state
    end
  end

  @doc """
  Gets a character at a position.
  """
  @spec get_char(map(), integer(), integer()) :: String.t() | nil
  def get_char(state, x, y) do
    Map.get(state.buffer, {x, y})
  end

  @doc """
  Draws text at a position.
  """
  @spec draw_text(map(), integer(), integer(), String.t()) :: map()
  def draw_text(state, x, y, text) do
    text
    |> String.graphemes()
    |> Enum.with_index()
    |> Enum.reduce(state, fn {char, i}, acc ->
      set_char(acc, x + i, y, char)
    end)
  end

  @doc """
  Draws a horizontal line.
  """
  @spec draw_hline(map(), integer(), integer(), integer(), String.t()) :: map()
  def draw_hline(state, x, y, length, char \\ "─") do
    Enum.reduce(0..(length - 1), state, fn i, acc ->
      set_char(acc, x + i, y, char)
    end)
  end

  @doc """
  Draws a vertical line.
  """
  @spec draw_vline(map(), integer(), integer(), integer(), String.t()) :: map()
  def draw_vline(state, x, y, length, char \\ "│") do
    Enum.reduce(0..(length - 1), state, fn i, acc ->
      set_char(acc, x, y + i, char)
    end)
  end

  @doc """
  Draws a line between two points using Bresenham's algorithm.
  """
  @spec draw_line(map(), integer(), integer(), integer(), integer(), String.t()) :: map()
  def draw_line(state, x1, y1, x2, y2, char \\ "•") do
    dx = abs(x2 - x1)
    dy = abs(y2 - y1)
    sx = if x1 < x2, do: 1, else: -1
    sy = if y1 < y2, do: 1, else: -1

    draw_line_impl(state, x1, y1, x2, y2, dx, dy, sx, sy, dx - dy, char)
  end

  defp draw_line_impl(state, x, y, x2, y2, dx, dy, sx, sy, err, char) do
    state = set_char(state, x, y, char)

    if x == x2 and y == y2 do
      state
    else
      e2 = 2 * err

      {new_x, new_err} =
        if e2 > -dy do
          {x + sx, err - dy}
        else
          {x, err}
        end

      {new_y, new_err} =
        if e2 < dx do
          {y + sy, new_err + dx}
        else
          {y, new_err}
        end

      draw_line_impl(state, new_x, new_y, x2, y2, dx, dy, sx, sy, new_err, char)
    end
  end

  @doc """
  Draws a rectangle outline.
  """
  @spec draw_rect(
          map(),
          integer(),
          integer(),
          integer(),
          integer(),
          String.t(),
          String.t(),
          String.t(),
          String.t(),
          String.t(),
          String.t()
        ) :: map()
  def draw_rect(
        state,
        x,
        y,
        width,
        height,
        h \\ "─",
        v \\ "│",
        tl \\ "┌",
        tr \\ "┐",
        bl \\ "└",
        br \\ "┘"
      ) do
    # Top edge
    state = set_char(state, x, y, tl)
    state = draw_hline(state, x + 1, y, width - 2, h)
    state = set_char(state, x + width - 1, y, tr)

    # Side edges
    state = draw_vline(state, x, y + 1, height - 2, v)
    state = draw_vline(state, x + width - 1, y + 1, height - 2, v)

    # Bottom edge
    state = set_char(state, x, y + height - 1, bl)
    state = draw_hline(state, x + 1, y + height - 1, width - 2, h)
    set_char(state, x + width - 1, y + height - 1, br)
  end

  @doc """
  Fills a rectangle with a character.
  """
  @spec fill_rect(map(), integer(), integer(), integer(), integer(), String.t()) :: map()
  def fill_rect(state, x, y, width, height, char) do
    for dx <- 0..(width - 1),
        dy <- 0..(height - 1),
        reduce: state do
      acc -> set_char(acc, x + dx, y + dy, char)
    end
  end

  # Braille drawing

  @doc """
  Sets a Braille dot at sub-character position.

  Each character cell is 2 dots wide and 4 dots high.
  """
  @spec set_dot(map(), integer(), integer()) :: map()
  def set_dot(state, x, y) do
    key = {x, y, 0, 0}
    %{state | braille_buffer: Map.put(state.braille_buffer, key, true)}
  end

  @doc """
  Clears a Braille dot at sub-character position.
  """
  @spec clear_dot(map(), integer(), integer()) :: map()
  def clear_dot(state, x, y) do
    key = {x, y, 0, 0}
    %{state | braille_buffer: Map.delete(state.braille_buffer, key)}
  end

  @doc """
  Draws a Braille line between two points.

  Coordinates are in sub-character (dot) space:
  - X resolution: width * 2
  - Y resolution: height * 4
  """
  @spec draw_braille_line(map(), integer(), integer(), integer(), integer()) :: map()
  def draw_braille_line(state, x1, y1, x2, y2) do
    dx = abs(x2 - x1)
    dy = abs(y2 - y1)
    sx = if x1 < x2, do: 1, else: -1
    sy = if y1 < y2, do: 1, else: -1

    draw_braille_line_impl(state, x1, y1, x2, y2, dx, dy, sx, sy, dx - dy)
  end

  defp draw_braille_line_impl(state, x, y, x2, y2, dx, dy, sx, sy, err) do
    state = set_dot(state, x, y)

    if x == x2 and y == y2 do
      state
    else
      e2 = 2 * err

      {new_x, new_err} =
        if e2 > -dy do
          {x + sx, err - dy}
        else
          {x, err}
        end

      {new_y, new_err} =
        if e2 < dx do
          {y + sy, new_err + dx}
        else
          {y, new_err}
        end

      draw_braille_line_impl(state, new_x, new_y, x2, y2, dx, dy, sx, sy, new_err)
    end
  end

  @doc """
  Converts dots to a Braille character.

  Takes a list of {x, y} coordinates within a 2x4 cell.
  """
  @spec dots_to_braille([{integer(), integer()}]) :: String.t()
  def dots_to_braille(dots) do
    pattern =
      Enum.reduce(dots, 0, fn {x, y}, acc ->
        bit = Map.get(@dot_bits, {x, y}, 0)
        Bitwise.bor(acc, bit)
      end)

    <<@braille_base + pattern::utf8>>
  end

  @doc """
  Returns empty Braille character.
  """
  @spec empty_braille() :: String.t()
  def empty_braille, do: <<@braille_base::utf8>>

  @doc """
  Returns full Braille character (all dots set).
  """
  @spec full_braille() :: String.t()
  def full_braille, do: <<@braille_base + 0xFF::utf8>>

  @doc """
  Clears all Braille dots.
  """
  @spec clear_braille(map()) :: map()
  def clear_braille(state) do
    %{state | braille_buffer: %{}}
  end

  @doc """
  Gets the Braille resolution (dots) for the canvas.
  """
  @spec braille_resolution(map()) :: {integer(), integer()}
  def braille_resolution(state) do
    {state.width * 2, state.height * 4}
  end

  # Public API

  @doc """
  Updates the canvas dimensions.
  """
  @spec resize(map(), integer(), integer()) :: map()
  def resize(state, width, height) do
    %{
      state
      | width: width,
        height: height,
        buffer: create_buffer(width, height, state.default_char),
        braille_buffer: %{}
    }
  end

  @doc """
  Creates a canvas and draws on it with a function.
  """
  @spec draw(integer(), integer(), (map() -> map())) :: map()
  def draw(width, height, draw_fn) do
    state = %{
      width: width,
      height: height,
      default_char: " ",
      on_draw: nil,
      buffer: create_buffer(width, height, " "),
      braille_buffer: %{}
    }

    draw_fn.(state)
  end

  @doc """
  Renders the canvas state to a list of strings.
  """
  @spec to_strings(map()) :: [String.t()]
  def to_strings(state) do
    buffer = merge_braille_buffer(state)

    for y <- 0..(state.height - 1) do
      row =
        for x <- 0..(state.width - 1) do
          Map.get(buffer, {x, y}, state.default_char)
        end

      Enum.join(row)
    end
  end
end
