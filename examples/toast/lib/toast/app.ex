defmodule Toast.App do
  @moduledoc """
  Toast Widget Example

  This example demonstrates how to use the TermUI.Widgets.Toast and
  ToastManager widgets for displaying auto-dismissing notifications.

  Features demonstrated:
  - Info, Success, Warning, Error toast types
  - Different screen positions (6 positions)
  - Auto-dismiss after configurable duration
  - Toast stacking when multiple appear
  - Click or Escape to dismiss manually
  - ToastManager for handling multiple toasts

  Controls:
  - 1: Show Info Toast
  - 2: Show Success Toast
  - 3: Show Warning Toast
  - 4: Show Error Toast
  - 5: Show Multiple Toasts (stacking demo)
  - P: Cycle through positions
  - C: Clear all toasts
  - Q: Quit the application
  """

  use TermUI.Elm

  alias TermUI.Event
  alias TermUI.Renderer.Style
  alias TermUI.Widgets.ToastManager

  @positions [
    :bottom_right,
    :bottom_center,
    :bottom_left,
    :top_right,
    :top_center,
    :top_left
  ]

  @position_names %{
    bottom_right: "Bottom Right",
    bottom_center: "Bottom Center",
    bottom_left: "Bottom Left",
    top_right: "Top Right",
    top_center: "Top Center",
    top_left: "Top Left"
  }

  # ----------------------------------------------------------------------------
  # Component Callbacks
  # ----------------------------------------------------------------------------

  @doc """
  Initialize the component state.
  """
  def init(_opts) do
    %{
      toast_manager: ToastManager.new(position: :bottom_right, default_duration: 3000),
      current_position: :bottom_right,
      position_index: 0,
      toast_count: 0,
      last_action: nil
    }
  end

  @doc """
  Convert keyboard events to messages.
  """
  def event_to_msg(%Event.Key{key: "1"}, _state), do: {:msg, {:show_toast, :info}}
  def event_to_msg(%Event.Key{key: "2"}, _state), do: {:msg, {:show_toast, :success}}
  def event_to_msg(%Event.Key{key: "3"}, _state), do: {:msg, {:show_toast, :warning}}
  def event_to_msg(%Event.Key{key: "4"}, _state), do: {:msg, {:show_toast, :error}}
  def event_to_msg(%Event.Key{key: "5"}, _state), do: {:msg, :show_multiple}
  def event_to_msg(%Event.Key{key: key}, _state) when key in ["p", "P"], do: {:msg, :cycle_position}
  def event_to_msg(%Event.Key{key: key}, _state) when key in ["c", "C"], do: {:msg, :clear_toasts}
  def event_to_msg(%Event.Key{key: key}, _state) when key in ["q", "Q"], do: {:msg, :quit}

  # Tick event for auto-dismiss
  def event_to_msg(%Event.Tick{}, _state), do: {:msg, :tick}

  def event_to_msg(_event, _state), do: :ignore

  @doc """
  Update state based on messages.
  """
  def update({:show_toast, type}, state) do
    message = get_message_for_type(type)
    manager = ToastManager.add_toast(state.toast_manager, message, type)

    {%{state |
      toast_manager: manager,
      toast_count: state.toast_count + 1,
      last_action: "Showed #{type} toast"
    }, []}
  end

  def update(:show_multiple, state) do
    # Add multiple toasts to demonstrate stacking
    manager = state.toast_manager
    manager = ToastManager.add_toast(manager, "First notification", :info)
    manager = ToastManager.add_toast(manager, "Second notification", :success)
    manager = ToastManager.add_toast(manager, "Third notification", :warning)

    {%{state |
      toast_manager: manager,
      toast_count: state.toast_count + 3,
      last_action: "Showed 3 stacked toasts"
    }, []}
  end

  def update(:cycle_position, state) do
    new_index = rem(state.position_index + 1, length(@positions))
    new_position = Enum.at(@positions, new_index)

    # Update manager position
    manager = %{state.toast_manager | position: new_position}

    {%{state |
      toast_manager: manager,
      current_position: new_position,
      position_index: new_index,
      last_action: "Changed position to #{@position_names[new_position]}"
    }, []}
  end

  def update(:clear_toasts, state) do
    manager = ToastManager.clear_all(state.toast_manager)

    {%{state |
      toast_manager: manager,
      last_action: "Cleared all toasts"
    }, []}
  end

  def update(:tick, state) do
    # Update toast manager to remove expired toasts
    manager = ToastManager.tick(state.toast_manager)
    {%{state | toast_manager: manager}, []}
  end

  def update(:quit, state) do
    {state, [:quit]}
  end

  @doc """
  Render the current state to a render tree.
  """
  def view(state) do
    stack(:vertical, [
      render_main_content(state),
      ToastManager.render(state.toast_manager, %{width: 80, height: 24, x: 0, y: 0})
    ])
  end

  # ----------------------------------------------------------------------------
  # Private Helpers
  # ----------------------------------------------------------------------------

  defp get_message_for_type(:info), do: "This is an informational message"
  defp get_message_for_type(:success), do: "Operation completed successfully!"
  defp get_message_for_type(:warning), do: "Warning: Please review this action"
  defp get_message_for_type(:error), do: "Error: Something went wrong"

  defp render_main_content(state) do
    stack(:vertical, [
      # Title
      text("Toast Widget Example", Style.new(fg: :cyan, attrs: [:bold])),
      text("", nil),

      # Instructions
      text("Press a number key to show different toast types:", nil),
      text("", nil),
      text("  1 - Info Toast      (ℹ blue)", nil),
      text("  2 - Success Toast   (✓ green)", nil),
      text("  3 - Warning Toast   (⚠ yellow)", nil),
      text("  4 - Error Toast     (✗ red)", nil),
      text("  5 - Multiple Toasts (stacking demo)", nil),
      text("", nil),

      # Controls
      render_controls(state)
    ])
  end

  defp render_controls(state) do
    box_width = 55
    inner_width = box_width - 2

    top_border = "┌─ Controls " <> String.duplicate("─", inner_width - 12) <> "─┐"
    bottom_border = "└" <> String.duplicate("─", inner_width) <> "┘"

    position_name = @position_names[state.current_position]
    active_toasts = ToastManager.toast_count(state.toast_manager)

    stack(:vertical, [
      text("", nil),
      text(top_border, Style.new(fg: :yellow)),
      text("│" <> String.pad_trailing("  1-5       Show toast(s)", inner_width) <> "│", nil),
      text("│" <> String.pad_trailing("  P         Cycle position", inner_width) <> "│", nil),
      text("│" <> String.pad_trailing("  C         Clear all toasts", inner_width) <> "│", nil),
      text("│" <> String.pad_trailing("  Q         Quit", inner_width) <> "│", nil),
      text("│" <> String.pad_trailing("", inner_width) <> "│", nil),
      text("│" <> String.pad_trailing("  Position: #{position_name}", inner_width) <> "│", nil),
      text("│" <> String.pad_trailing("  Active toasts: #{active_toasts}", inner_width) <> "│", nil),
      text("│" <> String.pad_trailing("  Total shown: #{state.toast_count}", inner_width) <> "│", nil),
      text("│" <> String.pad_trailing("  Last action: #{state.last_action || "(none)"}", inner_width) <> "│", nil),
      text(bottom_border, Style.new(fg: :yellow)),
      text("", nil),
      text("Toasts auto-dismiss after 3 seconds. Click or Escape to dismiss early.", Style.new(fg: :white, attrs: [:dim]))
    ])
  end

  # ----------------------------------------------------------------------------
  # Public API
  # ----------------------------------------------------------------------------

  @doc """
  Run the toast example application.
  """
  def run do
    TermUI.Runtime.run(root: __MODULE__)
  end
end
