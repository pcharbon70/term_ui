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

  @behaviour TermUI.Component

  import TermUI.Component.RenderNode

  alias TermUI.Event
  alias TermUI.Style

  # ----------------------------------------------------------------------------
  # Component Callbacks
  # ----------------------------------------------------------------------------

  @doc """
  Initialize the component state.
  """
  @impl true
  def init(_opts) do
    %{
      # Dialog state
      dialog_visible: false,
      dialog_type: nil,
      dialog_title: "",
      dialog_content: "",
      dialog_buttons: [],
      focused_button: 0,
      # Result tracking
      last_result: nil
    }
  end

  @doc """
  Convert keyboard events to messages.
  """
  @impl true
  def event_to_msg(%Event.Key{key: "1"}, state) when not state.dialog_visible, do: {:msg, :show_info}
  def event_to_msg(%Event.Key{key: "2"}, state) when not state.dialog_visible, do: {:msg, :show_confirm}
  def event_to_msg(%Event.Key{key: "3"}, state) when not state.dialog_visible, do: {:msg, :show_warning}

  # Dialog controls
  def event_to_msg(%Event.Key{key: :escape}, state) when state.dialog_visible, do: {:msg, :close_dialog}
  def event_to_msg(%Event.Key{key: :tab}, state) when state.dialog_visible, do: {:msg, :next_button}
  def event_to_msg(%Event.Key{key: :left}, state) when state.dialog_visible, do: {:msg, :prev_button}
  def event_to_msg(%Event.Key{key: :right}, state) when state.dialog_visible, do: {:msg, :next_button}
  def event_to_msg(%Event.Key{key: :enter}, state) when state.dialog_visible, do: {:msg, :select_button}
  def event_to_msg(%Event.Key{key: " "}, state) when state.dialog_visible, do: {:msg, :select_button}

  def event_to_msg(%Event.Key{key: key}, _state) when key in ["q", "Q"], do: {:msg, :quit}
  def event_to_msg(_event, _state), do: :ignore

  @doc """
  Update state based on messages.
  """
  @impl true
  def update(:show_info, state) do
    {%{state |
      dialog_visible: true,
      dialog_type: :info,
      dialog_title: "Information",
      dialog_content: "This is an informational message.\nPress OK to continue.",
      dialog_buttons: ["OK"],
      focused_button: 0
    }, []}
  end

  def update(:show_confirm, state) do
    {%{state |
      dialog_visible: true,
      dialog_type: :confirm,
      dialog_title: "Confirm Action",
      dialog_content: "Are you sure you want to proceed?\nThis action cannot be undone.",
      dialog_buttons: ["Cancel", "Confirm"],
      focused_button: 0
    }, []}
  end

  def update(:show_warning, state) do
    {%{state |
      dialog_visible: true,
      dialog_type: :warning,
      dialog_title: "Warning",
      dialog_content: "Unsaved changes will be lost!\nDo you want to save before closing?",
      dialog_buttons: ["Don't Save", "Cancel", "Save"],
      focused_button: 2
    }, []}
  end

  def update(:close_dialog, state) do
    {%{state | dialog_visible: false, last_result: "Cancelled"}, []}
  end

  def update(:next_button, state) do
    max_idx = length(state.dialog_buttons) - 1
    new_idx = min(state.focused_button + 1, max_idx)
    {%{state | focused_button: new_idx}, []}
  end

  def update(:prev_button, state) do
    new_idx = max(state.focused_button - 1, 0)
    {%{state | focused_button: new_idx}, []}
  end

  def update(:select_button, state) do
    selected = Enum.at(state.dialog_buttons, state.focused_button)
    {%{state | dialog_visible: false, last_result: "Selected: #{selected}"}, []}
  end

  def update(:quit, state) do
    {state, [:quit]}
  end

  @doc """
  Render the current state to a render tree.
  """
  @impl true
  def view(state) do
    main_content = render_main_content(state)

    if state.dialog_visible do
      stack(:vertical, [
        main_content,
        text(""),
        render_dialog(state)
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
      styled(
        text("Dialog Widget Example"),
        Style.new(fg: :cyan, attrs: [:bold])
      ),
      text(""),

      # Instructions
      text("Press a number key to show different dialog types:"),
      text(""),
      text("  1 - Info Dialog (single button)"),
      text("  2 - Confirm Dialog (two buttons)"),
      text("  3 - Warning Dialog (three buttons)"),
      text(""),

      # Last result
      text("Last result: #{state.last_result || "(none)"}"),
      text(""),

      # Controls
      styled(
        text("Controls:"),
        Style.new(fg: :yellow)
      ),
      text("  1/2/3     Show dialog"),
      text("  Tab/←/→   Navigate buttons (in dialog)"),
      text("  Enter     Select button"),
      text("  Escape    Close dialog"),
      text("  Q         Quit")
    ])
  end

  defp render_dialog(state) do
    width = 45

    # Get title style based on dialog type
    title_style =
      case state.dialog_type do
        :info -> Style.new(fg: :cyan)
        :confirm -> Style.new(fg: :blue)
        :warning -> Style.new(fg: :yellow)
        _ -> Style.new(fg: :white)
      end

    # Build dialog
    stack(:vertical, [
      # Top border
      text("┌" <> String.duplicate("─", width - 2) <> "┐"),

      # Title
      styled(
        text("│ " <> String.pad_trailing(state.dialog_title, width - 4) <> " │"),
        title_style
      ),

      # Separator
      text("├" <> String.duplicate("─", width - 2) <> "┤"),

      # Content
      render_dialog_content(state.dialog_content, width),

      # Separator
      text("├" <> String.duplicate("─", width - 2) <> "┤"),

      # Buttons
      render_buttons(state, width),

      # Bottom border
      text("└" <> String.duplicate("─", width - 2) <> "┘")
    ])
  end

  defp render_dialog_content(content, width) do
    lines = String.split(content, "\n")

    rows =
      Enum.map(lines, fn line ->
        padded = String.pad_trailing(line, width - 4)
        truncated = String.slice(padded, 0, width - 4)
        text("│ " <> truncated <> " │")
      end)

    stack(:vertical, rows)
  end

  defp render_buttons(state, width) do
    button_texts =
      state.dialog_buttons
      |> Enum.with_index()
      |> Enum.map(fn {label, idx} ->
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

    line = "│ " <> String.duplicate(" ", left_pad) <>
           buttons_line <>
           String.duplicate(" ", inner_width - left_pad - String.length(buttons_line)) <> " │"

    text(line)
  end

  # ----------------------------------------------------------------------------
  # Public API
  # ----------------------------------------------------------------------------

  @doc """
  Run the dialog example application.
  """
  def run do
    TermUI.run(__MODULE__)
  end
end
