defmodule TermUI.Renderer.StyleTest do
  use ExUnit.Case, async: true

  alias TermUI.Renderer.{Cell, Style}

  describe "new/0" do
    test "creates empty style" do
      style = Style.new()
      assert is_nil(style.fg)
      assert is_nil(style.bg)
      assert MapSet.size(style.attrs) == 0
    end
  end

  describe "new/1" do
    test "creates style with options" do
      style = Style.new(fg: :red, bg: :blue, attrs: [:bold])
      assert style.fg == :red
      assert style.bg == :blue
      assert :bold in style.attrs
    end
  end

  describe "fluent builder" do
    test "fg/2 sets foreground" do
      style = Style.new() |> Style.fg(:red)
      assert style.fg == :red
    end

    test "bg/2 sets background" do
      style = Style.new() |> Style.bg(:blue)
      assert style.bg == :blue
    end

    test "bold/1 adds bold attribute" do
      style = Style.new() |> Style.bold()
      assert :bold in style.attrs
    end

    test "dim/1 adds dim attribute" do
      style = Style.new() |> Style.dim()
      assert :dim in style.attrs
    end

    test "italic/1 adds italic attribute" do
      style = Style.new() |> Style.italic()
      assert :italic in style.attrs
    end

    test "underline/1 adds underline attribute" do
      style = Style.new() |> Style.underline()
      assert :underline in style.attrs
    end

    test "blink/1 adds blink attribute" do
      style = Style.new() |> Style.blink()
      assert :blink in style.attrs
    end

    test "reverse/1 adds reverse attribute" do
      style = Style.new() |> Style.reverse()
      assert :reverse in style.attrs
    end

    test "hidden/1 adds hidden attribute" do
      style = Style.new() |> Style.hidden()
      assert :hidden in style.attrs
    end

    test "strikethrough/1 adds strikethrough attribute" do
      style = Style.new() |> Style.strikethrough()
      assert :strikethrough in style.attrs
    end

    test "chaining multiple operations" do
      style =
        Style.new()
        |> Style.fg(:red)
        |> Style.bg(:black)
        |> Style.bold()
        |> Style.underline()

      assert style.fg == :red
      assert style.bg == :black
      assert :bold in style.attrs
      assert :underline in style.attrs
    end
  end

  describe "add_attr/2" do
    test "adds attribute" do
      style = Style.new() |> Style.add_attr(:bold)
      assert :bold in style.attrs
    end
  end

  describe "remove_attr/2" do
    test "removes attribute" do
      style = Style.new(attrs: [:bold, :italic]) |> Style.remove_attr(:bold)
      refute :bold in style.attrs
      assert :italic in style.attrs
    end
  end

  describe "merge/2" do
    test "override replaces base colors" do
      base = Style.new(fg: :white, bg: :black)
      override = Style.new(fg: :red)
      merged = Style.merge(base, override)

      assert merged.fg == :red
      assert merged.bg == :black
    end

    test "nil in override doesn't replace base" do
      base = Style.new(fg: :white, bg: :black)
      override = Style.new()
      merged = Style.merge(base, override)

      assert merged.fg == :white
      assert merged.bg == :black
    end

    test "attributes are combined" do
      base = Style.new(attrs: [:bold])
      override = Style.new(attrs: [:italic])
      merged = Style.merge(base, override)

      assert :bold in merged.attrs
      assert :italic in merged.attrs
    end

    test "merging empty styles" do
      merged = Style.merge(Style.new(), Style.new())
      assert is_nil(merged.fg)
      assert is_nil(merged.bg)
      assert MapSet.size(merged.attrs) == 0
    end

    test "complete style merge" do
      base = Style.new(fg: :white, bg: :black, attrs: [:bold])
      override = Style.new(fg: :red, attrs: [:underline])
      merged = Style.merge(base, override)

      assert merged.fg == :red
      assert merged.bg == :black
      assert :bold in merged.attrs
      assert :underline in merged.attrs
    end
  end

  describe "to_cell/2" do
    test "creates cell with character and style" do
      style = Style.new() |> Style.fg(:red) |> Style.bold()
      cell = Style.to_cell(style, "X")

      assert cell.char == "X"
      assert cell.fg == :red
      assert cell.bg == :default
      assert :bold in cell.attrs
    end

    test "uses default for unset colors" do
      style = Style.new()
      cell = Style.to_cell(style, "A")

      assert cell.fg == :default
      assert cell.bg == :default
    end

    test "preserves all attributes" do
      style = Style.new(attrs: [:bold, :italic, :underline])
      cell = Style.to_cell(style, "X")

      assert :bold in cell.attrs
      assert :italic in cell.attrs
      assert :underline in cell.attrs
    end
  end

  describe "apply_to_cell/2" do
    test "overrides cell colors with style" do
      cell = Cell.new("A", fg: :white)
      style = Style.new() |> Style.fg(:red)
      new_cell = Style.apply_to_cell(style, cell)

      assert new_cell.fg == :red
      assert new_cell.char == "A"
    end

    test "preserves cell values for unset style values" do
      cell = Cell.new("A", fg: :white, bg: :black)
      style = Style.new() |> Style.fg(:red)
      new_cell = Style.apply_to_cell(style, cell)

      assert new_cell.fg == :red
      assert new_cell.bg == :black
    end

    test "combines attributes" do
      cell = Cell.new("A", attrs: [:bold])
      style = Style.new(attrs: [:italic])
      new_cell = Style.apply_to_cell(style, cell)

      assert :bold in new_cell.attrs
      assert :italic in new_cell.attrs
    end
  end

  describe "reset/1" do
    test "returns empty style" do
      style = Style.new(fg: :red, attrs: [:bold])
      reset_style = Style.reset(style)

      assert is_nil(reset_style.fg)
      assert is_nil(reset_style.bg)
      assert MapSet.size(reset_style.attrs) == 0
    end
  end

  describe "empty?/1" do
    test "returns true for empty style" do
      assert Style.empty?(Style.new())
    end

    test "returns false when fg set" do
      refute Style.empty?(Style.new(fg: :red))
    end

    test "returns false when bg set" do
      refute Style.empty?(Style.new(bg: :blue))
    end

    test "returns false when attrs set" do
      refute Style.empty?(Style.new(attrs: [:bold]))
    end
  end

  describe "input validation" do
    test "new/1 raises on invalid foreground color" do
      assert_raise ArgumentError, fn ->
        Style.new(fg: :invalid_color)
      end
    end

    test "new/1 raises on invalid background color" do
      assert_raise ArgumentError, fn ->
        Style.new(bg: :invalid_color)
      end
    end

    test "new/1 raises on invalid attribute" do
      assert_raise ArgumentError, fn ->
        Style.new(attrs: [:invalid_attr])
      end
    end

    test "fg/2 raises on invalid color" do
      assert_raise ArgumentError, fn ->
        Style.new() |> Style.fg(:invalid_color)
      end
    end

    test "bg/2 raises on invalid color" do
      assert_raise ArgumentError, fn ->
        Style.new() |> Style.bg(:invalid_color)
      end
    end

    test "add_attr/2 raises on invalid attribute" do
      assert_raise ArgumentError, fn ->
        Style.new() |> Style.add_attr(:invalid_attr)
      end
    end

    test "new/1 raises on out-of-range 256-color" do
      assert_raise ArgumentError, fn ->
        Style.new(fg: 256)
      end
    end

    test "new/1 raises on out-of-range RGB" do
      assert_raise ArgumentError, fn ->
        Style.new(fg: {256, 0, 0})
      end
    end

    test "accepts 256-color values" do
      style = Style.new(fg: 196, bg: 21)
      assert style.fg == 196
      assert style.bg == 21
    end

    test "accepts RGB color values" do
      style = Style.new(fg: {255, 128, 0}, bg: {0, 0, 255})
      assert style.fg == {255, 128, 0}
      assert style.bg == {0, 0, 255}
    end

    test "accepts all named colors" do
      style = Style.new(fg: :bright_red, bg: :bright_blue)
      assert style.fg == :bright_red
      assert style.bg == :bright_blue
    end

    test "accepts all valid attributes" do
      style = Style.new(attrs: [:bold, :dim, :italic, :underline, :blink, :reverse, :hidden, :strikethrough])
      assert MapSet.size(style.attrs) == 8
    end
  end

  describe "equal?/2" do
    test "returns true for identical styles" do
      s1 = Style.new(fg: :red, bg: :blue, attrs: [:bold, :italic])
      s2 = Style.new(fg: :red, bg: :blue, attrs: [:bold, :italic])
      assert Style.equal?(s1, s2)
    end

    test "returns true for empty styles" do
      assert Style.equal?(Style.new(), Style.new())
    end

    test "returns false for different foreground colors" do
      s1 = Style.new(fg: :red)
      s2 = Style.new(fg: :blue)
      refute Style.equal?(s1, s2)
    end

    test "returns false for different background colors" do
      s1 = Style.new(bg: :red)
      s2 = Style.new(bg: :blue)
      refute Style.equal?(s1, s2)
    end

    test "returns false for different attributes" do
      s1 = Style.new(attrs: [:bold])
      s2 = Style.new(attrs: [:italic])
      refute Style.equal?(s1, s2)
    end

    test "returns false when one has attribute other doesn't" do
      s1 = Style.new(attrs: [:bold])
      s2 = Style.new()
      refute Style.equal?(s1, s2)
    end

    test "attribute order doesn't matter" do
      s1 = Style.new(attrs: [:bold, :italic])
      s2 = Style.new(attrs: [:italic, :bold])
      assert Style.equal?(s1, s2)
    end

    test "returns true for styles with 256-color" do
      s1 = Style.new(fg: 196, bg: 21)
      s2 = Style.new(fg: 196, bg: 21)
      assert Style.equal?(s1, s2)
    end

    test "returns true for styles with RGB color" do
      s1 = Style.new(fg: {255, 128, 0})
      s2 = Style.new(fg: {255, 128, 0})
      assert Style.equal?(s1, s2)
    end

    test "returns false for nil vs set color" do
      s1 = Style.new(fg: :red)
      s2 = Style.new()
      refute Style.equal?(s1, s2)
    end
  end
end
