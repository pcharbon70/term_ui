defmodule TermUI.Layout.CacheTest do
  use ExUnit.Case

  alias TermUI.Layout.{Cache, Constraint}

  setup do
    # Start cache for each test with small size for testing eviction
    {:ok, pid} = Cache.start_link(max_size: 10, eviction_count: 3, name: :test_cache)
    on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)
    :ok
  end

  describe "solve/3 - basic caching" do
    test "returns correct result" do
      constraints = [Constraint.length(20), Constraint.fill()]
      area = %{x: 0, y: 0, width: 100, height: 10}

      result = Cache.solve(constraints, area)

      assert [
               %{x: 0, y: 0, width: 20, height: 10},
               %{x: 20, y: 0, width: 80, height: 10}
             ] = result
    end

    test "caches and returns same result" do
      constraints = [Constraint.length(30), Constraint.fill()]
      area = %{x: 0, y: 0, width: 100, height: 10}

      result1 = Cache.solve(constraints, area)
      result2 = Cache.solve(constraints, area)

      assert result1 == result2
    end

    test "records hit on second call" do
      constraints = [Constraint.length(20), Constraint.fill()]
      area = %{x: 0, y: 0, width: 100, height: 10}

      Cache.reset_stats()

      Cache.solve(constraints, area)
      stats1 = Cache.stats()
      assert stats1.misses == 1
      assert stats1.hits == 0

      Cache.solve(constraints, area)
      stats2 = Cache.stats()
      assert stats2.misses == 1
      assert stats2.hits == 1
    end

    test "different dimensions are different cache entries" do
      constraints = [Constraint.fill()]
      area1 = %{x: 0, y: 0, width: 100, height: 10}
      area2 = %{x: 0, y: 0, width: 200, height: 10}

      Cache.reset_stats()

      Cache.solve(constraints, area1)
      Cache.solve(constraints, area2)

      stats = Cache.stats()
      assert stats.misses == 2
      assert stats.hits == 0
      assert stats.size == 2
    end

    test "different constraints are different cache entries" do
      area = %{x: 0, y: 0, width: 100, height: 10}
      constraints1 = [Constraint.length(20), Constraint.fill()]
      constraints2 = [Constraint.length(30), Constraint.fill()]

      Cache.reset_stats()

      Cache.solve(constraints1, area)
      Cache.solve(constraints2, area)

      stats = Cache.stats()
      assert stats.misses == 2
      assert stats.size == 2
    end
  end

  describe "solve_uncached/3" do
    test "returns result without caching" do
      constraints = [Constraint.length(20), Constraint.fill()]
      area = %{x: 0, y: 0, width: 100, height: 10}

      Cache.reset_stats()

      result = Cache.solve_uncached(constraints, area)

      assert [
               %{x: 0, y: 0, width: 20, height: 10},
               %{x: 20, y: 0, width: 80, height: 10}
             ] = result

      stats = Cache.stats()
      assert stats.size == 0
      assert stats.hits == 0
      assert stats.misses == 0
    end
  end

  describe "lookup/1 and insert/2" do
    test "lookup returns miss for unknown key" do
      key = {:erlang.phash2([]), 100, 10}
      assert :miss = Cache.lookup(key)
    end

    test "insert and lookup returns result" do
      key = {:erlang.phash2([Constraint.fill()]), 100, 10}
      result = [%{x: 0, y: 0, width: 100, height: 10}]

      Cache.insert(key, result)
      assert {:ok, ^result} = Cache.lookup(key)
    end

    test "lookup updates access time" do
      constraints = [Constraint.fill()]
      area = %{x: 0, y: 0, width: 100, height: 10}

      # First solve
      Cache.solve(constraints, area)

      # Wait a bit
      Process.sleep(10)

      # Second lookup should update access time
      Cache.solve(constraints, area)

      # Entry should still be there and be "recent"
      key = {:erlang.phash2(constraints), 100, 10}
      {:ok, _result} = Cache.lookup(key)
    end
  end

  describe "invalidate/1" do
    test "removes specific entry" do
      constraints = [Constraint.fill()]
      area = %{x: 0, y: 0, width: 100, height: 10}

      Cache.solve(constraints, area)
      assert Cache.size() == 1

      key = {:erlang.phash2(constraints), 100, 10}
      Cache.invalidate(key)

      assert Cache.size() == 0
    end
  end

  describe "invalidate_constraints/1" do
    test "removes all entries for constraint set" do
      constraints = [Constraint.fill()]
      area1 = %{x: 0, y: 0, width: 100, height: 10}
      area2 = %{x: 0, y: 0, width: 200, height: 20}

      Cache.solve(constraints, area1)
      Cache.solve(constraints, area2)
      assert Cache.size() == 2

      Cache.invalidate_constraints(constraints)
      assert Cache.size() == 0
    end

    test "does not remove entries for other constraints" do
      constraints1 = [Constraint.fill()]
      constraints2 = [Constraint.length(50)]
      area = %{x: 0, y: 0, width: 100, height: 10}

      Cache.solve(constraints1, area)
      Cache.solve(constraints2, area)
      assert Cache.size() == 2

      Cache.invalidate_constraints(constraints1)
      assert Cache.size() == 1
    end
  end

  describe "clear/0" do
    test "removes all entries" do
      area = %{x: 0, y: 0, width: 100, height: 10}

      for i <- 1..5 do
        Cache.solve([Constraint.length(i), Constraint.fill()], area)
      end

      assert Cache.size() == 5

      Cache.clear()
      assert Cache.size() == 0
    end
  end

  describe "stats/0" do
    test "returns accurate statistics" do
      Cache.reset_stats()

      constraints = [Constraint.fill()]
      area = %{x: 0, y: 0, width: 100, height: 10}

      # 1 miss
      Cache.solve(constraints, area)
      # 3 hits
      Cache.solve(constraints, area)
      Cache.solve(constraints, area)
      Cache.solve(constraints, area)

      stats = Cache.stats()
      assert stats.size == 1
      assert stats.hits == 3
      assert stats.misses == 1
      assert stats.hit_rate == 0.75
    end

    test "hit_rate is 0.0 when no requests" do
      Cache.reset_stats()
      stats = Cache.stats()
      assert stats.hit_rate == 0.0
    end
  end

  describe "reset_stats/0" do
    test "resets hit and miss counters" do
      constraints = [Constraint.fill()]
      area = %{x: 0, y: 0, width: 100, height: 10}

      Cache.solve(constraints, area)
      Cache.solve(constraints, area)

      stats1 = Cache.stats()
      assert stats1.hits > 0 or stats1.misses > 0

      Cache.reset_stats()

      stats2 = Cache.stats()
      assert stats2.hits == 0
      assert stats2.misses == 0
    end
  end

  describe "LRU eviction" do
    test "evicts oldest entries when over limit" do
      area = %{x: 0, y: 0, width: 100, height: 10}

      # Fill cache beyond max_size (10)
      for i <- 1..15 do
        Cache.solve([Constraint.length(i), Constraint.fill()], area)
        # Small delay to ensure different access times
        Process.sleep(1)
      end

      # Force synchronous eviction multiple times to get below max
      Cache.evict_now(:test_cache)
      Cache.evict_now(:test_cache)

      # Should be at or below max_size after multiple evictions
      assert Cache.size() <= 10
    end

    test "keeps recently accessed entries" do
      area = %{x: 0, y: 0, width: 100, height: 10}

      # Add initial entries
      for i <- 1..8 do
        Cache.solve([Constraint.length(i), Constraint.fill()], area)
        Process.sleep(1)
      end

      # Access first entry to make it recent
      Cache.solve([Constraint.length(1), Constraint.fill()], area)
      Process.sleep(1)

      # Add more entries to trigger eviction
      for i <- 9..15 do
        Cache.solve([Constraint.length(i), Constraint.fill()], area)
        Process.sleep(1)
      end

      # Force synchronous eviction
      Cache.evict_now(:test_cache)

      # First entry should still be there (was accessed recently)
      key = {:erlang.phash2([Constraint.length(1), Constraint.fill()]), 100, 10}
      assert {:ok, _} = Cache.lookup(key)
    end
  end

  describe "warm/1" do
    test "pre-populates cache" do
      Cache.reset_stats()

      layouts = [
        {[Constraint.length(20), Constraint.fill()], %{x: 0, y: 0, width: 100, height: 10}, []},
        {[Constraint.length(30), Constraint.fill()], %{x: 0, y: 0, width: 100, height: 10}, []},
        {[Constraint.fill()], %{x: 0, y: 0, width: 200, height: 20}, []}
      ]

      Cache.warm(layouts)

      # Cache should be populated
      assert Cache.size() == 3

      # Stats should be reset after warming
      stats = Cache.stats()
      assert stats.hits == 0
      assert stats.misses == 0
    end

    test "subsequent calls are hits" do
      layouts = [
        {[Constraint.fill()], %{x: 0, y: 0, width: 100, height: 10}, []}
      ]

      Cache.warm(layouts)

      # Now access should be a hit
      Cache.solve([Constraint.fill()], %{x: 0, y: 0, width: 100, height: 10})

      stats = Cache.stats()
      assert stats.hits == 1
      assert stats.misses == 0
    end
  end

  describe "size/0" do
    test "returns current entry count" do
      assert Cache.size() == 0

      area = %{x: 0, y: 0, width: 100, height: 10}
      Cache.solve([Constraint.fill()], area)

      assert Cache.size() == 1

      Cache.solve([Constraint.length(20)], area)

      assert Cache.size() == 2
    end
  end

  describe "solver options" do
    test "caches with gap option" do
      constraints = [Constraint.length(20), Constraint.length(20)]
      area = %{x: 0, y: 0, width: 100, height: 10}

      result = Cache.solve(constraints, area, gap: 10)

      assert [
               %{x: 0, y: 0, width: 20, height: 10},
               %{x: 30, y: 0, width: 20, height: 10}
             ] = result
    end

    test "caches vertical layouts" do
      constraints = [Constraint.length(5), Constraint.fill()]
      area = %{x: 0, y: 0, width: 50, height: 20}

      result = Cache.solve(constraints, area, direction: :vertical)

      assert [
               %{x: 0, y: 0, width: 50, height: 5},
               %{x: 0, y: 5, width: 50, height: 15}
             ] = result
    end
  end
end
