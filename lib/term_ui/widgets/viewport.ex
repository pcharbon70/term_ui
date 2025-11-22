defmodule TermUI.Widgets.Viewport do
  @moduledoc """
  Viewport widget for scrollable content.

  Viewport displays a scrollable view of content larger than the viewport area.
  It tracks scroll position, clips content to bounds, and optionally shows
  scroll bars for visual feedback and interaction.

  ## Usage

      Viewport.new(
        content: large_content_tree(),
        width: 40,
        height: 20,
        scroll_bars: :both
      )

  ## Features

  - Scrollable view of larger content
  - Automatic content clipping to viewport bounds
  - Optional vertical and horizontal scroll bars
  - Keyboard navigation (arrow keys, Page Up/Down, Home/End)
  - Mouse wheel scrolling
  - Scroll bar drag interaction

  ## Keyboard Navigation

  - Arrow keys: Scroll by one line/column
  - Page Up/Down: Scroll by viewport height
  - Home/End: Scroll to top/bottom
  - Ctrl+Home/End: Scroll to start/end horizontally
  """

  use TermUI.StatefulComponent

  alias TermUI.Event

  @doc """
  Creates new Viewport widget props.

  ## Options

  - `:content` - Content to display (render node)
  - `:content_width` - Width of content (for horizontal scrolling)
  - `:content_height` - Height of content (for vertical scrolling)
  - `:width` - Viewport width (default: 40)
  - `:height` - Viewport height (default: 20)
  - `:scroll_x` - Initial horizontal scroll position (default: 0)
  - `:scroll_y` - Initial vertical scroll position (default: 0)
  - `:scroll_bars` - Scroll bar display: :none, :vertical, :horizontal, :both (default: :both)
  - `:on_scroll` - Callback when scroll position changes
  - `:scroll_step` - Lines to scroll per step (default: 1)
  - `:page_step` - Lines to scroll per page (default: viewport height)
  """
  @spec new(keyword()) :: map()
  def new(opts) do
    %{
      content: Keyword.get(opts, :content, empty()),
      content_width: Keyword.get(opts, :content_width, 100),
      content_height: Keyword.get(opts, :content_height, 100),
      width: Keyword.get(opts, :width, 40),
      height: Keyword.get(opts, :height, 20),
      scroll_x: Keyword.get(opts, :scroll_x, 0),
      scroll_y: Keyword.get(opts, :scroll_y, 0),
      scroll_bars: Keyword.get(opts, :scroll_bars, :both),
      on_scroll: Keyword.get(opts, :on_scroll),
      scroll_step: Keyword.get(opts, :scroll_step, 1),
      page_step: Keyword.get(opts, :page_step)
    }
  end

  @impl true
  def init(props) do
    state = %{
      content: props.content,
      content_width: props.content_width,
      content_height: props.content_height,
      width: props.width,
      height: props.height,
      scroll_x: clamp_scroll(props.scroll_x, props.content_width, viewport_width(props)),
      scroll_y: clamp_scroll(props.scroll_y, props.content_height, viewport_height(props)),
      scroll_bars: props.scroll_bars,
      on_scroll: props.on_scroll,
      scroll_step: props.scroll_step,
      page_step: props.page_step || props.height,
      dragging: nil
    }

    {:ok, state}
  end

  @impl true
  def handle_event(%Event.Key{key: :up}, state) do
    scroll_by(state, 0, -state.scroll_step)
  end

  def handle_event(%Event.Key{key: :down}, state) do
    scroll_by(state, 0, state.scroll_step)
  end

  def handle_event(%Event.Key{key: :left}, state) do
    scroll_by(state, -state.scroll_step, 0)
  end

  def handle_event(%Event.Key{key: :right}, state) do
    scroll_by(state, state.scroll_step, 0)
  end

  def handle_event(%Event.Key{key: :page_up}, state) do
    scroll_by(state, 0, -state.page_step)
  end

  def handle_event(%Event.Key{key: :page_down}, state) do
    scroll_by(state, 0, state.page_step)
  end

  def handle_event(%Event.Key{key: :home, modifiers: modifiers}, state) do
    if :ctrl in modifiers do
      # Ctrl+Home: scroll to top-left
      scroll_to(state, 0, 0)
    else
      # Home: scroll to top
      scroll_to(state, state.scroll_x, 0)
    end
  end

  def handle_event(%Event.Key{key: :end, modifiers: modifiers}, state) do
    if :ctrl in modifiers do
      # Ctrl+End: scroll to bottom-right
      max_x = max(0, state.content_width - viewport_width(state))
      max_y = max(0, state.content_height - viewport_height(state))
      scroll_to(state, max_x, max_y)
    else
      # End: scroll to bottom
      max_y = max(0, state.content_height - viewport_height(state))
      scroll_to(state, state.scroll_x, max_y)
    end
  end

  def handle_event(%Event.Mouse{action: :scroll_up}, state) do
    scroll_by(state, 0, -state.scroll_step * 3)
  end

  def handle_event(%Event.Mouse{action: :scroll_down}, state) do
    scroll_by(state, 0, state.scroll_step * 3)
  end

  def handle_event(%Event.Mouse{action: :click, x: x, y: y}, state) do
    # Check if click is on scroll bar
    cond do
      click_on_vertical_bar?(state, x, y) ->
        handle_vertical_bar_click(state, y)

      click_on_horizontal_bar?(state, x, y) ->
        handle_horizontal_bar_click(state, x)

      true ->
        {:ok, state}
    end
  end

  def handle_event(%Event.Mouse{action: :drag, x: x, y: y}, state) do
    case state.dragging do
      :vertical ->
        handle_vertical_drag(state, y)

      :horizontal ->
        handle_horizontal_drag(state, x)

      nil ->
        {:ok, state}
    end
  end

  def handle_event(%Event.Mouse{action: :release}, state) do
    {:ok, %{state | dragging: nil}}
  end

  def handle_event(_event, state) do
    {:ok, state}
  end

  @impl true
  def render(state, _area) do
    vp_width = viewport_width(state)
    vp_height = viewport_height(state)

    # Render clipped content
    content = render_clipped_content(state, vp_width, vp_height)

    # Render scroll bars if enabled
    case state.scroll_bars do
      :none ->
        content

      :vertical ->
        v_bar = render_vertical_bar(state, vp_height)
        stack(:horizontal, [content, v_bar])

      :horizontal ->
        h_bar = render_horizontal_bar(state, vp_width)
        stack(:vertical, [content, h_bar])

      :both ->
        v_bar = render_vertical_bar(state, vp_height)
        h_bar = render_horizontal_bar(state, vp_width)

        # Content + vertical bar on top, horizontal bar on bottom
        top_row = stack(:horizontal, [content, v_bar])
        # Add corner piece
        corner = text("░")
        bottom_row = stack(:horizontal, [h_bar, corner])

        stack(:vertical, [top_row, bottom_row])
    end
  end

  # Private functions

  defp viewport_width(state) do
    case state.scroll_bars do
      :vertical -> state.width - 1
      :both -> state.width - 1
      _ -> state.width
    end
  end

  defp viewport_height(state) do
    case state.scroll_bars do
      :horizontal -> state.height - 1
      :both -> state.height - 1
      _ -> state.height
    end
  end

  defp clamp_scroll(scroll, content_size, viewport_size) do
    max_scroll = max(0, content_size - viewport_size)
    min(max(0, scroll), max_scroll)
  end

  defp scroll_by(state, dx, dy) do
    new_x = state.scroll_x + dx
    new_y = state.scroll_y + dy
    scroll_to(state, new_x, new_y)
  end

  defp scroll_to(state, x, y) do
    vp_width = viewport_width(state)
    vp_height = viewport_height(state)

    new_x = clamp_scroll(x, state.content_width, vp_width)
    new_y = clamp_scroll(y, state.content_height, vp_height)

    if new_x != state.scroll_x or new_y != state.scroll_y do
      new_state = %{state | scroll_x: new_x, scroll_y: new_y}

      if state.on_scroll do
        state.on_scroll.(new_x, new_y)
      end

      {:ok, new_state}
    else
      {:ok, state}
    end
  end

  defp render_clipped_content(state, vp_width, vp_height) do
    # Create a viewport container that clips content
    %{
      type: :viewport,
      content: state.content,
      scroll_x: state.scroll_x,
      scroll_y: state.scroll_y,
      width: vp_width,
      height: vp_height
    }
  end

  defp render_vertical_bar(state, height) do
    vp_height = viewport_height(state)

    # Calculate thumb position and size
    visible_fraction = min(1.0, vp_height / max(1, state.content_height))
    thumb_size = max(1, round(height * visible_fraction))

    scroll_fraction =
      if state.content_height <= vp_height do
        0.0
      else
        state.scroll_y / (state.content_height - vp_height)
      end

    thumb_pos = round((height - thumb_size) * scroll_fraction)

    # Build the bar
    lines =
      for y <- 0..(height - 1) do
        char =
          if y >= thumb_pos and y < thumb_pos + thumb_size do
            "█"
          else
            "░"
          end

        text(char)
      end

    stack(:vertical, lines)
  end

  defp render_horizontal_bar(state, width) do
    vp_width = viewport_width(state)

    # Calculate thumb position and size
    visible_fraction = min(1.0, vp_width / max(1, state.content_width))
    thumb_size = max(1, round(width * visible_fraction))

    scroll_fraction =
      if state.content_width <= vp_width do
        0.0
      else
        state.scroll_x / (state.content_width - vp_width)
      end

    thumb_pos = round((width - thumb_size) * scroll_fraction)

    # Build the bar
    chars =
      for x <- 0..(width - 1) do
        if x >= thumb_pos and x < thumb_pos + thumb_size do
          "█"
        else
          "░"
        end
      end

    text(Enum.join(chars))
  end

  defp click_on_vertical_bar?(state, x, _y) do
    has_vertical_bar?(state) and x >= viewport_width(state)
  end

  defp click_on_horizontal_bar?(state, _x, y) do
    has_horizontal_bar?(state) and y >= viewport_height(state)
  end

  defp has_vertical_bar?(state) do
    state.scroll_bars in [:vertical, :both]
  end

  defp has_horizontal_bar?(state) do
    state.scroll_bars in [:horizontal, :both]
  end

  defp handle_vertical_bar_click(state, y) do
    vp_height = viewport_height(state)

    # Calculate thumb position
    visible_fraction = min(1.0, vp_height / max(1, state.content_height))
    thumb_size = max(1, round(vp_height * visible_fraction))

    scroll_fraction =
      if state.content_height <= vp_height do
        0.0
      else
        state.scroll_y / (state.content_height - vp_height)
      end

    thumb_pos = round((vp_height - thumb_size) * scroll_fraction)

    if y >= thumb_pos and y < thumb_pos + thumb_size do
      # Click on thumb - start dragging
      {:ok, %{state | dragging: :vertical}}
    else
      # Click on track - page scroll
      if y < thumb_pos do
        scroll_by(state, 0, -state.page_step)
      else
        scroll_by(state, 0, state.page_step)
      end
    end
  end

  defp handle_horizontal_bar_click(state, x) do
    vp_width = viewport_width(state)

    # Calculate thumb position
    visible_fraction = min(1.0, vp_width / max(1, state.content_width))
    thumb_size = max(1, round(vp_width * visible_fraction))

    scroll_fraction =
      if state.content_width <= vp_width do
        0.0
      else
        state.scroll_x / (state.content_width - vp_width)
      end

    thumb_pos = round((vp_width - thumb_size) * scroll_fraction)

    if x >= thumb_pos and x < thumb_pos + thumb_size do
      # Click on thumb - start dragging
      {:ok, %{state | dragging: :horizontal}}
    else
      # Click on track - page scroll
      if x < thumb_pos do
        scroll_by(state, -state.page_step, 0)
      else
        scroll_by(state, state.page_step, 0)
      end
    end
  end

  defp handle_vertical_drag(state, y) do
    vp_height = viewport_height(state)

    if state.content_height <= vp_height do
      {:ok, state}
    else
      # Convert y position to scroll position
      visible_fraction = min(1.0, vp_height / max(1, state.content_height))
      thumb_size = max(1, round(vp_height * visible_fraction))
      track_size = vp_height - thumb_size

      if track_size > 0 do
        scroll_fraction = y / track_size
        new_y = round(scroll_fraction * (state.content_height - vp_height))
        scroll_to(state, state.scroll_x, new_y)
      else
        {:ok, state}
      end
    end
  end

  defp handle_horizontal_drag(state, x) do
    vp_width = viewport_width(state)

    if state.content_width <= vp_width do
      {:ok, state}
    else
      # Convert x position to scroll position
      visible_fraction = min(1.0, vp_width / max(1, state.content_width))
      thumb_size = max(1, round(vp_width * visible_fraction))
      track_size = vp_width - thumb_size

      if track_size > 0 do
        scroll_fraction = x / track_size
        new_x = round(scroll_fraction * (state.content_width - vp_width))
        scroll_to(state, new_x, state.scroll_y)
      else
        {:ok, state}
      end
    end
  end

  # Public API

  @doc """
  Gets the current scroll position.
  """
  @spec get_scroll(map()) :: {integer(), integer()}
  def get_scroll(state) do
    {state.scroll_x, state.scroll_y}
  end

  @doc """
  Sets the scroll position.
  """
  @spec set_scroll(map(), integer(), integer()) :: map()
  def set_scroll(state, x, y) do
    vp_width = viewport_width(state)
    vp_height = viewport_height(state)

    %{
      state
      | scroll_x: clamp_scroll(x, state.content_width, vp_width),
        scroll_y: clamp_scroll(y, state.content_height, vp_height)
    }
  end

  @doc """
  Scrolls to make a position visible.
  """
  @spec scroll_into_view(map(), integer(), integer()) :: map()
  def scroll_into_view(state, x, y) do
    vp_width = viewport_width(state)
    vp_height = viewport_height(state)

    # Calculate new scroll to make position visible
    new_x =
      cond do
        x < state.scroll_x -> x
        x >= state.scroll_x + vp_width -> x - vp_width + 1
        true -> state.scroll_x
      end

    new_y =
      cond do
        y < state.scroll_y -> y
        y >= state.scroll_y + vp_height -> y - vp_height + 1
        true -> state.scroll_y
      end

    set_scroll(state, new_x, new_y)
  end

  @doc """
  Updates the content.
  """
  @spec set_content(map(), term()) :: map()
  def set_content(state, content) do
    %{state | content: content}
  end

  @doc """
  Updates the content dimensions.
  """
  @spec set_content_size(map(), integer(), integer()) :: map()
  def set_content_size(state, width, height) do
    vp_width = viewport_width(state)
    vp_height = viewport_height(state)

    %{
      state
      | content_width: width,
        content_height: height,
        scroll_x: clamp_scroll(state.scroll_x, width, vp_width),
        scroll_y: clamp_scroll(state.scroll_y, height, vp_height)
    }
  end

  @doc """
  Checks if content is scrollable vertically.
  """
  @spec can_scroll_vertical?(map()) :: boolean()
  def can_scroll_vertical?(state) do
    state.content_height > viewport_height(state)
  end

  @doc """
  Checks if content is scrollable horizontally.
  """
  @spec can_scroll_horizontal?(map()) :: boolean()
  def can_scroll_horizontal?(state) do
    state.content_width > viewport_width(state)
  end

  @doc """
  Gets the visible fraction (0.0 - 1.0) for vertical scrolling.
  """
  @spec visible_fraction_vertical(map()) :: float()
  def visible_fraction_vertical(state) do
    min(1.0, viewport_height(state) / max(1, state.content_height))
  end

  @doc """
  Gets the visible fraction (0.0 - 1.0) for horizontal scrolling.
  """
  @spec visible_fraction_horizontal(map()) :: float()
  def visible_fraction_horizontal(state) do
    min(1.0, viewport_width(state) / max(1, state.content_width))
  end
end
