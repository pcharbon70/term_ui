defmodule TermUI.Widgets.CanvasTest do
  use ExUnit.Case, async: true

  alias TermUI.Widgets.Canvas

  describe "init/1" do
    test "initializes with default values" do
      props = Canvas.new([])
      {:ok, state} = Canvas.init(props)

      assert state.width == 40
      assert state.height == 20
      assert state.default_char == " "
    end

    test "initializes with custom values" do
      props =
        Canvas.new(
          width: 60,
          height: 30,
          default_char: "."
        )

      {:ok, state} = Canvas.init(props)

      assert state.width == 60
      assert state.height == 30
      assert state.default_char == "."
    end

    test "creates empty buffer" do
      props = Canvas.new(width: 5, height: 5)
      {:ok, state} = Canvas.init(props)

      # All positions should have default char
      assert Canvas.get_char(state, 0, 0) == " "
      assert Canvas.get_char(state, 4, 4) == " "
    end
  end

  describe "set_char/4 and get_char/3" do
    test "sets and gets character at position" do
      props = Canvas.new(width: 10, height: 10)
      {:ok, state} = Canvas.init(props)

      state = Canvas.set_char(state, 5, 5, "X")
      assert Canvas.get_char(state, 5, 5) == "X"
    end

    test "ignores out of bounds positions" do
      props = Canvas.new(width: 10, height: 10)
      {:ok, state} = Canvas.init(props)

      # Should not crash
      state = Canvas.set_char(state, -1, 0, "X")
      state = Canvas.set_char(state, 0, -1, "X")
      state = Canvas.set_char(state, 100, 0, "X")
      state = Canvas.set_char(state, 0, 100, "X")

      assert state.width == 10
    end

    test "returns nil for out of bounds get" do
      props = Canvas.new(width: 10, height: 10)
      {:ok, state} = Canvas.init(props)

      assert Canvas.get_char(state, -1, 0) == nil
      assert Canvas.get_char(state, 100, 0) == nil
    end
  end

  describe "clear/1 and fill/2" do
    test "clear resets to default character" do
      props = Canvas.new(width: 5, height: 5)
      {:ok, state} = Canvas.init(props)

      state = Canvas.set_char(state, 2, 2, "X")
      state = Canvas.clear(state)

      assert Canvas.get_char(state, 2, 2) == " "
    end

    test "fill sets all positions to character" do
      props = Canvas.new(width: 5, height: 5)
      {:ok, state} = Canvas.init(props)

      state = Canvas.fill(state, "#")

      assert Canvas.get_char(state, 0, 0) == "#"
      assert Canvas.get_char(state, 4, 4) == "#"
      assert Canvas.get_char(state, 2, 2) == "#"
    end
  end

  describe "draw_text/4" do
    test "draws text at position" do
      props = Canvas.new(width: 20, height: 5)
      {:ok, state} = Canvas.init(props)

      state = Canvas.draw_text(state, 5, 2, "Hello")

      assert Canvas.get_char(state, 5, 2) == "H"
      assert Canvas.get_char(state, 6, 2) == "e"
      assert Canvas.get_char(state, 7, 2) == "l"
      assert Canvas.get_char(state, 8, 2) == "l"
      assert Canvas.get_char(state, 9, 2) == "o"
    end

    test "clips text that goes past edge" do
      props = Canvas.new(width: 10, height: 5)
      {:ok, state} = Canvas.init(props)

      state = Canvas.draw_text(state, 7, 0, "Hello")

      assert Canvas.get_char(state, 7, 0) == "H"
      assert Canvas.get_char(state, 8, 0) == "e"
      assert Canvas.get_char(state, 9, 0) == "l"
      # Rest clipped
    end
  end

  describe "draw_hline/5" do
    test "draws horizontal line" do
      props = Canvas.new(width: 20, height: 5)
      {:ok, state} = Canvas.init(props)

      state = Canvas.draw_hline(state, 2, 2, 5, "─")

      assert Canvas.get_char(state, 2, 2) == "─"
      assert Canvas.get_char(state, 3, 2) == "─"
      assert Canvas.get_char(state, 4, 2) == "─"
      assert Canvas.get_char(state, 5, 2) == "─"
      assert Canvas.get_char(state, 6, 2) == "─"
    end
  end

  describe "draw_vline/5" do
    test "draws vertical line" do
      props = Canvas.new(width: 20, height: 10)
      {:ok, state} = Canvas.init(props)

      state = Canvas.draw_vline(state, 5, 2, 4, "│")

      assert Canvas.get_char(state, 5, 2) == "│"
      assert Canvas.get_char(state, 5, 3) == "│"
      assert Canvas.get_char(state, 5, 4) == "│"
      assert Canvas.get_char(state, 5, 5) == "│"
    end
  end

  describe "draw_line/6" do
    test "draws diagonal line" do
      props = Canvas.new(width: 10, height: 10)
      {:ok, state} = Canvas.init(props)

      state = Canvas.draw_line(state, 0, 0, 4, 4, "*")

      # Should have dots along diagonal
      assert Canvas.get_char(state, 0, 0) == "*"
      assert Canvas.get_char(state, 4, 4) == "*"
    end

    test "draws horizontal line with Bresenham" do
      props = Canvas.new(width: 10, height: 5)
      {:ok, state} = Canvas.init(props)

      state = Canvas.draw_line(state, 0, 2, 5, 2, "-")

      for x <- 0..5 do
        assert Canvas.get_char(state, x, 2) == "-"
      end
    end

    test "draws vertical line with Bresenham" do
      props = Canvas.new(width: 5, height: 10)
      {:ok, state} = Canvas.init(props)

      state = Canvas.draw_line(state, 2, 0, 2, 5, "|")

      for y <- 0..5 do
        assert Canvas.get_char(state, 2, y) == "|"
      end
    end
  end

  describe "draw_rect/12" do
    test "draws rectangle outline" do
      props = Canvas.new(width: 20, height: 10)
      {:ok, state} = Canvas.init(props)

      state = Canvas.draw_rect(state, 2, 2, 8, 5)

      # Corners
      assert Canvas.get_char(state, 2, 2) == "┌"
      assert Canvas.get_char(state, 9, 2) == "┐"
      assert Canvas.get_char(state, 2, 6) == "└"
      assert Canvas.get_char(state, 9, 6) == "┘"

      # Edges
      assert Canvas.get_char(state, 5, 2) == "─"
      assert Canvas.get_char(state, 5, 6) == "─"
      assert Canvas.get_char(state, 2, 4) == "│"
      assert Canvas.get_char(state, 9, 4) == "│"
    end
  end

  describe "fill_rect/6" do
    test "fills rectangle area" do
      props = Canvas.new(width: 20, height: 10)
      {:ok, state} = Canvas.init(props)

      state = Canvas.fill_rect(state, 2, 2, 3, 3, "#")

      for x <- 2..4, y <- 2..4 do
        assert Canvas.get_char(state, x, y) == "#"
      end

      # Outside should be empty
      assert Canvas.get_char(state, 1, 2) == " "
      assert Canvas.get_char(state, 5, 2) == " "
    end
  end

  describe "Braille drawing" do
    test "dots_to_braille converts coordinates" do
      # Single dot at top-left
      result = Canvas.dots_to_braille([{0, 0}])
      assert result == "⠁"

      # Single dot at top-right
      result = Canvas.dots_to_braille([{1, 0}])
      assert result == "⠈"

      # Multiple dots
      result = Canvas.dots_to_braille([{0, 0}, {1, 0}])
      assert result == "⠉"
    end

    test "empty_braille returns blank character" do
      result = Canvas.empty_braille()
      assert result == "⠀"
    end

    test "full_braille returns all-dots character" do
      result = Canvas.full_braille()
      assert result == "⣿"
    end

    test "set_dot and clear_dot modify braille buffer" do
      props = Canvas.new(width: 10, height: 10)
      {:ok, state} = Canvas.init(props)

      state = Canvas.set_dot(state, 0, 0)
      assert Map.has_key?(state.braille_buffer, {0, 0, 0, 0})

      state = Canvas.clear_dot(state, 0, 0)
      refute Map.has_key?(state.braille_buffer, {0, 0, 0, 0})
    end

    test "braille_resolution returns correct dimensions" do
      props = Canvas.new(width: 40, height: 20)
      {:ok, state} = Canvas.init(props)

      {w, h} = Canvas.braille_resolution(state)
      # 40 * 2
      assert w == 80
      # 20 * 4
      assert h == 80
    end

    test "clear_braille removes all dots" do
      props = Canvas.new(width: 10, height: 10)
      {:ok, state} = Canvas.init(props)

      state = Canvas.set_dot(state, 0, 0)
      state = Canvas.set_dot(state, 1, 1)
      state = Canvas.clear_braille(state)

      assert state.braille_buffer == %{}
    end
  end

  describe "render/2" do
    test "renders canvas to stack of text nodes" do
      props = Canvas.new(width: 5, height: 3)
      {:ok, state} = Canvas.init(props)

      result = Canvas.render(state, %{width: 80, height: 24, x: 0, y: 0})

      assert result.type == :stack
      assert result.direction == :vertical
      assert length(result.children) == 3
    end

    test "applies on_draw callback" do
      on_draw = fn state ->
        Canvas.set_char(state, 0, 0, "X")
      end

      props = Canvas.new(width: 5, height: 3, on_draw: on_draw)
      {:ok, state} = Canvas.init(props)

      result = Canvas.render(state, %{width: 80, height: 24, x: 0, y: 0})

      # First row should have X
      [first | _] = result.children
      assert String.starts_with?(first.content, "X")
    end
  end

  describe "public API" do
    test "resize updates dimensions" do
      props = Canvas.new(width: 10, height: 10)
      {:ok, state} = Canvas.init(props)

      state = Canvas.resize(state, 20, 15)
      assert state.width == 20
      assert state.height == 15
    end

    test "draw creates and draws on canvas" do
      state =
        Canvas.draw(10, 5, fn canvas ->
          Canvas.set_char(canvas, 0, 0, "X")
        end)

      assert Canvas.get_char(state, 0, 0) == "X"
      assert state.width == 10
      assert state.height == 5
    end

    test "to_strings converts canvas to string list" do
      props = Canvas.new(width: 5, height: 2)
      {:ok, state} = Canvas.init(props)

      state = Canvas.draw_text(state, 0, 0, "Hello")

      lines = Canvas.to_strings(state)
      assert length(lines) == 2
      assert Enum.at(lines, 0) == "Hello"
    end
  end

  describe "complex drawing" do
    test "can draw box with text" do
      props = Canvas.new(width: 12, height: 5)
      {:ok, state} = Canvas.init(props)

      state =
        state
        |> Canvas.draw_rect(0, 0, 12, 5)
        |> Canvas.draw_text(2, 2, "Content")

      # Verify box corners
      assert Canvas.get_char(state, 0, 0) == "┌"
      assert Canvas.get_char(state, 11, 0) == "┐"

      # Verify text
      assert Canvas.get_char(state, 2, 2) == "C"
    end

    test "can chain multiple operations" do
      state =
        Canvas.draw(20, 10, fn canvas ->
          canvas
          |> Canvas.fill(".")
          |> Canvas.draw_rect(2, 2, 10, 5)
          |> Canvas.fill_rect(3, 3, 8, 3, " ")
          |> Canvas.draw_text(4, 4, "Hi")
        end)

      # Background should be dots
      assert Canvas.get_char(state, 0, 0) == "."

      # Inside rect should be space (before text)
      assert Canvas.get_char(state, 6, 4) == " "

      # Text should be visible
      assert Canvas.get_char(state, 4, 4) == "H"
      assert Canvas.get_char(state, 5, 4) == "i"
    end
  end
end
