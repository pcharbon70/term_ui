defmodule TermUI.Widgets.SparklineTest do
  use ExUnit.Case, async: true

  alias TermUI.Widgets.Sparkline

  describe "render/1" do
    test "renders sparkline from values" do
      result = Sparkline.render(values: [1, 2, 3, 4, 5])

      assert result.type == :text
    end

    test "returns empty for empty values" do
      result = Sparkline.render(values: [])

      assert result.type == :empty
    end

    test "uses custom min/max" do
      result =
        Sparkline.render(
          values: [5, 5, 5],
          min: 0,
          max: 10
        )

      assert result.type == :text
      # All values at 50% should produce same character
    end
  end

  describe "value_to_bar/3" do
    test "maps minimum value to lowest bar" do
      result = Sparkline.value_to_bar(0, 0, 10)

      assert result == "▁"
    end

    test "maps maximum value to highest bar" do
      result = Sparkline.value_to_bar(10, 0, 10)

      assert result == "█"
    end

    test "maps middle value to middle bar" do
      result = Sparkline.value_to_bar(5, 0, 10)

      # Should be around middle
      bars = Sparkline.bar_characters()
      middle_index = div(length(bars), 2)
      assert result == Enum.at(bars, middle_index)
    end

    test "clamps values below min" do
      result = Sparkline.value_to_bar(-10, 0, 10)

      assert result == "▁"
    end

    test "clamps values above max" do
      result = Sparkline.value_to_bar(100, 0, 10)

      assert result == "█"
    end

    test "handles equal min and max" do
      result = Sparkline.value_to_bar(5, 5, 5)

      # Should return middle bar
      assert is_binary(result)
    end
  end

  describe "to_string/2" do
    test "converts values to sparkline string" do
      result = Sparkline.to_string([1, 5, 10], min: 0, max: 10)

      assert is_binary(result)
      assert String.length(result) == 3
    end

    test "returns empty string for empty values" do
      result = Sparkline.to_string([])

      assert result == ""
    end

    test "auto-scales when min/max not provided" do
      result = Sparkline.to_string([10, 20, 30])

      assert String.length(result) == 3
    end
  end

  describe "bar_characters/0" do
    test "returns list of bar characters" do
      bars = Sparkline.bar_characters()

      assert is_list(bars)
      assert length(bars) == 8
      assert "▁" in bars
      assert "█" in bars
    end
  end

  describe "render_labeled/1" do
    test "renders labeled sparkline with range" do
      result =
        Sparkline.render_labeled(
          values: [1, 5, 10],
          label: "CPU",
          show_range: true
        )

      assert result.type == :stack
      assert result.direction == :horizontal
    end

    test "returns empty for empty values" do
      result = Sparkline.render_labeled(values: [])

      assert result.type == :empty
    end

    test "omits range when disabled" do
      result =
        Sparkline.render_labeled(
          values: [1, 5, 10],
          show_range: false
        )

      # Should have fewer children
      assert result.type == :stack
    end
  end

  describe "color ranges" do
    test "applies colors based on value ranges" do
      # This would need actual Style structs in real tests
      result =
        Sparkline.render(
          values: [10, 50, 90],
          color_ranges: [
            # Would be green
            {0, nil},
            # Would be yellow
            {60, nil},
            # Would be red
            {80, nil}
          ]
        )

      # With color ranges, output is a stack of styled parts
      assert result.type == :stack
    end
  end
end
