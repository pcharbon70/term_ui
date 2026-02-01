defmodule TermUI.Widgets.AlertDialog do
  @moduledoc """
  Alert dialog widget for standardized messages and confirmations.

  Alert dialog is a specialized dialog with predefined button configurations
  and visual icons for different message types.

  ## Usage

      AlertDialog.new(
        type: :confirm,
        title: "Delete File",
        message: "Are you sure you want to delete this file?",
        on_result: fn result -> handle_result(result) end
      )

  ## Alert Types

  - `:info` - Information message (i icon, OK button)
  - `:success` - Success message (✓ icon, OK button)
  - `:warning` - Warning message (⚠ icon, OK button)
  - `:error` - Error message (✗ icon, OK button)
  - `:confirm` - Confirmation dialog (? icon, Yes/No buttons)
  - `:ok_cancel` - OK/Cancel dialog (OK/Cancel buttons)

  ## Keyboard Navigation

  - Tab/Shift+Tab: Move between buttons
  - Enter/Space: Activate focused button
  - Escape: Close (same as Cancel/No)
  - Y: Yes (in confirm dialogs)
  - N: No (in confirm dialogs)
  """

  use TermUI.StatefulComponent

  alias TermUI.CharacterSet
  alias TermUI.Event

  # Icon keys mapped to CharacterSet fields (or literal strings for ?)
  @type_icon_keys %{
    info: :info,
    success: :check,
    warning: :warning,
    error: :cross_mark,
    confirm: :literal_question,
    ok_cancel: :literal_question
  }

  @type_buttons %{
    info: [%{id: :ok, label: "OK", default: true}],
    success: [%{id: :ok, label: "OK", default: true}],
    warning: [%{id: :ok, label: "OK", default: true}],
    error: [%{id: :ok, label: "OK", default: true}],
    confirm: [
      %{id: :no, label: "No"},
      %{id: :yes, label: "Yes", default: true}
    ],
    ok_cancel: [
      %{id: :cancel, label: "Cancel"},
      %{id: :ok, label: "OK", default: true}
    ]
  }

  @doc """
  Creates new AlertDialog widget props.

  ## Options

  - `:type` - Alert type (required): :info, :success, :warning, :error, :confirm, :ok_cancel
  - `:title` - Dialog title (required)
  - `:message` - Message to display (required)
  - `:on_result` - Callback with result (:ok, :cancel, :yes, :no)
  - `:width` - Dialog width (default: 50)
  - `:background_style` - Style for the dialog background (default: black background)
  - `:border_style` - Style for the border and title (default: cyan foreground)
  - `:icon_style` - Style for the icon
  - `:message_style` - Style for the message
  - `:button_style` - Style for buttons
  - `:focused_button_style` - Style for focused button
  """
  @spec new(keyword()) :: map()
  def new(opts) do
    type = Keyword.fetch!(opts, :type)

    %{
      type: type,
      title: Keyword.fetch!(opts, :title),
      message: Keyword.fetch!(opts, :message),
      buttons: Map.get(@type_buttons, type, [%{id: :ok, label: "OK"}]),
      icon_key: Map.get(@type_icon_keys, type, nil),
      width: Keyword.get(opts, :width, 50),
      on_result: Keyword.get(opts, :on_result),
      background_style: Keyword.get(opts, :background_style, default_background_style()),
      border_style: Keyword.get(opts, :border_style, default_border_style()),
      icon_style: Keyword.get(opts, :icon_style),
      message_style: Keyword.get(opts, :message_style),
      button_style: Keyword.get(opts, :button_style),
      focused_button_style: Keyword.get(opts, :focused_button_style)
    }
  end

  # Default styles for the dialog
  defp default_background_style do
    TermUI.Renderer.Style.new(bg: :black)
  end

  defp default_border_style do
    TermUI.Renderer.Style.new(fg: :cyan)
  end

  @impl true
  def init(props) do
    state = %{
      alert_type: props.type,
      title: props.title,
      message: props.message,
      buttons: props.buttons,
      icon_key: props.icon_key,
      width: props.width,
      focused_button: get_default_focus(props.buttons),
      on_result: props.on_result,
      background_style: props.background_style,
      border_style: props.border_style,
      icon_style: props.icon_style,
      message_style: props.message_style,
      button_style: props.button_style,
      focused_button_style: props.focused_button_style,
      visible: true
    }

    {:ok, state}
  end

  @impl true
  def handle_event(%Event.Key{key: :escape}, state) do
    # Escape acts as Cancel/No
    result = if state.alert_type == :confirm, do: :no, else: :cancel
    handle_result(state, result)
  end

  def handle_event(%Event.Key{key: :tab, modifiers: modifiers}, state) do
    direction = if :shift in modifiers, do: -1, else: 1
    state = move_button_focus(state, direction)
    {:ok, state}
  end

  def handle_event(%Event.Key{key: key}, state) when key in [:enter, " "] do
    handle_result(state, state.focused_button)
  end

  def handle_event(%Event.Key{key: :left}, state) do
    state = move_button_focus(state, -1)
    {:ok, state}
  end

  def handle_event(%Event.Key{key: :right}, state) do
    state = move_button_focus(state, 1)
    {:ok, state}
  end

  # Shortcut keys for confirm dialogs
  def handle_event(%Event.Key{key: "y"}, state) when state.alert_type == :confirm do
    handle_result(state, :yes)
  end

  def handle_event(%Event.Key{key: "n"}, state) when state.alert_type == :confirm do
    handle_result(state, :no)
  end

  # Debug: Log all events to console (temporary)
  def handle_event(event, state) do
    # Log only key events, ignore mouse events to reduce spam
    case event do
      %TermUI.Event.Key{} ->
        IO.inspect(event, label: "AlertDialog Key event")
      _ ->
        :ok
    end

    # ESC key handling - more permissive pattern match
    case event do
      %TermUI.Event.Key{key: key} when key == :escape or key == :ESC ->
        result = if state.alert_type == :confirm, do: :no, else: :cancel
        handle_result(state, result)

      %TermUI.Event.Mouse{} ->
        # Ignore mouse events
        {:ok, state}

      _ ->
        {:ok, state}
    end
  end

  @impl true
  def render(%{visible: false}, _area), do: empty()

  @impl true
  def render(state, area) do
    # Calculate dialog position (centered)
    dialog_width = state.width
    dialog_height = calculate_height(state)

    pos_x = max(0, div(area.width - dialog_width, 2))
    pos_y = max(0, div(area.height - dialog_height, 2))

    # Render dialog content
    dialog = render_dialog(state, dialog_width)

    # Return as overlay with background fill
    %{
      type: :overlay,
      content: dialog,
      x: pos_x,
      y: pos_y,
      z: 100,
      # Provide dimensions and background for opaque fill
      width: dialog_width,
      height: dialog_height,
      bg: state.background_style
    }
  end

  # Private functions

  defp get_default_focus(buttons) do
    default = Enum.find(buttons, fn b -> Map.get(b, :default, false) end)

    if default do
      default.id
    else
      case buttons do
        [first | _] -> first.id
        [] -> nil
      end
    end
  end

  defp move_button_focus(state, direction) do
    button_ids = Enum.map(state.buttons, & &1.id)

    case Enum.find_index(button_ids, &(&1 == state.focused_button)) do
      nil ->
        state

      current_idx ->
        new_idx = rem(current_idx + direction + length(button_ids), length(button_ids))
        %{state | focused_button: Enum.at(button_ids, new_idx)}
    end
  end

  defp handle_result(state, result) do
    if state.on_result do
      state.on_result.(result)
    end

    {:ok, %{state | visible: false}}
  end

  defp calculate_height(state) do
    # Title (1) + icon+message (1) + buttons (1) + borders (4) + padding (2)
    message_lines = String.split(state.message, "\n") |> length()
    6 + message_lines
  end

  defp render_dialog(state, width) do
    chars = CharacterSet.current_charset()

    # Border - with border_style
    top_border =
      text(chars.tl <> String.duplicate(chars.h_line, width - 2) <> chars.tr)
      |> styled(state.border_style)

    bottom_border =
      text(chars.bl <> String.duplicate(chars.h_line, width - 2) <> chars.br)
      |> styled(state.border_style)

    # Title - with border_style
    title = render_title(state, width, chars) |> styled(state.border_style)

    # Separator - with border_style
    separator =
      text(chars.t_right <> String.duplicate(chars.h_line, width - 2) <> chars.t_left)
      |> styled(state.border_style)

    # Icon and message - with background style handled in render_content
    content = render_content(state, width, chars)

    # Buttons - with background style handled in render_buttons
    buttons = render_buttons(state, width, chars)

    stack(:vertical, [
      top_border,
      title,
      separator,
      content,
      separator,
      buttons,
      bottom_border
    ])
  end

  # Merge multiple styles, with later styles taking precedence
  defp merge_style_options(styles) do
    styles
    |> Enum.reject(&is_nil/1)
    |> Enum.reduce(fn style, acc ->
      TermUI.Renderer.Style.merge(acc, style)
    end)
  end

  defp merge_style_options(style1, style2) do
    merge_style_options([style1, style2])
  end

  defp render_title(state, width, chars) do
    # Get icon from charset (or use "?" for confirm/ok_cancel)
    icon =
      case state.icon_key do
        :literal_question -> "?"
        nil -> ""
        key -> Map.get(chars, key, "")
      end

    # Include icon in title if present
    # Extra space after icon to account for unicode width variations
    title_text =
      if icon != "" do
        icon <> "  " <> state.title
      else
        state.title
      end

    padding = width - String.length(title_text) - 4
    left_pad = div(padding, 2)
    right_pad = padding - left_pad

    line =
      chars.v_line <>
        " " <>
        String.duplicate(" ", left_pad) <>
        title_text <>
        String.duplicate(" ", right_pad) <>
        " " <> chars.v_line

    text(line)
  end

  defp render_content(state, width, chars) do
    # Message only (icon is now in title)
    message = state.message

    # Pad to width
    inner_width = width - 4
    padded = String.pad_trailing(message, inner_width)
    padded = String.slice(padded, 0, inner_width)

    line = chars.v_line <> " " <> padded <> " " <> chars.v_line

    # Merge message_style with background_style
    style = merge_style_options(state.message_style, state.background_style)

    if style do
      styled(text(line), style)
    else
      text(line)
    end
  end

  defp render_buttons(state, width, chars) do
    button_texts =
      Enum.map(state.buttons, fn button ->
        label = button.label

        if button.id == state.focused_button do
          "[ " <> label <> " ]"
        else
          "  " <> label <> "  "
        end
      end)

    buttons_line = Enum.join(button_texts, " ")

    # Center buttons
    inner_width = width - 4
    padding = inner_width - String.length(buttons_line)
    left_pad = max(0, div(padding, 2))

    line =
      chars.v_line <>
        " " <>
        String.duplicate(" ", left_pad) <>
        buttons_line <>
        String.duplicate(" ", max(0, inner_width - left_pad - String.length(buttons_line))) <>
        " " <> chars.v_line

    # Merge button_style or focused_button_style with background_style
    button_style =
      if state.focused_button_style do
        state.focused_button_style
      else
        state.button_style
      end

    style = merge_style_options(button_style, state.background_style)

    if style do
      styled(text(line), style)
    else
      text(line)
    end
  end

  # Public API

  @doc """
  Gets whether the alert is visible.
  """
  @spec visible?(map()) :: boolean()
  def visible?(state) do
    state.visible
  end

  @doc """
  Shows the alert.
  """
  @spec show(map()) :: map()
  def show(state) do
    %{state | visible: true}
  end

  @doc """
  Hides the alert.
  """
  @spec hide(map()) :: map()
  def hide(state) do
    %{state | visible: false}
  end

  @doc """
  Gets the alert type.
  """
  @spec get_type(map()) :: atom()
  def get_type(state) do
    state.alert_type
  end

  @doc """
  Gets the currently focused button.
  """
  @spec get_focused_button(map()) :: term()
  def get_focused_button(state) do
    state.focused_button
  end

  @doc """
  Updates the message.
  """
  @spec set_message(map(), String.t()) :: map()
  def set_message(state, message) do
    %{state | message: message}
  end
end
