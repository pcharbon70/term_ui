defmodule TermUI.Widgets.ViewportTest do
  use ExUnit.Case, async: true

  alias TermUI.Widgets.Viewport
  alias TermUI.Event

  describe "init/1" do
    test "initializes with default values" do
      props = Viewport.new([])
      {:ok, state} = Viewport.init(props)

      assert state.width == 40
      assert state.height == 20
      assert state.scroll_x == 0
      assert state.scroll_y == 0
      assert state.scroll_bars == :both
    end

    test "initializes with custom values" do
      props = Viewport.new(
        width: 60,
        height: 30,
        scroll_x: 10,
        scroll_y: 20,
        content_width: 200,
        content_height: 100,
        scroll_bars: :vertical
      )
      {:ok, state} = Viewport.init(props)

      assert state.width == 60
      assert state.height == 30
      assert state.scroll_x == 10
      assert state.scroll_y == 20
      assert state.scroll_bars == :vertical
    end

    test "clamps initial scroll position" do
      props = Viewport.new(
        width: 40,
        height: 20,
        content_width: 50,
        content_height: 30,
        scroll_x: 100,
        scroll_y: 100
      )
      {:ok, state} = Viewport.init(props)

      # Should be clamped to max scroll
      assert state.scroll_x <= 50 - 39  # content_width - viewport_width
      assert state.scroll_y <= 30 - 19  # content_height - viewport_height
    end
  end

  describe "keyboard scrolling" do
    test "scrolls down with arrow key" do
      props = Viewport.new(content_height: 100, height: 20)
      {:ok, state} = Viewport.init(props)

      {:ok, state} = Viewport.handle_event(%Event.Key{key: :down}, state)
      assert state.scroll_y == 1
    end

    test "scrolls up with arrow key" do
      props = Viewport.new(content_height: 100, height: 20, scroll_y: 10)
      {:ok, state} = Viewport.init(props)

      {:ok, state} = Viewport.handle_event(%Event.Key{key: :up}, state)
      assert state.scroll_y == 9
    end

    test "scrolls right with arrow key" do
      props = Viewport.new(content_width: 100, width: 40)
      {:ok, state} = Viewport.init(props)

      {:ok, state} = Viewport.handle_event(%Event.Key{key: :right}, state)
      assert state.scroll_x == 1
    end

    test "scrolls left with arrow key" do
      props = Viewport.new(content_width: 100, width: 40, scroll_x: 10)
      {:ok, state} = Viewport.init(props)

      {:ok, state} = Viewport.handle_event(%Event.Key{key: :left}, state)
      assert state.scroll_x == 9
    end

    test "page down scrolls by page" do
      props = Viewport.new(content_height: 100, height: 20)
      {:ok, state} = Viewport.init(props)

      {:ok, state} = Viewport.handle_event(%Event.Key{key: :page_down}, state)
      assert state.scroll_y == 20
    end

    test "page up scrolls by page" do
      props = Viewport.new(content_height: 100, height: 20, scroll_y: 50)
      {:ok, state} = Viewport.init(props)

      {:ok, state} = Viewport.handle_event(%Event.Key{key: :page_up}, state)
      assert state.scroll_y == 30
    end

    test "home scrolls to top" do
      props = Viewport.new(content_height: 100, height: 20, scroll_y: 50)
      {:ok, state} = Viewport.init(props)

      {:ok, state} = Viewport.handle_event(%Event.Key{key: :home, modifiers: []}, state)
      assert state.scroll_y == 0
    end

    test "end scrolls to bottom" do
      props = Viewport.new(content_height: 100, height: 20)
      {:ok, state} = Viewport.init(props)

      {:ok, state} = Viewport.handle_event(%Event.Key{key: :end, modifiers: []}, state)
      assert state.scroll_y == 81  # 100 - 19
    end

    test "ctrl+home scrolls to top-left" do
      props = Viewport.new(
        content_width: 100,
        content_height: 100,
        width: 40,
        height: 20,
        scroll_x: 50,
        scroll_y: 50
      )
      {:ok, state} = Viewport.init(props)

      {:ok, state} = Viewport.handle_event(%Event.Key{key: :home, modifiers: [:ctrl]}, state)
      assert state.scroll_x == 0
      assert state.scroll_y == 0
    end

    test "ctrl+end scrolls to bottom-right" do
      props = Viewport.new(
        content_width: 100,
        content_height: 100,
        width: 40,
        height: 20
      )
      {:ok, state} = Viewport.init(props)

      {:ok, state} = Viewport.handle_event(%Event.Key{key: :end, modifiers: [:ctrl]}, state)
      assert state.scroll_x == 61  # 100 - 39
      assert state.scroll_y == 81  # 100 - 19
    end
  end

  describe "mouse scrolling" do
    test "scroll up with mouse wheel" do
      props = Viewport.new(content_height: 100, height: 20, scroll_y: 10)
      {:ok, state} = Viewport.init(props)

      {:ok, state} = Viewport.handle_event(%Event.Mouse{action: :scroll_up}, state)
      assert state.scroll_y < 10
    end

    test "scroll down with mouse wheel" do
      props = Viewport.new(content_height: 100, height: 20)
      {:ok, state} = Viewport.init(props)

      {:ok, state} = Viewport.handle_event(%Event.Mouse{action: :scroll_down}, state)
      assert state.scroll_y > 0
    end
  end

  describe "scroll clamping" do
    test "does not scroll below 0" do
      props = Viewport.new(content_height: 100, height: 20, scroll_y: 0)
      {:ok, state} = Viewport.init(props)

      {:ok, state} = Viewport.handle_event(%Event.Key{key: :up}, state)
      assert state.scroll_y == 0
    end

    test "does not scroll past content" do
      props = Viewport.new(content_height: 30, height: 20, scroll_y: 11)
      {:ok, state} = Viewport.init(props)

      {:ok, state} = Viewport.handle_event(%Event.Key{key: :down}, state)
      # Should be clamped to max
      assert state.scroll_y <= 11
    end
  end

  describe "render/2" do
    test "renders viewport container" do
      props = Viewport.new(width: 40, height: 20, scroll_bars: :none)
      {:ok, state} = Viewport.init(props)

      result = Viewport.render(state, %{width: 80, height: 24, x: 0, y: 0})
      assert result.type == :viewport
    end

    test "renders with vertical scroll bar" do
      props = Viewport.new(width: 40, height: 20, scroll_bars: :vertical)
      {:ok, state} = Viewport.init(props)

      result = Viewport.render(state, %{width: 80, height: 24, x: 0, y: 0})
      assert result.type == :stack
      assert result.direction == :horizontal
    end

    test "renders with horizontal scroll bar" do
      props = Viewport.new(width: 40, height: 20, scroll_bars: :horizontal)
      {:ok, state} = Viewport.init(props)

      result = Viewport.render(state, %{width: 80, height: 24, x: 0, y: 0})
      assert result.type == :stack
      assert result.direction == :vertical
    end

    test "renders with both scroll bars" do
      props = Viewport.new(width: 40, height: 20, scroll_bars: :both)
      {:ok, state} = Viewport.init(props)

      result = Viewport.render(state, %{width: 80, height: 24, x: 0, y: 0})
      assert result.type == :stack
      assert result.direction == :vertical
    end
  end

  describe "public API" do
    test "get_scroll returns current position" do
      props = Viewport.new(scroll_x: 10, scroll_y: 20)
      {:ok, state} = Viewport.init(props)

      assert Viewport.get_scroll(state) == {10, 20}
    end

    test "set_scroll updates position" do
      props = Viewport.new(content_width: 100, content_height: 100)
      {:ok, state} = Viewport.init(props)

      state = Viewport.set_scroll(state, 30, 40)
      assert Viewport.get_scroll(state) == {30, 40}
    end

    test "set_scroll clamps to bounds" do
      props = Viewport.new(content_width: 50, content_height: 50, width: 40, height: 20)
      {:ok, state} = Viewport.init(props)

      state = Viewport.set_scroll(state, 100, 100)
      {x, y} = Viewport.get_scroll(state)
      assert x <= 50 - 39
      assert y <= 50 - 19
    end

    test "scroll_into_view scrolls to make position visible" do
      props = Viewport.new(
        content_width: 100,
        content_height: 100,
        width: 40,
        height: 20
      )
      {:ok, state} = Viewport.init(props)

      state = Viewport.scroll_into_view(state, 50, 50)
      {x, y} = Viewport.get_scroll(state)
      # Position should now be visible
      assert x <= 50 and x + 39 > 50
      assert y <= 50 and y + 19 > 50
    end

    test "can_scroll_vertical? returns true when content exceeds viewport" do
      props = Viewport.new(content_height: 100, height: 20)
      {:ok, state} = Viewport.init(props)

      assert Viewport.can_scroll_vertical?(state)
    end

    test "can_scroll_vertical? returns false when content fits" do
      props = Viewport.new(content_height: 10, height: 20)
      {:ok, state} = Viewport.init(props)

      refute Viewport.can_scroll_vertical?(state)
    end

    test "visible_fraction_vertical returns correct ratio" do
      props = Viewport.new(content_height: 100, height: 20, scroll_bars: :none)
      {:ok, state} = Viewport.init(props)

      # viewport_height is 20, content is 100
      assert_in_delta Viewport.visible_fraction_vertical(state), 0.2, 0.01
    end

    test "set_content_size updates dimensions" do
      props = Viewport.new([])
      {:ok, state} = Viewport.init(props)

      state = Viewport.set_content_size(state, 200, 300)
      assert state.content_width == 200
      assert state.content_height == 300
    end
  end
end
