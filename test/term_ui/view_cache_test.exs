defmodule TermUI.ViewCacheTest do
  use ExUnit.Case, async: true

  alias TermUI.ViewCache

  describe "new/0" do
    test "creates empty cache" do
      cache = ViewCache.new()
      assert cache.state_hash == nil
      assert cache.render_tree == nil
      assert cache.hits == 0
      assert cache.misses == 0
    end
  end

  describe "get/2 and put/3" do
    test "returns :miss for empty cache" do
      cache = ViewCache.new()
      assert :miss = ViewCache.get(cache, %{count: 0})
    end

    test "returns :hit when state matches" do
      state = %{count: 5}
      render_tree = {:text, "Count: 5"}

      cache =
        ViewCache.new()
        |> ViewCache.put(state, render_tree)

      assert {:hit, ^render_tree} = ViewCache.get(cache, state)
    end

    test "returns :miss when state differs" do
      state1 = %{count: 5}
      state2 = %{count: 10}
      render_tree = {:text, "Count: 5"}

      cache =
        ViewCache.new()
        |> ViewCache.put(state1, render_tree)

      assert :miss = ViewCache.get(cache, state2)
    end
  end

  describe "record_hit/1 and record_miss/2" do
    test "increments hit counter" do
      cache = ViewCache.new()
      cache = ViewCache.record_hit(cache)
      cache = ViewCache.record_hit(cache)

      assert cache.hits == 2
    end

    test "increments miss counter and records time" do
      cache = ViewCache.new()
      cache = ViewCache.record_miss(cache, 500)

      assert cache.misses == 1
      assert cache.last_render_time_us == 500
    end
  end

  describe "invalidate/1" do
    test "clears cached state and render tree" do
      state = %{count: 5}
      render_tree = {:text, "Count: 5"}

      cache =
        ViewCache.new()
        |> ViewCache.put(state, render_tree)
        |> ViewCache.invalidate()

      assert :miss = ViewCache.get(cache, state)
    end
  end

  describe "stats/1" do
    test "returns hit rate statistics" do
      cache = ViewCache.new()

      cache =
        cache
        |> ViewCache.record_hit()
        |> ViewCache.record_hit()
        |> ViewCache.record_hit()
        |> ViewCache.record_miss(100)

      stats = ViewCache.stats(cache)

      assert stats.hits == 3
      assert stats.misses == 1
      assert_in_delta stats.hit_rate, 75.0, 0.1
    end

    test "handles zero total" do
      cache = ViewCache.new()
      stats = ViewCache.stats(cache)

      assert stats.hit_rate == 0.0
    end
  end

  describe "check_performance/1" do
    test "returns :ok for fast renders" do
      cache = %{ViewCache.new() | last_render_time_us: 500}
      assert :ok = ViewCache.check_performance(cache)
    end

    test "returns warning for slow renders" do
      cache = %{ViewCache.new() | last_render_time_us: 2000}
      assert {:slow_view, 2000} = ViewCache.check_performance(cache)
    end
  end

  describe "memoize/3" do
    test "calls view function on miss" do
      cache = ViewCache.new()
      state = %{count: 5}

      view_fn = fn s -> {:text, "Count: #{s.count}"} end

      {render_tree, new_cache} = ViewCache.memoize(cache, state, view_fn)

      assert render_tree == {:text, "Count: 5"}
      assert new_cache.misses == 1
    end

    test "uses cache on hit" do
      state = %{count: 5}
      render_tree = {:text, "Count: 5"}

      cache =
        ViewCache.new()
        |> ViewCache.put(state, render_tree)

      call_count = :counters.new(1, [])

      view_fn = fn s ->
        :counters.add(call_count, 1, 1)
        {:text, "Count: #{s.count}"}
      end

      {result, new_cache} = ViewCache.memoize(cache, state, view_fn)

      assert result == render_tree
      assert new_cache.hits == 1
      assert :counters.get(call_count, 1) == 0
    end

    test "recalculates when state changes" do
      state1 = %{count: 5}
      state2 = %{count: 10}

      cache = ViewCache.new()

      view_fn = fn s -> {:text, "Count: #{s.count}"} end

      {_, cache} = ViewCache.memoize(cache, state1, view_fn)
      {render_tree, cache} = ViewCache.memoize(cache, state2, view_fn)

      assert render_tree == {:text, "Count: 10"}
      assert cache.misses == 2
    end
  end

  describe "view memoization scenario" do
    test "skips render for unchanged state" do
      state = %{count: 0}
      cache = ViewCache.new()

      view_fn = fn s -> {:text, "Count: #{s.count}"} end

      # First render - miss
      {_, cache} = ViewCache.memoize(cache, state, view_fn)

      # Same state - hit
      {_, cache} = ViewCache.memoize(cache, state, view_fn)
      {_, cache} = ViewCache.memoize(cache, state, view_fn)

      stats = ViewCache.stats(cache)
      assert stats.hits == 2
      assert stats.misses == 1
    end
  end
end
