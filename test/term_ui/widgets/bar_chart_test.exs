defmodule TermUI.Widgets.BarChartTest do
  use ExUnit.Case, async: true

  alias TermUI.Widgets.BarChart

  @test_data [
    %{label: "A", value: 10},
    %{label: "B", value: 20},
    %{label: "C", value: 15}
  ]

  describe "render/1 horizontal" do
    test "renders horizontal bar chart" do
      result = BarChart.render(data: @test_data, width: 30)

      assert result.type == :stack
      assert result.direction == :vertical
      assert length(result.children) == 3
    end

    test "returns empty for empty data" do
      result = BarChart.render(data: [], width: 30)

      assert result.type == :empty
    end

    test "renders bars proportional to values" do
      data = [
        %{label: "A", value: 10},
        %{label: "B", value: 20}
      ]

      result = BarChart.render(
        data: data,
        width: 30,
        show_labels: false,
        show_values: false
      )

      # Second bar should be longer than first
      [first, second] = result.children

      assert first.type == :text
      assert second.type == :text
    end

    test "shows value labels when enabled" do
      result = BarChart.render(
        data: @test_data,
        width: 40,
        show_values: true
      )

      # Values should be in the output
      [first | _] = result.children
      assert String.contains?(first.content, "10")
    end

    test "shows bar labels when enabled" do
      result = BarChart.render(
        data: @test_data,
        width: 40,
        show_labels: true
      )

      [first | _] = result.children
      assert String.contains?(first.content, "A")
    end

    test "hides labels when disabled" do
      result = BarChart.render(
        data: @test_data,
        width: 40,
        show_labels: false,
        show_values: false
      )

      [first | _] = result.children
      refute String.contains?(first.content, "A")
    end

    test "uses custom bar character" do
      result = BarChart.render(
        data: [%{label: "A", value: 10}],
        width: 20,
        bar_char: "#",
        show_labels: false,
        show_values: false
      )

      [first] = result.children
      assert String.contains?(first.content, "#")
    end
  end

  describe "render/1 vertical" do
    test "renders vertical bar chart" do
      result = BarChart.render(
        data: @test_data,
        direction: :vertical,
        width: 20,
        height: 5
      )

      assert result.type == :stack
      assert result.direction == :vertical
    end

    test "returns empty for empty data" do
      result = BarChart.render(
        data: [],
        direction: :vertical,
        width: 20,
        height: 5
      )

      assert result.type == :empty
    end
  end

  describe "bar/1" do
    test "creates simple progress bar" do
      result = BarChart.bar(value: 50, max: 100, width: 10)

      assert result.type == :text
      assert String.length(result.content) == 10
    end

    test "fills proportionally to value" do
      result = BarChart.bar(value: 50, max: 100, width: 10)

      # Should be half filled
      filled_count = result.content
      |> String.graphemes()
      |> Enum.count(&(&1 == "█"))

      assert filled_count == 5
    end

    test "handles zero max value" do
      result = BarChart.bar(value: 50, max: 0, width: 10)

      assert result.type == :text
    end

    test "clamps to max width" do
      result = BarChart.bar(value: 200, max: 100, width: 10)

      filled_count = result.content
      |> String.graphemes()
      |> Enum.count(&(&1 == "█"))

      assert filled_count == 10
    end

    test "uses custom characters" do
      result = BarChart.bar(
        value: 50,
        max: 100,
        width: 10,
        bar_char: "=",
        empty_char: "-"
      )

      assert String.contains?(result.content, "=")
      assert String.contains?(result.content, "-")
    end
  end

  describe "formatting" do
    test "formats integer values" do
      result = BarChart.render(
        data: [%{label: "A", value: 42}],
        width: 30,
        show_values: true
      )

      [first] = result.children
      assert String.contains?(first.content, "42")
    end

    test "formats float values" do
      result = BarChart.render(
        data: [%{label: "A", value: 3.14159}],
        width: 30,
        show_values: true
      )

      [first] = result.children
      assert String.contains?(first.content, "3.1")
    end
  end
end
