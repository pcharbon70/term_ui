defmodule TermUI.Renderer.CellTest do
  use ExUnit.Case, async: true

  alias TermUI.Renderer.Cell

  describe "new/1" do
    test "creates cell with character" do
      cell = Cell.new("A")
      assert cell.char == "A"
      assert cell.fg == :default
      assert cell.bg == :default
      assert MapSet.size(cell.attrs) == 0
    end

    test "creates cell with foreground color" do
      cell = Cell.new("X", fg: :red)
      assert cell.fg == :red
      assert cell.bg == :default
    end

    test "creates cell with background color" do
      cell = Cell.new("X", bg: :blue)
      assert cell.fg == :default
      assert cell.bg == :blue
    end

    test "creates cell with 256-color" do
      cell = Cell.new("X", fg: 196, bg: 21)
      assert cell.fg == 196
      assert cell.bg == 21
    end

    test "creates cell with RGB color" do
      cell = Cell.new("X", fg: {255, 128, 0}, bg: {0, 0, 255})
      assert cell.fg == {255, 128, 0}
      assert cell.bg == {0, 0, 255}
    end

    test "creates cell with attributes" do
      cell = Cell.new("X", attrs: [:bold, :italic])
      assert :bold in cell.attrs
      assert :italic in cell.attrs
    end

    test "raises on invalid color" do
      assert_raise ArgumentError, fn ->
        Cell.new("X", fg: :invalid_color)
      end
    end

    test "raises on invalid attribute" do
      assert_raise ArgumentError, fn ->
        Cell.new("X", attrs: [:invalid_attr])
      end
    end

    test "raises on out-of-range 256-color" do
      assert_raise ArgumentError, fn ->
        Cell.new("X", fg: 256)
      end
    end

    test "raises on out-of-range RGB" do
      assert_raise ArgumentError, fn ->
        Cell.new("X", fg: {256, 0, 0})
      end
    end
  end

  describe "empty/0" do
    test "returns empty cell" do
      cell = Cell.empty()
      assert cell.char == " "
      assert cell.fg == :default
      assert cell.bg == :default
      assert MapSet.size(cell.attrs) == 0
    end
  end

  describe "equal?/2" do
    test "returns true for identical cells" do
      cell1 = Cell.new("A", fg: :red, attrs: [:bold])
      cell2 = Cell.new("A", fg: :red, attrs: [:bold])
      assert Cell.equal?(cell1, cell2)
    end

    test "returns true for empty cells" do
      assert Cell.equal?(Cell.empty(), Cell.empty())
    end

    test "returns false for different characters" do
      cell1 = Cell.new("A")
      cell2 = Cell.new("B")
      refute Cell.equal?(cell1, cell2)
    end

    test "returns false for different foreground" do
      cell1 = Cell.new("A", fg: :red)
      cell2 = Cell.new("A", fg: :blue)
      refute Cell.equal?(cell1, cell2)
    end

    test "returns false for different background" do
      cell1 = Cell.new("A", bg: :red)
      cell2 = Cell.new("A", bg: :blue)
      refute Cell.equal?(cell1, cell2)
    end

    test "returns false for different attributes" do
      cell1 = Cell.new("A", attrs: [:bold])
      cell2 = Cell.new("A", attrs: [:italic])
      refute Cell.equal?(cell1, cell2)
    end
  end

  describe "empty?/1" do
    test "returns true for empty cell" do
      assert Cell.empty?(Cell.empty())
    end

    test "returns false for cell with character" do
      refute Cell.empty?(Cell.new("A"))
    end

    test "returns false for cell with color" do
      cell = %Cell{char: " ", fg: :red, bg: :default, attrs: MapSet.new()}
      refute Cell.empty?(cell)
    end

    test "returns false for cell with attribute" do
      cell = %Cell{char: " ", fg: :default, bg: :default, attrs: MapSet.new([:bold])}
      refute Cell.empty?(cell)
    end
  end

  describe "put_char/2" do
    test "updates character preserving style" do
      cell = Cell.new("A", fg: :red)
      new_cell = Cell.put_char(cell, "B")
      assert new_cell.char == "B"
      assert new_cell.fg == :red
    end
  end

  describe "put_fg/2" do
    test "updates foreground color" do
      cell = Cell.new("A")
      new_cell = Cell.put_fg(cell, :green)
      assert new_cell.fg == :green
    end
  end

  describe "put_bg/2" do
    test "updates background color" do
      cell = Cell.new("A")
      new_cell = Cell.put_bg(cell, :yellow)
      assert new_cell.bg == :yellow
    end
  end

  describe "add_attr/2" do
    test "adds attribute" do
      cell = Cell.new("A")
      new_cell = Cell.add_attr(cell, :bold)
      assert :bold in new_cell.attrs
    end

    test "adding same attribute is idempotent" do
      cell = Cell.new("A", attrs: [:bold])
      new_cell = Cell.add_attr(cell, :bold)
      assert MapSet.size(new_cell.attrs) == 1
    end
  end

  describe "remove_attr/2" do
    test "removes attribute" do
      cell = Cell.new("A", attrs: [:bold, :italic])
      new_cell = Cell.remove_attr(cell, :bold)
      refute :bold in new_cell.attrs
      assert :italic in new_cell.attrs
    end
  end

  describe "has_attr?/2" do
    test "returns true when attribute present" do
      cell = Cell.new("A", attrs: [:bold])
      assert Cell.has_attr?(cell, :bold)
    end

    test "returns false when attribute absent" do
      cell = Cell.new("A")
      refute Cell.has_attr?(cell, :bold)
    end
  end

  describe "named_colors/0" do
    test "returns list of named colors" do
      colors = Cell.named_colors()
      assert :red in colors
      assert :green in colors
      assert :blue in colors
      assert :bright_white in colors
    end
  end

  describe "valid_attributes/0" do
    test "returns list of valid attributes" do
      attrs = Cell.valid_attributes()
      assert :bold in attrs
      assert :italic in attrs
      assert :underline in attrs
      assert :strikethrough in attrs
    end
  end

  describe "character sanitization" do
    test "preserves normal ASCII characters" do
      cell = Cell.new("A")
      assert cell.char == "A"
    end

    test "preserves space character" do
      cell = Cell.new(" ")
      assert cell.char == " "
    end

    test "preserves Unicode characters" do
      cell = Cell.new("世")
      assert cell.char == "世"
    end

    test "preserves emoji" do
      cell = Cell.new("🎉")
      assert cell.char == "🎉"
    end

    test "strips escape sequence (CSI)" do
      # \e[2J is clear screen
      cell = Cell.new("\e[2J")
      assert cell.char == " "
    end

    test "strips escape sequence with text after" do
      cell = Cell.new("\e[31mRed")
      assert cell.char == "Red"
    end

    test "strips null character" do
      cell = Cell.new("\x00")
      assert cell.char == " "
    end

    test "strips bell character" do
      cell = Cell.new("\x07")
      assert cell.char == " "
    end

    test "strips backspace" do
      cell = Cell.new("\x08")
      assert cell.char == " "
    end

    test "strips tab character" do
      cell = Cell.new("\t")
      assert cell.char == " "
    end

    test "strips newline" do
      cell = Cell.new("\n")
      assert cell.char == " "
    end

    test "strips carriage return" do
      cell = Cell.new("\r")
      assert cell.char == " "
    end

    test "strips DEL character" do
      cell = Cell.new("\x7F")
      assert cell.char == " "
    end

    test "strips C1 control characters" do
      # 0x9B is CSI in C1 range
      cell = Cell.new(<<0x9B>>)
      assert cell.char == " "
    end

    test "strips escape from mixed content" do
      cell = Cell.new("A\e[0mB")
      assert cell.char == "AB"
    end

    test "strips multiple control characters" do
      cell = Cell.new("\x00\x01\x02X\x03\x04")
      assert cell.char == "X"
    end

    test "put_char also sanitizes" do
      cell = Cell.new("A")
      new_cell = Cell.put_char(cell, "\e[2J")
      assert new_cell.char == " "
    end

    test "OSC sequence is stripped" do
      # OSC to set window title
      cell = Cell.new("\e]2;malicious\x07")
      assert cell.char == " "
    end

    test "preserves accented characters" do
      cell = Cell.new("é")
      assert cell.char == "é"
    end

    test "preserves combining characters" do
      # e + combining acute accent
      cell = Cell.new("e\u0301")
      assert cell.char == "e\u0301"
    end

    test "preserves multiple combining marks" do
      # a + combining acute + combining tilde
      cell = Cell.new("a\u0301\u0303")
      assert cell.char == "a\u0301\u0303"
    end

    test "preserves flag emoji (regional indicators)" do
      # US flag (U+1F1FA U+1F1F8)
      cell = Cell.new("🇺🇸")
      assert cell.char == "🇺🇸"
    end

    test "preserves emoji with skin tone modifier" do
      # Waving hand + medium skin tone
      cell = Cell.new("👋🏽")
      assert cell.char == "👋🏽"
    end

    test "preserves ZWJ emoji sequences" do
      # Family emoji (man + ZWJ + woman + ZWJ + girl)
      cell = Cell.new("👨‍👩‍👧")
      assert cell.char == "👨‍👩‍👧"
    end

    test "preserves keycap sequences" do
      # Keycap digit one (1 + combining enclosing keycap)
      cell = Cell.new("1️⃣")
      assert cell.char == "1️⃣"
    end
  end

  describe "wide character support" do
    test "ASCII characters have width 1" do
      cell = Cell.new("A")
      assert Cell.width(cell) == 1
      refute Cell.wide?(cell)
    end

    test "CJK characters have width 2" do
      cell = Cell.new("日")
      assert Cell.width(cell) == 2
      assert Cell.wide?(cell)
    end

    test "emoji have width 2" do
      cell = Cell.new("😀")
      assert Cell.width(cell) == 2
      assert Cell.wide?(cell)
    end

    test "space has width 1" do
      cell = Cell.new(" ")
      assert Cell.width(cell) == 1
      refute Cell.wide?(cell)
    end

    test "empty cell has width 1" do
      cell = Cell.empty()
      assert Cell.width(cell) == 1
      refute Cell.wide?(cell)
    end

    test "wide_placeholder creates placeholder cell" do
      primary = Cell.new("日", fg: :red)
      placeholder = Cell.wide_placeholder(primary)

      assert placeholder.char == ""
      assert placeholder.fg == :red
      assert placeholder.width == 0
      assert Cell.wide_placeholder?(placeholder)
      refute Cell.wide_placeholder?(primary)
    end

    test "equal? considers width" do
      # Same char different width shouldn't be equal
      cell1 = Cell.new("A")
      cell2 = %{cell1 | width: 2}
      refute Cell.equal?(cell1, cell2)
    end

    test "equal? considers wide_placeholder" do
      cell1 = Cell.new("A")
      cell2 = %{cell1 | wide_placeholder: true}
      refute Cell.equal?(cell1, cell2)
    end

    test "Hangul has width 2" do
      cell = Cell.new("한")
      assert Cell.width(cell) == 2
    end

    test "Hiragana has width 2" do
      cell = Cell.new("あ")
      assert Cell.width(cell) == 2
    end

    test "fullwidth ASCII has width 2" do
      cell = Cell.new("Ａ")
      assert Cell.width(cell) == 2
    end
  end
end
