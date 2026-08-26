defmodule TermUI.Layout do
  @moduledoc """
  Pure rectangle allocation and frame placement.

  Layout rectangles use zero-based coordinates because mouse events use the
  same coordinate system. `place/3` converts them to the one-based coordinates
  used by `TermUI.Frame.overlay/4`.
  """

  alias TermUI.{Frame, Mouse}
  alias TermUI.Mouse.Region

  @type rect ::
          {x :: non_neg_integer(), y :: non_neg_integer(), width :: non_neg_integer(),
           height :: non_neg_integer()}
  @type track :: non_neg_integer() | :fill | {:weight, pos_integer() | float()}
  @type padding ::
          non_neg_integer()
          | {non_neg_integer(), non_neg_integer(), non_neg_integer(), non_neg_integer()}

  defguardp is_rect(x, y, width, height)
            when is_integer(x) and x >= 0 and is_integer(y) and y >= 0 and is_integer(width) and
                   width >= 0 and is_integer(height) and height >= 0

  @doc "Creates a root rectangle from frame dimensions."
  @spec new({non_neg_integer(), non_neg_integer()}) ::
          {0, 0, non_neg_integer(), non_neg_integer()}
  def new({width, height})
      when is_integer(width) and width >= 0 and is_integer(height) and height >= 0,
      do: {0, 0, width, height}

  @doc "Returns a rectangle's frame dimensions."
  @spec dimensions(rect()) :: {non_neg_integer(), non_neg_integer()}
  def dimensions({_x, _y, width, height}), do: {width, height}

  @doc "Insets a rectangle by uniform or per-side padding."
  @spec inset(rect(), padding()) :: rect()
  def inset(rect, padding) when is_integer(padding) and padding >= 0,
    do: inset(rect, {padding, padding, padding, padding})

  def inset({x, y, width, height}, {top, right, bottom, left})
      when is_rect(x, y, width, height) and is_integer(top) and top >= 0 and is_integer(right) and
             right >= 0 and is_integer(bottom) and bottom >= 0 and is_integer(left) and left >= 0 do
    inset_x = min(left, width)
    inset_y = min(top, height)

    {
      x + inset_x,
      y + inset_y,
      max(width - left - right, 0),
      max(height - top - bottom, 0)
    }
  end

  @doc "Returns a child rectangle clipped to its parent."
  @spec at(rect(), {non_neg_integer(), non_neg_integer()}, {non_neg_integer(), non_neg_integer()}) ::
          rect()
  def at({x, y, width, height}, {child_x, child_y}, {child_width, child_height})
      when is_rect(x, y, width, height) and is_integer(child_x) and child_x >= 0 and
             is_integer(child_y) and child_y >= 0 and is_integer(child_width) and child_width >= 0 and
             is_integer(child_height) and child_height >= 0 do
    offset_x = min(child_x, width)
    offset_y = min(child_y, height)

    {
      x + offset_x,
      y + offset_y,
      min(child_width, max(width - offset_x, 0)),
      min(child_height, max(height - offset_y, 0))
    }
  end

  @doc "Allocates horizontal tracks inside a rectangle."
  @spec row(rect(), [track()], keyword()) :: [rect()]
  def row({x, y, width, height}, tracks, opts \\ [])
      when is_rect(x, y, width, height) and is_list(tracks) do
    gap = opts |> Keyword.get(:gap, 0) |> non_negative_integer!(:gap)
    sizes = allocate(tracks, width, gap)
    boundary = x + width

    sizes
    |> Enum.map_reduce(x, fn size, cursor ->
      start = min(cursor, boundary)
      size = min(size, boundary - start)
      {{start, y, size, height}, min(start + size + gap, boundary)}
    end)
    |> elem(0)
  end

  @doc "Allocates vertical tracks inside a rectangle."
  @spec column(rect(), [track()], keyword()) :: [rect()]
  def column({x, y, width, height}, tracks, opts \\ [])
      when is_rect(x, y, width, height) and is_list(tracks) do
    gap = opts |> Keyword.get(:gap, 0) |> non_negative_integer!(:gap)
    sizes = allocate(tracks, height, gap)
    boundary = y + height

    sizes
    |> Enum.map_reduce(y, fn size, cursor ->
      start = min(cursor, boundary)
      size = min(size, boundary - start)
      {{x, start, width, size}, min(start + size + gap, boundary)}
    end)
    |> elem(0)
  end

  @doc "Allocates an equal-cell, row-major grid."
  @spec grid(rect(), non_neg_integer(), keyword()) :: [rect()]
  def grid(rect, item_count, opts \\ [])

  def grid({x, y, width, height}, 0, _opts) when is_rect(x, y, width, height), do: []

  def grid({x, y, width, height}, item_count, opts)
      when is_rect(x, y, width, height) and is_integer(item_count) and item_count > 0 do
    columns = opts |> Keyword.get(:columns, 2) |> positive_integer!(:columns)
    rows = opts |> Keyword.get(:rows, ceil_div(item_count, columns)) |> positive_integer!(:rows)

    column_gap =
      opts
      |> Keyword.get(:column_gap, Keyword.get(opts, :gap, 0))
      |> non_negative_integer!(:column_gap)

    row_gap =
      opts
      |> Keyword.get(:row_gap, Keyword.get(opts, :gap, 0))
      |> non_negative_integer!(:row_gap)

    cell_count = min(item_count, columns * rows)

    Enum.map(0..(cell_count - 1), fn index ->
      column_index = rem(index, columns)
      row_index = div(index, columns)
      {cell_x, cell_width} = equal_track(x, width, columns, column_gap, column_index)
      {cell_y, cell_height} = equal_track(y, height, rows, row_gap, row_index)
      {cell_x, cell_y, cell_width, cell_height}
    end)
  end

  @doc "Places and clips a child frame inside a rectangle."
  @spec place(Frame.t(), Frame.t(), rect()) :: Frame.t()
  def place(%Frame{} = base, %Frame{}, {x, y, 0, height}) when is_rect(x, y, 0, height),
    do: base

  def place(%Frame{} = base, %Frame{}, {x, y, width, 0}) when is_rect(x, y, width, 0),
    do: base

  def place(%Frame{} = base, %Frame{} = child, {x, y, width, height})
      when is_rect(x, y, width, height) do
    width = min(width, max(base.width - x, 0))
    height = min(height, max(base.height - y, 0))

    if width == 0 or height == 0 do
      base
    else
      clipped = Frame.overlay(Frame.new(width, height), child, 1, 1)
      Frame.overlay(base, clipped, x + 1, y + 1)
    end
  end

  @doc "Creates a mouse region from a non-empty rectangle."
  @spec region(term(), rect(), keyword()) :: Region.t() | nil
  def region(id, rect, opts \\ [])

  def region(_id, {x, y, 0, height}, _opts) when is_rect(x, y, 0, height), do: nil
  def region(_id, {x, y, width, 0}, _opts) when is_rect(x, y, width, 0), do: nil

  def region(id, {x, y, width, height}, opts) when is_rect(x, y, width, height),
    do: Mouse.region(id, x, y, width, height, opts)

  defp allocate([], _length, _gap), do: []

  defp allocate(tracks, length, gap) do
    gap_total = gap * max(length(tracks) - 1, 0)
    available = max(length - gap_total, 0)
    fixed_total = Enum.reduce(tracks, 0, fn track, total -> total + fixed_size(track) end)
    flexible_space = max(available - fixed_total, 0)
    flexible_sizes = weighted_sizes(tracks, flexible_space)

    {sizes, _remaining, _flexible_sizes} =
      Enum.reduce(tracks, {[], available, flexible_sizes}, fn track,
                                                              {sizes, remaining, flexible_sizes} ->
        if flexible?(track) do
          [flexible_size | rest] = flexible_sizes
          size = min(flexible_size, remaining)
          {[size | sizes], remaining - size, rest}
        else
          size = min(fixed_size(track), remaining)
          {[size | sizes], remaining - size, flexible_sizes}
        end
      end)

    Enum.reverse(sizes)
  end

  defp weighted_sizes(tracks, available) do
    weights = tracks |> Enum.filter(&flexible?/1) |> Enum.map(&weight/1)

    case Enum.sum(weights) do
      total when total > 0 -> largest_remainder(weights, available, total)
      _total -> []
    end
  end

  defp largest_remainder(weights, available, total) do
    shares = Enum.map(weights, &(available * &1 / total))
    base = Enum.map(shares, &floor/1)
    remainder = available - Enum.sum(base)

    winners =
      shares
      |> Enum.with_index()
      |> Enum.sort_by(fn {share, index} -> {-(share - floor(share)), index} end)
      |> Enum.take(remainder)
      |> MapSet.new(fn {_share, index} -> index end)

    base
    |> Enum.with_index()
    |> Enum.map(fn {size, index} -> size + if(MapSet.member?(winners, index), do: 1, else: 0) end)
  end

  defp fixed_size(track) when is_integer(track) and track >= 0, do: track
  defp fixed_size(_track), do: 0
  defp flexible?(:fill), do: true
  defp flexible?({:weight, weight}) when is_number(weight) and weight > 0, do: true
  defp flexible?(_track), do: false
  defp weight(:fill), do: 1.0
  defp weight({:weight, weight}), do: weight * 1.0
  defp ceil_div(value, divisor), do: div(value + divisor - 1, divisor)

  defp equal_track(origin, length, count, gap, index) do
    available = max(length - gap * max(count - 1, 0), 0)
    size = div(available, count)
    remainder = rem(available, count)
    offset = index * (size + gap) + min(index, remainder)
    track_size = size + if(index < remainder, do: 1, else: 0)
    start = min(origin + offset, origin + length)
    {start, min(track_size, origin + length - start)}
  end

  defp non_negative_integer!(value, _name) when is_integer(value) and value >= 0, do: value

  defp non_negative_integer!(value, name),
    do: raise(ArgumentError, "#{name} must be a non-negative integer, got: #{inspect(value)}")

  defp positive_integer!(value, _name) when is_integer(value) and value > 0, do: value

  defp positive_integer!(value, name),
    do: raise(ArgumentError, "#{name} must be a positive integer, got: #{inspect(value)}")
end
