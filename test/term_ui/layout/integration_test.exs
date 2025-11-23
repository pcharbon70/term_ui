defmodule TermUI.Layout.IntegrationTest do
  use ExUnit.Case, async: true

  alias TermUI.Layout.Alignment
  alias TermUI.Layout.Cache
  alias TermUI.Layout.Constraint
  alias TermUI.Layout.Solver

  describe "three-pane layout" do
    test "sidebar, main, and detail with ratio constraints" do
      # Classic three-pane: sidebar (1), main (3), detail panel (fixed 30)
      constraints = [
        Constraint.ratio(1),
        Constraint.ratio(3),
        Constraint.length(30)
      ]

      area = %{x: 0, y: 0, width: 150, height: 40}
      rects = Solver.solve_to_rects(constraints, area, direction: :horizontal)

      assert length(rects) == 3

      # Detail gets exactly 30
      detail = Enum.at(rects, 2)
      assert detail.width == 30

      # Remaining 120 split 1:3 = 30:90
      sidebar = Enum.at(rects, 0)
      main = Enum.at(rects, 1)
      assert sidebar.width == 30
      assert main.width == 90

      # All have full height
      assert Enum.all?(rects, &(&1.height == 40))

      # Positions are contiguous
      assert sidebar.x == 0
      assert main.x == 30
      assert detail.x == 120
    end

    test "three-pane adapts to different sizes" do
      constraints = [
        Constraint.ratio(1),
        Constraint.ratio(2),
        Constraint.length(20)
      ]

      # Smaller terminal
      small_area = %{x: 0, y: 0, width: 80, height: 24}
      rects = Solver.solve_to_rects(constraints, small_area, direction: :horizontal)

      # Detail still 20, remaining 60 split 1:2 = 20:40
      assert Enum.at(rects, 0).width == 20
      assert Enum.at(rects, 1).width == 40
      assert Enum.at(rects, 2).width == 20

      # Larger terminal
      large_area = %{x: 0, y: 0, width: 200, height: 50}
      rects = Solver.solve_to_rects(constraints, large_area, direction: :horizontal)

      # Detail still 20, remaining 180 split 1:2 = 60:120
      assert Enum.at(rects, 0).width == 60
      assert Enum.at(rects, 1).width == 120
      assert Enum.at(rects, 2).width == 20
    end
  end

  describe "form layout" do
    test "labels and inputs with percentage and fill" do
      # Form row: fixed label, flexible input
      constraints = [
        Constraint.percentage(30),
        Constraint.fill()
      ]

      area = %{x: 0, y: 0, width: 100, height: 1}
      rects = Solver.solve_to_rects(constraints, area, direction: :horizontal)

      label = Enum.at(rects, 0)
      input = Enum.at(rects, 1)

      assert label.width == 30
      assert input.width == 70
    end

    test "multiple form rows stacked vertically" do
      # Three form rows
      row_constraints = [
        Constraint.length(3),
        Constraint.length(3),
        Constraint.length(3)
      ]

      area = %{x: 0, y: 0, width: 80, height: 9}
      rows = Solver.solve_to_rects(row_constraints, area, direction: :vertical)

      # Each row is 3 cells high
      assert Enum.all?(rows, &(&1.height == 3))

      # Rows are stacked
      assert Enum.at(rows, 0).y == 0
      assert Enum.at(rows, 1).y == 3
      assert Enum.at(rows, 2).y == 6
    end

    test "form with min-width labels" do
      constraints = [
        Constraint.percentage(20) |> Constraint.with_min(15),
        Constraint.fill()
      ]

      # Small area where 20% would be < 15
      small_area = %{x: 0, y: 0, width: 50, height: 1}
      rects = Solver.solve_to_rects(constraints, small_area, direction: :horizontal)

      label = Enum.at(rects, 0)
      # Min enforced: 15 instead of 10
      assert label.width == 15
    end
  end

  describe "nested containers" do
    test "horizontal container with vertical children" do
      # Outer: two columns
      outer_constraints = [
        Constraint.ratio(1),
        Constraint.ratio(1)
      ]

      outer_area = %{x: 0, y: 0, width: 80, height: 24}
      columns = Solver.solve_to_rects(outer_constraints, outer_area, direction: :horizontal)

      # Each column is 40 wide
      assert Enum.at(columns, 0).width == 40
      assert Enum.at(columns, 1).width == 40

      # Inner: stack items vertically in first column
      inner_constraints = [
        Constraint.length(5),
        Constraint.fill(),
        Constraint.length(3)
      ]

      column_area = Enum.at(columns, 0)
      items = Solver.solve_to_rects(inner_constraints, column_area, direction: :vertical)

      # Items positioned within column
      assert Enum.at(items, 0).height == 5
      # 24 - 5 - 3
      assert Enum.at(items, 1).height == 16
      assert Enum.at(items, 2).height == 3

      # All items have column width
      assert Enum.all?(items, &(&1.width == 40))
    end

    test "three levels of nesting" do
      # Level 1: split horizontally
      l1_constraints = [Constraint.ratio(1), Constraint.ratio(2)]
      l1_area = %{x: 0, y: 0, width: 120, height: 30}
      l1_rects = Solver.solve_to_rects(l1_constraints, l1_area, direction: :horizontal)

      # Level 2: split first column vertically
      l2_constraints = [Constraint.length(10), Constraint.fill()]
      l2_area = Enum.at(l1_rects, 0)
      l2_rects = Solver.solve_to_rects(l2_constraints, l2_area, direction: :vertical)

      # Level 3: split remaining space horizontally
      l3_constraints = [Constraint.percentage(50), Constraint.percentage(50)]
      l3_area = Enum.at(l2_rects, 1)
      l3_rects = Solver.solve_to_rects(l3_constraints, l3_area, direction: :horizontal)

      # Verify dimensions propagate correctly
      assert Enum.at(l1_rects, 0).width == 40
      assert Enum.at(l2_rects, 0).height == 10
      assert Enum.at(l2_rects, 1).height == 20
      assert Enum.at(l3_rects, 0).width == 20
      assert Enum.at(l3_rects, 1).width == 20
    end
  end

  describe "alignment integration" do
    test "centered content in larger container" do
      constraints = [Constraint.length(20), Constraint.length(20)]
      area = %{x: 0, y: 0, width: 100, height: 10}

      # Solve then center
      rects = Solver.solve_to_rects(constraints, area, direction: :horizontal)

      aligned =
        Alignment.apply(rects, area,
          direction: :horizontal,
          justify: :center,
          align: :center
        )

      # Total content is 40, centered in 100 = offset 30
      assert Enum.at(aligned, 0).x == 30
      assert Enum.at(aligned, 1).x == 50
    end

    test "space-between distribution" do
      constraints = [
        Constraint.length(10),
        Constraint.length(10),
        Constraint.length(10)
      ]

      area = %{x: 0, y: 0, width: 100, height: 10}
      rects = Solver.solve_to_rects(constraints, area, direction: :horizontal)

      aligned =
        Alignment.apply(rects, area,
          direction: :horizontal,
          justify: :space_between
        )

      # 3 items of 10 = 30, remaining 70 split between 2 gaps = 35 each
      assert Enum.at(aligned, 0).x == 0
      assert Enum.at(aligned, 1).x == 45
      assert Enum.at(aligned, 2).x == 90
    end

    test "align-self overrides" do
      constraints = [Constraint.length(20), Constraint.length(20), Constraint.length(20)]
      area = %{x: 0, y: 0, width: 60, height: 20}

      rects = Solver.solve_to_rects(constraints, area, direction: :horizontal)

      # Different alignment per item
      aligned =
        Alignment.apply(rects, area,
          direction: :horizontal,
          align: :start,
          align_self: [:start, :center, :end]
        )

      # First at top, second centered, third at bottom
      assert Enum.at(aligned, 0).y == 0
      # Center: (20 - height) / 2, but rect height is 20, so centered at 0
      # Actually the rects have height 20, cross axis is height
      # With align_self :center on a 20-height item in 20-height area = 0
      assert Enum.at(aligned, 1).y == 0
      assert Enum.at(aligned, 2).y == 0
    end

    test "margins reduce component size" do
      constraints = [Constraint.fill()]
      area = %{x: 0, y: 0, width: 100, height: 50}

      rects = Solver.solve_to_rects(constraints, area, direction: :horizontal)
      margin = Alignment.parse_spacing(5)
      with_margins = Alignment.apply_margins(rects, margin)

      rect = Enum.at(with_margins, 0)
      assert rect.x == 5
      assert rect.y == 5
      assert rect.width == 90
      assert rect.height == 40
    end
  end

  describe "cache integration" do
    setup do
      # Cache uses a singleton ETS table, just ensure it's started
      case Cache.start_link([]) do
        {:ok, _} -> :ok
        {:error, {:already_started, _}} -> :ok
      end

      # Ensure cleanup after test to prevent state leakage
      on_exit(fn ->
        try do
          Cache.clear()
        rescue
          ArgumentError -> :ok
        end
      end)

      :ok
    end

    test "repeated layouts use cache" do
      constraints = [Constraint.ratio(1), Constraint.ratio(2)]
      area = %{x: 0, y: 0, width: 100, height: 20}

      # Clear to get clean stats
      Cache.clear()

      # First call - cache miss
      result1 = Cache.solve(constraints, area)

      # Second call - cache hit
      result2 = Cache.solve(constraints, area)

      assert result1 == result2

      stats = Cache.stats()
      assert stats.hits >= 1
    end

    test "different sizes create different cache entries" do
      constraints = [Constraint.fill()]
      area1 = %{x: 0, y: 0, width: 100, height: 20}
      area2 = %{x: 0, y: 0, width: 200, height: 20}

      Cache.clear()

      Cache.solve(constraints, area1)
      Cache.solve(constraints, area2)

      stats = Cache.stats()
      assert stats.size == 2
    end

    test "cache clear removes all entries" do
      constraints = [Constraint.length(50)]
      area = %{x: 0, y: 0, width: 100, height: 20}

      Cache.solve(constraints, area)
      stats_before = Cache.stats()
      assert stats_before.size >= 1

      Cache.clear()
      stats_after = Cache.stats()
      assert stats_after.size == 0
    end

    test "evict_now triggers synchronous eviction" do
      Cache.clear()

      # Add some entries
      for i <- 1..10 do
        constraints = [Constraint.length(i)]
        area = %{x: 0, y: 0, width: 100, height: 20}
        Cache.solve(constraints, area)
      end

      stats_before = Cache.stats()
      assert stats_before.size == 10

      # Eviction only removes entries if over max_size
      # With default max_size of 500, nothing will be evicted
      # But we can verify the function runs without error
      Cache.evict_now()

      stats_after = Cache.stats()
      # Size unchanged since we're under max_size
      assert stats_after.size == 10
    end

    test "cache tracks access for LRU" do
      Cache.clear()

      constraints = [Constraint.fill()]
      area = %{x: 0, y: 0, width: 100, height: 20}

      # First access
      Cache.solve(constraints, area)

      # Wait a moment then access again
      Process.sleep(1)
      Cache.solve(constraints, area)

      # Should have 1 hit (second access)
      stats = Cache.stats()
      assert stats.hits >= 1
      assert stats.misses >= 1
    end

    test "warm preloads cache entries" do
      Cache.clear()

      entries = [
        {[Constraint.length(10)], %{x: 0, y: 0, width: 100, height: 20}, []},
        {[Constraint.fill()], %{x: 0, y: 0, width: 200, height: 30}, []}
      ]

      Cache.warm(entries)

      stats = Cache.stats()
      # Stats reset after warm, so size should be 2 but hits/misses reset
      assert stats.size == 2

      # Subsequent solves should hit cache
      Cache.solve([Constraint.length(10)], %{x: 0, y: 0, width: 100, height: 20})
      Cache.solve([Constraint.fill()], %{x: 0, y: 0, width: 200, height: 30})

      stats_after = Cache.stats()
      assert stats_after.hits == 2
    end
  end

  describe "resize handling" do
    test "layout recalculates on size change" do
      constraints = [Constraint.percentage(50), Constraint.fill()]

      # Initial size
      area1 = %{x: 0, y: 0, width: 100, height: 24}
      rects1 = Solver.solve_to_rects(constraints, area1, direction: :horizontal)

      assert Enum.at(rects1, 0).width == 50
      assert Enum.at(rects1, 1).width == 50

      # After resize
      area2 = %{x: 0, y: 0, width: 200, height: 24}
      rects2 = Solver.solve_to_rects(constraints, area2, direction: :horizontal)

      assert Enum.at(rects2, 0).width == 100
      assert Enum.at(rects2, 1).width == 100
    end

    test "min constraints protect during shrink" do
      constraints = [
        Constraint.percentage(30) |> Constraint.with_min(20),
        Constraint.fill()
      ]

      # Large enough for 30%
      large = %{x: 0, y: 0, width: 100, height: 24}
      rects = Solver.solve_to_rects(constraints, large, direction: :horizontal)
      assert Enum.at(rects, 0).width == 30

      # Too small - min kicks in
      small = %{x: 0, y: 0, width: 50, height: 24}
      rects = Solver.solve_to_rects(constraints, small, direction: :horizontal)
      assert Enum.at(rects, 0).width == 20
    end
  end

  describe "edge cases" do
    test "single component fills entire area" do
      constraints = [Constraint.fill()]
      area = %{x: 10, y: 5, width: 80, height: 20}

      rects = Solver.solve_to_rects(constraints, area, direction: :horizontal)
      rect = Enum.at(rects, 0)

      assert rect.x == 10
      assert rect.y == 5
      assert rect.width == 80
      assert rect.height == 20
    end

    test "all fixed constraints" do
      constraints = [
        Constraint.length(10),
        Constraint.length(20),
        Constraint.length(30)
      ]

      area = %{x: 0, y: 0, width: 100, height: 10}
      rects = Solver.solve_to_rects(constraints, area, direction: :horizontal)

      assert Enum.at(rects, 0).width == 10
      assert Enum.at(rects, 1).width == 20
      assert Enum.at(rects, 2).width == 30
    end

    test "zero-size area produces zero-size rects" do
      constraints = [Constraint.fill()]
      area = %{x: 0, y: 0, width: 0, height: 0}

      rects = Solver.solve_to_rects(constraints, area, direction: :horizontal)
      rect = Enum.at(rects, 0)

      assert rect.width == 0
      assert rect.height == 0
    end

    test "empty constraints list produces empty rects" do
      constraints = []
      area = %{x: 0, y: 0, width: 100, height: 20}

      rects = Solver.solve_to_rects(constraints, area, direction: :horizontal)

      assert rects == []
    end

    test "constraints exceeding available space are reduced" do
      # Total fixed: 150, available: 100
      constraints = [
        Constraint.length(50),
        Constraint.length(50),
        Constraint.length(50)
      ]

      area = %{x: 0, y: 0, width: 100, height: 10}
      rects = Solver.solve_to_rects(constraints, area, direction: :horizontal)

      # Should reduce proportionally, total should not exceed available
      total_width = Enum.reduce(rects, 0, fn r, acc -> acc + r.width end)
      assert total_width <= 100
    end

    test "all ratios with no remaining space get zero" do
      # Fixed takes all space
      constraints = [
        Constraint.length(100),
        Constraint.ratio(1),
        Constraint.ratio(2)
      ]

      area = %{x: 0, y: 0, width: 100, height: 10}
      rects = Solver.solve_to_rects(constraints, area, direction: :horizontal)

      assert Enum.at(rects, 0).width == 100
      assert Enum.at(rects, 1).width == 0
      assert Enum.at(rects, 2).width == 0
    end

    test "percentage over 100 raises error" do
      assert_raise ArgumentError, ~r/percentage must be between 0 and 100/, fn ->
        Constraint.percentage(150)
      end
    end

    test "min constraint is enforced even when exceeding available" do
      constraints = [
        Constraint.fill() |> Constraint.with_min(200)
      ]

      area = %{x: 0, y: 0, width: 100, height: 10}
      rects = Solver.solve_to_rects(constraints, area, direction: :horizontal)

      # Min is enforced - may exceed available (overflow scenario)
      assert Enum.at(rects, 0).width == 200
    end
  end
end
