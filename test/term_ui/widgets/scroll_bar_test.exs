defmodule TermUI.Widgets.ScrollBarTest do
  use ExUnit.Case, async: true

  alias TermUI.Widgets.ScrollBar
  alias TermUI.Event

  describe "init/1" do
    test "initializes with default values" do
      props = ScrollBar.new([])
      {:ok, state} = ScrollBar.init(props)

      assert state.orientation == :vertical
      assert state.total == 100
      assert state.visible == 20
      assert state.position == 0
      assert state.length == 20
    end

    test "initializes with custom values" do
      props =
        ScrollBar.new(
          orientation: :horizontal,
          total: 200,
          visible: 50,
          position: 25,
          length: 30
        )

      {:ok, state} = ScrollBar.init(props)

      assert state.orientation == :horizontal
      assert state.total == 200
      assert state.visible == 50
      assert state.position == 25
      assert state.length == 30
    end

    test "clamps initial position" do
      props =
        ScrollBar.new(
          total: 100,
          visible: 20,
          position: 200
        )

      {:ok, state} = ScrollBar.init(props)

      # Should be clamped to max (100 - 20 = 80)
      assert state.position == 80
    end
  end

  describe "keyboard scrolling" do
    test "scrolls down with arrow key (vertical)" do
      props = ScrollBar.new(orientation: :vertical)
      {:ok, state} = ScrollBar.init(props)

      {:ok, state} = ScrollBar.handle_event(%Event.Key{key: :down}, state)
      assert state.position == 1
    end

    test "scrolls up with arrow key (vertical)" do
      props = ScrollBar.new(orientation: :vertical, position: 10)
      {:ok, state} = ScrollBar.init(props)

      {:ok, state} = ScrollBar.handle_event(%Event.Key{key: :up}, state)
      assert state.position == 9
    end

    test "scrolls right with arrow key (horizontal)" do
      props = ScrollBar.new(orientation: :horizontal)
      {:ok, state} = ScrollBar.init(props)

      {:ok, state} = ScrollBar.handle_event(%Event.Key{key: :right}, state)
      assert state.position == 1
    end

    test "scrolls left with arrow key (horizontal)" do
      props = ScrollBar.new(orientation: :horizontal, position: 10)
      {:ok, state} = ScrollBar.init(props)

      {:ok, state} = ScrollBar.handle_event(%Event.Key{key: :left}, state)
      assert state.position == 9
    end

    test "page down scrolls by visible amount" do
      props = ScrollBar.new(visible: 20)
      {:ok, state} = ScrollBar.init(props)

      {:ok, state} = ScrollBar.handle_event(%Event.Key{key: :page_down}, state)
      assert state.position == 20
    end

    test "page up scrolls by visible amount" do
      props = ScrollBar.new(visible: 20, position: 50)
      {:ok, state} = ScrollBar.init(props)

      {:ok, state} = ScrollBar.handle_event(%Event.Key{key: :page_up}, state)
      assert state.position == 30
    end

    test "home scrolls to start" do
      props = ScrollBar.new(position: 50)
      {:ok, state} = ScrollBar.init(props)

      {:ok, state} = ScrollBar.handle_event(%Event.Key{key: :home}, state)
      assert state.position == 0
    end

    test "end scrolls to end" do
      props = ScrollBar.new(total: 100, visible: 20)
      {:ok, state} = ScrollBar.init(props)

      {:ok, state} = ScrollBar.handle_event(%Event.Key{key: :end}, state)
      assert state.position == 80
    end
  end

  describe "mouse interaction" do
    test "starts dragging when clicking on thumb" do
      props = ScrollBar.new(length: 20)
      {:ok, state} = ScrollBar.init(props)

      # Click at top (where thumb is for position 0)
      {:ok, state} = ScrollBar.handle_event(%Event.Mouse{action: :click, x: 0, y: 0}, state)
      assert state.dragging == true
    end

    test "releases drag on mouse release" do
      props = ScrollBar.new([])
      {:ok, state} = ScrollBar.init(props)
      state = %{state | dragging: true}

      {:ok, state} = ScrollBar.handle_event(%Event.Mouse{action: :release}, state)
      assert state.dragging == false
    end
  end

  describe "render/2" do
    test "renders vertical scroll bar" do
      props = ScrollBar.new(orientation: :vertical, length: 10)
      {:ok, state} = ScrollBar.init(props)

      result = ScrollBar.render(state, %{width: 80, height: 24, x: 0, y: 0})
      assert result.type == :stack
      assert result.direction == :vertical
      assert length(result.children) == 10
    end

    test "renders horizontal scroll bar" do
      props = ScrollBar.new(orientation: :horizontal, length: 10)
      {:ok, state} = ScrollBar.init(props)

      result = ScrollBar.render(state, %{width: 80, height: 24, x: 0, y: 0})
      assert result.type == :text
    end

    test "uses custom track and thumb characters" do
      props =
        ScrollBar.new(
          orientation: :horizontal,
          length: 10,
          track_char: "-",
          thumb_char: "#"
        )

      {:ok, state} = ScrollBar.init(props)

      result = ScrollBar.render(state, %{width: 80, height: 24, x: 0, y: 0})
      assert String.contains?(result.content, "#")
      assert String.contains?(result.content, "-")
    end

    test "thumb size proportional to visible fraction" do
      # Large visible fraction = large thumb
      props =
        ScrollBar.new(
          orientation: :horizontal,
          total: 100,
          visible: 80,
          length: 20
        )

      {:ok, state} = ScrollBar.init(props)

      result = ScrollBar.render(state, %{width: 80, height: 24, x: 0, y: 0})
      thumb_count = result.content |> String.graphemes() |> Enum.count(&(&1 == "█"))
      # 80% visible should give large thumb (80% of 20 = 16)
      assert thumb_count >= 15
    end
  end

  describe "public API" do
    test "get_position returns current position" do
      props = ScrollBar.new(position: 42)
      {:ok, state} = ScrollBar.init(props)

      assert ScrollBar.get_position(state) == 42
    end

    test "set_position updates position" do
      props = ScrollBar.new([])
      {:ok, state} = ScrollBar.init(props)

      state = ScrollBar.set_position(state, 50)
      assert ScrollBar.get_position(state) == 50
    end

    test "set_position clamps to bounds" do
      props = ScrollBar.new(total: 100, visible: 20)
      {:ok, state} = ScrollBar.init(props)

      state = ScrollBar.set_position(state, 200)
      assert ScrollBar.get_position(state) == 80
    end

    test "set_dimensions updates total and visible" do
      props = ScrollBar.new([])
      {:ok, state} = ScrollBar.init(props)

      state = ScrollBar.set_dimensions(state, 200, 50)
      assert state.total == 200
      assert state.visible == 50
    end

    test "get_fraction returns scroll fraction" do
      props = ScrollBar.new(total: 100, visible: 20, position: 40)
      {:ok, state} = ScrollBar.init(props)

      # 40 / 80 = 0.5
      assert_in_delta ScrollBar.get_fraction(state), 0.5, 0.01
    end

    test "set_fraction updates position by fraction" do
      props = ScrollBar.new(total: 100, visible: 20)
      {:ok, state} = ScrollBar.init(props)

      state = ScrollBar.set_fraction(state, 0.5)
      # 0.5 * 80 = 40
      assert ScrollBar.get_position(state) == 40
    end

    test "can_scroll? returns true when content exceeds visible" do
      props = ScrollBar.new(total: 100, visible: 20)
      {:ok, state} = ScrollBar.init(props)

      assert ScrollBar.can_scroll?(state)
    end

    test "can_scroll? returns false when content fits" do
      props = ScrollBar.new(total: 20, visible: 100)
      {:ok, state} = ScrollBar.init(props)

      refute ScrollBar.can_scroll?(state)
    end

    test "visible_fraction returns correct ratio" do
      props = ScrollBar.new(total: 100, visible: 25)
      {:ok, state} = ScrollBar.init(props)

      assert_in_delta ScrollBar.visible_fraction(state), 0.25, 0.01
    end
  end

  describe "convenience constructors" do
    test "vertical/1 creates vertical scroll bar" do
      props = ScrollBar.vertical(length: 30)
      {:ok, state} = ScrollBar.init(props)

      assert state.orientation == :vertical
      assert state.length == 30
    end

    test "horizontal/1 creates horizontal scroll bar" do
      props = ScrollBar.horizontal(length: 40)
      {:ok, state} = ScrollBar.init(props)

      assert state.orientation == :horizontal
      assert state.length == 40
    end
  end

  describe "edge cases" do
    test "handles equal total and visible" do
      props = ScrollBar.new(total: 100, visible: 100)
      {:ok, state} = ScrollBar.init(props)

      # Should not crash and position should be 0
      assert state.position == 0
      assert ScrollBar.get_fraction(state) == 0.0
    end

    test "handles zero total" do
      props = ScrollBar.new(total: 0, visible: 20)
      {:ok, state} = ScrollBar.init(props)

      assert state.position == 0
    end

    test "scroll position stays clamped after dimension change" do
      props = ScrollBar.new(total: 100, visible: 20, position: 80)
      {:ok, state} = ScrollBar.init(props)

      # Reduce content size
      state = ScrollBar.set_dimensions(state, 50, 20)
      # Position should be clamped to new max (50 - 20 = 30)
      assert state.position <= 30
    end
  end
end
