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

  ## Mouse Support

  In raw mode, dialog buttons can be clicked with the mouse. Clicking a button
  produces the same result as pressing Enter on that button. Mouse events are
  ignored in TTY mode.

  - Left click on button: Activate the button
  """

  use TermUI.StatefulComponent

  alias TermUI.CharacterSet
  alias TermUI.Event
  alias TermUI.PersistentTerms
  alias TermUI.Renderer.Style
  alias TermUI.Theme

  # Dialyzer: Suppress opaque type warnings for Style helpers
  @dialyzer {:nowarn_function, bg_theme: 1}

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

  # ----------------------------------------------------------------------------
  # Style Helper Functions
  # ----------------------------------------------------------------------------

  @spec bg_theme(atom()) :: Style.t()
  defp bg_theme(color) when is_atom(color),
    do: Style.new() |> Style.bg(color)

  # ----------------------------------------------------------------------------
  # StatefulComponent Callbacks
  # ----------------------------------------------------------------------------

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

  def handle_event(%Event.Mouse{action: :press, button: :left, x: x, y: y}, state) do
    # Only handle mouse events in raw mode
    if PersistentTerms.backend_mode() == :raw do
      handle_button_click(state, x, y)
    else
      # Ignore mouse events in TTY mode
      {:ok, state}
    end
  end

  def handle_event(_event, state) do
    {:ok, state}
  end

  # ----------------------------------------------------------------------------
  # Private Helpers for Event Handling
  # ----------------------------------------------------------------------------

  defp handle_button_click(state, x, y) do
    case find_button_at_position(state, x, y) do
      nil ->
        {:ok, state}

      button_id ->
        activate_button(state, button_id)
    end
  end

  defp activate_button(state, button_id) do
    if state.on_confirm do
      state.on_confirm.(button_id)
    end

    {:ok, %{state | focused_button: button_id, visible: false}}
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
      bg: bg_theme(Theme.get_color(:background))
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

  defp find_button_at_position(state, click_x, click_y) do
    button_row_y = calculate_button_row_y(state)

    if click_y == button_row_y do
      find_button_by_x_position(state, click_x)
    else
      nil
    end
  end

  defp calculate_button_row_y(state) do
    _area_width = 80
    area_height = 24
    _dialog_width = state.width
    dialog_height = calculate_height(state)

    dialog_y = max(0, div(area_height - dialog_height, 2))
    content_lines = estimate_content_lines(state.content)
    button_row_in_dialog = 4 + content_lines

    dialog_y + button_row_in_dialog
  end

  defp find_button_by_x_position(state, click_x) do
    dialog_x = calculate_dialog_x(state.width)
    inner_width = state.width - 4
    button_texts = build_button_texts(state)
    left_pad = calculate_button_padding(button_texts, inner_width)
    buttons_start_x = dialog_x + 2 + left_pad

    find_button_at_x(state.buttons, button_texts, buttons_start_x, click_x)
  end

  defp calculate_dialog_x(dialog_width) do
    max(0, div(80 - dialog_width, 2))
  end

  defp build_button_texts(state) do
    Enum.map(state.buttons, fn button ->
      label = button.label
      if button.id == state.focused_button do
        "[ " <> label <> " ]"
      else
        "  " <> label <> "  "
      end
    end)
  end

  defp calculate_button_padding(button_texts, inner_width) do
    buttons_line = Enum.join(button_texts, " ")
    max(0, div(inner_width - String.length(buttons_line), 2))
  end

  defp find_button_at_x(buttons, button_texts, start_x, click_x) do
    # Iterate through buttons to find which one contains click_x
    Enum.reduce_while(buttons, {button_texts, start_x}, fn button, {texts, current_x} ->
      [button_text | remaining_texts] = texts
      button_width = String.length(button_text)

      if click_x >= current_x and click_x < current_x + button_width do
        {:halt, button.id}
      else
        {:cont, {remaining_texts, current_x + button_width + 1}}  # +1 for space between buttons
      end
    end)
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
    chars = CharacterSet.current_charset()

    # Title bar
    title = render_title(state, width, chars)

    # Content area
    content = render_content(state, width, chars)

    # Button bar
    buttons = render_buttons(state, chars)

    # Border
    top_border = text(chars.tl <> String.duplicate(chars.h_line, width - 2) <> chars.tr)
    bottom_border = text(chars.bl <> String.duplicate(chars.h_line, width - 2) <> chars.br)

    stack(:vertical, [
      top_border,
      title,
      render_separator(width, chars),
      content,
      render_separator(width, chars),
      buttons,
      bottom_border
    ])
  end

  defp render_title(state, width, chars) do
    # Center title in available space
    title_text = state.title
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

    if state.title_style do
      styled(text(line), state.title_style)
    else
      text(line)
    end
  end

  defp render_separator(width, chars) do
    text(chars.t_right <> String.duplicate(chars.h_line, width - 2) <> chars.t_left)
  end

  defp render_content(state, width, chars) do
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
        line = chars.v_line <> " " <> padded <> " " <> chars.v_line

        if state.content_style do
          styled(text(line), state.content_style)
        else
          text(line)
        end
      end)

    stack(:vertical, content_lines)
  end

  defp render_buttons(state, chars) do
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
      chars.v_line <>
        " " <>
        String.duplicate(" ", left_pad) <>
        buttons_line <>
        String.duplicate(" ", inner_width - left_pad - String.length(buttons_line)) <>
        " " <> chars.v_line

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
