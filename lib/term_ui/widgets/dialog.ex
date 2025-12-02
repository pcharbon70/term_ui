defmodule TermUI.Widgets.Dialog do
  @moduledoc """
  Dialog widget for modal overlays.

  Dialog appears centered over the application with a backdrop, traps focus,
  and handles Escape for cancellation. Use for confirmations, forms, and
  important messages.

  ## Usage

      Dialog.new(
        title: "Confirm Delete",
        content: delete_confirmation_content(),
        buttons: [
          %{id: :cancel, label: "Cancel"},
          %{id: :confirm, label: "Delete", style: :danger}
        ],
        on_close: fn -> dismiss_dialog() end,
        on_confirm: fn button_id -> handle_action(button_id) end
      )

  ## Features

  - Centered display with customizable width/height
  - Semi-transparent backdrop
  - Focus trapping (Tab cycles within dialog)
  - Escape to close
  - Button navigation and selection

  ## Keyboard Navigation

  - Tab/Shift+Tab: Move between buttons
  - Enter/Space: Activate focused button
  - Escape: Close dialog
  """

  use TermUI.StatefulComponent

  alias TermUI.Event
  alias TermUI.Renderer.Style

  @doc """
  Creates new Dialog widget props.

  ## Options

  - `:title` - Dialog title (required)
  - `:content` - Dialog body content (render node)
  - `:buttons` - List of button definitions
  - `:width` - Dialog width (default: 40)
  - `:on_close` - Callback when dialog is closed
  - `:on_confirm` - Callback when button is activated
  - `:closeable` - Whether Escape closes dialog (default: true)
  - `:title_style` - Style for title bar
  - `:content_style` - Style for content area
  - `:button_style` - Style for buttons
  - `:focused_button_style` - Style for focused button
  """
  @spec new(keyword()) :: map()
  def new(opts) do
    %{
      title: Keyword.fetch!(opts, :title),
      content: Keyword.get(opts, :content, empty()),
      buttons: Keyword.get(opts, :buttons, [%{id: :ok, label: "OK"}]),
      width: Keyword.get(opts, :width, 40),
      on_close: Keyword.get(opts, :on_close),
      on_confirm: Keyword.get(opts, :on_confirm),
      closeable: Keyword.get(opts, :closeable, true),
      title_style: Keyword.get(opts, :title_style),
      content_style: Keyword.get(opts, :content_style),
      button_style: Keyword.get(opts, :button_style),
      focused_button_style: Keyword.get(opts, :focused_button_style)
    }
  end

  @impl true
  def init(props) do
    state = %{
      title: props.title,
      content: props.content,
      buttons: props.buttons,
      width: props.width,
      focused_button: get_default_focus(props.buttons),
      on_close: props.on_close,
      on_confirm: props.on_confirm,
      closeable: props.closeable,
      title_style: props.title_style,
      content_style: props.content_style,
      button_style: props.button_style,
      focused_button_style: props.focused_button_style,
      visible: true
    }

    {:ok, state}
  end

  @impl true
  def handle_event(%Event.Key{key: :escape}, state) do
    if state.closeable do
      close_dialog(state)
    else
      {:ok, state}
    end
  end

  def handle_event(%Event.Key{key: :tab, modifiers: modifiers}, state) do
    # Focus trapping - cycle through buttons
    direction = if :shift in modifiers, do: -1, else: 1
    state = move_button_focus(state, direction)
    {:ok, state}
  end

  def handle_event(%Event.Key{key: key}, state) when key in [:enter, " "] do
    # Activate focused button and close dialog
    if state.on_confirm && state.focused_button do
      state.on_confirm.(state.focused_button)
    end

    {:ok, %{state | visible: false}}
  end

  def handle_event(%Event.Key{key: :left}, state) do
    state = move_button_focus(state, -1)
    {:ok, state}
  end

  def handle_event(%Event.Key{key: :right}, state) do
    state = move_button_focus(state, 1)
    {:ok, state}
  end

  def handle_event(%Event.Mouse{action: :click, x: x, y: y}, state) do
    # Check if click is on a button
    case find_button_at_position(state, x, y) do
      nil ->
        {:ok, state}

      button_id ->
        if state.on_confirm do
          state.on_confirm.(button_id)
        end

        {:ok, %{state | focused_button: button_id, visible: false}}
    end
  end

  def handle_event(_event, state) do
    {:ok, state}
  end

  @impl true
  def render(%{visible: false}, _area), do: empty()

  def render(state, area) do
    # Calculate dialog position (centered)
    dialog_width = state.width
    dialog_height = calculate_height(state)

    pos_x = max(0, div(area.width - dialog_width, 2))
    pos_y = max(0, div(area.height - dialog_height, 2))

    # Render dialog content
    dialog = render_dialog(state, dialog_width)

    # Return as overlay with opaque background
    %{
      type: :overlay,
      content: dialog,
      x: pos_x,
      y: pos_y,
      z: 100,
      # Provide dimensions and background for opaque fill
      width: dialog_width,
      height: dialog_height,
      bg: Style.new(bg: :black)
    }
  end

  # Private functions

  defp get_default_focus(buttons) do
    # Focus on first button, or one marked as default
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

  defp close_dialog(state) do
    if state.on_close do
      state.on_close.()
    end

    {:ok, %{state | visible: false}}
  end

  defp find_button_at_position(_state, _x, _y) do
    # Simplified - would need actual button positions from render
    nil
  end

  defp calculate_height(state) do
    # Title (1) + border (2) + content (estimated 3) + buttons (1) + padding (2)
    content_lines = estimate_content_lines(state.content)
    3 + content_lines + 2
  end

  defp estimate_content_lines(content) do
    case content do
      %{type: :text, content: text} ->
        String.split(text, "\n") |> length()

      %{type: :stack, direction: :vertical, children: children} ->
        length(children)

      _ ->
        3
    end
  end

  defp render_dialog(state, width) do
    # Title bar
    title = render_title(state, width)

    # Content area
    content = render_content(state, width)

    # Button bar
    buttons = render_buttons(state)

    # Border
    top_border = text("┌" <> String.duplicate("─", width - 2) <> "┐")
    bottom_border = text("└" <> String.duplicate("─", width - 2) <> "┘")

    stack(:vertical, [
      top_border,
      title,
      render_separator(width),
      content,
      render_separator(width),
      buttons,
      bottom_border
    ])
  end

  defp render_title(state, width) do
    # Center title in available space
    title_text = state.title
    padding = width - String.length(title_text) - 4
    left_pad = div(padding, 2)
    right_pad = padding - left_pad

    line =
      "│ " <>
        String.duplicate(" ", left_pad) <>
        title_text <>
        String.duplicate(" ", right_pad) <> " │"

    if state.title_style do
      styled(text(line), state.title_style)
    else
      text(line)
    end
  end

  defp render_separator(width) do
    text("├" <> String.duplicate("─", width - 2) <> "┤")
  end

  defp render_content(state, width) do
    # Extract text from content node
    content_text =
      case state.content do
        %{type: :text, content: t} -> t
        %{type: :empty} -> ""
        _ -> ""
      end

    # Split into lines and render each with borders
    inner_width = width - 4
    lines = String.split(content_text, "\n")

    content_lines =
      Enum.map(lines, fn line_text ->
        padded = String.pad_trailing(line_text, inner_width)
        padded = String.slice(padded, 0, inner_width)
        line = "│ " <> padded <> " │"

        if state.content_style do
          styled(text(line), state.content_style)
        else
          text(line)
        end
      end)

    stack(:vertical, content_lines)
  end

  defp render_buttons(state) do
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
    inner_width = state.width - 4
    padding = inner_width - String.length(buttons_line)
    left_pad = div(padding, 2)

    line =
      "│ " <>
        String.duplicate(" ", left_pad) <>
        buttons_line <>
        String.duplicate(" ", inner_width - left_pad - String.length(buttons_line)) <> " │"

    if state.focused_button_style do
      styled(text(line), state.focused_button_style)
    else
      text(line)
    end
  end

  # Public API

  @doc """
  Gets whether the dialog is visible.
  """
  @spec visible?(map()) :: boolean()
  def visible?(state) do
    state.visible
  end

  @doc """
  Shows the dialog.
  """
  @spec show(map()) :: map()
  def show(state) do
    %{state | visible: true}
  end

  @doc """
  Hides the dialog.
  """
  @spec hide(map()) :: map()
  def hide(state) do
    %{state | visible: false}
  end

  @doc """
  Gets the currently focused button ID.
  """
  @spec get_focused_button(map()) :: term()
  def get_focused_button(state) do
    state.focused_button
  end

  @doc """
  Sets focus to a specific button.
  """
  @spec focus_button(map(), term()) :: map()
  def focus_button(state, button_id) do
    if Enum.any?(state.buttons, &(&1.id == button_id)) do
      %{state | focused_button: button_id}
    else
      state
    end
  end

  @doc """
  Updates the dialog content.
  """
  @spec set_content(map(), term()) :: map()
  def set_content(state, content) do
    %{state | content: content}
  end

  @doc """
  Updates the dialog title.
  """
  @spec set_title(map(), String.t()) :: map()
  def set_title(state, title) do
    %{state | title: title}
  end
end
