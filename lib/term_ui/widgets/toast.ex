defmodule TermUI.Widgets.Toast do
  @moduledoc """
  Toast notification widget for brief, auto-dismissing messages.

  Toasts appear at the screen edge and automatically dismiss after a duration.
  Multiple toasts stack vertically. Toasts don't capture focus or block
  interaction.

  ## Usage

      Toast.new(
        message: "File saved successfully",
        type: :success,
        duration: 3000,
        position: :bottom_right
      )

  ## Toast Types

  - `:info` - Information (blue)
  - `:success` - Success (green)
  - `:warning` - Warning (yellow)
  - `:error` - Error (red)

  ## Positions

  - `:top_left`, `:top_center`, `:top_right`
  - `:bottom_left`, `:bottom_center`, `:bottom_right`
  """

  use TermUI.StatefulComponent

  alias TermUI.Event

  @type_icons %{
    info: "ℹ",
    success: "✓",
    warning: "⚠",
    error: "✗"
  }

  @doc """
  Creates new Toast widget props.

  ## Options

  - `:message` - Toast message (required)
  - `:type` - Toast type: :info, :success, :warning, :error (default: :info)
  - `:duration` - Auto-dismiss duration in ms (default: 3000, nil for no auto-dismiss)
  - `:position` - Screen position (default: :bottom_right)
  - `:width` - Toast width (default: 40)
  - `:on_dismiss` - Callback when toast is dismissed
  - `:style` - Style for toast background
  - `:icon_style` - Style for icon
  - `:message_style` - Style for message text
  """
  @spec new(keyword()) :: map()
  def new(opts) do
    type = Keyword.get(opts, :type, :info)

    %{
      message: Keyword.fetch!(opts, :message),
      type: type,
      icon: Map.get(@type_icons, type, ""),
      duration: Keyword.get(opts, :duration, 3000),
      position: Keyword.get(opts, :position, :bottom_right),
      width: Keyword.get(opts, :width, 40),
      on_dismiss: Keyword.get(opts, :on_dismiss),
      style: Keyword.get(opts, :style),
      icon_style: Keyword.get(opts, :icon_style),
      message_style: Keyword.get(opts, :message_style)
    }
  end

  @impl true
  def init(props) do
    state = %{
      message: props.message,
      toast_type: props.type,
      icon: props.icon,
      duration: props.duration,
      position: props.position,
      width: props.width,
      on_dismiss: props.on_dismiss,
      style: props.style,
      icon_style: props.icon_style,
      message_style: props.message_style,
      visible: true,
      created_at: System.monotonic_time(:millisecond)
    }

    {:ok, state}
  end

  @impl true
  def handle_event(%Event.Key{key: :escape}, state) do
    dismiss(state)
  end

  def handle_event(%Event.Mouse{action: :click}, state) do
    # Click on toast dismisses it
    dismiss(state)
  end

  def handle_event(_event, state) do
    {:ok, state}
  end

  @impl true
  def render(state, area) do
    if not state.visible do
      empty()
    else
      # Calculate position
      {pos_x, pos_y} = calculate_position(state, area)

      # Render toast content
      toast = render_toast(state)

      # Return as overlay
      %{
        type: :overlay,
        content: toast,
        x: pos_x,
        y: pos_y,
        z: 150  # Higher z-order than dialogs
      }
    end
  end

  # Private functions

  defp calculate_position(state, area) do
    width = state.width
    height = 3  # Single line toast

    case state.position do
      :top_left -> {1, 1}
      :top_center -> {div(area.width - width, 2), 1}
      :top_right -> {area.width - width - 1, 1}
      :bottom_left -> {1, area.height - height - 1}
      :bottom_center -> {div(area.width - width, 2), area.height - height - 1}
      :bottom_right -> {area.width - width - 1, area.height - height - 1}
      _ -> {area.width - width - 1, area.height - height - 1}
    end
  end

  defp render_toast(state) do
    width = state.width

    # Icon + message
    icon = state.icon
    message = state.message

    content_text = if icon != "" do
      icon <> " " <> message
    else
      message
    end

    # Truncate if too long
    inner_width = width - 4
    content_text = String.slice(content_text, 0, inner_width)
    padded = String.pad_trailing(content_text, inner_width)

    # Build toast box
    top_border = text("┌" <> String.duplicate("─", width - 2) <> "┐")
    content_line = text("│ " <> padded <> " │")
    bottom_border = text("└" <> String.duplicate("─", width - 2) <> "┘")

    content = stack(:vertical, [top_border, content_line, bottom_border])

    if state.style do
      styled(content, state.style)
    else
      content
    end
  end

  defp dismiss(state) do
    if state.on_dismiss do
      state.on_dismiss.()
    end
    {:ok, %{state | visible: false}}
  end

  # Public API

  @doc """
  Gets whether the toast is visible.
  """
  @spec visible?(map()) :: boolean()
  def visible?(state) do
    state.visible
  end

  @doc """
  Dismisses the toast.
  """
  @spec dismiss_toast(map()) :: map()
  def dismiss_toast(state) do
    if state.on_dismiss do
      state.on_dismiss.()
    end
    %{state | visible: false}
  end

  @doc """
  Checks if toast should auto-dismiss based on elapsed time.
  """
  @spec should_dismiss?(map()) :: boolean()
  def should_dismiss?(state) do
    if state.duration do
      elapsed = System.monotonic_time(:millisecond) - state.created_at
      elapsed >= state.duration
    else
      false
    end
  end

  @doc """
  Gets the toast type.
  """
  @spec get_type(map()) :: atom()
  def get_type(state) do
    state.toast_type
  end

  @doc """
  Gets the toast position.
  """
  @spec get_position(map()) :: atom()
  def get_position(state) do
    state.position
  end

  @doc """
  Gets the elapsed time since toast was created.
  """
  @spec elapsed_time(map()) :: non_neg_integer()
  def elapsed_time(state) do
    System.monotonic_time(:millisecond) - state.created_at
  end
