defmodule Canvas.App do
  @moduledoc """
  Canvas Widget Example

  This example demonstrates how to use the TermUI.Widgets.Canvas widget
  for custom drawing with direct buffer access.

  Features demonstrated:
  - Basic canvas creation
  - Drawing text at positions
  - Drawing lines (horizontal, vertical, diagonal)
  - Drawing rectangles
  - Drawing with Braille characters for sub-character resolution

  Controls:
  - 1: Show basic shapes demo
  - 2: Show box drawing demo
  - 3: Show Braille drawing demo
  - C: Clear canvas
  - Q: Quit the application
  """

  use TermUI.Elm

  alias TermUI.Widgets.Canvas
  alias TermUI.Event
  alias TermUI.Renderer.Style

  # Canvas dimensions
  @canvas_width 50
  @canvas_height 15

  # ----------------------------------------------------------------------------
  # Component Callbacks
  # ----------------------------------------------------------------------------

  @doc """
  Initialize the component state.
  """
  def init(_opts) do
    %{
      demo: :shapes,
      canvas: create_canvas(:shapes)
    }
  end

  defp create_canvas(demo) do
    state = %{
      width: @canvas_width,
      height: @canvas_height,
      default_char: " ",
      buffer: create_empty_buffer(),
      braille_buffer: %{}
    }

    case demo do
      :shapes -> draw_shapes_demo(state)
      :boxes -> draw_boxes_demo(state)
      :braille -> draw_braille_demo(state)
    end
  end

  defp create_empty_buffer do
    for x <- 0..(@canvas_width - 1),
        y <- 0..(@canvas_height - 1),
        into: %{} do
      {{x, y}, " "}
    end
  end

  @doc """
  Convert keyboard events to messages.
  """
  def event_to_msg(%Event.Key{key: "1"}, _state), do: {:msg, {:set_demo, :shapes}}
  def event_to_msg(%Event.Key{key: "2"}, _state), do: {:msg, {:set_demo, :boxes}}
  def event_to_msg(%Event.Key{key: "3"}, _state), do: {:msg, {:set_demo, :braille}}
  def event_to_msg(%Event.Key{key: key}, _state) when key in ["c", "C"], do: {:msg, :clear}
  def event_to_msg(%Event.Key{key: key}, _state) when key in ["q", "Q"], do: {:msg, :quit}
  def event_to_msg(_event, _state), do: :ignore

  @doc """
  Update state based on messages.
  """
  def update({:set_demo, demo}, state) do
    {%{state | demo: demo, canvas: create_canvas(demo)}, []}
  end

  def update(:clear, state) do
    {%{state | canvas: %{state.canvas | buffer: create_empty_buffer(), braille_buffer: %{}}}, []}
  end

  def update(:quit, state) do
    {state, [:quit]}
  end

  @doc """
  Render the current state to a render tree.
  """
  def view(state) do
    stack(:vertical, [
      # Title
      text("Canvas Widget Example", Style.new(fg: :cyan, attrs: [:bold])),
      text("", nil),

      # Canvas area with border
      render_canvas(state.canvas),
      text("", nil),

      # Current demo
      text("Demo: #{state.demo}", nil),
      text("", nil),

      # Controls
      text("Controls:", Style.new(fg: :yellow)),
      text("  1   Basic shapes demo", nil),
      text("  2   Box drawing demo", nil),
      text("  3   Braille drawing demo", nil),
      text("  C   Clear canvas", nil),
      text("  Q   Quit", nil)
    ])
  end

  # ----------------------------------------------------------------------------
  # Canvas Rendering
  # ----------------------------------------------------------------------------

  defp render_canvas(canvas) do
    # Convert canvas buffer to lines
    lines =
      for y <- 0..(canvas.height - 1) do
        row =
          for x <- 0..(canvas.width - 1) do
            Map.get(canvas.buffer, {x, y}, " ")
          end

        text("│" <> Enum.join(row) <> "│", nil)
      end

    # Add borders
    top_border = text("┌" <> String.duplicate("─", canvas.width) <> "┐", nil)
    bottom_border = text("└" <> String.duplicate("─", canvas.width) <> "┘", nil)

    stack(:vertical, [top_border | lines] ++ [bottom_border])
  end

  # ----------------------------------------------------------------------------
  # Demo Drawing Functions
  # ----------------------------------------------------------------------------

  defp draw_shapes_demo(state) do
    state
    # Draw title text
    |> draw_text(2, 1, "Basic Shapes Demo")
    # Draw horizontal line
    |> draw_hline(2, 3, 20, "─")
    # Draw vertical line
    |> draw_vline(25, 3, 8, "│")
    # Draw diagonal line using dots
    |> draw_line(30, 3, 45, 10, "•")
    # Draw some points
    |> draw_text(2, 5, "Points: ")
    |> set_char(10, 5, "●")
    |> set_char(12, 5, "○")
    |> set_char(14, 5, "◆")
    |> set_char(16, 5, "◇")
    # Draw labels
    |> draw_text(2, 8, "H-Line above")
    |> draw_text(27, 6, "V")
    |> draw_text(32, 12, "Diagonal")
  end

  defp draw_boxes_demo(state) do
    state
    # Draw title
    |> draw_text(2, 1, "Box Drawing Demo")
    # Draw a simple box
    |> draw_rect(2, 3, 15, 5)
    |> draw_text(4, 5, "Box 1")
    # Draw another box with double lines
    |> draw_rect(20, 3, 15, 5, %{
      h: "═",
      v: "║",
      tl: "╔",
      tr: "╗",
      bl: "╚",
      br: "╝"
    })
    |> draw_text(22, 5, "Box 2")
    # Draw a box with rounded corners
    |> draw_rect(2, 9, 15, 5, %{
      h: "─",
      v: "│",
      tl: "╭",
      tr: "╮",
      bl: "╰",
      br: "╯"
    })
    |> draw_text(4, 11, "Rounded")
    # Draw nested boxes
    |> draw_rect(20, 9, 20, 5)
    |> draw_rect(22, 10, 16, 3)
    |> draw_text(25, 11, "Nested")
  end

  defp draw_braille_demo(state) do
    # For the braille demo, we need to use braille_buffer
    # Each character cell is 2 dots wide x 4 dots high

    state
    |> draw_text(2, 1, "Braille Drawing Demo")
    |> draw_text(2, 3, "Sub-character resolution using Braille patterns:")
    # Show the braille characters
    |> draw_text(2, 5, "Empty: " <> Canvas.empty_braille())
    |> draw_text(12, 5, "Full: " <> Canvas.full_braille())
    # Show individual dot positions
    |> draw_text(2, 7, "Dot positions in a cell:")
    |> draw_text(2, 8, "1 4")
    |> draw_text(2, 9, "2 5")
    |> draw_text(2, 10, "3 6")
    |> draw_text(2, 11, "7 8")
    # Draw some braille patterns
    |> draw_text(10, 7, "Patterns:")
    |> draw_text(10, 8, Canvas.dots_to_braille([{0, 0}]))
    |> draw_text(12, 8, Canvas.dots_to_braille([{1, 0}]))
    |> draw_text(14, 8, Canvas.dots_to_braille([{0, 1}]))
    |> draw_text(16, 8, Canvas.dots_to_braille([{0, 0}, {1, 1}]))
    |> draw_text(18, 8, Canvas.dots_to_braille([{0, 0}, {0, 1}, {0, 2}, {0, 3}]))
    |> draw_text(20, 8, Canvas.dots_to_braille([{0, 0}, {1, 0}, {0, 1}, {1, 1}]))
    # Resolution info
    |> draw_text(2, 13, "Canvas: #{@canvas_width}x#{@canvas_height} chars = #{@canvas_width * 2}x#{@canvas_height * 4} braille dots")
  end

  # ----------------------------------------------------------------------------
  # Canvas Drawing Helpers
  # ----------------------------------------------------------------------------

  defp set_char(state, x, y, char) do
    if x >= 0 and x < state.width and y >= 0 and y < state.height do
      %{state | buffer: Map.put(state.buffer, {x, y}, char)}
    else
      state
    end
  end

  defp draw_text(state, x, y, text) do
    text
    |> String.graphemes()
    |> Enum.with_index()
    |> Enum.reduce(state, fn {char, i}, acc ->
      set_char(acc, x + i, y, char)
    end)
  end

  defp draw_hline(state, x, y, length, char) do
    Enum.reduce(0..(length - 1), state, fn i, acc ->
      set_char(acc, x + i, y, char)
    end)
  end

  defp draw_vline(state, x, y, length, char) do
    Enum.reduce(0..(length - 1), state, fn i, acc ->
      set_char(acc, x, y + i, char)
    end)
  end

  defp draw_line(state, x1, y1, x2, y2, char) do
    # Bresenham's line algorithm
    dx = abs(x2 - x1)
    dy = abs(y2 - y1)
    sx = if x1 < x2, do: 1, else: -1
    sy = if y1 < y2, do: 1, else: -1

    draw_line_impl(state, x1, y1, x2, y2, dx, dy, sx, sy, dx - dy, char)
  end

  defp draw_line_impl(state, x, y, target_x, target_y, dx, dy, sx, sy, err, char) do
    state = set_char(state, x, y, char)

    if x == target_x and y == target_y do
      state
    else
      e2 = 2 * err

      {new_x, new_err} =
        if e2 > -dy do
          {x + sx, err - dy}
        else
          {x, err}
        end

      {new_y, new_err} =
        if e2 < dx do
          {y + sy, new_err + dx}
        else
          {y, new_err}
        end

      draw_line_impl(state, new_x, new_y, target_x, target_y, dx, dy, sx, sy, new_err, char)
    end
  end

  defp draw_rect(state, x, y, width, height, border \\ %{}) do
    h = Map.get(border, :h, "─")
    v = Map.get(border, :v, "│")
    tl = Map.get(border, :tl, "┌")
    tr = Map.get(border, :tr, "┐")
    bl = Map.get(border, :bl, "└")
    br = Map.get(border, :br, "┘")

    state
    # Top edge
    |> set_char(x, y, tl)
    |> draw_hline(x + 1, y, width - 2, h)
    |> set_char(x + width - 1, y, tr)
    # Side edges
    |> draw_vline(x, y + 1, height - 2, v)
    |> draw_vline(x + width - 1, y + 1, height - 2, v)
    # Bottom edge
    |> set_char(x, y + height - 1, bl)
    |> draw_hline(x + 1, y + height - 1, width - 2, h)
    |> set_char(x + width - 1, y + height - 1, br)
  end

  # ----------------------------------------------------------------------------
  # Public API
  # ----------------------------------------------------------------------------

  @doc """
  Run the canvas example application.
  """
  def run do
    TermUI.Runtime.run(root: __MODULE__)
  end
end
