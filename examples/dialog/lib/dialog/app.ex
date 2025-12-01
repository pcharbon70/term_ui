defmodule Dialog.App do
  @moduledoc """
  Dialog Widget Example

  This example demonstrates how to use the TermUI.Widgets.Dialog widget
  for displaying modal dialogs with buttons.

  Features demonstrated:
  - Basic dialog with title and content
  - Multiple button options
  - Button navigation
  - Dialog open/close states
  - Different dialog types (info, confirm, warning)

  Controls:
  - 1: Show Info Dialog
  - 2: Show Confirm Dialog
  - 3: Show Warning Dialog
  - Tab/Arrow: Navigate buttons (when dialog open)
  - Enter: Select button (when dialog open)
  - Escape: Close dialog
  - Q: Quit the application
  """

  use TermUI.Elm

  alias TermUI.Event
  alias TermUI.Renderer.Style
  alias TermUI.Widgets.Dialog

  # ----------------------------------------------------------------------------
  # Component Callbacks
  # ----------------------------------------------------------------------------

  @doc """
  Initialize the component state.
  """
  def init(_opts) do
    %{
      # Current dialog state (nil when no dialog visible)
      dialog: nil,
      # Result tracking
      last_result: nil
    }
  end

  @doc """
  Convert keyboard events to messages.
  """
  # When no dialog is visible, number keys show dialogs
  def event_to_msg(%Event.Key{key: "1"}, %{dialog: nil}), do: {:msg, :show_info}
  def event_to_msg(%Event.Key{key: "2"}, %{dialog: nil}), do: {:msg, :show_confirm}
  def event_to_msg(%Event.Key{key: "3"}, %{dialog: nil}), do: {:msg, :show_warning}

  # When dialog is visible, forward events to the dialog widget
  def event_to_msg(event, %{dialog: dialog}) when dialog != nil, do: {:msg, {:dialog_event, event}}

  def event_to_msg(%Event.Key{key: key}, _state) when key in ["q", "Q"], do: {:msg, :quit}
  def event_to_msg(_event, _state), do: :ignore

  @doc """
  Update state based on messages.
  """
  def update(:show_info, state) do
    {show_dialog(state, "Information", "This is an informational message.\nPress OK to continue.", [
      %{id: :ok, label: "OK"}
    ]), []}
  end

  def update(:show_confirm, state) do
    {show_dialog(state, "Confirm Action", "Are you sure you want to proceed?\nThis action cannot be undone.", [
      %{id: :cancel, label: "Cancel"},
      %{id: :confirm, label: "Confirm"}
    ]), []}
  end

  def update(:show_warning, state) do
    {show_dialog(state, "Warning", "Unsaved changes will be lost!\nDo you want to save before closing?", [
      %{id: :dont_save, label: "Don't Save"},
      %{id: :cancel, label: "Cancel"},
      %{id: :save, label: "Save", default: true}
    ]), []}
  end

  def update({:dialog_event, event}, state) do
    case Dialog.handle_event(event, state.dialog) do
      {:ok, new_dialog} ->
        if Dialog.visible?(new_dialog) do
          {%{state | dialog: new_dialog}, []}
        else
          # Dialog was closed - capture result
          result = Dialog.get_focused_button(new_dialog)
          {%{state | dialog: nil, last_result: format_result(result)}, []}
        end
    end
  end

  def update(:quit, state) do
    {state, [:quit]}
  end

  # Helper to create and initialize a dialog
  defp show_dialog(state, title, content, buttons) do
    props = Dialog.new(
      title: title,
      content: text(content, nil),
      buttons: buttons,
      width: 45
    )
    {:ok, dialog} = Dialog.init(props)
    %{state | dialog: dialog}
  end

  defp format_result(nil), do: "Cancelled"
  defp format_result(result), do: "Selected: #{result}"

  @doc """
  Render the current state to a render tree.
  """
  def view(state) do
    main_content = render_main_content(state)

    if state.dialog != nil do
      stack(:vertical, [
        main_content,
        text("", nil),
        Dialog.render(state.dialog, %{width: 80, height: 24})
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
      text("Dialog Widget Example", Style.new(fg: :cyan, attrs: [:bold])),
      text("", nil),

      # Instructions
      text("Press a number key to show different dialog types:", nil),
      text("", nil),
      text("  1 - Info Dialog (single button)", nil),
      text("  2 - Confirm Dialog (two buttons)", nil),
      text("  3 - Warning Dialog (three buttons)", nil),
      text("", nil),

      text("", nil),

      # Controls
      render_controls(state)
    ])
  end

  defp render_controls(state) do
    box_width = 50
    inner_width = box_width - 2

    top_border = "┌─ Controls " <> String.duplicate("─", inner_width - 12) <> "─┐"
    bottom_border = "└" <> String.duplicate("─", inner_width) <> "┘"

    stack(:vertical, [
      text("", nil),
      text(top_border, Style.new(fg: :yellow)),
      text("│" <> String.pad_trailing("  1/2/3     Show dialog", inner_width) <> "│", nil),
      text("│" <> String.pad_trailing("  Tab/←/→   Navigate buttons (in dialog)", inner_width) <> "│", nil),
      text("│" <> String.pad_trailing("  Enter     Select button", inner_width) <> "│", nil),
      text("│" <> String.pad_trailing("  Escape    Close dialog", inner_width) <> "│", nil),
      text("│" <> String.pad_trailing("  Q         Quit", inner_width) <> "│", nil),
      text("│" <> String.pad_trailing("", inner_width) <> "│", nil),
      text("│" <> String.pad_trailing("  Last result: #{state.last_result || "(none)"}", inner_width) <> "│", nil),
      text(bottom_border, Style.new(fg: :yellow))
    ])
  end

  # ----------------------------------------------------------------------------
  # Public API
  # ----------------------------------------------------------------------------

  @doc """
  Run the dialog example application.
  """
  def run do
    TermUI.Runtime.run(root: __MODULE__)
  end
end
