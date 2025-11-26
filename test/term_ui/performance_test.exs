defmodule TermUI.PerformanceTest do
  # async: false because tests use shared ETS tables
  use ExUnit.Case, async: false

  alias TermUI.Layout.Cache
  alias TermUI.Layout.Constraint
  alias TermUI.Layout.Solver
  alias TermUI.Style
  alias TermUI.Theme

  # Performance targets (in microseconds)
  # 1ms
  @layout_solve_target_us 1000
  # 0.1ms
  @cache_lookup_target_us 100
  # 0.5ms
  @style_resolution_target_us 500
  # 5ms
  @frame_target_us 5000

  # Multiplier for slower CI environments
  @ci_multiplier if System.get_env("CI"), do: 3, else: 1

  # Warmup iterations to stabilize JIT
  @warmup_iterations 10

  # Helper to run with warmup
  defp measure_with_warmup(iterations, fun) do
    # Warmup runs to stabilize JIT/BEAM
    for _ <- 1..@warmup_iterations, do: fun.()

    # Timed run
    {time_us, _result} =
      :timer.tc(fn ->
        for _ <- 1..iterations, do: fun.()
      end)

    time_us / iterations
  end

  defp adjusted_target(base_target) do
    base_target * @ci_multiplier
  end

  describe "layout solver performance" do
    test "simple constraints solve quickly" do
      constraints = [
        Constraint.length(20),
        Constraint.fill(),
        Constraint.length(20)
      ]

      avg_us =
        measure_with_warmup(100, fn ->
          Solver.solve(constraints, 100)
        end)

      target = adjusted_target(@layout_solve_target_us)

      assert avg_us < target,
             "Simple solve took #{avg_us}us, target is #{target}us"
    end

    test "percentage constraints solve quickly" do
      constraints = [
        Constraint.percentage(25),
        Constraint.percentage(50),
        Constraint.percentage(25)
      ]

      avg_us =
        measure_with_warmup(100, fn ->
          Solver.solve(constraints, 200)
        end)

      target = adjusted_target(@layout_solve_target_us)

      assert avg_us < target,
             "Percentage solve took #{avg_us}us, target is #{target}us"
    end

    test "ratio constraints solve quickly" do
      constraints = [
        Constraint.ratio(1),
        Constraint.ratio(2),
        Constraint.ratio(3)
      ]

      avg_us =
        measure_with_warmup(100, fn ->
          Solver.solve(constraints, 300)
        end)

      target = adjusted_target(@layout_solve_target_us)

      assert avg_us < target,
             "Ratio solve took #{avg_us}us, target is #{target}us"
    end

    test "mixed constraints solve within target" do
      constraints = [
        Constraint.length(30),
        Constraint.percentage(20) |> Constraint.with_min(15),
        Constraint.ratio(1),
        Constraint.fill()
      ]

      avg_us =
        measure_with_warmup(100, fn ->
          Solver.solve(constraints, 200)
        end)

      target = adjusted_target(@layout_solve_target_us)

      assert avg_us < target,
             "Mixed solve took #{avg_us}us, target is #{target}us"
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

      avg_us =
        measure_with_warmup(100, fn ->
          Solver.solve(constraints, 500)
        end)

      # Allow 2x for larger constraint sets
      target = adjusted_target(@layout_solve_target_us * 2)

      assert avg_us < target,
             "10-constraint solve took #{avg_us}us, target is #{target}us"
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

      # Ensure cleanup after test (safely handle if table doesn't exist)
      on_exit(fn ->
        try do
          Cache.clear()
        rescue
          ArgumentError -> :ok
        end
      end)

      :ok
    end

    test "cache hit is fast" do
      constraints = [Constraint.fill()]
      area = %{x: 0, y: 0, width: 100, height: 20}

      # Prime the cache
      Cache.solve(constraints, area)

      # Measure hits with warmup
      avg_us =
        measure_with_warmup(1000, fn ->
          Cache.solve(constraints, area)
        end)

      target = adjusted_target(@cache_lookup_target_us)

      assert avg_us < target,
             "Cache hit took #{avg_us}us, target is #{target}us"
    end

    test "direct ETS lookup is very fast" do
      constraints = [Constraint.fill()]
      area = %{x: 0, y: 0, width: 100, height: 20}

      # Prime the cache
      Cache.solve(constraints, area)

      # Get the key format from cache_key
      key = {constraints, area.width, area.height}

      # Measure direct lookups with warmup
      avg_us =
        measure_with_warmup(1000, fn ->
          Cache.lookup(key)
        end)

      # Direct lookup should be even faster
      target = adjusted_target(@cache_lookup_target_us / 2)

      assert avg_us < target,
             "Direct lookup took #{avg_us}us, target is #{target}us"
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
      avg_us =
        measure_with_warmup(1000, fn ->
          Style.new()
          |> Style.fg(:blue)
          |> Style.bg(:white)
          |> Style.bold()
        end)

      target = adjusted_target(@style_resolution_target_us)

      assert avg_us < target,
             "Style creation took #{avg_us}us, target is #{target}us"
    end

    test "style merge is fast" do
      base = Style.new() |> Style.fg(:blue) |> Style.bg(:white)
      overlay = Style.new() |> Style.bold() |> Style.underline()

      avg_us =
        measure_with_warmup(1000, fn ->
          Style.merge(base, overlay)
        end)

      target = adjusted_target(@style_resolution_target_us)

      assert avg_us < target,
             "Style merge took #{avg_us}us, target is #{target}us"
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

      avg_us =
        measure_with_warmup(1000, fn ->
          Enum.reduce(styles, Style.new(), fn child, parent ->
            Style.inherit(child, parent)
          end)
        end)

      target = adjusted_target(@style_resolution_target_us)

      assert avg_us < target,
             "5-level inheritance took #{avg_us}us, target is #{target}us"
    end

    test "variant selection is fast" do
      variants =
        Style.build_variants(%{
          normal: Style.new() |> Style.fg(:white),
          focused: Style.new() |> Style.fg(:blue) |> Style.bold(),
          disabled: Style.new() |> Style.fg(:bright_black)
        })

      avg_us =
        measure_with_warmup(1000, fn ->
          Style.get_variant(variants, :focused)
        end)

      target = adjusted_target(@style_resolution_target_us / 5)

      assert avg_us < target,
             "Variant selection took #{avg_us}us, target is #{target}us"
    end
  end

  describe "theme performance" do
    setup do
      name = :"perf_theme_#{:erlang.unique_integer([:positive])}"
      {:ok, _} = Theme.start_link(name: name, theme: :dark)
      %{server: name}
    end

    test "theme access via ETS is fast", %{server: server} do
      avg_us =
        measure_with_warmup(1000, fn ->
          Theme.get_theme(server)
        end)

      target = adjusted_target(@cache_lookup_target_us)

      assert avg_us < target,
             "Theme access took #{avg_us}us, target is #{target}us"
    end

    test "color lookup is fast", %{server: server} do
      avg_us =
        measure_with_warmup(1000, fn ->
          Theme.get_color(:primary, server)
        end)

      target = adjusted_target(@cache_lookup_target_us)

      assert avg_us < target,
             "Color lookup took #{avg_us}us, target is #{target}us"
    end

    test "component style access is fast", %{server: server} do
      avg_us =
        measure_with_warmup(1000, fn ->
          Theme.get_component_style(:button, :focused, server)
        end)

      target = adjusted_target(@cache_lookup_target_us * 2)

      assert avg_us < target,
             "Component style took #{avg_us}us, target is #{target}us"
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

      # Ensure cleanup after test (safely handle if table doesn't exist)
      on_exit(fn ->
        try do
          Cache.clear()
        rescue
          ArgumentError -> :ok
        end
      end)

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

      # Warmup
      for _ <- 1..@warmup_iterations do
        _layout = Cache.solve(constraints, area)
        base_style = Style.new() |> Style.fg(:white) |> Style.bg(:black)

        for _ <- 1..10 do
          component_style = Style.new() |> Style.bold()
          _effective = Style.inherit(component_style, base_style)
          _color = Theme.get_color(:primary, theme)
        end
      end

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

      target = adjusted_target(@frame_target_us)

      assert time_us < target,
             "Frame took #{time_us}us, target is #{target}us"
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

      # Warmup
      for _ <- 1..@warmup_iterations do
        _outer = Cache.solve(outer_constraints, outer_area)
        _inner = Cache.solve(inner_constraints, inner_area)

        styles = [
          Style.new() |> Style.fg(:blue),
          Style.new() |> Style.bg(:white),
          Style.new() |> Style.bold(),
          Style.new() |> Style.underline()
        ]

        Enum.reduce(styles, Style.new(), fn child, parent ->
          Style.inherit(child, parent)
        end)

        for color <- [:background, :foreground, :primary, :secondary] do
          Theme.get_color(color, theme)
        end

        for semantic <- [:success, :warning, :error] do
          Theme.get_semantic(semantic, theme)
        end
      end

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

      target = adjusted_target(@frame_target_us * 2)

      assert time_us < target,
             "Complex frame took #{time_us}us, target is #{target}us"
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

          avg_us =
            measure_with_warmup(100, fn ->
              Solver.solve(constraints, n * 50)
            end)

          {n, avg_us}
        end

      # Check roughly linear scaling
      [{n1, t1}, {n2, t2}, {n3, t3}] = times

      # Ratio of time to constraints should be similar
      ratio1 = t1 / n1
      ratio2 = t2 / n2
      ratio3 = t3 / n3

      # Allow 3x variance for linear scaling (adjusted for CI)
      multiplier = 3 * @ci_multiplier
      assert ratio2 < ratio1 * multiplier, "Scaling not linear: #{n1}->#{n2}"
      assert ratio3 < ratio2 * multiplier, "Scaling not linear: #{n2}->#{n3}"
    end
  end
end
