defmodule TermUI.Component.RenderNodeTest do
  use ExUnit.Case, async: true

  alias TermUI.Component.RenderNode
  alias TermUI.Renderer.Style

  describe "empty/0" do
    test "creates empty node" do
      node = RenderNode.empty()
      assert node.type == :empty
      assert node.content == nil
      assert node.children == []
    end
  end

  describe "text/1 and text/2" do
    test "creates text node with content" do
      node = RenderNode.text("Hello")
      assert node.type == :text
      assert node.content == "Hello"
      assert node.style == nil
    end

    test "creates text node with style" do
      style = Style.new() |> Style.fg(:red)
      node = RenderNode.text("Error", style)
      assert node.type == :text
      assert node.content == "Error"
      assert node.style.fg == :red
    end
  end

  describe "box/1 and box/2" do
    test "creates box with children" do
      children = [RenderNode.text("Content")]
      node = RenderNode.box(children)
      assert node.type == :box
      assert length(node.children) == 1
      assert hd(node.children).content == "Content"
    end

    test "creates box with style option" do
      style = Style.new() |> Style.bg(:blue)
      node = RenderNode.box([], style: style)
      assert node.style.bg == :blue
    end

    test "creates box with dimensions" do
      node = RenderNode.box([], width: 20, height: 10)
      assert node.width == 20
      assert node.height == 10
    end

    test "box with empty children" do
      node = RenderNode.box([])
      assert node.type == :box
      assert node.children == []
    end
  end

  describe "stack/2 and stack/3" do
    test "creates vertical stack" do
      children = [RenderNode.text("Top"), RenderNode.text("Bottom")]
      node = RenderNode.stack(:vertical, children)
      assert node.type == :stack
      assert node.direction == :vertical
      assert length(node.children) == 2
    end

    test "creates horizontal stack" do
      children = [RenderNode.text("Left"), RenderNode.text("Right")]
      node = RenderNode.stack(:horizontal, children)
      assert node.direction == :horizontal
    end

    test "creates stack with options" do
      style = Style.new() |> Style.bg(:black)
      node = RenderNode.stack(:vertical, [], style: style, width: 30)
      assert node.style.bg == :black
      assert node.width == 30
    end
  end

  describe "styled/2" do
    test "wraps node in styled box" do
      inner = RenderNode.text("Hello")
      style = Style.new() |> Style.fg(:red)
      node = RenderNode.styled(inner, style)

      assert node.type == :box
      assert node.style.fg == :red
      assert length(node.children) == 1
      assert hd(node.children).content == "Hello"
    end
  end

  describe "width/2 and height/2" do
    test "sets width on node" do
      node = RenderNode.box([]) |> RenderNode.width(20)
      assert node.width == 20
    end

    test "sets height on node" do
      node = RenderNode.box([]) |> RenderNode.height(10)
      assert node.height == 10
    end

    test "accepts :auto as width" do
      node = RenderNode.box([]) |> RenderNode.width(:auto)
      assert node.width == :auto
    end

    test "accepts :auto as height" do
      node = RenderNode.box([]) |> RenderNode.height(:auto)
      assert node.height == :auto
    end

    test "chaining width and height" do
      node =
        RenderNode.box([])
        |> RenderNode.width(20)
        |> RenderNode.height(10)

      assert node.width == 20
      assert node.height == 10
    end
  end

  describe "empty?/1" do
    test "returns true for empty node" do
      assert RenderNode.empty?(RenderNode.empty())
    end

    test "returns false for text node" do
      refute RenderNode.empty?(RenderNode.text("Hello"))
    end

    test "returns false for box node" do
      refute RenderNode.empty?(RenderNode.box([]))
    end

    test "returns false for stack node" do
      refute RenderNode.empty?(RenderNode.stack(:vertical, []))
    end
  end

  describe "child_count/1" do
    test "returns 0 for text node" do
      assert RenderNode.child_count(RenderNode.text("Hello")) == 0
    end

    test "returns 0 for empty node" do
      assert RenderNode.child_count(RenderNode.empty()) == 0
    end

    test "returns count for box with children" do
      children = [RenderNode.text("A"), RenderNode.text("B"), RenderNode.text("C")]
      node = RenderNode.box(children)
      assert RenderNode.child_count(node) == 3
    end

    test "returns count for stack with children" do
      children = [RenderNode.text("A"), RenderNode.text("B")]
      node = RenderNode.stack(:vertical, children)
      assert RenderNode.child_count(node) == 2
    end
  end
end