end

defmodule TermUI.Widgets.ToastManager do
  @moduledoc """
  Manages multiple toast notifications with stacking.

  ToastManager handles the lifecycle of multiple toasts, including
  stacking, auto-dismiss, and position management.

  ## Usage

      # Create manager
      {:ok, manager} = ToastManager.init(%{position: :bottom_right})

      # Add toasts
      manager = ToastManager.add_toast(manager, "File saved", :success)
      manager = ToastManager.add_toast(manager, "Warning: Low disk space", :warning)

      # Update (check auto-dismiss)
      manager = ToastManager.tick(manager)
  """

  alias TermUI.Widgets.Toast

  @doc """
  Creates a new ToastManager.
  """
  @spec new(keyword()) :: map()
  def new(opts \\ []) do
    %{
      toasts: [],
      position: Keyword.get(opts, :position, :bottom_right),
      max_toasts: Keyword.get(opts, :max_toasts, 5),
      default_duration: Keyword.get(opts, :default_duration, 3000),
      spacing: Keyword.get(opts, :spacing, 1)
    }
  end

  @doc """
  Adds a new toast to the manager.
  """
  @spec add_toast(map(), String.t(), atom(), keyword()) :: map()
  def add_toast(manager, message, type \\ :info, opts \\ []) do
    toast_props = Toast.new(
      message: message,
      type: type,
      duration: Keyword.get(opts, :duration, manager.default_duration),
      position: manager.position,
      width: Keyword.get(opts, :width, 40),
      on_dismiss: Keyword.get(opts, :on_dismiss)
    )

    {:ok, toast_state} = Toast.init(toast_props)

    # Add to list, respecting max
    toasts = [toast_state | manager.toasts]
    toasts = Enum.take(toasts, manager.max_toasts)

    %{manager | toasts: toasts}
  end

  @doc """
  Updates the manager, removing dismissed toasts.
  """
  @spec tick(map()) :: map()
  def tick(manager) do
    toasts = manager.toasts
    |> Enum.filter(fn toast ->
      Toast.visible?(toast) && not Toast.should_dismiss?(toast)
    end)

    %{manager | toasts: toasts}
  end

  @doc """
  Gets all visible toasts.
  """
  @spec get_toasts(map()) :: [map()]
  def get_toasts(manager) do
    Enum.filter(manager.toasts, &Toast.visible?/1)
  end

  @doc """
  Gets the count of visible toasts.
  """
  @spec toast_count(map()) :: non_neg_integer()
  def toast_count(manager) do
    length(get_toasts(manager))
  end

  @doc """
  Clears all toasts.
  """
  @spec clear_all(map()) :: map()
  def clear_all(manager) do
    %{manager | toasts: []}
  end

  @doc """
  Renders all toasts with stacking.
  """
  @spec render(map(), map()) :: term()
  def render(manager, area) do
    toasts = get_toasts(manager)

    if Enum.empty?(toasts) do
      %{type: :empty}
    else
      # Render each toast with offset for stacking
      toast_nodes = toasts
      |> Enum.with_index()
      |> Enum.map(fn {toast, index} ->
        # Adjust position for stacking
        offset = index * (3 + manager.spacing)  # 3 = toast height
        adjusted_area = adjust_area_for_stack(area, manager.position, offset)
        Toast.render(toast, adjusted_area)
      end)

      %{type: :stack, direction: :vertical, children: toast_nodes}
    end
  end

  defp adjust_area_for_stack(area, position, offset) do
    case position do
      pos when pos in [:top_left, :top_center, :top_right] ->
        %{area | y: area.y + offset}

      pos when pos in [:bottom_left, :bottom_center, :bottom_right] ->
        %{area | height: area.height - offset}

      _ ->
        area
    end
  end
end
