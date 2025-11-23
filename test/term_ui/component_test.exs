defmodule TermUI.ComponentTest do
  use ExUnit.Case, async: true

  alias TermUI.Component.RenderNode
  alias TermUI.Renderer.Style

  # Test component that implements only required callback
  defmodule MinimalLabel do
    use TermUI.Component

    @impl true
    def render(props, _area) do
      text(props[:text] || "")
    end
  end

  # Test component with all optional callbacks
  defmodule FullLabel do
    use TermUI.Component

    @impl true
    def describe do
      %{
        name: "FullLabel",
        description: "A label with all callbacks",
        version: "1.0.0"
      }
    end

    @impl true
    def default_props do
      %{
        text: "Default Text",
        style: nil
      }
    end

    @impl true
    def render(props, _area) do
      merged = merge_props(props)

      if merged.style do
        styled(text(merged.text), merged.style)
      else
        text(merged.text)
      end
    end
  end

  # Test component using render tree builders
  defmodule ComplexComponent do
    use TermUI.Component

    @impl true
    def render(props, area) do
      box([
        text("Header"),
        stack(:vertical, [
          text("Item 1"),
          text("Item 2"),
          text("Item 3")
        ]),
        text("Width: #{area.width}")
      ])
    end
  end

  describe "Component behaviour implementation" do
    test "minimal component only needs render callback" do
      area = %{x: 0, y: 0, width: 80, height: 24}
      result = MinimalLabel.render(%{text: "Hello"}, area)
      assert result.type == :text
      assert result.content == "Hello"
    end

    test "render receives correct props" do
      area = %{x: 0, y: 0, width: 80, height: 24}
      result = MinimalLabel.render(%{text: "Test"}, area)
      assert result.content == "Test"
    end

    test "render receives correct area" do
      area = %{x: 5, y: 10, width: 40, height: 12}
      result = ComplexComponent.render(%{}, area)
      # Find the text node that shows width
      width_text =
        Enum.find(result.children, fn child ->
          child.type == :text and String.contains?(child.content || "", "Width")
        end)

      assert width_text.content == "Width: 40"
    end
  end

  describe "__using__ macro" do
    test "injects default describe implementation" do
      info = MinimalLabel.describe()
      assert info.name == "TermUI.ComponentTest.MinimalLabel"
      assert info.description == nil
      assert info.version == nil
    end

    test "injects default default_props implementation" do
      props = MinimalLabel.default_props()
      assert props == %{}
    end

    test "injects merge_props helper" do
      merged = MinimalLabel.merge_props(%{custom: "value"})
      assert merged == %{custom: "value"}
    end

    test "imports RenderNode alias" do
      # Verify that we can use text() directly in render
      area = %{x: 0, y: 0, width: 80, height: 24}
      result = MinimalLabel.render(%{text: "Test"}, area)
      assert %RenderNode{} = result
    end
  end

  describe "optional callbacks" do
    test "describe returns component metadata" do
      info = FullLabel.describe()
      assert info.name == "FullLabel"
      assert info.description == "A label with all callbacks"
      assert info.version == "1.0.0"
    end

    test "default_props returns defaults" do
      props = FullLabel.default_props()
      assert props.text == "Default Text"
      assert props.style == nil
    end

    test "default_props merges with passed props" do
      merged = FullLabel.merge_props(%{style: Style.new() |> Style.fg(:red)})
      assert merged.text == "Default Text"
      assert merged.style.fg == :red
    end

    test "passed props override defaults" do
      merged = FullLabel.merge_props(%{text: "Custom"})
      assert merged.text == "Custom"
    end
  end

  describe "render tree output" do
    test "can return RenderNode struct" do
      area = %{x: 0, y: 0, width: 80, height: 24}
      result = MinimalLabel.render(%{text: "Hello"}, area)
      assert %RenderNode{} = result
    end

    test "can build complex trees with builders" do
      area = %{x: 0, y: 0, width: 80, height: 24}
      result = ComplexComponent.render(%{}, area)

      assert result.type == :box
      assert length(result.children) == 3

      # Check nested stack
      stack_child = Enum.at(result.children, 1)
      assert stack_child.type == :stack
      assert stack_child.direction == :vertical
      assert length(stack_child.children) == 3
    end

    test "styled helper wraps content" do
      area = %{x: 0, y: 0, width: 80, height: 24}
      style = Style.new() |> Style.fg(:blue)
      result = FullLabel.render(%{style: style}, area)

      # styled() wraps in a box
      assert result.type == :box
      assert result.style.fg == :blue
      assert hd(result.children).content == "Default Text"
    end
  end

  describe "edge cases" do
    test "empty props uses defaults" do
      area = %{x: 0, y: 0, width: 80, height: 24}
      result = MinimalLabel.render(%{}, area)
      assert result.content == ""
    end

    test "nil text prop uses empty string" do
      area = %{x: 0, y: 0, width: 80, height: 24}
      result = MinimalLabel.render(%{text: nil}, area)
      assert result.content == ""
    end

    test "zero size area" do
      area = %{x: 0, y: 0, width: 0, height: 0}
      result = ComplexComponent.render(%{}, area)
      assert result.type == :box
    end
  end
end
