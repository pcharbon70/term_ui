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

  # ----------------------------------------------------------------------------
  # Component Callbacks
  # ----------------------------------------------------------------------------

  @doc """
  Initialize the component state.
  """
  def init(_opts) do
    %{
      # Alert state
      alert_visible: false,
      alert_type: nil,
      alert_title: "",
      alert_message: "",
      alert_buttons: [],
      focused_button: 0,
      # Result tracking
      last_result: nil,
      last_alert_type: nil
    }
  end

  @doc """
  Convert keyboard events to messages.
  """
  def event_to_msg(%Event.Key{key: "1"}, state) when not state.alert_visible, do: {:msg, :show_info}
  def event_to_msg(%Event.Key{key: "2"}, state) when not state.alert_visible, do: {:msg, :show_success}
  def event_to_msg(%Event.Key{key: "3"}, state) when not state.alert_visible, do: {:msg, :show_warning}
  def event_to_msg(%Event.Key{key: "4"}, state) when not state.alert_visible, do: {:msg, :show_error}
  def event_to_msg(%Event.Key{key: "5"}, state) when not state.alert_visible, do: {:msg, :show_confirm}
  def event_to_msg(%Event.Key{key: "6"}, state) when not state.alert_visible, do: {:msg, :show_ok_cancel}

  # Alert controls
  def event_to_msg(%Event.Key{key: :escape}, state) when state.alert_visible, do: {:msg, :cancel_alert}
  def event_to_msg(%Event.Key{key: :tab}, state) when state.alert_visible, do: {:msg, :next_button}
  def event_to_msg(%Event.Key{key: :left}, state) when state.alert_visible, do: {:msg, :prev_button}
  def event_to_msg(%Event.Key{key: :right}, state) when state.alert_visible, do: {:msg, :next_button}
  def event_to_msg(%Event.Key{key: :enter}, state) when state.alert_visible, do: {:msg, :select_button}
  def event_to_msg(%Event.Key{key: " "}, state) when state.alert_visible, do: {:msg, :select_button}

  # Y/N shortcuts for confirm dialog
  def event_to_msg(%Event.Key{key: "y"}, state) when state.alert_visible and state.alert_type == :confirm do
    {:msg, {:select_result, :yes}}
  end
  def event_to_msg(%Event.Key{key: "n"}, state) when state.alert_visible and state.alert_type == :confirm do
    {:msg, {:select_result, :no}}
  end

  def event_to_msg(%Event.Key{key: key}, _state) when key in ["q", "Q"], do: {:msg, :quit}
  def event_to_msg(_event, _state), do: :ignore

  @doc """
  Update state based on messages.
  """
  def update(:show_info, state) do
    {%{state |
      alert_visible: true,
      alert_type: :info,
      alert_title: "Information",
      alert_message: "This is an informational message.",
      alert_buttons: [{:ok, "OK"}],
      focused_button: 0
    }, []}
  end

  def update(:show_success, state) do
    {%{state |
      alert_visible: true,
      alert_type: :success,
      alert_title: "Success",
      alert_message: "Operation completed successfully!",
      alert_buttons: [{:ok, "OK"}],
      focused_button: 0
    }, []}
  end

  def update(:show_warning, state) do
    {%{state |
      alert_visible: true,
      alert_type: :warning,
      alert_title: "Warning",
      alert_message: "Please proceed with caution.",
      alert_buttons: [{:ok, "OK"}],
      focused_button: 0
    }, []}
  end

  def update(:show_error, state) do
    {%{state |
      alert_visible: true,
      alert_type: :error,
      alert_title: "Error",
      alert_message: "An error occurred during the operation.",
      alert_buttons: [{:ok, "OK"}],
      focused_button: 0
    }, []}
  end

  def update(:show_confirm, state) do
    {%{state |
      alert_visible: true,
      alert_type: :confirm,
      alert_title: "Confirm Action",
      alert_message: "Are you sure you want to proceed?",
      alert_buttons: [{:no, "No"}, {:yes, "Yes"}],
      focused_button: 1
    }, []}
  end

  def update(:show_ok_cancel, state) do
    {%{state |
      alert_visible: true,
      alert_type: :ok_cancel,
      alert_title: "Save Changes",
      alert_message: "Do you want to save your changes?",
      alert_buttons: [{:cancel, "Cancel"}, {:ok, "OK"}],
      focused_button: 1
    }, []}
  end

  def update(:cancel_alert, state) do
    result = if state.alert_type == :confirm, do: :no, else: :cancel
    {%{state | alert_visible: false, last_result: result, last_alert_type: state.alert_type}, []}
  end

  def update(:next_button, state) do
    max_idx = length(state.alert_buttons) - 1
    new_idx = min(state.focused_button + 1, max_idx)
    {%{state | focused_button: new_idx}, []}
  end

  def update(:prev_button, state) do
    new_idx = max(state.focused_button - 1, 0)
    {%{state | focused_button: new_idx}, []}
  end

  def update(:select_button, state) do
    {result, _label} = Enum.at(state.alert_buttons, state.focused_button)
    {%{state | alert_visible: false, last_result: result, last_alert_type: state.alert_type}, []}
  end

  def update({:select_result, result}, state) do
    {%{state | alert_visible: false, last_result: result, last_alert_type: state.alert_type}, []}
  end

  def update(:quit, state) do
    {state, [:quit]}
  end

  @doc """
  Render the current state to a render tree.
  """
  def view(state) do
    main_content = render_main_content(state)

    if state.alert_visible do
      stack(:vertical, [
        main_content,
        text("", nil),
        render_alert(state)
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

  defp render_alert(state) do
    width = 50

    # Get icon and style based on alert type
    {icon, title_style} = get_alert_icon_and_style(state.alert_type)

    # Build alert
    stack(:vertical, [
      # Top border
      text("┌" <> String.duplicate("─", width - 2) <> "┐", nil),

      # Title with icon
      render_alert_title(state.alert_title, icon, width, title_style),

      # Separator
      text("├" <> String.duplicate("─", width - 2) <> "┤", nil),

      # Message
      render_alert_message(state.alert_message, width),

      # Separator
      text("├" <> String.duplicate("─", width - 2) <> "┤", nil),

      # Buttons
      render_alert_buttons(state, width),

      # Bottom border
      text("└" <> String.duplicate("─", width - 2) <> "┘", nil)
    ])
  end

  defp get_alert_icon_and_style(:info), do: {"ℹ", Style.new(fg: :cyan)}
  defp get_alert_icon_and_style(:success), do: {"✓", Style.new(fg: :green)}
  defp get_alert_icon_and_style(:warning), do: {"⚠", Style.new(fg: :yellow)}
  defp get_alert_icon_and_style(:error), do: {"✗", Style.new(fg: :red)}
  defp get_alert_icon_and_style(:confirm), do: {"?", Style.new(fg: :blue)}
  defp get_alert_icon_and_style(:ok_cancel), do: {"?", Style.new(fg: :blue)}
  defp get_alert_icon_and_style(_), do: {"", Style.new(fg: :white)}

  defp render_alert_title(title, icon, width, style) do
    title_with_icon = if icon != "", do: "#{icon} #{title}", else: title
    inner_width = width - 4
    padded = String.pad_trailing(title_with_icon, inner_width)
    truncated = String.slice(padded, 0, inner_width)
    line = "│ " <> truncated <> " │"
    text(line, style)
  end

  defp render_alert_message(message, width) do
    inner_width = width - 4
    padded = String.pad_trailing(message, inner_width)
    truncated = String.slice(padded, 0, inner_width)
    text("│ " <> truncated <> " │", nil)
  end

  defp render_alert_buttons(state, width) do
    button_texts =
      state.alert_buttons
      |> Enum.with_index()
      |> Enum.map(fn {{_id, label}, idx} ->
        if idx == state.focused_button do
          "[ " <> label <> " ]"
        else
          "  " <> label <> "  "
        end
      end)

    buttons_line = Enum.join(button_texts, " ")

    # Center the buttons
    inner_width = width - 4
    padding = max(0, inner_width - String.length(buttons_line))
    left_pad = div(padding, 2)

    line = "│ " <>
           String.duplicate(" ", left_pad) <>
           buttons_line <>
           String.duplicate(" ", inner_width - left_pad - String.length(buttons_line)) <> " │"

    text(line, nil)
  end

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
