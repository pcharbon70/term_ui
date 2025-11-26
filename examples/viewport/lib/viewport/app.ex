defmodule Viewport.App do
  @moduledoc """
  Viewport Widget Example

  This example demonstrates how to use the TermUI.Widgets.Viewport widget
  for displaying scrollable content larger than the view area.

  Features demonstrated:
  - Vertical scrolling through large content
  - Scroll position tracking
  - Visual scroll position indicator
  - Keyboard navigation

  Note: The actual Viewport widget is a StatefulComponent with scroll bar
  rendering. This example shows the scrolling concept with simpler rendering.

  Controls:
  - Up/Down: Scroll by one line
  - Page Up/Down: Scroll by page (5 lines)
  - Home/End: Jump to top/bottom
  - Q: Quit the application
  """

  use TermUI.Elm

  alias TermUI.Event
  alias TermUI.Renderer.Style

  # Content configuration
  @content_height 50
  @viewport_height 10

  # ----------------------------------------------------------------------------
  # Component Callbacks
  # ----------------------------------------------------------------------------

  @doc """
  Initialize the component state.
  """
  def init(_opts) do
    %{
      scroll_y: 0,
      content: generate_content()
    }
  end

  defp generate_content do
    # Generate 50 lines of content
    for i <- 1..@content_height do
      line_content =
        case rem(i, 10) do
          0 -> "────────── Section #{div(i, 10)} ──────────"
          _ -> "Line #{String.pad_leading(to_string(i), 2, "0")}: Lorem ipsum dolor sit amet"
        end

      {i, line_content}
    end
  end

  @doc """
  Convert keyboard events to messages.
  """
  def event_to_msg(%Event.Key{key: :up}, _state), do: {:msg, {:scroll, -1}}
  def event_to_msg(%Event.Key{key: :down}, _state), do: {:msg, {:scroll, 1}}
  def event_to_msg(%Event.Key{key: :page_up}, _state), do: {:msg, {:scroll, -5}}
  def event_to_msg(%Event.Key{key: :page_down}, _state), do: {:msg, {:scroll, 5}}
  def event_to_msg(%Event.Key{key: :home}, _state), do: {:msg, :scroll_top}
  def event_to_msg(%Event.Key{key: :end}, _state), do: {:msg, :scroll_bottom}
  def event_to_msg(%Event.Key{key: key}, _state) when key in ["q", "Q"], do: {:msg, :quit}
  def event_to_msg(_event, _state), do: :ignore

  @doc """
  Update state based on messages.
  """
  def update({:scroll, delta}, state) do
    max_scroll = @content_height - @viewport_height
    new_scroll = max(0, min(max_scroll, state.scroll_y + delta))
    {%{state | scroll_y: new_scroll}, []}
  end

  def update(:scroll_top, state) do
    {%{state | scroll_y: 0}, []}
  end

  def update(:scroll_bottom, state) do
    max_scroll = @content_height - @viewport_height
    {%{state | scroll_y: max_scroll}, []}
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
      text("Viewport Widget Example", Style.new(fg: :cyan, attrs: [:bold])),
      text("", nil),

      # Content area with scroll bar
      render_viewport_area(state),
      text("", nil),

      # Scroll position info
      text("", nil),

      # Controls
      render_controls(state)
    ])
  end

  defp render_controls(state) do
    box_width = 56
    inner_width = box_width - 2

    top_border = "┌─ Controls " <> String.duplicate("─", inner_width - 12) <> "─┐"
    bottom_border = "└" <> String.duplicate("─", inner_width) <> "┘"

    stack(:vertical, [
      text("", nil),
      text(top_border, Style.new(fg: :yellow)),
      text("│" <> String.pad_trailing("  ↑/↓           Scroll one line", inner_width) <> "│", nil),
      text("│" <> String.pad_trailing("  Page Up/Down  Scroll by 5", inner_width) <> "│", nil),
      text("│" <> String.pad_trailing("  Home/End      Jump to top/bottom", inner_width) <> "│", nil),
      text("│" <> String.pad_trailing("  Q             Quit", inner_width) <> "│", nil),
      text("│" <> String.pad_trailing("", inner_width) <> "│", nil),
      text("│" <> String.pad_trailing("  Scroll: #{state.scroll_y}/#{@content_height - @viewport_height}", inner_width) <> "│", nil),
      text("│" <> String.pad_trailing("  Showing lines #{state.scroll_y + 1}-#{state.scroll_y + @viewport_height} of #{@content_height}", inner_width) <> "│", nil),
      text(bottom_border, Style.new(fg: :yellow))
    ])
  end

  # ----------------------------------------------------------------------------
  # Private Helpers
  # ----------------------------------------------------------------------------

  defp render_viewport_area(state) do
    # Get visible content lines
    visible_lines =
      state.content
      |> Enum.slice(state.scroll_y, @viewport_height)

    # Render content lines
    content_rows =
      Enum.map(visible_lines, fn {_line_num, content} ->
        # Truncate to fit viewport width
        truncated = String.slice(content, 0, 50)
        padded = String.pad_trailing(truncated, 50)
        text("│ " <> padded <> " ", nil)
      end)

    # Render scroll bar
    scroll_bar = render_scroll_bar(state)

    # Combine content and scroll bar
    rows_with_bar =
      Enum.zip(content_rows, scroll_bar)
      |> Enum.map(fn {content_row, bar_char} ->
        stack(:horizontal, [content_row, text(bar_char, nil), text("│", nil)])
      end)

    # Add top and bottom borders
    top_border = text("┌" <> String.duplicate("─", 52) <> "┬─┐", nil)
    bottom_border = text("└" <> String.duplicate("─", 52) <> "┴─┘", nil)

    stack(:vertical, [top_border | rows_with_bar] ++ [bottom_border])
  end

  defp render_scroll_bar(state) do
    max_scroll = @content_height - @viewport_height

    # Calculate thumb position and size
    visible_fraction = @viewport_height / @content_height
    thumb_size = max(1, round(@viewport_height * visible_fraction))

    scroll_fraction =
      if max_scroll > 0 do
        state.scroll_y / max_scroll
      else
        0.0
      end

    thumb_pos = round((@viewport_height - thumb_size) * scroll_fraction)

    # Build scroll bar characters
    for i <- 0..(@viewport_height - 1) do
      if i >= thumb_pos and i < thumb_pos + thumb_size do
        "█"
      else
        "░"
      end
    end
  end

  # ----------------------------------------------------------------------------
  # Public API
  # ----------------------------------------------------------------------------

  @doc """
  Run the viewport example application.
  """
  def run do
    TermUI.Runtime.run(root: __MODULE__)
  end
end
