defmodule TermUI.PerformanceTest do
  use ExUnit.Case, async: true

  alias TermUI.Layout.{Constraint, Solver, Cache}
  alias TermUI.Style
  alias TermUI.Theme

  # Performance targets
  @layout_solve_target_us 1000  # 1ms
  @cache_lookup_target_us 100   # 0.1ms
  @style_resolution_target_us 500  # 0.5ms
  @frame_target_us 5000  # 5ms

  describe "layout solver performance" do
    test "simple constraints solve quickly" do
      constraints = [
        Constraint.length(20),
        Constraint.fill(),
        Constraint.length(20)
      ]

      {time_us, _result} =
        :timer.tc(fn ->
          for _ <- 1..100 do
            Solver.solve(constraints, 100)
          end
        end)

      avg_us = time_us / 100
      assert avg_us < @layout_solve_target_us,
             "Simple solve took #{avg_us}us, target is #{@layout_solve_target_us}us"
    end

    test "percentage constraints solve quickly" do
      constraints = [
        Constraint.percentage(25),
        Constraint.percentage(50),
        Constraint.percentage(25)
      ]

      {time_us, _result} =
        :timer.tc(fn ->
          for _ <- 1..100 do
            Solver.solve(constraints, 200)
          end
        end)

      avg_us = time_us / 100
      assert avg_us < @layout_solve_target_us,
             "Percentage solve took #{avg_us}us, target is #{@layout_solve_target_us}us"
    end

    test "ratio constraints solve quickly" do
      constraints = [
        Constraint.ratio(1),
        Constraint.ratio(2),
        Constraint.ratio(3)
      ]

      {time_us, _result} =
        :timer.tc(fn ->
          for _ <- 1..100 do
            Solver.solve(constraints, 300)
          end
        end)

      avg_us = time_us / 100
      assert avg_us < @layout_solve_target_us,
             "Ratio solve took #{avg_us}us, target is #{@layout_solve_target_us}us"
    end

    test "mixed constraints solve within target" do
      constraints = [
        Constraint.length(30),
        Constraint.percentage(20) |> Constraint.with_min(15),
        Constraint.ratio(1),
        Constraint.fill()
      ]

      {time_us, _result} =
        :timer.tc(fn ->
          for _ <- 1..100 do
            Solver.solve(constraints, 200)
          end
        end)

      avg_us = time_us / 100
      assert avg_us < @layout_solve_target_us,
             "Mixed solve took #{avg_us}us, target is #{@layout_solve_target_us}us"
    end

    test "10 constraints solve within 2x target" do
      constraints =
        for i <- 1..10 do
          case rem(i, 3) do
            0 -> Constraint.length(10)
            1 -> Constraint.ratio(1)
            2 -> Constraint.percentage(5)
          end
        end

      {time_us, _result} =
        :timer.tc(fn ->
          for _ <- 1..100 do
            Solver.solve(constraints, 500)
          end
        end)

      avg_us = time_us / 100
      # Allow 2x for larger constraint sets
      assert avg_us < @layout_solve_target_us * 2,
             "10-constraint solve took #{avg_us}us, target is #{@layout_solve_target_us * 2}us"
    end
  end

  describe "cache performance" do
    setup do
      # Cache uses singleton ETS table
      case Cache.start_link([]) do
        {:ok, _} -> :ok
        {:error, {:already_started, _}} -> :ok
      end

      Cache.clear()
      :ok
    end

    test "cache hit is fast" do
      constraints = [Constraint.fill()]
      area = %{x: 0, y: 0, width: 100, height: 20}

      # Prime the cache
      Cache.solve(constraints, area)

      # Measure hits
      {time_us, _result} =
        :timer.tc(fn ->
          for _ <- 1..1000 do
            Cache.solve(constraints, area)
          end
        end)

      avg_us = time_us / 1000
      assert avg_us < @cache_lookup_target_us,
             "Cache hit took #{avg_us}us, target is #{@cache_lookup_target_us}us"
    end

    test "direct ETS lookup is very fast" do
      constraints = [Constraint.fill()]
      area = %{x: 0, y: 0, width: 100, height: 20}

      # Prime the cache
      Cache.solve(constraints, area)

      # Get the key format from cache_key
      key = {constraints, area.width, area.height}

      # Measure direct lookups
      {time_us, _result} =
        :timer.tc(fn ->
          for _ <- 1..1000 do
            Cache.lookup(key)
          end
        end)

      avg_us = time_us / 1000
      # Direct lookup should be even faster
      assert avg_us < @cache_lookup_target_us / 2,
             "Direct lookup took #{avg_us}us, target is #{@cache_lookup_target_us / 2}us"
    end

    test "cache achieves good hit rate" do
      Cache.clear()

      constraints = [
        Constraint.ratio(1),
        Constraint.ratio(2)
      ]

      # Simulate realistic usage: same constraints, different sizes
      areas = [
        %{x: 0, y: 0, width: 80, height: 20},
        %{x: 0, y: 0, width: 100, height: 20},
        %{x: 0, y: 0, width: 120, height: 20},
        %{x: 0, y: 0, width: 100, height: 20},
        %{x: 0, y: 0, width: 80, height: 20},
        %{x: 0, y: 0, width: 100, height: 20},
        %{x: 0, y: 0, width: 120, height: 20},
        %{x: 0, y: 0, width: 100, height: 20}
      ]

      for area <- areas do
        Cache.solve(constraints, area)
      end

      stats = Cache.stats()

      # 3 unique sizes, 8 total calls = 5 hits
      hit_rate = stats.hits / (stats.hits + stats.misses) * 100

      assert hit_rate >= 60,
             "Cache hit rate #{hit_rate}%, expected >= 60%"
    end
  end

  describe "style resolution performance" do
    test "style creation is fast" do
      {time_us, _result} =
        :timer.tc(fn ->
          for _ <- 1..1000 do
            Style.new()
            |> Style.fg(:blue)
            |> Style.bg(:white)
            |> Style.bold()
          end
        end)

      avg_us = time_us / 1000
      assert avg_us < @style_resolution_target_us,
             "Style creation took #{avg_us}us, target is #{@style_resolution_target_us}us"
    end

    test "style merge is fast" do
      base = Style.new() |> Style.fg(:blue) |> Style.bg(:white)
      overlay = Style.new() |> Style.bold() |> Style.underline()

      {time_us, _result} =
        :timer.tc(fn ->
          for _ <- 1..1000 do
            Style.merge(base, overlay)
          end
        end)

      avg_us = time_us / 1000
      assert avg_us < @style_resolution_target_us,
             "Style merge took #{avg_us}us, target is #{@style_resolution_target_us}us"
    end

    test "style inheritance chain is fast" do
      # Create inheritance chain
      styles = [
        Style.new() |> Style.fg(:blue),
        Style.new() |> Style.bg(:white),
        Style.new() |> Style.bold(),
        Style.new() |> Style.fg(:red),
        Style.new() |> Style.underline()
      ]

      {time_us, _result} =
        :timer.tc(fn ->
          for _ <- 1..1000 do
            Enum.reduce(styles, Style.new(), fn child, parent ->
              Style.inherit(child, parent)
            end)
          end
        end)

      avg_us = time_us / 1000
      assert avg_us < @style_resolution_target_us,
             "5-level inheritance took #{avg_us}us, target is #{@style_resolution_target_us}us"
    end

    test "variant selection is fast" do
      variants = Style.build_variants(%{
        normal: Style.new() |> Style.fg(:white),
        focused: Style.new() |> Style.fg(:blue) |> Style.bold(),
        disabled: Style.new() |> Style.fg(:bright_black)
      })

      {time_us, _result} =
        :timer.tc(fn ->
          for _ <- 1..1000 do
            Style.get_variant(variants, :focused)
          end
        end)

      avg_us = time_us / 1000
      assert avg_us < @style_resolution_target_us / 5,
             "Variant selection took #{avg_us}us, target is #{@style_resolution_target_us / 5}us"
    end
  end

  describe "theme performance" do
    setup do
      name = :"perf_theme_#{:erlang.unique_integer([:positive])}"
      {:ok, _} = Theme.start_link(name: name, theme: :dark)
      %{server: name}
    end

    test "theme access via ETS is fast", %{server: server} do
      {time_us, _result} =
        :timer.tc(fn ->
          for _ <- 1..1000 do
            Theme.get_theme(server)
          end
        end)

      avg_us = time_us / 1000
      assert avg_us < @cache_lookup_target_us,
             "Theme access took #{avg_us}us, target is #{@cache_lookup_target_us}us"
    end

    test "color lookup is fast", %{server: server} do
      {time_us, _result} =
        :timer.tc(fn ->
          for _ <- 1..1000 do
            Theme.get_color(:primary, server)
          end
        end)

      avg_us = time_us / 1000
      assert avg_us < @cache_lookup_target_us,
             "Color lookup took #{avg_us}us, target is #{@cache_lookup_target_us}us"
    end

    test "component style access is fast", %{server: server} do
      {time_us, _result} =
        :timer.tc(fn ->
          for _ <- 1..1000 do
            Theme.get_component_style(:button, :focused, server)
          end
        end)

      avg_us = time_us / 1000
      assert avg_us < @cache_lookup_target_us * 2,
             "Component style took #{avg_us}us, target is #{@cache_lookup_target_us * 2}us"
    end
  end

  describe "full frame simulation" do
    setup do
      # Cache uses singleton
      case Cache.start_link([]) do
        {:ok, _} -> :ok
        {:error, {:already_started, _}} -> :ok
      end

      Cache.clear()

      theme_name = :"frame_theme_#{:erlang.unique_integer([:positive])}"
      {:ok, _} = Theme.start_link(name: theme_name, theme: :dark)
      %{theme: theme_name}
    end

    test "typical frame completes within target", %{theme: theme} do
      # Simulate a typical frame:
      # 1. Solve layout (3 panels)
      # 2. Resolve styles for 10 components
      # 3. Get theme colors

      constraints = [
        Constraint.ratio(1),
        Constraint.ratio(3),
        Constraint.length(30)
      ]
      area = %{x: 0, y: 0, width: 150, height: 40}

      {time_us, _result} =
        :timer.tc(fn ->
          # Layout solve
          _layout = Cache.solve(constraints, area)

          # Style resolution for components
          base_style = Style.new() |> Style.fg(:white) |> Style.bg(:black)

          for _ <- 1..10 do
            component_style = Style.new() |> Style.bold()
            _effective = Style.inherit(component_style, base_style)
            _color = Theme.get_color(:primary, theme)
          end
        end)

      assert time_us < @frame_target_us,
             "Frame took #{time_us}us, target is #{@frame_target_us}us"
    end

    test "complex frame still completes within 2x target", %{theme: theme} do
      # More complex frame:
      # - Nested layouts
      # - Deep style inheritance
      # - Multiple theme lookups

      outer_constraints = [Constraint.ratio(1), Constraint.ratio(2)]
      inner_constraints = [Constraint.length(5), Constraint.fill(), Constraint.length(3)]
      outer_area = %{x: 0, y: 0, width: 120, height: 30}
      inner_area = %{x: 0, y: 0, width: 80, height: 30}

      {time_us, _result} =
        :timer.tc(fn ->
          # Nested layout
          _outer = Cache.solve(outer_constraints, outer_area)
          _inner = Cache.solve(inner_constraints, inner_area)

          # Deep style chain
          styles = [
            Style.new() |> Style.fg(:blue),
            Style.new() |> Style.bg(:white),
            Style.new() |> Style.bold(),
            Style.new() |> Style.underline()
          ]

          _final =
            Enum.reduce(styles, Style.new(), fn child, parent ->
              Style.inherit(child, parent)
            end)

          # Theme lookups
          for color <- [:background, :foreground, :primary, :secondary] do
            Theme.get_color(color, theme)
          end

          for semantic <- [:success, :warning, :error] do
            Theme.get_semantic(semantic, theme)
          end
        end)

      assert time_us < @frame_target_us * 2,
             "Complex frame took #{time_us}us, target is #{@frame_target_us * 2}us"
    end
  end

  describe "scalability" do
    test "solver scales linearly with constraints" do
      times =
        for n <- [5, 10, 20] do
          constraints =
            for _ <- 1..n do
              Constraint.ratio(1)
            end

          {time_us, _} =
            :timer.tc(fn ->
              for _ <- 1..100 do
                Solver.solve(constraints, n * 50)
              end
            end)

          {n, time_us / 100}
        end

      # Check roughly linear scaling
      [{n1, t1}, {n2, t2}, {n3, t3}] = times

      # Ratio of time to constraints should be similar
      ratio1 = t1 / n1
      ratio2 = t2 / n2
      ratio3 = t3 / n3

      # Allow 3x variance for linear scaling
      assert ratio2 < ratio1 * 3, "Scaling not linear: #{n1}->#{n2}"
      assert ratio3 < ratio2 * 3, "Scaling not linear: #{n2}->#{n3}"
    end
  end
end
