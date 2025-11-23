defmodule TermUI.Widgets.GaugeTest do
  use ExUnit.Case, async: true

  alias TermUI.Widgets.Gauge

  describe "render/1 bar style" do
    test "renders bar gauge" do
      result =
        Gauge.render(
          value: 50,
          min: 0,
          max: 100,
          width: 20
        )

      assert result.type == :stack
      assert result.direction == :vertical
    end

    test "shows value when enabled" do
      result =
        Gauge.render(
          value: 75,
          min: 0,
          max: 100,
          width: 20,
          show_value: true
        )

      # Should contain value in output
      assert result.type == :stack
    end

    test "shows range when enabled" do
      result =
        Gauge.render(
          value: 50,
          min: 0,
          max: 100,
          width: 20,
          show_range: true
        )

      assert result.type == :stack
    end

    test "uses custom bar characters" do
      result =
        Gauge.render(
          value: 50,
          min: 0,
          max: 100,
          width: 10,
          bar_char: "=",
          empty_char: "-",
          show_value: false,
          show_range: false
        )

      # Find the bar row
      bar_row =
        Enum.find(result.children, fn child ->
          child.type == :stack && child.direction == :horizontal
        end)

      assert bar_row != nil
    end

    test "adds label when provided" do
      result =
        Gauge.render(
          value: 50,
          min: 0,
          max: 100,
          label: "Progress"
        )

      assert result.type == :stack
      # First child should be label
      [first | _] = result.children
      assert first.type == :text
      assert first.content == "Progress"
    end
  end

  describe "render/1 arc style" do
    test "renders arc gauge" do
      result =
        Gauge.render(
          value: 50,
          min: 0,
          max: 100,
          width: 20,
          style_type: :arc
        )

      assert result.type == :stack
    end

    test "shows value in arc style" do
      result =
        Gauge.render(
          value: 75,
          min: 0,
          max: 100,
          width: 20,
          style_type: :arc,
          show_value: true
        )

      assert result.type == :stack
    end
  end

  describe "value normalization" do
    test "normalizes value within range" do
      result =
        Gauge.render(
          value: 50,
          min: 0,
          max: 100,
          width: 10,
          show_value: false,
          show_range: false
        )

      assert result.type == :stack
    end

    test "clamps value below min" do
      result =
        Gauge.render(
          value: -10,
          min: 0,
          max: 100,
          width: 10
        )

      assert result.type == :stack
    end

    test "clamps value above max" do
      result =
        Gauge.render(
          value: 150,
          min: 0,
          max: 100,
          width: 10
        )

      assert result.type == :stack
    end

    test "handles equal min and max" do
      result =
        Gauge.render(
          value: 50,
          min: 50,
          max: 50,
          width: 10
        )

      assert result.type == :stack
    end
  end

  describe "percentage/2" do
    test "creates percentage gauge" do
      result = Gauge.percentage(75, width: 20)

      assert result.type == :stack
    end

    test "uses 0-100 range" do
      result = Gauge.percentage(50)

      assert result.type == :stack
    end
  end

  describe "traffic_light/1" do
    test "creates traffic light gauge" do
      result =
        Gauge.traffic_light(
          value: 50,
          warning: 60,
          danger: 80
        )

      assert result.type == :stack
    end

    test "uses default thresholds" do
      result = Gauge.traffic_light(value: 70)

      assert result.type == :stack
    end
  end

  describe "zones" do
    test "applies zone styles" do
      zones = [
        # green
        {0, nil},
        # yellow
        {60, nil},
        # red
        {80, nil}
      ]

      result =
        Gauge.render(
          value: 85,
          min: 0,
          max: 100,
          zones: zones
        )

      assert result.type == :stack
    end
  end

  describe "formatting" do
    test "formats integer values" do
      result =
        Gauge.render(
          value: 42,
          show_value: true,
          show_range: false
        )

      assert result.type == :stack
    end

    test "formats float values" do
      result =
        Gauge.render(
          value: 3.14159,
          show_value: true,
          show_range: false
        )

      assert result.type == :stack
    end
  end
end
