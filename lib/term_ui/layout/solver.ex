defmodule TermUI.Layout.Solver do
  @moduledoc """
  Constraint solver for the layout system.

  Translates constraints into concrete cell positions and sizes using a
  Cassowary-inspired greedy multi-pass algorithm.

  ## Algorithm

  The solver processes constraints in priority order:
  1. **Fixed pass** - allocate length constraints exactly
  2. **Percentage pass** - calculate from total available space
  3. **Ratio/Fill pass** - distribute remaining space proportionally

  ## Examples

      # Three-pane layout
      constraints = [
        Constraint.length(20),
        Constraint.ratio(1),
        Constraint.ratio(2)
      ]

      sizes = Solver.solve(constraints, 100)
      # => [20, 27, 53]

      # Get positioned rectangles
      rects = Solver.solve_to_rects(constraints, %{x: 0, y: 0, width: 100, height: 10})
      # => [
      #   %{x: 0, y: 0, width: 20, height: 10},
      #   %{x: 20, y: 0, width: 27, height: 10},
      #   %{x: 47, y: 0, width: 53, height: 10}
      # ]
  """

  require Logger

  alias TermUI.Layout.Constraint
  alias TermUI.Layout.Constraint.{Length, Percentage, Ratio, Fill}

  @type rect :: %{x: integer(), y: integer(), width: integer(), height: integer()}
  @type direction :: :horizontal | :vertical
  @type solve_opts :: [
          direction: direction(),
          gap: non_neg_integer(),
          cross_axis: non_neg_integer() | nil
        ]

  # Public API

  @doc """
  Solves constraints and returns a list of sizes.

  ## Parameters

  - `constraints` - list of constraints to solve
  - `available` - total available space in cells

  ## Returns

  List of solved sizes (non-negative integers) in same order as constraints.

  ## Examples

      iex> Solver.solve([Constraint.length(20), Constraint.fill()], 100)
      [20, 80]

      iex> Solver.solve([Constraint.percentage(50), Constraint.percentage(50)], 100)
      [50, 50]

      iex> Solver.solve([Constraint.ratio(1), Constraint.ratio(2)], 90)
      [30, 60]
  """
  @spec solve([Constraint.t()], non_neg_integer()) :: [non_neg_integer()]
  def solve(constraints, available) when is_list(constraints) and available >= 0 do
    # Try fast paths first
    case try_fast_path(constraints, available) do
      {:ok, sizes} ->
        sizes

      :general ->
        solve_general(constraints, available)
    end
  end

  @doc """
  Solves constraints and returns positioned rectangles.

  ## Parameters

  - `constraints` - list of constraints to solve
  - `area` - bounding rectangle with x, y, width, height
  - `opts` - solving options
    - `:direction` - `:horizontal` (default) or `:vertical`
    - `:gap` - spacing between elements (default 0)
    - `:cross_axis` - size on cross axis (default uses area dimension)

  ## Returns

  List of rectangles with x, y, width, height.

  ## Examples

      iex> Solver.solve_to_rects(
      ...>   [Constraint.length(20), Constraint.fill()],
      ...>   %{x: 0, y: 0, width: 100, height: 10}
      ...> )
      [
        %{x: 0, y: 0, width: 20, height: 10},
        %{x: 20, y: 0, width: 80, height: 10}
      ]
  """
  @spec solve_to_rects([Constraint.t()], rect(), solve_opts()) :: [rect()]
  def solve_to_rects(constraints, area, opts \\ []) do
    direction = Keyword.get(opts, :direction, :horizontal)
    gap = Keyword.get(opts, :gap, 0)

    {main_size, cross_size} =
      case direction do
        :horizontal -> {area.width, area.height}
        :vertical -> {area.height, area.width}
      end

    cross_size = Keyword.get(opts, :cross_axis, cross_size)

    # Account for gaps in available space
    total_gaps = max(0, length(constraints) - 1) * gap
    available = max(0, main_size - total_gaps)

    sizes = solve(constraints, available)

    # Convert sizes to rectangles
    sizes_to_rects(sizes, area, direction, gap, cross_size)
  end

  @doc """
  Solves horizontal layout (widths) with explicit cross-axis height.

  ## Parameters

  - `constraints` - width constraints
  - `area` - bounding rectangle
  - `opts` - options including `:gap`

  ## Returns

  List of rectangles positioned horizontally.
  """
  @spec solve_horizontal([Constraint.t()], rect(), keyword()) :: [rect()]
  def solve_horizontal(constraints, area, opts \\ []) do
    solve_to_rects(constraints, area, Keyword.put(opts, :direction, :horizontal))
  end

  @doc """
  Solves vertical layout (heights) with explicit cross-axis width.

  ## Parameters

  - `constraints` - height constraints
  - `area` - bounding rectangle
  - `opts` - options including `:gap`

  ## Returns

  List of rectangles positioned vertically.
  """
  @spec solve_vertical([Constraint.t()], rect(), keyword()) :: [rect()]
  def solve_vertical(constraints, area, opts \\ []) do
    solve_to_rects(constraints, area, Keyword.put(opts, :direction, :vertical))
  end

  # Fast paths for common cases

  defp try_fast_path([], _available), do: {:ok, []}

  defp try_fast_path(constraints, available) do
    cond do
      all_fixed?(constraints) ->
        {:ok, solve_all_fixed(constraints, available)}

      single_fill?(constraints) ->
        {:ok, solve_single_fill(constraints, available)}

      true ->
        :general
    end
  end

  defp all_fixed?(constraints) do
    Enum.all?(constraints, &Constraint.fixed?/1)
  end

  defp single_fill?(constraints) do
    fills = Enum.count(constraints, fn c ->
      case Constraint.unwrap(c) do
        %Fill{} -> true
        _ -> false
      end
    end)

    fills == 1 and
      Enum.all?(constraints, fn c ->
        inner = Constraint.unwrap(c)
        match?(%Length{}, inner) or match?(%Fill{}, inner)
      end)
  end

  defp solve_all_fixed(constraints, available) do
    sizes = Enum.map(constraints, fn c -> resolve_length(c) end)
    total = Enum.sum(sizes)

    if total > available do
      Logger.warning("Fixed constraints total #{total} exceeds available #{available}")
      scale_proportionally(sizes, available)
    else
      sizes
    end
  end

  defp solve_single_fill(constraints, available) do
    {sizes, fill_idx} =
      constraints
      |> Enum.with_index()
      |> Enum.map_reduce(nil, fn {c, idx}, fill_idx ->
        case Constraint.unwrap(c) do
          %Fill{} ->
            {{0, idx}, idx}

          %Length{value: v} ->
            {{v, idx}, fill_idx}
        end
      end)

    fixed_total = sizes |> Enum.map(&elem(&1, 0)) |> Enum.sum()
    fill_size = max(0, available - fixed_total)

    # Apply min/max bounds to fill
    fill_constraint = Enum.at(constraints, fill_idx)
    bounded_fill = apply_bounds(fill_constraint, fill_size)

    sizes
    |> Enum.map(fn {size, idx} ->
      if idx == fill_idx, do: bounded_fill, else: size
    end)
  end

  # General solving algorithm

  defp solve_general(constraints, available) do
    indexed = Enum.with_index(constraints)

    # Pass 1: Allocate fixed sizes
    {fixed_sizes, remaining1} = allocate_fixed(indexed, available)

    # Pass 2: Allocate percentages (from original available)
    {percent_sizes, remaining2} = allocate_percentages(indexed, available, remaining1)

    # Pass 3: Allocate ratios and fills
    {flex_sizes, _remaining3} = allocate_flexible(indexed, remaining2)

    # Merge results in original order
    merge_sizes(indexed, fixed_sizes, percent_sizes, flex_sizes)
    |> apply_all_bounds(constraints, available)
    |> handle_overflow(available)
  end

  defp allocate_fixed(indexed, available) do
    fixed =
      indexed
      |> Enum.filter(fn {c, _idx} -> is_length?(c) end)
      |> Enum.map(fn {c, idx} -> {idx, resolve_length(c)} end)
      |> Map.new()

    used = fixed |> Map.values() |> Enum.sum()
    {fixed, max(0, available - used)}
  end

  defp allocate_percentages(indexed, total_available, remaining) do
    percentages =
      indexed
      |> Enum.filter(fn {c, _idx} -> is_percentage?(c) end)
      |> Enum.map(fn {c, idx} ->
        inner = Constraint.unwrap(c)
        size = round(total_available * inner.value / 100)
        {idx, size}
      end)
      |> Map.new()

    used = percentages |> Map.values() |> Enum.sum()
    {percentages, max(0, remaining - used)}
  end

  defp allocate_flexible(indexed, remaining) do
    flex_constraints =
      indexed
      |> Enum.filter(fn {c, _idx} -> is_flexible?(c) end)

    if flex_constraints == [] do
      {%{}, remaining}
    else
      total_ratio =
        flex_constraints
        |> Enum.map(fn {c, _idx} -> get_ratio_value(c) end)
        |> Enum.sum()

      flex_sizes =
        flex_constraints
        |> Enum.map(fn {c, idx} ->
          ratio = get_ratio_value(c)
          size = if total_ratio > 0, do: round(remaining * ratio / total_ratio), else: 0
          {idx, size}
        end)
        |> Map.new()

      used = flex_sizes |> Map.values() |> Enum.sum()
      {flex_sizes, max(0, remaining - used)}
    end
  end

  defp merge_sizes(indexed, fixed, percentages, flexible) do
    indexed
    |> Enum.map(fn {_c, idx} ->
      Map.get(fixed, idx) || Map.get(percentages, idx) || Map.get(flexible, idx) || 0
    end)
  end

  defp apply_all_bounds(sizes, constraints, available) do
    # First pass: apply bounds
    bounded =
      Enum.zip(sizes, constraints)
      |> Enum.map(fn {size, constraint} ->
        apply_bounds(constraint, size)
      end)

    # Check if bounds caused overflow
    total = Enum.sum(bounded)

    if total > available do
      # Reduce non-min-bounded items proportionally
      reduce_to_fit(bounded, constraints, available)
    else
      bounded
    end
  end

  defp reduce_to_fit(sizes, constraints, available) do
    total = Enum.sum(sizes)
    excess = total - available

    # Find reducible items (not at their min)
    reducible =
      Enum.zip(sizes, constraints)
      |> Enum.with_index()
      |> Enum.filter(fn {{size, constraint}, _idx} ->
        min_val = Constraint.get_min(constraint) || 0
        size > min_val
      end)

    if reducible == [] do
      # Nothing can be reduced, return as is with warning
      Logger.warning("Cannot satisfy min constraints: total #{total} exceeds available #{available}")
      sizes
    else
      # Calculate how much each can be reduced
      reducible_total =
        reducible
        |> Enum.map(fn {{size, constraint}, _idx} ->
          min_val = Constraint.get_min(constraint) || 0
          size - min_val
        end)
        |> Enum.sum()

      if reducible_total <= 0 do
        Logger.warning("Cannot reduce: all at minimum")
        sizes
      else
        # Reduce proportionally
        sizes
        |> Enum.with_index()
        |> Enum.map(fn {size, idx} ->
          constraint = Enum.at(constraints, idx)
          min_val = Constraint.get_min(constraint) || 0
          reducible_amount = size - min_val

          if reducible_amount > 0 do
            reduction = round(excess * reducible_amount / reducible_total)
            max(min_val, size - reduction)
          else
            size
          end
        end)
      end
    end
  end

  defp handle_overflow(sizes, available) do
    total = Enum.sum(sizes)

    if total > available do
      Logger.warning("Constraint overflow: total #{total} exceeds available #{available}")
      scale_proportionally(sizes, available)
    else
      sizes
    end
  end

  defp scale_proportionally(sizes, available) do
    total = Enum.sum(sizes)

    if total == 0 do
      sizes
    else
      Enum.map(sizes, fn size ->
        round(size * available / total)
      end)
    end
  end

  # Helper functions

  defp is_length?(constraint) do
    case Constraint.unwrap(constraint) do
      %Length{} -> true
      _ -> false
    end
  end

  defp is_percentage?(constraint) do
    case Constraint.unwrap(constraint) do
      %Percentage{} -> true
      _ -> false
    end
  end

  defp is_flexible?(constraint) do
    case Constraint.unwrap(constraint) do
      %Ratio{} -> true
      %Fill{} -> true
      _ -> false
    end
  end

  defp resolve_length(constraint) do
    case Constraint.unwrap(constraint) do
      %Length{value: v} -> v
      _ -> 0
    end
  end

  defp get_ratio_value(constraint) do
    case Constraint.unwrap(constraint) do
      %Ratio{value: v} -> v
      %Fill{} -> 1
      _ -> 0
    end
  end

  defp apply_bounds(constraint, size) do
    min_val = Constraint.get_min(constraint)
    max_val = Constraint.get_max(constraint)

    size
    |> then(fn s -> if min_val, do: max(min_val, s), else: s end)
    |> then(fn s -> if max_val, do: min(max_val, s), else: s end)
  end

  # Position calculation

  defp sizes_to_rects(sizes, area, direction, gap, cross_size) do
    {start_main, start_cross} =
      case direction do
        :horizontal -> {area.x, area.y}
        :vertical -> {area.y, area.x}
      end

    {rects, _pos} =
      sizes
      |> Enum.map_reduce(start_main, fn size, pos ->
        rect =
          case direction do
            :horizontal ->
              %{x: pos, y: start_cross, width: size, height: cross_size}

            :vertical ->
              %{x: start_cross, y: pos, width: cross_size, height: size}
          end

        {rect, pos + size + gap}
      end)

    rects
  end
end
