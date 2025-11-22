defmodule TermUI.Widgets.ScrollBar do
  @moduledoc """
  Standalone scroll bar widget.

  ScrollBar provides a visual indicator and interactive control for scrolling.
  Can be used independently or integrated with other scrollable widgets.

  ## Usage

      ScrollBar.new(
        orientation: :vertical,
        total: 100,
        visible: 20,
        position: 0,
        length: 20,
        on_scroll: fn pos -> handle_scroll(pos) end
      )

  ## Features

  - Vertical and horizontal orientations
  - Proportional thumb size based on visible/total ratio
  - Track click for page scrolling
  - Drag scrolling for smooth navigation
  - Customizable appearance

  ## Mouse Interaction

  - Click on thumb: Start dragging
  - Click on track: Page scroll toward click
  - Drag thumb: Smooth scrolling
  """

  use TermUI.StatefulComponent

  alias TermUI.Event

  @doc """
  Creates new ScrollBar widget props.

  ## Options

  - `:orientation` - :vertical or :horizontal (default: :vertical)
  - `:total` - Total content size (default: 100)
  - `:visible` - Visible content size (default: 20)
  - `:position` - Current scroll position (default: 0)
  - `:length` - Bar length in characters (default: 20)
  - `:on_scroll` - Callback when position changes
  - `:track_char` - Character for track (default: "░")
  - `:thumb_char` - Character for thumb (default: "█")
  - `:min_thumb_size` - Minimum thumb size (default: 1)
  """
  @spec new(keyword()) :: map()
  def new(opts) do
    %{
      orientation: Keyword.get(opts, :orientation, :vertical),
      total: Keyword.get(opts, :total, 100),
      visible: Keyword.get(opts, :visible, 20),
      position: Keyword.get(opts, :position, 0),
      length: Keyword.get(opts, :length, 20),
      on_scroll: Keyword.get(opts, :on_scroll),
      track_char: Keyword.get(opts, :track_char, "░"),
      thumb_char: Keyword.get(opts, :thumb_char, "█"),
      min_thumb_size: Keyword.get(opts, :min_thumb_size, 1)
    }
  end

  @impl true
  def init(props) do
    state = %{
      orientation: props.orientation,
      total: props.total,
      visible: props.visible,
      position: clamp_position(props.position, props.total, props.visible),
      length: props.length,
      on_scroll: props.on_scroll,
      track_char: props.track_char,
      thumb_char: props.thumb_char,
      min_thumb_size: props.min_thumb_size,
      dragging: false,
      drag_offset: 0
    }

    {:ok, state}
  end

  @impl true
  def handle_event(%Event.Mouse{action: :click, x: x, y: y}, state) do
    pos = if state.orientation == :vertical, do: y, else: x

    {thumb_pos, thumb_size} = thumb_metrics(state)

    if pos >= thumb_pos and pos < thumb_pos + thumb_size do
      # Click on thumb - start dragging
      drag_offset = pos - thumb_pos
      {:ok, %{state | dragging: true, drag_offset: drag_offset}}
    else
      # Click on track - page scroll
      if pos < thumb_pos do
        scroll_by(state, -state.visible)
      else
        scroll_by(state, state.visible)
      end
    end
  end

  def handle_event(%Event.Mouse{action: :drag, x: x, y: y}, state) do
    if state.dragging do
      pos = if state.orientation == :vertical, do: y, else: x
      handle_drag(state, pos)
    else
      {:ok, state}
    end
  end

  def handle_event(%Event.Mouse{action: :release}, state) do
    {:ok, %{state | dragging: false, drag_offset: 0}}
  end

  def handle_event(%Event.Key{key: :up}, state) when state.orientation == :vertical do
    scroll_by(state, -1)
  end

  def handle_event(%Event.Key{key: :down}, state) when state.orientation == :vertical do
    scroll_by(state, 1)
  end

  def handle_event(%Event.Key{key: :left}, state) when state.orientation == :horizontal do
    scroll_by(state, -1)
  end

  def handle_event(%Event.Key{key: :right}, state) when state.orientation == :horizontal do
    scroll_by(state, 1)
  end

  def handle_event(%Event.Key{key: :page_up}, state) do
    scroll_by(state, -state.visible)
  end

  def handle_event(%Event.Key{key: :page_down}, state) do
    scroll_by(state, state.visible)
  end

  def handle_event(%Event.Key{key: :home}, state) do
    scroll_to(state, 0)
  end

  def handle_event(%Event.Key{key: :end}, state) do
    max_pos = max(0, state.total - state.visible)
    scroll_to(state, max_pos)
  end

  def handle_event(_event, state) do
    {:ok, state}
  end

  @impl true
  def render(state, _area) do
    {thumb_pos, thumb_size} = thumb_metrics(state)

    chars =
      for i <- 0..(state.length - 1) do
        if i >= thumb_pos and i < thumb_pos + thumb_size do
          state.thumb_char
        else
          state.track_char
        end
      end

    case state.orientation do
      :vertical ->
        lines = Enum.map(chars, &text/1)
        stack(:vertical, lines)

      :horizontal ->
        text(Enum.join(chars))
    end
  end

  # Private functions

  defp clamp_position(position, total, visible) do
    max_pos = max(0, total - visible)
    min(max(0, position), max_pos)
  end

  defp thumb_metrics(state) do
    if state.total <= state.visible do
      # Content fits in viewport - full thumb
      {0, state.length}
    else
      # Calculate proportional thumb size
      visible_fraction = state.visible / state.total
      thumb_size = max(state.min_thumb_size, round(state.length * visible_fraction))

      # Calculate thumb position
      max_pos = state.total - state.visible
      scroll_fraction = if max_pos > 0, do: state.position / max_pos, else: 0.0
      track_space = state.length - thumb_size
      thumb_pos = round(track_space * scroll_fraction)

      {thumb_pos, thumb_size}
    end
  end

  defp scroll_by(state, delta) do
    new_pos = state.position + delta
    scroll_to(state, new_pos)
  end

  defp scroll_to(state, position) do
    new_pos = clamp_position(position, state.total, state.visible)

    if new_pos != state.position do
      new_state = %{state | position: new_pos}

      if state.on_scroll do
        state.on_scroll.(new_pos)
      end

      {:ok, new_state}
    else
      {:ok, state}
    end
  end

  defp handle_drag(state, pos) do
    # Convert position to scroll value
    {_thumb_pos, thumb_size} = thumb_metrics(state)
    track_space = state.length - thumb_size

    if track_space > 0 do
      # Adjust for drag offset
      adjusted_pos = pos - state.drag_offset
      scroll_fraction = adjusted_pos / track_space

      max_pos = state.total - state.visible
      new_pos = round(scroll_fraction * max_pos)

      scroll_to(state, new_pos)
    else
      {:ok, state}
    end
  end

  # Public API

  @doc """
  Gets the current scroll position.
  """
  @spec get_position(map()) :: integer()
  def get_position(state) do
    state.position
  end

  @doc """
  Sets the scroll position.
  """
  @spec set_position(map(), integer()) :: map()
  def set_position(state, position) do
    %{state | position: clamp_position(position, state.total, state.visible)}
  end

  @doc """
  Updates the content dimensions.
  """
  @spec set_dimensions(map(), integer(), integer()) :: map()
  def set_dimensions(state, total, visible) do
    %{
      state
      | total: total,
        visible: visible,
        position: clamp_position(state.position, total, visible)
    }
  end

  @doc """
  Gets the scroll fraction (0.0 - 1.0).
  """
  @spec get_fraction(map()) :: float()
  def get_fraction(state) do
    max_pos = max(0, state.total - state.visible)

    if max_pos > 0 do
      state.position / max_pos
    else
      0.0
    end
  end

  @doc """
  Sets scroll by fraction (0.0 - 1.0).
  """
  @spec set_fraction(map(), float()) :: map()
  def set_fraction(state, fraction) do
    max_pos = max(0, state.total - state.visible)
    position = round(fraction * max_pos)
    set_position(state, position)
  end

  @doc """
  Returns true if scrolling is possible (content exceeds visible).
  """
  @spec can_scroll?(map()) :: boolean()
  def can_scroll?(state) do
    state.total > state.visible
  end

  @doc """
  Returns the visible fraction (thumb size ratio).
  """
  @spec visible_fraction(map()) :: float()
  def visible_fraction(state) do
    if state.total > 0 do
      min(1.0, state.visible / state.total)
    else
      1.0
    end
  end

  @doc """
  Creates a simple vertical scroll bar.
  """
  @spec vertical(keyword()) :: map()
  def vertical(opts) do
    opts
    |> Keyword.put(:orientation, :vertical)
    |> new()
  end

  @doc """
  Creates a simple horizontal scroll bar.
  """
  @spec horizontal(keyword()) :: map()
  def horizontal(opts) do
    opts
    |> Keyword.put(:orientation, :horizontal)
    |> new()
  end
end
