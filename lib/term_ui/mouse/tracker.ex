defmodule TermUI.Mouse.Tracker do
  @moduledoc """
  Tracks mouse state for drag and hover detection.

  The tracker maintains state for:
  - Drag operations (press → move → release)
  - Hover detection (enter/leave events)
  - Last known mouse position

  ## Usage

      # Create new tracker
      tracker = Tracker.new()

      # Process mouse events
      {tracker, events} = Tracker.process(tracker, mouse_event)

      # Events may include:
      # - {:drag_start, button, x, y}
      # - {:drag_move, button, x, y, dx, dy}
      # - {:drag_end, button, x, y}
      # - {:hover_enter, component_id}
      # - {:hover_leave, component_id}
  """

  alias TermUI.Event

  @type t :: %__MODULE__{
          button_down: atom() | nil,
          press_position: {integer(), integer()} | nil,
          last_position: {integer(), integer()} | nil,
          dragging: boolean(),
          hovered_component: atom() | nil,
          drag_threshold: integer()
        }

  defstruct [
    :button_down,
    :press_position,
    :last_position,
    :hovered_component,
    dragging: false,
    drag_threshold: 3
  ]

  @doc """
  Creates a new mouse tracker.

  ## Options

  - `:drag_threshold` - Pixels of movement before drag starts (default: 3)
  """
  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    %__MODULE__{
      drag_threshold: Keyword.get(opts, :drag_threshold, 3)
    }
  end

  @doc """
  Processes a mouse event and returns updated tracker and generated events.

  Generated events:
  - `{:drag_start, button, x, y}` - Drag operation started
  - `{:drag_move, button, x, y, dx, dy}` - Mouse moved during drag
  - `{:drag_end, button, x, y}` - Drag operation ended
  """
  @spec process(t(), Event.Mouse.t()) :: {t(), list()}
  def process(tracker, %Event.Mouse{action: :press, button: button, x: x, y: y}) do
    tracker = %{
      tracker
      | button_down: button,
        press_position: {x, y},
        last_position: {x, y},
        dragging: false
    }

    {tracker, []}
  end

  def process(tracker, %Event.Mouse{action: :release, button: button, x: x, y: y}) do
    events =
      if tracker.dragging and tracker.button_down == button do
        [{:drag_end, button, x, y}]
      else
        []
      end

    tracker = %{
      tracker
      | button_down: nil,
        press_position: nil,
        dragging: false
    }

    {tracker, events}
  end

  def process(tracker, %Event.Mouse{action: :move, x: x, y: y}) do
    {tracker, events} = process_motion(tracker, x, y)
    tracker = %{tracker | last_position: {x, y}}
    {tracker, events}
  end

  def process(tracker, %Event.Mouse{action: :drag, button: button, x: x, y: y}) do
    # Drag events come with button info
    {tracker, events} = process_motion(tracker, x, y, button)
    tracker = %{tracker | last_position: {x, y}}
    {tracker, events}
  end

  def process(tracker, %Event.Mouse{}) do
    # Scroll or other events don't affect drag/hover state
    {tracker, []}
  end

  @doc """
  Updates hover state and returns enter/leave events.
  """
  @spec update_hover(t(), atom() | nil) :: {t(), list()}
  def update_hover(tracker, component_id) do
    cond do
      tracker.hovered_component == component_id ->
        {tracker, []}

      tracker.hovered_component == nil ->
        tracker = %{tracker | hovered_component: component_id}
        {tracker, [{:hover_enter, component_id}]}

      component_id == nil ->
        old = tracker.hovered_component
        tracker = %{tracker | hovered_component: nil}
        {tracker, [{:hover_leave, old}]}

      true ->
        old = tracker.hovered_component
        tracker = %{tracker | hovered_component: component_id}
        {tracker, [{:hover_leave, old}, {:hover_enter, component_id}]}
    end
  end

  @doc """
  Returns whether a drag operation is in progress.
  """
  @spec dragging?(t()) :: boolean()
  def dragging?(tracker), do: tracker.dragging

  @doc """
  Returns the currently hovered component.
  """
  @spec hovered_component(t()) :: atom() | nil
  def hovered_component(tracker), do: tracker.hovered_component

  @doc """
  Returns the button currently pressed.
  """
  @spec button_down(t()) :: atom() | nil
  def button_down(tracker), do: tracker.button_down

  @doc """
  Resets drag state (useful on focus loss).
  """
  @spec reset_drag(t()) :: t()
  def reset_drag(tracker) do
    %{tracker | button_down: nil, press_position: nil, dragging: false}
  end

  # --- Private Functions ---

  defp process_motion(tracker, x, y, button \\ nil) do
    button = button || tracker.button_down

    cond do
      # No button down, no drag events
      button == nil ->
        {tracker, []}

      # Already dragging, emit drag move
      tracker.dragging ->
        {dx, dy} = delta(tracker.last_position, {x, y})
        {tracker, [{:drag_move, button, x, y, dx, dy}]}

      # Check if we should start dragging
      should_start_drag?(tracker, x, y) ->
        tracker = %{tracker | dragging: true}
        {px, py} = tracker.press_position
        {tracker, [{:drag_start, button, px, py}, {:drag_move, button, x, y, x - px, y - py}]}

      # Not yet dragging
      true ->
        {tracker, []}
    end
  end

  defp should_start_drag?(tracker, x, y) do
    case tracker.press_position do
      nil ->
        false

      {px, py} ->
        dx = abs(x - px)
        dy = abs(y - py)
        dx >= tracker.drag_threshold or dy >= tracker.drag_threshold
    end
  end

  defp delta(nil, _), do: {0, 0}
  defp delta({x1, y1}, {x2, y2}), do: {x2 - x1, y2 - y1}
end
