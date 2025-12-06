defmodule TermUI.Color.ConverterTest do
  use ExUnit.Case, async: true

  alias TermUI.Color.Converter

  describe "rgb_to_256/1" do
    test "converts pure red to color cube index" do
      # Pure red (255, 0, 0) maps to cube index 196 (5*36 + 0*6 + 0 + 16)
      assert Converter.rgb_to_256({255, 0, 0}) == 196
    end

    test "converts pure green to color cube index" do
      # Pure green (0, 255, 0) maps to cube index 46 (0*36 + 5*6 + 0 + 16)
      assert Converter.rgb_to_256({0, 255, 0}) == 46
    end

    test "converts pure blue to color cube index" do
      # Pure blue (0, 0, 255) maps to cube index 21 (0*36 + 0*6 + 5 + 16)
      assert Converter.rgb_to_256({0, 0, 255}) == 21
    end

    test "converts grayscale to grayscale ramp" do
      # Mid-gray (128, 128, 128) maps to grayscale range 232-255
      result = Converter.rgb_to_256({128, 128, 128})
      assert result >= 232 and result <= 255
    end

    test "converts black to grayscale index 232" do
      assert Converter.rgb_to_256({0, 0, 0}) == 232
    end

    test "converts white to grayscale index 255" do
      assert Converter.rgb_to_256({255, 255, 255}) == 255
    end

    test "converts near-grayscale to grayscale ramp" do
      # Colors with small variance are treated as grayscale
      result = Converter.rgb_to_256({128, 130, 127})
      assert result >= 232 and result <= 255
    end

    test "converts non-grayscale to color cube" do
      # Colors with larger variance go to color cube
      result = Converter.rgb_to_256({200, 100, 50})
      assert result >= 16 and result <= 231
    end

    test "handles minimum values" do
      assert Converter.rgb_to_256({0, 0, 0}) == 232
    end

    test "handles maximum values" do
      assert Converter.rgb_to_256({255, 255, 255}) == 255
    end

    test "color cube indices are in correct range" do
      # Any non-grayscale color should be in 16-231 range
      result = Converter.rgb_to_256({255, 128, 0})
      assert result >= 16 and result <= 231
    end
  end

  describe "rgb_to_16/2" do
    test "converts bright red to foreground code 91" do
      assert Converter.rgb_to_16({255, 0, 0}, :fg) == 91
    end

    test "converts bright red to background code 101" do
      assert Converter.rgb_to_16({255, 0, 0}, :bg) == 101
    end

    test "converts dark red to foreground code 31" do
      assert Converter.rgb_to_16({128, 0, 0}, :fg) == 31
    end

    test "converts dark red to background code 41" do
      assert Converter.rgb_to_16({128, 0, 0}, :bg) == 41
    end

    test "converts green to appropriate code" do
      # Dark green
      result = Converter.rgb_to_16({0, 128, 0}, :fg)
      assert result in [32, 92]

      # Bright green
      result = Converter.rgb_to_16({0, 255, 0}, :fg)
      assert result == 92
    end

    test "converts blue to appropriate code" do
      result = Converter.rgb_to_16({0, 0, 255}, :fg)
      assert result == 94
    end

    test "converts white to bright white" do
      assert Converter.rgb_to_16({255, 255, 255}, :fg) == 97
    end

    test "converts black to black" do
      assert Converter.rgb_to_16({0, 0, 0}, :fg) == 30
    end

    test "foreground codes are in valid ranges" do
      result = Converter.rgb_to_16({200, 100, 50}, :fg)
      assert result in 30..37 or result in 90..97
    end

    test "background codes are in valid ranges" do
      result = Converter.rgb_to_16({200, 100, 50}, :bg)
      assert result in 40..47 or result in 100..107
    end

    test "background is foreground + 10 for normal colors" do
      fg = Converter.rgb_to_16({0, 0, 0}, :fg)
      bg = Converter.rgb_to_16({0, 0, 0}, :bg)
      assert bg == fg + 10
    end

    test "background is foreground + 10 for bright colors" do
      fg = Converter.rgb_to_16({255, 0, 0}, :fg)
      bg = Converter.rgb_to_16({255, 0, 0}, :bg)
      assert bg == fg + 10
    end
  end

  describe "grayscale?/1" do
    test "pure gray is grayscale" do
      assert Converter.grayscale?({128, 128, 128}) == true
    end

    test "near-gray is grayscale" do
      assert Converter.grayscale?({128, 130, 127}) == true
    end

    test "black is grayscale" do
      assert Converter.grayscale?({0, 0, 0}) == true
    end

    test "white is grayscale" do
      assert Converter.grayscale?({255, 255, 255}) == true
    end

    test "pure red is not grayscale" do
      assert Converter.grayscale?({255, 0, 0}) == false
    end

    test "pure green is not grayscale" do
      assert Converter.grayscale?({0, 255, 0}) == false
    end

    test "pure blue is not grayscale" do
      assert Converter.grayscale?({0, 0, 255}) == false
    end

    test "orange is not grayscale" do
      assert Converter.grayscale?({255, 128, 0}) == false
    end
  end

  describe "luminance_weights/0" do
    test "returns correct weights" do
      {r, g, b} = Converter.luminance_weights()
      assert_in_delta r, 0.299, 0.001
      assert_in_delta g, 0.587, 0.001
      assert_in_delta b, 0.114, 0.001
    end

    test "weights sum to 1.0" do
      {r, g, b} = Converter.luminance_weights()
      assert_in_delta r + g + b, 1.0, 0.001
    end
  end

  describe "perceptual color matching" do
    test "similar reds match to same color" do
      # Slightly different reds should map to same 16-color
      red1 = Converter.rgb_to_16({255, 0, 0}, :fg)
      red2 = Converter.rgb_to_16({250, 10, 5}, :fg)
      assert red1 == red2
    end

    test "yellow maps to yellow" do
      result = Converter.rgb_to_16({255, 255, 0}, :fg)
      assert result == 93  # bright yellow
    end

    test "magenta maps to magenta" do
      result = Converter.rgb_to_16({255, 0, 255}, :fg)
      assert result == 95  # bright magenta
    end

    test "cyan maps to cyan" do
      result = Converter.rgb_to_16({0, 255, 255}, :fg)
      assert result == 96  # bright cyan
    end
  end

  describe "edge cases" do
    test "handles all zeros" do
      assert Converter.rgb_to_256({0, 0, 0}) == 232
      assert Converter.rgb_to_16({0, 0, 0}, :fg) == 30
    end

    test "handles all 255s" do
      assert Converter.rgb_to_256({255, 255, 255}) == 255
      assert Converter.rgb_to_16({255, 255, 255}, :fg) == 97
    end

    test "handles mid-range values" do
      result256 = Converter.rgb_to_256({127, 127, 127})
      assert result256 >= 232 and result256 <= 255

      result16 = Converter.rgb_to_16({127, 127, 127}, :fg)
      assert result16 in [37, 90]  # Could be light gray or dark gray
    end
  end
end
