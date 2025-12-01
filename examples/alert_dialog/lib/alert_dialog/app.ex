defmodule AlertDialog.App do
  @moduledoc """
  Alert Dialog Widget Example

  This example demonstrates how to use the TermUI.Widgets.AlertDialog widget
  for displaying standardized message dialogs.

  Features demonstrated:
  - Info alert (informational message)
  - Success alert (operation succeeded)
  - Warning alert (caution message)
  - Error alert (error message)
  - Confirm dialog (Yes/No choice)
  - OK/Cancel dialog (OK/Cancel choice)
  - Keyboard shortcuts (Y/N for confirm)

  Controls:
  - 1: Show Info Alert
  - 2: Show Success Alert
  - 3: Show Warning Alert
  - 4: Show Error Alert
  - 5: Show Confirm Dialog
  - 6: Show OK/Cancel Dialog
  - Tab/Arrow: Navigate buttons (when alert open)
  - Enter: Select button (when alert open)
  - Y/N: Quick select (in confirm dialogs)
  - Escape: Cancel/Close alert
  - Q: Quit the application
  """

  use TermUI.Elm

  alias TermUI.Event
  alias TermUI.Renderer.Style
  alias TermUI.Widgets.AlertDialog

  # ----------------------------------------------------------------------------
  # Component Callbacks
  # ----------------------------------------------------------------------------

  @doc """
  Initialize the component state.
  """
  def init(_opts) do
    %{
      # Current alert dialog state (nil when no alert visible)
      alert: nil,
      # Result tracking
      last_result: nil,
      last_alert_type: nil
    }
  end

  @doc """
  Convert keyboard events to messages.
  """
  # When no alert is visible, number keys show alerts
  def event_to_msg(%Event.Key{key: "1"}, %{alert: nil}), do: {:msg, :show_info}
  def event_to_msg(%Event.Key{key: "2"}, %{alert: nil}), do: {:msg, :show_success}
  def event_to_msg(%Event.Key{key: "3"}, %{alert: nil}), do: {:msg, :show_warning}
  def event_to_msg(%Event.Key{key: "4"}, %{alert: nil}), do: {:msg, :show_error}
  def event_to_msg(%Event.Key{key: "5"}, %{alert: nil}), do: {:msg, :show_confirm}
  def event_to_msg(%Event.Key{key: "6"}, %{alert: nil}), do: {:msg, :show_ok_cancel}

  # When alert is visible, forward events to the alert widget
  def event_to_msg(event, %{alert: alert}) when alert != nil, do: {:msg, {:alert_event, event}}

  def event_to_msg(%Event.Key{key: key}, _state) when key in ["q", "Q"], do: {:msg, :quit}
  def event_to_msg(_event, _state), do: :ignore

  @doc """
  Update state based on messages.
  """
  def update(:show_info, state), do: {show_alert(state, :info, "Information", "This is an informational message."), []}
  def update(:show_success, state), do: {show_alert(state, :success, "Success", "Operation completed successfully!"), []}
  def update(:show_warning, state), do: {show_alert(state, :warning, "Warning", "Please proceed with caution."), []}
  def update(:show_error, state), do: {show_alert(state, :error, "Error", "An error occurred during the operation."), []}
  def update(:show_confirm, state), do: {show_alert(state, :confirm, "Confirm Action", "Are you sure you want to proceed?"), []}
  def update(:show_ok_cancel, state), do: {show_alert(state, :ok_cancel, "Save Changes", "Do you want to save your changes?"), []}

  def update({:alert_event, event}, state) do
    case AlertDialog.handle_event(event, state.alert) do
      {:ok, new_alert} ->
        if AlertDialog.visible?(new_alert) do
          {%{state | alert: new_alert}, []}
        else
          # Alert was closed - capture result
          result = AlertDialog.get_focused_button(new_alert)
          alert_type = AlertDialog.get_type(new_alert)
          {%{state | alert: nil, last_result: result, last_alert_type: alert_type}, []}
        end
    end
  end

  def update(:quit, state) do
    {state, [:quit]}
  end

  # Helper to create and initialize an alert dialog
  defp show_alert(state, type, title, message) do
    props = AlertDialog.new(type: type, title: title, message: message)
    {:ok, alert} = AlertDialog.init(props)
    %{state | alert: alert}
  end

  @doc """
  Render the current state to a render tree.
  """
  def view(state) do
    main_content = render_main_content(state)

    if state.alert != nil do
      stack(:vertical, [
        main_content,
        text("", nil),
        AlertDialog.render(state.alert, %{width: 80, height: 24})
      ])
    else
      main_content
    end
  end

  # ----------------------------------------------------------------------------
  # Private Helpers
  # ----------------------------------------------------------------------------

  defp render_main_content(state) do
    stack(:vertical, [
      # Title
      text("Alert Dialog Widget Example", Style.new(fg: :cyan, attrs: [:bold])),
      text("", nil),

      # Instructions
      text("Press a number key to show different alert types:", nil),
      text("", nil),
      text("  1 - Info Alert      (informational message)", nil),
      text("  2 - Success Alert   (operation succeeded)", nil),
      text("  3 - Warning Alert   (caution message)", nil),
      text("  4 - Error Alert     (error message)", nil),
      text("  5 - Confirm Dialog  (Yes/No choice)", nil),
      text("  6 - OK/Cancel       (OK/Cancel choice)", nil),
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

    result_text = format_result(state.last_result, state.last_alert_type)

    stack(:vertical, [
      text("", nil),
      text(top_border, Style.new(fg: :yellow)),
      text("│" <> String.pad_trailing("  1-6       Show alert type", inner_width) <> "│", nil),
      text("│" <> String.pad_trailing("  Tab/←/→   Navigate buttons (in alert)", inner_width) <> "│", nil),
      text("│" <> String.pad_trailing("  Enter     Select button", inner_width) <> "│", nil),
      text("│" <> String.pad_trailing("  Y/N       Quick select (confirm only)", inner_width) <> "│", nil),
      text("│" <> String.pad_trailing("  Escape    Cancel/Close alert", inner_width) <> "│", nil),
      text("│" <> String.pad_trailing("  Q         Quit", inner_width) <> "│", nil),
      text("│" <> String.pad_trailing("", inner_width) <> "│", nil),
      text("│" <> String.pad_trailing("  Last result: #{result_text}", inner_width) <> "│", nil),
      text(bottom_border, Style.new(fg: :yellow))
    ])
  end

  defp format_result(nil, _type), do: "(none)"
  defp format_result(result, type), do: "#{type} -> #{result}"

  # ----------------------------------------------------------------------------
  # Public API
  # ----------------------------------------------------------------------------

  @doc """
  Run the alert dialog example application.
  """
  def run do
    TermUI.Runtime.run(root: __MODULE__)
  end
end
