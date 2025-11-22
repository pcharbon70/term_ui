defmodule TermUI.Widgets.LineChart do
  @moduledoc """
  Line chart widget using Braille patterns for sub-character resolution.

  Each Braille character cell is 2 dots wide and 4 dots tall, enabling
  smooth line rendering in text mode. Perfect for time series visualization.

  ## Usage

      LineChart.render(
        series: [
          %{data: [1, 3, 5, 2, 8], color: :blue},
          %{data: [2, 4, 3, 6, 4], color: :red}
        ],
        width: 40,
        height: 10
      )

  ## Braille Patterns

  Braille patterns use Unicode range U+2800 to U+28FF.
  Each cell has 8 dots arranged as:
  ```
  1 4
  2 5
  3 6
  7 8
  ```
  """

  import TermUI.Component.RenderNode

  # Braille base character
  @braille_base 0x2800

  # Dot positions in braille cell (column, row) -> bit
  @dot_bits %{
    {0, 0} => 0x01,  # dot 1
    {0, 1} => 0x02,  # dot 2
    {0, 2} => 0x04,  # dot 3
    {1, 0} => 0x08,  # dot 4
    {1, 1} => 0x10,  # dot 5
    {1, 2} => 0x20,  # dot 6
    {0, 3} => 0x40,  # dot 7
    {1, 3} => 0x80   # dot 8
  }

  @doc """
  Renders a line chart using Braille patterns.

  ## Options

  - `:series` - List of series with data and optional color
  - `:data` - Single series data (alternative to :series)
  - `:width` - Chart width in characters (default: 40)
  - `:height` - Chart height in characters (default: 10)
  - `:min` - Minimum Y value (default: auto)
  - `:max` - Maximum Y value (default: auto)
  - `:show_axis` - Show axis lines (default: false)
  - `:style` - Style for the chart
  """
  @spec render(keyword()) :: TermUI.Component.RenderNode.t()
  def render(opts) do
    series = get_series(opts)
    width = Keyword.get(opts, :width, 40)
    height = Keyword.get(opts, :height, 10)
    show_axis = Keyword.get(opts, :show_axis, false)
    style = Keyword.get(opts, :style)

    if Enum.empty?(series) || Enum.all?(series, fn s -> Enum.empty?(s.data) end) do
      empty()
    else
      do_render(series, width, height, show_axis, style, opts)
    end
  end

  defp get_series(opts) do
    case Keyword.get(opts, :series) do
      nil ->
        case Keyword.get(opts, :data) do
          nil -> []
          data -> [%{data: data, color: nil}]
        end

      series ->
        series
    end
  end

  defp do_render(series, width, height, show_axis, style, opts) do
    # Get all values for scaling
    all_values = series |> Enum.flat_map(& &1.data)
    min = Keyword.get(opts, :min, Enum.min(all_values))
    max = Keyword.get(opts, :max, Enum.max(all_values))

    # Create canvas (width * 2 dots, height * 4 dots)
    canvas_width = width * 2
    canvas_height = height * 4

    # Initialize empty canvas
    canvas = :ets.new(:braille_canvas, [:set])

    # Draw each series
    Enum.each(series, fn s ->
      draw_series(canvas, s.data, canvas_width, canvas_height, min, max)
    end)

    # Convert canvas to braille characters
    rows = for y <- 0..(height - 1) do
      chars = for x <- 0..(width - 1) do
        pattern = get_cell_pattern(canvas, x, y)
        <<@braille_base + pattern::utf8>>
      end

      Enum.join(chars)
    end

    :ets.delete(canvas)

    # Build render tree
    row_nodes = Enum.map(rows, &text/1)

    result = if show_axis do
      # Add axis
      axis_row = text("└" <> String.duplicate("─", width - 1))
      stack(:vertical, row_nodes ++ [axis_row])
    else
      stack(:vertical, row_nodes)
    end

    if style do
      styled(result, style)
    else
      result
    end
  end

  defp draw_series(canvas, data, canvas_width, canvas_height, min, max) do
    points = data
    |> Enum.with_index()
    |> Enum.map(fn {value, index} ->
      x = round(index / max(1, length(data) - 1) * (canvas_width - 1))
      y = value_to_y(value, min, max, canvas_height)
      {x, y}
    end)

    # Draw lines between consecutive points
    points
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.each(fn [{x1, y1}, {x2, y2}] ->
      draw_line(canvas, x1, y1, x2, y2)
    end)

    # Also draw single points
    Enum.each(points, fn {x, y} ->
      set_dot(canvas, x, y)
    end)
  end

  defp value_to_y(value, min, max, canvas_height) when max > min do
    normalized = (value - min) / (max - min)
    # Invert Y (0 is top)
    round((1 - normalized) * (canvas_height - 1))
  end

  defp value_to_y(_value, _min, _max, canvas_height) do
    div(canvas_height, 2)
  end

  defp draw_line(canvas, x1, y1, x2, y2) do
    # Bresenham's line algorithm
    dx = abs(x2 - x1)
    dy = abs(y2 - y1)
    sx = if x1 < x2, do: 1, else: -1
    sy = if y1 < y2, do: 1, else: -1
    err = dx - dy

    draw_line_loop(canvas, x1, y1, x2, y2, dx, dy, sx, sy, err)
  end

  defp draw_line_loop(canvas, x, y, x2, y2, dx, dy, sx, sy, err) do
    set_dot(canvas, x, y)

    if x == x2 and y == y2 do
      :ok
    else
      e2 = 2 * err

      {new_x, new_err} = if e2 > -dy do
        {x + sx, err - dy}
      else
        {x, err}
      end

      {new_y, new_err} = if e2 < dx do
        {y + sy, new_err + dx}
      else
        {y, new_err}
      end

      draw_line_loop(canvas, new_x, new_y, x2, y2, dx, dy, sx, sy, new_err)
    end
  end

  defp set_dot(canvas, x, y) when x >= 0 and y >= 0 do
    :ets.insert(canvas, {{x, y}, true})
  end

  defp set_dot(_canvas, _x, _y), do: :ok

  defp get_cell_pattern(canvas, cell_x, cell_y) do
    # Get the 2x4 dots for this cell
    base_x = cell_x * 2
    base_y = cell_y * 4

    Enum.reduce(@dot_bits, 0, fn {{dx, dy}, bit}, acc ->
      if :ets.lookup(canvas, {base_x + dx, base_y + dy}) != [] do
        Bitwise.bor(acc, bit)
      else
        acc
      end
    end)
  end

  @doc """
  Converts coordinates to a single Braille character.

  Useful for drawing individual points.
  """
  @spec dots_to_braille([{0 | 1, 0..3}]) :: String.t()
  def dots_to_braille(dots) do
    pattern = Enum.reduce(dots, 0, fn {x, y}, acc ->
      bit = Map.get(@dot_bits, {x, y}, 0)
      Bitwise.bor(acc, bit)
    end)

    <<@braille_base + pattern::utf8>>
  end

  @doc """
  Returns an empty Braille character.
  """
  @spec empty_braille() :: String.t()
  def empty_braille do
    <<@braille_base::utf8>>
  end

  @doc """
  Returns a full Braille character (all dots).
  """
  @spec full_braille() :: String.t()
  def full_braille do
    <<@braille_base + 0xFF::utf8>>
  end
end
