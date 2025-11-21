defmodule TermUI.Component.HelpersTest do
  use ExUnit.Case, async: true

  alias TermUI.Component.Helpers
  alias TermUI.Component.RenderNode
  alias TermUI.Renderer.Style

  describe "text/1 and text/2" do
    test "delegates to RenderNode.text" do
      node = Helpers.text("Hello")
      assert node.type == :text
      assert node.content == "Hello"
    end

    test "with style" do
      style = Style.new() |> Style.fg(:red)
      node = Helpers.text("Error", style)
      assert node.style.fg == :red
    end
  end

  describe "box/1 and box/2" do
    test "delegates to RenderNode.box" do
      node = Helpers.box([Helpers.text("Content")])
      assert node.type == :box
      assert length(node.children) == 1
    end

    test "with options" do
      node = Helpers.box([], width: 20)
      assert node.width == 20
    end
  end

  describe "stack/2 and stack/3" do
    test "delegates to RenderNode.stack" do
      node = Helpers.stack(:vertical, [Helpers.text("A")])
      assert node.type == :stack
      assert node.direction == :vertical
    end
  end

  describe "styled/2" do
    test "delegates to RenderNode.styled" do
      inner = Helpers.text("Hello")
      style = Style.new() |> Style.fg(:red)
      node = Helpers.styled(inner, style)
      assert node.type == :box
      assert node.style.fg == :red
    end
  end

  describe "empty/0" do
    test "delegates to RenderNode.empty" do
      node = Helpers.empty()
      assert node.type == :empty
    end
  end

  describe "props!/2" do
    test "validates required props" do
      props = %{name: "Test"}
      result = Helpers.props!(props, [
        {:name, :string, required: true}
      ])
      assert result.name == "Test"
    end

    test "raises on missing required prop" do
      props = %{}
      assert_raise ArgumentError, ~r/Required prop :name is missing/, fn ->
        Helpers.props!(props, [
          {:name, :string, required: true}
        ])
      end
    end

    test "applies default values" do
      props = %{}
      result = Helpers.props!(props, [
        {:count, :integer, default: 0}
      ])
      assert result.count == 0
    end

    test "passed values override defaults" do
      props = %{count: 42}
      result = Helpers.props!(props, [
        {:count, :integer, default: 0}
      ])
      assert result.count == 42
    end

    test "validates string type" do
      props = %{name: 123}
      assert_raise ArgumentError, ~r/must be a string/, fn ->
        Helpers.props!(props, [
          {:name, :string, required: true}
        ])
      end
    end

    test "validates integer type" do
      props = %{count: "not a number"}
      assert_raise ArgumentError, ~r/must be an integer/, fn ->
        Helpers.props!(props, [
          {:count, :integer, required: true}
        ])
      end
    end

    test "validates boolean type" do
      props = %{enabled: "yes"}
      assert_raise ArgumentError, ~r/must be a boolean/, fn ->
        Helpers.props!(props, [
          {:enabled, :boolean, required: true}
        ])
      end
    end

    test "validates atom type" do
      props = %{mode: "fast"}
      assert_raise ArgumentError, ~r/must be an atom/, fn ->
        Helpers.props!(props, [
          {:mode, :atom, required: true}
        ])
      end
    end

    test "validates style type" do
      props = %{style: %{}}
      assert_raise ArgumentError, ~r/must be a Style/, fn ->
        Helpers.props!(props, [
          {:style, :style, required: true}
        ])
      end
    end

    test "any type accepts anything" do
      props = %{data: {:some, :tuple}}
      result = Helpers.props!(props, [
        {:data, :any, required: true}
      ])
      assert result.data == {:some, :tuple}
    end

    test "nil values pass type validation" do
      props = %{name: nil}
      result = Helpers.props!(props, [
        {:name, :string, default: "default"}
      ])
      assert result.name == nil
    end

    test "multiple props" do
      props = %{name: "Test", count: 5}
      result = Helpers.props!(props, [
        {:name, :string, required: true},
        {:count, :integer, default: 0},
        {:enabled, :boolean, default: true}
      ])
      assert result.name == "Test"
      assert result.count == 5
      assert result.enabled == true
    end

    test "accepts valid Style struct" do
      style = Style.new() |> Style.fg(:red)
      props = %{style: style}
      result = Helpers.props!(props, [
        {:style, :style, required: true}
      ])
      assert result.style.fg == :red
    end
  end

  describe "merge_styles/1" do
    test "merges multiple styles" do
      base = Style.new() |> Style.fg(:white)
      override = Style.new() |> Style.fg(:red) |> Style.bold()
      result = Helpers.merge_styles([base, override])

      assert result.fg == :red
      assert :bold in result.attrs
    end

    test "handles nil styles" do
      style = Style.new() |> Style.fg(:blue)
      result = Helpers.merge_styles([nil, style, nil])
      assert result.fg == :blue
    end

    test "empty list returns empty style" do
      result = Helpers.merge_styles([])
      assert Style.empty?(result)
    end

    test "single style returns itself" do
      style = Style.new() |> Style.fg(:green)
      result = Helpers.merge_styles([style])
      assert result.fg == :green
    end

    test "later styles override earlier" do
      s1 = Style.new() |> Style.fg(:red)
      s2 = Style.new() |> Style.fg(:blue)
      s3 = Style.new() |> Style.fg(:green)
      result = Helpers.merge_styles([s1, s2, s3])
      assert result.fg == :green
    end

    test "attributes combine" do
      s1 = Style.new() |> Style.bold()
      s2 = Style.new() |> Style.italic()
      result = Helpers.merge_styles([s1, s2])
      assert :bold in result.attrs
      assert :italic in result.attrs
    end
  end

  describe "compute_size/1" do
    test "single line text" do
      {width, height} = Helpers.compute_size("Hello")
      assert width == 5
      assert height == 1
    end

    test "multiline text" do
      {width, height} = Helpers.compute_size("Line 1\nLonger Line 2\nL3")
      assert width == 13
      assert height == 3
    end

    test "empty string" do
      {width, height} = Helpers.compute_size("")
      assert width == 0
      assert height == 1
    end

    test "only newlines" do
      {width, height} = Helpers.compute_size("\n\n")
      assert width == 0
      assert height == 3
    end
  end

  describe "compute_node_size/1" do
    test "text node returns text dimensions" do
      node = RenderNode.text("Hello")
      {width, height} = Helpers.compute_node_size(node)
      assert width == 5
      assert height == 1
    end

    test "empty node returns zero" do
      node = RenderNode.empty()
      {width, height} = Helpers.compute_node_size(node)
      assert width == 0
      assert height == 0
    end

    test "box with explicit size" do
      node = RenderNode.box([], width: 20, height: 10)
      {width, height} = Helpers.compute_node_size(node)
      assert width == 20
      assert height == 10
    end

    test "box without size returns auto" do
      node = RenderNode.box([])
      {width, height} = Helpers.compute_node_size(node)
      assert width == :auto
      assert height == :auto
    end

    test "node with nil content" do
      node = %RenderNode{type: :text, content: nil}
      {width, height} = Helpers.compute_node_size(node)
      assert width == 0
      assert height == 1
    end
  end

  describe "fits_in_rect?/2" do
    test "returns true when fits" do
      rect = %{x: 0, y: 0, width: 20, height: 10}
      assert Helpers.fits_in_rect?({10, 5}, rect)
    end

    test "returns true for exact fit" do
      rect = %{x: 0, y: 0, width: 20, height: 10}
      assert Helpers.fits_in_rect?({20, 10}, rect)
    end

    test "returns false when too wide" do
      rect = %{x: 0, y: 0, width: 20, height: 10}
      refute Helpers.fits_in_rect?({30, 5}, rect)
    end

    test "returns false when too tall" do
      rect = %{x: 0, y: 0, width: 20, height: 10}
      refute Helpers.fits_in_rect?({10, 15}, rect)
    end

    test "returns false when both exceed" do
      rect = %{x: 0, y: 0, width: 20, height: 10}
      refute Helpers.fits_in_rect?({30, 15}, rect)
    end

    test "zero size always fits" do
      rect = %{x: 0, y: 0, width: 20, height: 10}
      assert Helpers.fits_in_rect?({0, 0}, rect)
    end
  end

  describe "truncate_text/2" do
    test "returns text unchanged if shorter than max" do
      assert Helpers.truncate_text("Hello", 10) == "Hello"
    end

    test "returns text unchanged if equal to max" do
      assert Helpers.truncate_text("Hello", 5) == "Hello"
    end

    test "truncates to max width" do
      assert Helpers.truncate_text("Hello, World!", 5) == "Hello"
    end

    test "handles zero width" do
      assert Helpers.truncate_text("Hello", 0) == ""
    end

    test "handles empty string" do
      assert Helpers.truncate_text("", 10) == ""
    end
  end
end
