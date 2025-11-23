defmodule TermUI.Layout.Alignment do
  @moduledoc """
  Flexbox-inspired alignment for positioning components within allocated space.

  ## Alignment Model

  - **Main axis**: Direction of layout (X for horizontal, Y for vertical)
  - **Cross axis**: Perpendicular to main axis

  ## Justify Content (Main Axis)

  - `:start` - Pack at beginning
  - `:center` - Center in space
  - `:end` - Pack at end
  - `:space_between` - Equal space between components
  - `:space_around` - Equal space around each component

  ## Align Items (Cross Axis)

  - `:start` - Position at cross-axis start
  - `:center` - Center on cross-axis
  - `:end` - Position at cross-axis end
  - `:stretch` - Expand to fill cross-axis

  ## Examples

      # Apply alignment to solved rects
      rects = Solver.solve_to_rects(constraints, area)
      aligned = Alignment.apply(rects, area,
        direction: :horizontal,
        justify: :space_between,
        align: :center
      )

      # With margins
      aligned = Alignment.apply_with_spacing(rects, area,
        direction: :horizontal,
        margin: %{top: 5, right: 5, bottom: 5, left: 5}
      )
  """

  @type rect :: %{x: integer(), y: integer(), width: integer(), height: integer()}
  @type direction :: :horizontal | :vertical
  @type justify :: :start | :center | :end | :space_between | :space_around
  @type align :: :start | :center | :end | :stretch
  @type spacing :: %{top: integer(), right: integer(), bottom: integer(), left: integer()}

  @type opts :: [
          direction: direction(),
          justify: justify(),
          align: align(),
          align_self: [align() | nil]
        ]

  # Public API

  @doc """
  Applies alignment to a list of rectangles within a container area.

  ## Parameters

  - `rects` - list of rectangles from solver
  - `area` - container bounding rectangle
  - `opts` - alignment options
    - `:direction` - `:horizontal` (default) or `:vertical`
    - `:justify` - main axis alignment (default `:start`)
    - `:align` - cross axis alignment (default `:start`)
    - `:align_self` - per-component cross axis overrides

  ## Returns

  List of aligned rectangles.
  """
  @spec apply([rect()], rect(), opts()) :: [rect()]
  def apply(rects, area, opts \\ []) do
    direction = Keyword.get(opts, :direction, :horizontal)
    justify = Keyword.get(opts, :justify, :start)
    align = Keyword.get(opts, :align, :start)
    align_self = Keyword.get(opts, :align_self, [])

    rects
    |> apply_justify(area, direction, justify)
    |> apply_align(area, direction, align, align_self)
  end

  @doc """
  Applies margin to rectangles, shrinking them.

  ## Parameters

  - `rects` - list of rectangles
  - `margins` - list of margin maps (one per rect) or single margin for all

  ## Returns

  List of rectangles with margins applied.
  """
  @spec apply_margins([rect()], [spacing()] | spacing()) :: [rect()]
  def apply_margins(rects, margins) when is_map(margins) do
    Enum.map(rects, &apply_margin(&1, margins))
  end

  def apply_margins(rects, margins) when is_list(margins) do
    rects
    |> Enum.zip(margins ++ List.duplicate(%{top: 0, right: 0, bottom: 0, left: 0}, length(rects)))
    |> Enum.map(fn {rect, margin} -> apply_margin(rect, margin) end)
  end

  @doc """
  Applies padding to a rectangle, shrinking the content area.

  ## Parameters

  - `rect` - rectangle to pad
  - `padding` - padding map

  ## Returns

  Rectangle with padding applied (position adjusted, size reduced).
  """
  @spec apply_padding(rect(), spacing()) :: rect()
  def apply_padding(rect, padding) do
    %{
      x: rect.x + padding.left,
      y: rect.y + padding.top,
      width: max(0, rect.width - padding.left - padding.right),
      height: max(0, rect.height - padding.top - padding.bottom)
    }
  end

  @doc """
  Parses spacing shorthand into a spacing map.

  ## Examples

      iex> Alignment.parse_spacing(10)
      %{top: 10, right: 10, bottom: 10, left: 10}

      iex> Alignment.parse_spacing({5, 10})
      %{top: 5, right: 10, bottom: 5, left: 10}

      iex> Alignment.parse_spacing({1, 2, 3, 4})
      %{top: 1, right: 2, bottom: 3, left: 4}
  """
  @spec parse_spacing(
          integer()
          | {integer(), integer()}
          | {integer(), integer(), integer(), integer()}
        ) :: spacing()
  def parse_spacing(value) when is_integer(value) do
    %{top: value, right: value, bottom: value, left: value}
  end

  def parse_spacing({vertical, horizontal}) do
    %{top: vertical, right: horizontal, bottom: vertical, left: horizontal}
  end

  def parse_spacing({top, right, bottom, left}) do
    %{top: top, right: right, bottom: bottom, left: left}
  end

  def parse_spacing(%{} = map) do
    %{
      top: Map.get(map, :top, 0),
      right: Map.get(map, :right, 0),
      bottom: Map.get(map, :bottom, 0),
      left: Map.get(map, :left, 0)
    }
  end

  # Justify (main axis) implementation

  defp apply_justify(rects, area, direction, :start) do
    {main_start, _main_size} = get_main_axis(area, direction)
    shift_main_axis(rects, main_start, direction)
  end

  defp apply_justify(rects, area, direction, :center) do
    {main_start, main_size} = get_main_axis(area, direction)
    total_content = total_main_size(rects, direction)
    offset = div(main_size - total_content, 2)

    shift_main_axis(rects, main_start + offset, direction)
  end

  defp apply_justify(rects, area, direction, :end) do
    {main_start, main_size} = get_main_axis(area, direction)
    total_content = total_main_size(rects, direction)
    offset = main_size - total_content

    shift_main_axis(rects, main_start + offset, direction)
  end

  defp apply_justify(rects, area, direction, :space_between) do
    count = length(rects)

    if count <= 1 do
      rects
    else
      {main_start, main_size} = get_main_axis(area, direction)
      total_content = total_main_size(rects, direction)
      total_space = main_size - total_content
      space_between = div(total_space, count - 1)

      distribute_with_spacing(rects, main_start, space_between, direction)
    end
  end

  defp apply_justify(rects, area, direction, :space_around) do
    count = length(rects)

    if count == 0 do
      rects
    else
      {main_start, main_size} = get_main_axis(area, direction)
      total_content = total_main_size(rects, direction)
      total_space = main_size - total_content
      space_unit = div(total_space, count * 2)

      # Start with half space, then full space between each
      distribute_with_around(rects, main_start + space_unit, space_unit * 2, direction)
    end
  end

  # Align (cross axis) implementation

  defp apply_align(rects, area, direction, align, align_self) do
    {cross_start, cross_size} = get_cross_axis(area, direction)

    rects
    |> Enum.with_index()
    |> Enum.map(fn {rect, idx} ->
      effective_align = Enum.at(align_self, idx) || align
      apply_single_align(rect, cross_start, cross_size, direction, effective_align)
    end)
  end

  defp apply_single_align(rect, cross_start, _cross_size, direction, :start) do
    set_rect_cross_pos(rect, cross_start, direction)
  end

  defp apply_single_align(rect, cross_start, cross_size, direction, :center) do
    rect_cross_size = get_rect_cross_size(rect, direction)
    offset = div(cross_size - rect_cross_size, 2)
    set_rect_cross_pos(rect, cross_start + offset, direction)
  end

  defp apply_single_align(rect, cross_start, cross_size, direction, :end) do
    rect_cross_size = get_rect_cross_size(rect, direction)
    offset = cross_size - rect_cross_size
    set_rect_cross_pos(rect, cross_start + offset, direction)
  end

  defp apply_single_align(rect, cross_start, cross_size, direction, :stretch) do
    rect
    |> set_rect_cross_pos(cross_start, direction)
    |> set_rect_cross_size(cross_size, direction)
  end

  # Helper functions

  defp get_main_axis(area, :horizontal), do: {area.x, area.width}
  defp get_main_axis(area, :vertical), do: {area.y, area.height}

  defp get_cross_axis(area, :horizontal), do: {area.y, area.height}
  defp get_cross_axis(area, :vertical), do: {area.x, area.width}

  defp get_rect_main_size(rect, :horizontal), do: rect.width
  defp get_rect_main_size(rect, :vertical), do: rect.height

  defp get_rect_cross_size(rect, :horizontal), do: rect.height
  defp get_rect_cross_size(rect, :vertical), do: rect.width

  defp set_rect_cross_pos(rect, pos, :horizontal), do: %{rect | y: pos}
  defp set_rect_cross_pos(rect, pos, :vertical), do: %{rect | x: pos}

  defp set_rect_cross_size(rect, size, :horizontal), do: %{rect | height: size}
  defp set_rect_cross_size(rect, size, :vertical), do: %{rect | width: size}

  defp total_main_size(rects, direction) do
    Enum.reduce(rects, 0, fn rect, acc ->
      acc + get_rect_main_size(rect, direction)
    end)
  end

  defp shift_main_axis(rects, start_pos, direction) do
    {shifted, _pos} =
      Enum.map_reduce(rects, start_pos, fn rect, pos ->
        new_rect =
          case direction do
            :horizontal -> %{rect | x: pos}
            :vertical -> %{rect | y: pos}
          end

        {new_rect, pos + get_rect_main_size(rect, direction)}
      end)

    shifted
  end

  defp distribute_with_spacing(rects, start_pos, spacing, direction) do
    {distributed, _pos} =
      Enum.map_reduce(rects, start_pos, fn rect, pos ->
        new_rect =
          case direction do
            :horizontal -> %{rect | x: pos}
            :vertical -> %{rect | y: pos}
          end

        {new_rect, pos + get_rect_main_size(rect, direction) + spacing}
      end)

    distributed
  end

  defp distribute_with_around(rects, start_pos, spacing, direction) do
    {distributed, _pos} =
      Enum.map_reduce(rects, start_pos, fn rect, pos ->
        new_rect =
          case direction do
            :horizontal -> %{rect | x: pos}
            :vertical -> %{rect | y: pos}
          end

        {new_rect, pos + get_rect_main_size(rect, direction) + spacing}
      end)

    distributed
  end

  defp apply_margin(rect, margin) do
    %{
      x: rect.x + margin.left,
      y: rect.y + margin.top,
      width: max(0, rect.width - margin.left - margin.right),
      height: max(0, rect.height - margin.top - margin.bottom)
    }
  end
end
