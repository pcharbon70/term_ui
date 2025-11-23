defmodule TermUI.StyleIntegrationTest do
  use ExUnit.Case, async: true

  alias TermUI.Style

  describe "style inheritance chain" do
    test "child inherits from parent" do
      parent = Style.new() |> Style.fg(:blue) |> Style.bg(:white)
      child = Style.new() |> Style.bold()

      effective = Style.inherit(child, parent)

      assert effective.fg == :blue
      assert effective.bg == :white
      assert Style.has_attr?(effective, :bold)
    end

    test "child overrides parent" do
      parent = Style.new() |> Style.fg(:blue)
      child = Style.new() |> Style.fg(:red)

      effective = Style.inherit(child, parent)

      assert effective.fg == :red
    end

    test "multi-level inheritance" do
      grandparent = Style.new() |> Style.fg(:blue) |> Style.bg(:black)
      parent = Style.new() |> Style.fg(:cyan)
      child = Style.new() |> Style.bold()

      # First inherit grandparent -> parent
      parent_effective = Style.inherit(parent, grandparent)
      # Then inherit parent -> child
      child_effective = Style.inherit(child, parent_effective)

      # Grandparent bg inherited through
      assert child_effective.bg == :black
      # Parent fg override
      assert child_effective.fg == :cyan
      # Child attrs
      assert Style.has_attr?(child_effective, :bold)
    end

    test "deep inheritance chain (5 levels)" do
      styles = [
        Style.new() |> Style.fg(:red),
        Style.new() |> Style.bg(:white),
        Style.new() |> Style.bold(),
        Style.new() |> Style.fg(:blue),
        Style.new() |> Style.underline()
      ]

      # Fold through inheritance
      effective =
        Enum.reduce(styles, Style.new(), fn child, parent ->
          Style.inherit(child, parent)
        end)

      # Last fg wins
      assert effective.fg == :blue
      # bg from level 2
      assert effective.bg == :white
      # Only last level has attrs (inheritance replaces when child has any)
      assert Style.has_attr?(effective, :underline)
    end
  end

  describe "style merging" do
    test "merge combines attributes" do
      base = Style.new() |> Style.bold()
      overlay = Style.new() |> Style.italic()

      merged = Style.merge(base, overlay)

      assert Style.has_attr?(merged, :bold)
      assert Style.has_attr?(merged, :italic)
    end

    test "merge overlay wins for colors" do
      base = Style.new() |> Style.fg(:blue) |> Style.bg(:black)
      overlay = Style.new() |> Style.fg(:red)

      merged = Style.merge(base, overlay)

      assert merged.fg == :red
      assert merged.bg == :black
    end

    test "merge chain" do
      theme = Style.new() |> Style.fg(:white) |> Style.bg(:black)
      component = Style.new() |> Style.fg(:blue)
      state = Style.new() |> Style.bold()

      # Theme -> component -> state
      result =
        theme
        |> Style.merge(component)
        |> Style.merge(state)

      assert result.fg == :blue
      assert result.bg == :black
      assert Style.has_attr?(result, :bold)
    end
  end

  describe "variant selection" do
    test "select variant based on state" do
      variants =
        Style.build_variants(%{
          normal: Style.new() |> Style.fg(:white),
          focused: Style.new() |> Style.fg(:blue) |> Style.bold(),
          disabled: Style.new() |> Style.fg(:bright_black)
        })

      normal = Style.get_variant(variants, :normal)
      focused = Style.get_variant(variants, :focused)
      disabled = Style.get_variant(variants, :disabled)

      assert normal.fg == :white
      refute Style.has_attr?(normal, :bold)

      assert focused.fg == :blue
      assert Style.has_attr?(focused, :bold)

      assert disabled.fg == :bright_black
    end

    test "variants inherit from normal" do
      variants =
        Style.build_variants(%{
          normal: Style.new() |> Style.fg(:white) |> Style.bg(:black),
          focused: Style.new() |> Style.fg(:blue)
        })

      focused = Style.get_variant(variants, :focused)

      # Inherits bg from normal
      assert focused.bg == :black
      # Override fg
      assert focused.fg == :blue
    end

    test "fallback to normal for unknown state" do
      variants = %{
        normal: Style.new() |> Style.fg(:white)
      }

      result = Style.get_variant(variants, :unknown_state)
      assert result.fg == :white
    end
  end

  describe "color conversion integration" do
    test "RGB to indexed to named conversion chain" do
      rgb = {:rgb, 255, 0, 0}

      # Convert to indexed
      indexed = Style.convert_for_terminal(rgb, :color_256)
      assert {:indexed, _} = indexed

      # Convert to named
      named = Style.convert_for_terminal(indexed, :color_16)
      assert named == :bright_red
    end

    test "style with mixed color types" do
      style =
        Style.new()
        |> Style.fg({:rgb, 255, 128, 0})
        |> Style.bg({:indexed, 232})

      # Both can be converted to named
      fg_named = Style.to_named(style.fg)
      bg_named = Style.to_named(style.bg)

      assert is_atom(fg_named)
      assert is_atom(bg_named)
    end

    test "semantic colors resolve correctly" do
      colors = [:primary, :secondary, :success, :warning, :error, :info, :muted]

      for semantic <- colors do
        color = Style.semantic(semantic)
        assert is_atom(color) or is_tuple(color)
      end
    end

    test "named to RGB to indexed conversion chain" do
      named = :red

      # Convert named to RGB tuple
      {r, g, b} = Style.to_rgb(named)
      assert is_integer(r) and r >= 0 and r <= 255
      assert is_integer(g) and g >= 0 and g <= 255
      assert is_integer(b) and b >= 0 and b <= 255

      # Convert RGB to indexed (returns just the index number)
      idx = Style.rgb_to_indexed({r, g, b})
      assert is_integer(idx) and idx >= 0 and idx <= 255
    end

    test "edge RGB values convert correctly" do
      # Pure black
      black_rgb = {:rgb, 0, 0, 0}
      black_named = Style.to_named(black_rgb)
      assert black_named == :black

      # Pure white
      white_rgb = {:rgb, 255, 255, 255}
      white_named = Style.to_named(white_rgb)
      assert white_named == :bright_white

      # Edge values for indexed (0 = black, 255 = white)
      black_indexed = {:indexed, 0}
      assert Style.to_named(black_indexed) == :black

      white_indexed = {:indexed, 15}
      assert Style.to_named(white_indexed) == :bright_white
    end

    test "round-trip conversion preserves color identity" do
      # Named -> RGB -> Indexed -> Named
      original = :blue
      rgb_tuple = Style.to_rgb(original)
      idx = Style.rgb_to_indexed(rgb_tuple)
      # Wrap index as indexed tuple for to_named
      back_to_named = Style.to_named({:indexed, idx})

      # Should map back to same color or close equivalent
      assert back_to_named == original or back_to_named == :bright_blue
    end
  end

  describe "complex style scenarios" do
    test "button states with inheritance" do
      # Base button style
      base =
        Style.new()
        |> Style.fg(:white)
        |> Style.bg(:bright_black)

      # Variants
      variants =
        Style.build_variants(%{
          normal: base,
          focused: Style.new() |> Style.bg(:blue) |> Style.bold(),
          pressed: Style.new() |> Style.bg(:cyan) |> Style.reverse(),
          disabled: Style.new() |> Style.fg(:bright_black) |> Style.bg(:black)
        })

      # Simulate state changes
      states = [:normal, :focused, :pressed, :disabled]

      for state <- states do
        style = Style.get_variant(variants, state)
        assert %Style{} = style
        # All states should have fg (from base or override)
        assert style.fg != nil, "State #{state} should have fg color"
      end
    end

    test "text input with placeholder and content styles" do
      placeholder_style =
        Style.new()
        |> Style.fg(:bright_black)
        |> Style.italic()

      content_style =
        Style.new()
        |> Style.fg(:white)

      focused_modifier = Style.new() |> Style.bg(:blue)

      # Placeholder unfocused
      placeholder_unfocused = placeholder_style
      assert placeholder_unfocused.fg == :bright_black
      assert Style.has_attr?(placeholder_unfocused, :italic)

      # Placeholder focused
      placeholder_focused = Style.merge(placeholder_style, focused_modifier)
      assert placeholder_focused.bg == :blue
      assert Style.has_attr?(placeholder_focused, :italic)

      # Content focused
      content_focused = Style.merge(content_style, focused_modifier)
      assert content_focused.fg == :white
      assert content_focused.bg == :blue
    end

    test "nested container style propagation" do
      # Container defines base style
      container_style =
        Style.new()
        |> Style.fg(:white)
        |> Style.bg(:black)

      # Inner container adds border style
      inner_style = Style.new() |> Style.fg(:bright_black)

      # Widget in inner container
      widget_style = Style.new() |> Style.bold()

      # Build inheritance chain
      inner_effective = Style.inherit(inner_style, container_style)
      widget_effective = Style.inherit(widget_style, inner_effective)

      # Widget inherits container bg
      assert widget_effective.bg == :black
      # But gets inner fg
      assert widget_effective.fg == :bright_black
      # And its own attrs
      assert Style.has_attr?(widget_effective, :bold)
    end
  end

  describe "builder pattern fluency" do
    test "long builder chain" do
      style =
        Style.new()
        |> Style.fg(:blue)
        |> Style.bg(:white)
        |> Style.bold()
        |> Style.italic()
        |> Style.underline()

      assert style.fg == :blue
      assert style.bg == :white
      assert Style.has_attr?(style, :bold)
      assert Style.has_attr?(style, :italic)
      assert Style.has_attr?(style, :underline)
    end

    test "from/1 with all options" do
      style =
        Style.from(
          fg: :cyan,
          bg: :black,
          bold: true,
          italic: true,
          underline: true
        )

      assert style.fg == :cyan
      assert style.bg == :black
      assert Style.has_attr?(style, :bold)
      assert Style.has_attr?(style, :italic)
      assert Style.has_attr?(style, :underline)
    end
  end

  describe "immutability" do
    test "modifications don't affect original" do
      original = Style.new() |> Style.fg(:blue)
      modified = Style.fg(original, :red)

      assert original.fg == :blue
      assert modified.fg == :red
    end

    test "merge doesn't modify inputs" do
      base = Style.new() |> Style.fg(:blue)
      overlay = Style.new() |> Style.bold()

      _merged = Style.merge(base, overlay)

      # Originals unchanged
      assert base.fg == :blue
      refute Style.has_attr?(base, :bold)
      assert overlay.fg == nil
      assert Style.has_attr?(overlay, :bold)
    end
  end
end
