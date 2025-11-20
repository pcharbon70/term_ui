defmodule TermUI.Capabilities.FallbacksTest do
  use ExUnit.Case, async: true

  alias TermUI.Capabilities.Fallbacks

  describe "rgb_to_256/3" do
    test "converts black correctly" do
      assert Fallbacks.rgb_to_256(0, 0, 0) in 232..255
    end

    test "converts white correctly" do
      assert Fallbacks.rgb_to_256(255, 255, 255) in 232..255
    end

    test "converts pure red to color cube" do
      index = Fallbacks.rgb_to_256(255, 0, 0)
      assert index == 196
    end

    test "converts pure green to color cube" do
      index = Fallbacks.rgb_to_256(0, 255, 0)
      assert index == 46
    end

    test "converts pure blue to color cube" do
      index = Fallbacks.rgb_to_256(0, 0, 255)
      assert index == 21
    end

    test "converts gray values to grayscale ramp" do
      # Middle gray
      index = Fallbacks.rgb_to_256(128, 128, 128)
      assert index in 232..255
    end

    test "returns values in valid range" do
      for r <- [0, 64, 128, 192, 255],
          g <- [0, 64, 128, 192, 255],
          b <- [0, 64, 128, 192, 255] do
        index = Fallbacks.rgb_to_256(r, g, b)
        assert index >= 0 and index <= 255, "RGB(#{r},#{g},#{b}) -> #{index}"
      end
    end
  end

  describe "rgb_to_16/3" do
    test "converts black to color 0" do
      assert Fallbacks.rgb_to_16(0, 0, 0) == 0
    end

    test "converts white to color 15" do
      assert Fallbacks.rgb_to_16(255, 255, 255) == 15
    end

    test "converts pure red to red (1 or 9)" do
      index = Fallbacks.rgb_to_16(255, 0, 0)
      assert index in [1, 9]
    end

    test "converts pure green to green (2 or 10)" do
      index = Fallbacks.rgb_to_16(0, 255, 0)
      assert index in [2, 10]
    end

    test "converts pure blue to blue (4 or 12)" do
      index = Fallbacks.rgb_to_16(0, 0, 255)
      assert index in [4, 12]
    end

    test "converts yellow to yellow (3 or 11)" do
      index = Fallbacks.rgb_to_16(255, 255, 0)
      assert index in [3, 11]
    end

    test "converts magenta to magenta (5 or 13)" do
      index = Fallbacks.rgb_to_16(255, 0, 255)
      assert index in [5, 13]
    end

    test "converts cyan to cyan (6 or 14)" do
      index = Fallbacks.rgb_to_16(0, 255, 255)
      assert index in [6, 14]
    end

    test "returns values in valid range" do
      for r <- [0, 128, 255],
          g <- [0, 128, 255],
          b <- [0, 128, 255] do
        index = Fallbacks.rgb_to_16(r, g, b)
        assert index >= 0 and index <= 15, "RGB(#{r},#{g},#{b}) -> #{index}"
      end
    end
  end

  describe "color_256_to_16/1" do
    test "passes through ANSI colors 0-15" do
      for i <- 0..15 do
        assert Fallbacks.color_256_to_16(i) == i
      end
    end

    test "converts color cube indices" do
      # Red (index 196 in 256 palette = pure red)
      assert Fallbacks.color_256_to_16(196) in [1, 9]

      # Green (index 46 in 256 palette = pure green)
      assert Fallbacks.color_256_to_16(46) in [2, 10]

      # Blue (index 21 in 256 palette = pure blue)
      assert Fallbacks.color_256_to_16(21) in [4, 12]
    end

    test "converts grayscale indices" do
      # Black (232)
      assert Fallbacks.color_256_to_16(232) in [0, 8]

      # White (255)
      assert Fallbacks.color_256_to_16(255) in [7, 15]
    end

    test "returns values in valid range" do
      for i <- 0..255 do
        index = Fallbacks.color_256_to_16(i)
        assert index >= 0 and index <= 15, "256 color #{i} -> #{index}"
      end
    end
  end

  describe "unicode_to_ascii/1" do
    test "converts horizontal line" do
      assert Fallbacks.unicode_to_ascii("─") == "-"
    end

    test "converts vertical line" do
      assert Fallbacks.unicode_to_ascii("│") == "|"
    end

    test "converts corners" do
      assert Fallbacks.unicode_to_ascii("┌") == "+"
      assert Fallbacks.unicode_to_ascii("┐") == "+"
      assert Fallbacks.unicode_to_ascii("└") == "+"
      assert Fallbacks.unicode_to_ascii("┘") == "+"
    end

    test "converts T-junctions" do
      assert Fallbacks.unicode_to_ascii("├") == "+"
      assert Fallbacks.unicode_to_ascii("┤") == "+"
      assert Fallbacks.unicode_to_ascii("┬") == "+"
      assert Fallbacks.unicode_to_ascii("┴") == "+"
    end

    test "converts cross" do
      assert Fallbacks.unicode_to_ascii("┼") == "+"
    end

    test "converts double-line box drawing" do
      assert Fallbacks.unicode_to_ascii("═") == "="
      assert Fallbacks.unicode_to_ascii("║") == "|"
      assert Fallbacks.unicode_to_ascii("╔") == "+"
      assert Fallbacks.unicode_to_ascii("╝") == "+"
    end

    test "converts rounded corners" do
      assert Fallbacks.unicode_to_ascii("╭") == "+"
      assert Fallbacks.unicode_to_ascii("╮") == "+"
      assert Fallbacks.unicode_to_ascii("╯") == "+"
      assert Fallbacks.unicode_to_ascii("╰") == "+"
    end

    test "converts block elements" do
      assert Fallbacks.unicode_to_ascii("█") == "#"
      assert Fallbacks.unicode_to_ascii("░") == "."
      assert Fallbacks.unicode_to_ascii("▒") == ":"
      assert Fallbacks.unicode_to_ascii("▓") == "#"
    end

    test "converts arrows" do
      assert Fallbacks.unicode_to_ascii("←") == "<"
      assert Fallbacks.unicode_to_ascii("→") == ">"
      assert Fallbacks.unicode_to_ascii("↑") == "^"
      assert Fallbacks.unicode_to_ascii("↓") == "v"
    end

    test "converts checkmarks" do
      assert Fallbacks.unicode_to_ascii("✓") == "[x]"
      assert Fallbacks.unicode_to_ascii("✗") == "[ ]"
    end

    test "passes through ASCII characters" do
      assert Fallbacks.unicode_to_ascii("a") == "a"
      assert Fallbacks.unicode_to_ascii("Z") == "Z"
      assert Fallbacks.unicode_to_ascii("5") == "5"
      assert Fallbacks.unicode_to_ascii("+") == "+"
    end

    test "passes through unknown Unicode" do
      assert Fallbacks.unicode_to_ascii("α") == "α"
      assert Fallbacks.unicode_to_ascii("π") == "π"
    end
  end

  describe "string_to_ascii/1" do
    test "converts string with box drawing" do
      input = "┌──────┐"
      expected = "+------+"
      assert Fallbacks.string_to_ascii(input) == expected
    end

    test "converts complex box" do
      input = "│ text │"
      expected = "| text |"
      assert Fallbacks.string_to_ascii(input) == expected
    end

    test "converts mixed content" do
      input = "Status: ✓ Done"
      expected = "Status: [x] Done"
      assert Fallbacks.string_to_ascii(input) == expected
    end

    test "passes through pure ASCII" do
      input = "Hello, World!"
      assert Fallbacks.string_to_ascii(input) == input
    end

    test "handles empty string" do
      assert Fallbacks.string_to_ascii("") == ""
    end
  end

  describe "degrade_color/4" do
    test "returns RGB for true-color mode" do
      result = Fallbacks.degrade_color(128, 64, 32, :true_color)
      assert result == {:rgb, 128, 64, 32}
    end

    test "returns 256-color index for 256-color mode" do
      result = Fallbacks.degrade_color(255, 0, 0, :color_256)
      assert {:index_256, index} = result
      assert index in 0..255
    end

    test "returns 16-color index for 16-color mode" do
      result = Fallbacks.degrade_color(255, 0, 0, :color_16)
      assert {:index_16, index} = result
      assert index in 0..15
    end

    test "returns :none for monochrome mode" do
      result = Fallbacks.degrade_color(255, 0, 0, :monochrome)
      assert result == :none
    end
  end
end
