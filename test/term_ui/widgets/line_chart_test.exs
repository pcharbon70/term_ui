defmodule TermUI.Widgets.LineChartTest do
  use ExUnit.Case, async: true

  alias TermUI.Widgets.LineChart

  describe "render/1" do
    test "renders line chart from data" do
      result =
        LineChart.render(
          data: [1, 3, 5, 2, 8],
          width: 20,
          height: 5
        )

      assert result.type == :stack
      assert result.direction == :vertical
      assert length(result.children) == 5
    end

    test "returns empty for empty data" do
      result = LineChart.render(data: [], width: 20, height: 5)

      assert result.type == :empty
    end

    test "renders multiple series" do
      result =
        LineChart.render(
          series: [
            %{data: [1, 3, 5], color: nil},
            %{data: [2, 4, 3], color: nil}
          ],
          width: 20,
          height: 5
        )

      assert result.type == :stack
    end

    test "uses custom min/max" do
      result =
        LineChart.render(
          data: [5, 5, 5],
          min: 0,
          max: 10,
          width: 20,
          height: 5
        )

      assert result.type == :stack
    end

    test "shows axis when enabled" do
      result =
        LineChart.render(
          data: [1, 2, 3],
          width: 20,
          height: 5,
          show_axis: true
        )

      # Should have extra row for axis
      assert length(result.children) == 6
    end
  end

  describe "Braille functions" do
    test "empty_braille returns blank character" do
      result = LineChart.empty_braille()

      assert result == "⠀"
    end

    test "full_braille returns all-dots character" do
      result = LineChart.full_braille()

      assert result == "⣿"
    end

    test "dots_to_braille converts coordinates to character" do
      # Single dot at top-left
      result = LineChart.dots_to_braille([{0, 0}])
      assert result == "⠁"

      # Single dot at top-right
      result = LineChart.dots_to_braille([{1, 0}])
      assert result == "⠈"

      # Multiple dots
      result = LineChart.dots_to_braille([{0, 0}, {1, 0}])
      assert result == "⠉"
    end

    test "dots_to_braille handles all positions" do
      all_dots = [
        {0, 0},
        {0, 1},
        {0, 2},
        {0, 3},
        {1, 0},
        {1, 1},
        {1, 2},
        {1, 3}
      ]

      result = LineChart.dots_to_braille(all_dots)
      assert result == LineChart.full_braille()
    end
  end

  describe "line drawing" do
    test "renders single point" do
      result =
        LineChart.render(
          data: [5],
          width: 10,
          height: 3
        )

      assert result.type == :stack
    end

    test "renders two points with line" do
      result =
        LineChart.render(
          data: [0, 10],
          min: 0,
          max: 10,
          width: 10,
          height: 5
        )

      assert result.type == :stack
    end

    test "renders ascending line" do
      result =
        LineChart.render(
          data: [1, 2, 3, 4, 5],
          width: 20,
          height: 5
        )

      assert result.type == :stack
    end

    test "renders descending line" do
      result =
        LineChart.render(
          data: [5, 4, 3, 2, 1],
          width: 20,
          height: 5
        )

      assert result.type == :stack
    end
  end

  describe "series handling" do
    test "handles empty series list" do
      result =
        LineChart.render(
          series: [],
          width: 20,
          height: 5
        )

      assert result.type == :empty
    end

    test "handles series with empty data" do
      result =
        LineChart.render(
          series: [%{data: [], color: nil}],
          width: 20,
          height: 5
        )

      assert result.type == :empty
    end
  end
end
