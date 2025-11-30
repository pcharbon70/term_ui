defmodule TermUI.Widgets.VisualizationHelperTest do
  use ExUnit.Case, async: true

  alias TermUI.Widgets.VisualizationHelper, as: VizHelper

  describe "clamp_width/1" do
    test "returns value within bounds" do
      assert VizHelper.clamp_width(50) == 50
    end

    test "clamps large values to max" do
      assert VizHelper.clamp_width(2000) == VizHelper.max_width()
    end

    test "clamps negative values to 1" do
      assert VizHelper.clamp_width(-5) == 1
    end

    test "clamps zero to 1" do
      assert VizHelper.clamp_width(0) == 1
    end

    test "returns default for non-integer" do
      assert VizHelper.clamp_width("string") == 40
    end
  end

  describe "clamp_height/1" do
    test "returns value within bounds" do
      assert VizHelper.clamp_height(20) == 20
    end

    test "clamps large values to max" do
      assert VizHelper.clamp_height(1000) == VizHelper.max_height()
    end

    test "clamps negative values to 1" do
      assert VizHelper.clamp_height(-5) == 1
    end

    test "returns default for non-integer" do
      assert VizHelper.clamp_height(nil) == 10
    end
  end

  describe "normalize/3" do
    test "normalizes value in middle of range" do
      assert VizHelper.normalize(50, 0, 100) == 0.5
    end

    test "normalizes value at min" do
      assert VizHelper.normalize(0, 0, 100) == 0.0
    end

    test "normalizes value at max" do
      assert VizHelper.normalize(100, 0, 100) == 1.0
    end

    test "clamps value below min to 0" do
      assert VizHelper.normalize(-50, 0, 100) == 0.0
    end

    test "clamps value above max to 1" do
      assert VizHelper.normalize(150, 0, 100) == 1.0
    end

    test "returns 0.5 when min equals max" do
      assert VizHelper.normalize(50, 50, 50) == 0.5
    end

    test "handles negative ranges" do
      assert VizHelper.normalize(-25, -50, 0) == 0.5
    end

    test "handles float values" do
      assert_in_delta VizHelper.normalize(2.5, 0.0, 10.0), 0.25, 0.001
    end

    test "returns 0.5 for non-numeric input" do
      assert VizHelper.normalize("bad", 0, 100) == 0.5
    end
  end

  describe "scale/2" do
    test "scales 0.5 to half of target" do
      assert VizHelper.scale(0.5, 100) == 50
    end

    test "scales 0 to 0" do
      assert VizHelper.scale(0.0, 100) == 0
    end

    test "scales 1 to target size" do
      assert VizHelper.scale(1.0, 100) == 100
    end

    test "rounds to nearest integer" do
      assert VizHelper.scale(0.333, 10) == 3
    end
  end

  describe "normalize_and_scale/4" do
    test "combines normalize and scale" do
      assert VizHelper.normalize_and_scale(50, 0, 100, 20) == 10
    end

    test "handles edge cases" do
      assert VizHelper.normalize_and_scale(0, 0, 100, 20) == 0
      assert VizHelper.normalize_and_scale(100, 0, 100, 20) == 20
    end
  end

  describe "format_number/1" do
    test "formats integer" do
      assert VizHelper.format_number(42) == "42"
    end

    test "formats float to 1 decimal" do
      assert VizHelper.format_number(3.14159) == "3.1"
    end

    test "formats negative numbers" do
      assert VizHelper.format_number(-5) == "-5"
      assert VizHelper.format_number(-3.7) == "-3.7"
    end

    test "returns ??? for non-numbers" do
      assert VizHelper.format_number(:atom) == "???"
      assert VizHelper.format_number("string") == "???"
      assert VizHelper.format_number(nil) == "???"
    end
  end

  describe "find_zone/2" do
    test "finds zone for value" do
      zones = [{0, :green}, {60, :yellow}, {80, :red}]

      assert VizHelper.find_zone(50, zones) == :green
      assert VizHelper.find_zone(70, zones) == :yellow
      assert VizHelper.find_zone(90, zones) == :red
    end

    test "returns highest matching zone" do
      zones = [{0, :low}, {50, :mid}, {50, :mid_alt}]
      # Should return one of the 50 thresholds
      result = VizHelper.find_zone(50, zones)
      assert result in [:mid, :mid_alt]
    end

    test "returns nil for empty zones" do
      assert VizHelper.find_zone(50, []) == nil
    end

    test "returns nil for value below all thresholds" do
      zones = [{10, :a}, {20, :b}]
      assert VizHelper.find_zone(5, zones) == nil
    end

    test "handles exact threshold values" do
      zones = [{0, :a}, {50, :b}, {100, :c}]
      assert VizHelper.find_zone(50, zones) == :b
    end
  end

  describe "calculate_range/2" do
    test "calculates min and max from values" do
      assert VizHelper.calculate_range([1, 5, 3, 9, 2]) == {1, 9}
    end

    test "allows min override" do
      assert VizHelper.calculate_range([1, 5, 3], min: 0) == {0, 5}
    end

    test "allows max override" do
      assert VizHelper.calculate_range([1, 5, 3], max: 10) == {1, 10}
    end

    test "allows both overrides" do
      assert VizHelper.calculate_range([1, 5, 3], min: 0, max: 10) == {0, 10}
    end

    test "returns default for empty list" do
      assert VizHelper.calculate_range([]) == {0, 1}
    end

    test "handles single value" do
      assert VizHelper.calculate_range([5]) == {5, 5}
    end

    test "handles negative values" do
      assert VizHelper.calculate_range([-10, -5, -1]) == {-10, -1}
    end
  end

  describe "maybe_style/2" do
    test "returns node unchanged when style is nil" do
      import TermUI.Component.RenderNode
      node = text("hello")
      assert VizHelper.maybe_style(node, nil) == node
    end

    test "applies style when provided" do
      import TermUI.Component.RenderNode
      alias TermUI.Renderer.Style
      node = text("hello")
      style = Style.new(fg: :red)
      result = VizHelper.maybe_style(node, style)
      assert result.type == :box
      assert result.style == style
      assert result.children == [node]
    end
  end

  describe "cycle_color/2" do
    test "returns color at index" do
      colors = [:red, :blue, :green]
      assert VizHelper.cycle_color(colors, 0) == :red
      assert VizHelper.cycle_color(colors, 1) == :blue
      assert VizHelper.cycle_color(colors, 2) == :green
    end

    test "cycles through colors" do
      colors = [:red, :blue, :green]
      assert VizHelper.cycle_color(colors, 3) == :red
      assert VizHelper.cycle_color(colors, 4) == :blue
    end

    test "returns nil for empty list" do
      assert VizHelper.cycle_color([], 0) == nil
    end
  end

  describe "validate_number/1" do
    test "accepts integers" do
      assert VizHelper.validate_number(42) == :ok
    end

    test "accepts floats" do
      assert VizHelper.validate_number(3.14) == :ok
    end

    test "rejects non-numbers" do
      assert {:error, _} = VizHelper.validate_number("string")
      assert {:error, _} = VizHelper.validate_number(:atom)
      assert {:error, _} = VizHelper.validate_number(nil)
    end
  end

  describe "validate_number_list/1" do
    test "accepts list of numbers" do
      assert VizHelper.validate_number_list([1, 2, 3]) == :ok
      assert VizHelper.validate_number_list([1.0, 2.5, 3.7]) == :ok
      assert VizHelper.validate_number_list([1, 2.5, 3]) == :ok
    end

    test "accepts empty list" do
      assert VizHelper.validate_number_list([]) == :ok
    end

    test "rejects list with non-numbers" do
      assert {:error, msg} = VizHelper.validate_number_list([1, "two", 3])
      assert msg =~ "index 1"
    end

    test "rejects non-list" do
      assert {:error, _} = VizHelper.validate_number_list("not a list")
    end
  end

  describe "validate_bar_data/1" do
    test "accepts valid bar data" do
      data = [%{label: "A", value: 10}, %{label: "B", value: 20}]
      assert VizHelper.validate_bar_data(data) == :ok
    end

    test "accepts empty list" do
      assert VizHelper.validate_bar_data([]) == :ok
    end

    test "rejects missing label" do
      assert {:error, msg} = VizHelper.validate_bar_data([%{value: 10}])
      assert msg =~ "missing :label"
    end

    test "rejects missing value" do
      assert {:error, msg} = VizHelper.validate_bar_data([%{label: "A"}])
      assert msg =~ "missing :value"
    end

    test "rejects non-string label" do
      assert {:error, msg} = VizHelper.validate_bar_data([%{label: 123, value: 10}])
      assert msg =~ ":label must be a string"
    end

    test "rejects non-number value" do
      assert {:error, msg} = VizHelper.validate_bar_data([%{label: "A", value: "ten"}])
      assert msg =~ ":value must be a number"
    end

    test "rejects non-map items" do
      assert {:error, msg} = VizHelper.validate_bar_data(["not a map"])
      assert msg =~ "must be a map"
    end

    test "rejects non-list" do
      assert {:error, _} = VizHelper.validate_bar_data("not a list")
    end
  end

  describe "validate_series_data/1" do
    test "accepts valid series data" do
      series = [%{data: [1, 2, 3]}, %{data: [4, 5, 6], color: :red}]
      assert VizHelper.validate_series_data(series) == :ok
    end

    test "accepts empty list" do
      assert VizHelper.validate_series_data([]) == :ok
    end

    test "rejects missing data key" do
      assert {:error, msg} = VizHelper.validate_series_data([%{color: :red}])
      assert msg =~ "missing :data"
    end

    test "rejects non-list data" do
      assert {:error, msg} = VizHelper.validate_series_data([%{data: "not a list"}])
      assert msg =~ "must be a list"
    end

    test "rejects non-number in data" do
      assert {:error, msg} = VizHelper.validate_series_data([%{data: [1, "two", 3]}])
      assert msg =~ "contain only numbers"
    end

    test "rejects non-map series" do
      assert {:error, msg} = VizHelper.validate_series_data(["not a map"])
      assert msg =~ "must be a map"
    end
  end

  describe "validate_char/1" do
    test "accepts single character" do
      assert VizHelper.validate_char("█") == :ok
      assert VizHelper.validate_char("A") == :ok
      assert VizHelper.validate_char(" ") == :ok
    end

    test "rejects empty string" do
      assert {:error, msg} = VizHelper.validate_char("")
      assert msg =~ "empty string"
    end

    test "rejects multiple characters" do
      assert {:error, msg} = VizHelper.validate_char("ab")
      assert msg =~ "2 characters"
    end

    test "rejects non-string" do
      assert {:error, _} = VizHelper.validate_char(123)
    end
  end

  describe "safe_duplicate/2" do
    test "duplicates string normally" do
      assert VizHelper.safe_duplicate("█", 5) == "█████"
    end

    test "returns empty for negative count" do
      assert VizHelper.safe_duplicate("█", -5) == ""
    end

    test "returns empty for zero count" do
      assert VizHelper.safe_duplicate("█", 0) == ""
    end

    test "clamps to max width" do
      result = VizHelper.safe_duplicate("█", 10_000)
      assert String.length(result) == VizHelper.max_width()
    end

    test "handles multi-byte characters" do
      assert VizHelper.safe_duplicate("░", 3) == "░░░"
    end
  end
end
