defmodule Docs.WidgetCompatibilityTest do
  @moduledoc """
  Tests that code examples in widget-compatibility.md compile and work correctly.
  """
  use TermUI.TestCase, async: true

  alias TermUI.CharacterSet
  alias TermUI.Event
  alias TermUI.Renderer.Style
  alias TermUI.Theme
  alias TermUI.Widgets.ContextMenu
  alias TermUI.Widgets.ContextMenu.Inline, as: ContextMenuInline
  alias TermUI.Widgets.SplitPane
  alias TermUI.Widgets.TextInput

  setup do
    # Start Theme server for tests
    case Theme.start_link(theme: :dark) do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> :ok
    end

    :ok
  end

  describe "documentation code examples" do
    test "TextInput.new example compiles" do
      props = TextInput.new(placeholder: "Search...")
      assert props.placeholder == "Search..."
    end

    test "TextInput.Line.new example compiles" do
      props = TermUI.Widgets.TextInput.Line.new(prompt: "> ", label: "Enter command")
      assert props.prompt == "> "
      assert props.label == "Enter command"
    end

    test "ContextMenu.new example compiles" do
      items = [
        ContextMenu.action(:copy, "Copy"),
        ContextMenu.action(:paste, "Paste")
      ]

      props = ContextMenu.new(items: items, position: {10, 20})
      assert props.position == {10, 20}
    end

    test "ContextMenu.Inline.new example compiles" do
      # ContextMenu.Inline uses ContextMenu.action for item creation
      items = [
        ContextMenu.action(:copy, "Copy"),
        ContextMenu.action(:paste, "Paste")
      ]

      props = ContextMenuInline.new(items: items)
      assert is_list(props.items)
    end

    test "SplitPane.new example compiles" do
      import TermUI.Component.RenderNode

      # SplitPane requires :panes list, not :left/:right
      props =
        SplitPane.new(
          orientation: :horizontal,
          panes: [
            %{id: :left, content: text("Left panel"), size: 0.5},
            %{id: :right, content: text("Right panel"), size: 0.5}
          ],
          ctrl_resize_step: 0.05,
          min_ratio: 0.1,
          max_ratio: 0.9
        )

      assert props.ctrl_resize_step == 0.05
      assert props.min_ratio == 0.1
      assert props.max_ratio == 0.9
    end

    test "Theme-based colors example compiles" do
      # Good - theme-based colors
      style = Style.new() |> Style.fg(Theme.get_semantic(:error))
      assert %Style{} = style

      # Component styles may or may not exist depending on theme
      # The important thing is the function works without raising
      _result = Theme.get_component_style(:list, :selected)
      assert true
    end

    test "CharacterSet-based border example compiles" do
      chars = CharacterSet.current_charset()
      width = 10
      border = chars.tl <> String.duplicate(chars.h_line, width) <> chars.tr

      assert is_binary(border)
      assert String.length(border) == width + 2
    end

    test "Event handling patterns compile" do
      # These patterns should compile (not necessarily run)
      state = %{cursor: 0, items: [1, 2, 3]}

      # Mouse event pattern
      mouse_event = %Event.Mouse{action: :click, button: :left, x: 5, y: 10}
      assert mouse_event.action == :click

      # Key event pattern
      key_event = %Event.Key{key: :enter}
      assert key_event.key == :enter

      down_event = %Event.Key{key: :down}
      assert down_event.key == :down

      # These would be in actual widget handlers
      assert state.cursor == 0
    end

    test "CharacterSet.current returns valid atom" do
      charset = CharacterSet.current()
      assert charset in [:unicode, :ascii]
    end

    test "CharacterSet provides all documented characters" do
      chars = CharacterSet.current_charset()

      # Box drawing
      assert Map.has_key?(chars, :tl)
      assert Map.has_key?(chars, :tr)
      assert Map.has_key?(chars, :bl)
      assert Map.has_key?(chars, :br)
      assert Map.has_key?(chars, :h_line)
      assert Map.has_key?(chars, :v_line)
      assert Map.has_key?(chars, :cross)

      # Arrows
      assert Map.has_key?(chars, :arrow_up)
      assert Map.has_key?(chars, :arrow_down)
      assert Map.has_key?(chars, :arrow_left)
      assert Map.has_key?(chars, :arrow_right)

      # Indicators
      assert Map.has_key?(chars, :check)
      assert Map.has_key?(chars, :cross_mark)
      assert Map.has_key?(chars, :bullet)
      assert Map.has_key?(chars, :pointer)

      # Progress
      assert Map.has_key?(chars, :bar_full)
      assert Map.has_key?(chars, :bar_empty)
      assert Map.has_key?(chars, :bar_levels)
      assert Map.has_key?(chars, :sparkline_levels)

      # Icons
      assert Map.has_key?(chars, :info)
      assert Map.has_key?(chars, :warning)
      assert Map.has_key?(chars, :loading)
    end

    test "Unicode character mappings are correct" do
      chars = CharacterSet.get(:unicode)

      assert chars.tl == "┌"
      assert chars.tr == "┐"
      assert chars.bl == "└"
      assert chars.br == "┘"
      assert chars.h_line == "─"
      assert chars.v_line == "│"
      assert chars.arrow_up == "↑"
      assert chars.arrow_down == "↓"
      assert chars.arrow_left == "←"
      assert chars.arrow_right == "→"
      assert chars.check == "✓"
      assert chars.cross_mark == "✗"
      assert chars.bar_full == "█"
      assert chars.bar_empty == "░"
    end

    test "ASCII character mappings are correct" do
      chars = CharacterSet.get(:ascii)

      assert chars.tl == "+"
      assert chars.tr == "+"
      assert chars.bl == "+"
      assert chars.br == "+"
      assert chars.h_line == "-"
      assert chars.v_line == "|"
      assert chars.arrow_up == "^"
      assert chars.arrow_down == "v"
      assert chars.arrow_left == "<"
      assert chars.arrow_right == ">"
      assert chars.check == "x"
      assert chars.cross_mark == "X"
      assert chars.bar_full == "#"
      assert chars.bar_empty == "."
    end
  end
end
