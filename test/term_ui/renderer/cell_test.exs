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
end
