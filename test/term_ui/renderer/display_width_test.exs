defmodule TermUI.Renderer.DisplayWidthTest do
  use ExUnit.Case, async: true

  alias TermUI.Renderer.DisplayWidth

  describe "width/1" do
    test "ASCII characters are single-width" do
      assert DisplayWidth.width("A") == 1
      assert DisplayWidth.width("z") == 1
      assert DisplayWidth.width("0") == 1
      assert DisplayWidth.width("@") == 1
    end

    test "space is single-width" do
      assert DisplayWidth.width(" ") == 1
    end

    test "CJK characters are double-width" do
      assert DisplayWidth.width("日") == 2
      assert DisplayWidth.width("本") == 2
      assert DisplayWidth.width("語") == 2
      assert DisplayWidth.width("中") == 2
      assert DisplayWidth.width("文") == 2
    end

    test "Hiragana is double-width" do
      assert DisplayWidth.width("あ") == 2
      assert DisplayWidth.width("い") == 2
    end

    test "Katakana is double-width" do
      assert DisplayWidth.width("ア") == 2
      assert DisplayWidth.width("イ") == 2
    end

    test "Hangul is double-width" do
      assert DisplayWidth.width("한") == 2
      assert DisplayWidth.width("글") == 2
    end

    test "combining characters are zero-width" do
      # Combining acute accent
      assert DisplayWidth.width("\u0301") == 0
      # Combining grave accent
      assert DisplayWidth.width("\u0300") == 0
    end

    test "zero-width characters" do
      # Zero Width Space
      assert DisplayWidth.width("\u200B") == 0
      # Zero Width Joiner
      assert DisplayWidth.width("\u200D") == 0
    end

    test "control characters are zero-width" do
      # NULL
      assert DisplayWidth.width(<<0>>) == 0
      # BEL
      assert DisplayWidth.width(<<7>>) == 0
    end

    test "grapheme with combining character" do
      # e + combining acute = é (should be 1 width total)
      assert DisplayWidth.width("e\u0301") == 1
    end

    test "emoji are double-width" do
      assert DisplayWidth.width("😀") == 2
      assert DisplayWidth.width("🎉") == 2
    end

    test "fullwidth forms are double-width" do
      # Fullwidth A
      assert DisplayWidth.width("Ａ") == 2
    end
  end

  describe "string_width/1" do
    test "ASCII string" do
      assert DisplayWidth.string_width("Hello") == 5
      assert DisplayWidth.string_width("World") == 5
    end

    test "empty string" do
      assert DisplayWidth.string_width("") == 0
    end

    test "CJK string" do
      assert DisplayWidth.string_width("日本語") == 6
      assert DisplayWidth.string_width("中文") == 4
    end

    test "mixed width string" do
      # "A" (1) + "日" (2) + "B" (1) = 4
      assert DisplayWidth.string_width("A日B") == 4
    end

    test "string with combining characters" do
      # "Cafe" + combining acute = 4 width (combining char is zero-width)
      assert DisplayWidth.string_width("Cafe\u0301") == 4
    end

    test "string with precomposed characters" do
      # Café with precomposed é (U+00E9) = 4 chars, 4 width
      assert DisplayWidth.string_width("Café") == 4
    end

    test "emoji string" do
      assert DisplayWidth.string_width("😀😀") == 4
    end
  end

  describe "double_width?/1" do
    test "returns true for CJK" do
      assert DisplayWidth.double_width?("日")
      assert DisplayWidth.double_width?("한")
    end

    test "returns false for ASCII" do
      refute DisplayWidth.double_width?("A")
      refute DisplayWidth.double_width?(" ")
    end

    test "returns false for combining characters" do
      refute DisplayWidth.double_width?("\u0301")
    end
  end

  describe "zero_width?/1" do
    test "returns true for combining characters" do
      assert DisplayWidth.zero_width?("\u0301")
      assert DisplayWidth.zero_width?("\u200B")
    end

    test "returns false for regular characters" do
      refute DisplayWidth.zero_width?("A")
      refute DisplayWidth.zero_width?(" ")
    end

    test "returns false for wide characters" do
      refute DisplayWidth.zero_width?("日")
    end
  end

  describe "truncate/2" do
    test "truncates ASCII string" do
      {result, width} = DisplayWidth.truncate("Hello World", 5)
      assert result == "Hello"
      assert width == 5
    end

    test "returns full string if within width" do
      {result, width} = DisplayWidth.truncate("Hi", 10)
      assert result == "Hi"
      assert width == 2
    end

    test "truncates at character boundary for CJK" do
      # "日本語" = 6 width, truncate to 4
      {result, width} = DisplayWidth.truncate("日本語", 4)
      assert result == "日本"
      assert width == 4
    end

    test "doesn't split double-width character" do
      # "日本語" = 6 width, truncate to 5 (can't fit third char)
      {result, width} = DisplayWidth.truncate("日本語", 5)
      assert result == "日本"
      assert width == 4
    end

    test "empty string" do
      {result, width} = DisplayWidth.truncate("", 10)
      assert result == ""
      assert width == 0
    end

    test "zero width" do
      {result, width} = DisplayWidth.truncate("Hello", 0)
      assert result == ""
      assert width == 0
    end
  end

  describe "pad/3" do
    test "pads to right by default" do
      result = DisplayWidth.pad("Hi", 5)
      assert result == "Hi   "
    end

    test "pads to left" do
      result = DisplayWidth.pad("Hi", 5, direction: :left)
      assert result == "   Hi"
    end

    test "pads center" do
      result = DisplayWidth.pad("Hi", 6, direction: :center)
      assert result == "  Hi  "
    end

    test "no padding if string meets width" do
      result = DisplayWidth.pad("Hello", 5)
      assert result == "Hello"
    end

    test "no padding if string exceeds width" do
      result = DisplayWidth.pad("Hello", 3)
      assert result == "Hello"
    end

    test "custom padding character" do
      result = DisplayWidth.pad("Hi", 5, char: "-")
      assert result == "Hi---"
    end

    test "handles wide characters" do
      # "日" is width 2, pad to 4
      result = DisplayWidth.pad("日", 4)
      assert result == "日  "
    end
  end
end
