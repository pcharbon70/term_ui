defmodule TermUI.Widgets.TextInput do
  @moduledoc """
  TextInput widget for single-line and multi-line text input.

  Provides text editing with cursor movement, auto-growing height,
  and scrolling for content that exceeds the visible area.

  ## Usage

      TextInput.new(
        value: "",
        placeholder: "Enter text...",
        width: 40,
        multiline: true,
        max_visible_lines: 5
      )

  ## Features

  - Single-line and multi-line modes
  - Ctrl+Enter for newline insertion (multiline)
  - Auto-growing height up to max_visible_lines
  - Scrollable area when content exceeds visible lines
  - Cursor movement and text editing
  - Placeholder text support
  - Focus state handling

  ## Keyboard Controls

  - Left/Right: Move cursor horizontally
  - Up/Down: Move cursor between lines (multiline)
  - Home/End: Move to start/end of line
  - Ctrl+Home/End: Move to start/end of text
  - Backspace: Delete character before cursor
  - Delete: Delete character at cursor
  - Ctrl+Enter: Insert newline (multiline mode)
  - Enter: Submit (single-line) or insert newline if configured
  - Escape: Blur input
  """

  use TermUI.StatefulComponent

  alias TermUI.Event

  @default_width 40
  @default_max_visible_lines 5

  # ----------------------------------------------------------------------------
  # Props
  # ----------------------------------------------------------------------------

  @doc """
  Creates new TextInput widget props.

  ## Options

  - `:value` - Initial text value (default: "")
  - `:placeholder` - Placeholder text when empty (default: "")
  - `:width` - Widget width in characters (default: 40)
  - `:multiline` - Enable multi-line mode (default: false)
  - `:max_lines` - Maximum number of lines allowed, nil for unlimited (default: nil)
  - `:max_visible_lines` - Lines visible before scrolling (default: 5)
  - `:on_change` - Callback when value changes: fn(value) -> any
  - `:on_submit` - Callback when submitted: fn(value) -> any
  - `:enter_submits` - Enter key submits instead of newline in multiline (default: false)
  - `:disabled` - Disable input (default: false)
  - `:style` - Text style
  - `:focused_style` - Style when focused
  - `:placeholder_style` - Placeholder text style
  """
  @spec new(keyword()) :: map()
  def new(opts \\ []) do
    %{
      value: Keyword.get(opts, :value, ""),
      placeholder: Keyword.get(opts, :placeholder, ""),
      width: Keyword.get(opts, :width, @default_width),
      multiline: Keyword.get(opts, :multiline, false),
      max_lines: Keyword.get(opts, :max_lines),
      max_visible_lines: Keyword.get(opts, :max_visible_lines, @default_max_visible_lines),
      on_change: Keyword.get(opts, :on_change),
      on_submit: Keyword.get(opts, :on_submit),
      enter_submits: Keyword.get(opts, :enter_submits, false),
      disabled: Keyword.get(opts, :disabled, false),
      style: Keyword.get(opts, :style),
      focused_style: Keyword.get(opts, :focused_style),
      placeholder_style: Keyword.get(opts, :placeholder_style)
    }
  end

  # ----------------------------------------------------------------------------
  # StatefulComponent Callbacks
  # ----------------------------------------------------------------------------

  @impl true
  def init(props) do
    lines = text_to_lines(props.value)

    state = %{
      # Text content
      lines: lines,
      cursor_row: 0,
      cursor_col: 0,
      scroll_offset: 0,

      # Focus
      focused: false,

      # Configuration
      width: props.width,
      multiline: props.multiline,
      max_lines: props.max_lines,
      max_visible_lines: props.max_visible_lines,
      placeholder: props.placeholder,
      enter_submits: props.enter_submits,
      disabled: props.disabled,

      # Styles
      style: props.style,
      focused_style: props.focused_style,
      placeholder_style: props.placeholder_style,

      # Callbacks
      on_change: props.on_change,
      on_submit: props.on_submit
    }

    {:ok, state}
  end

  @impl true
  def update(new_props, state) do
    # Update configuration from new props
    state =
      state
      |> Map.put(:width, new_props.width)
      |> Map.put(:multiline, new_props.multiline)
      |> Map.put(:max_lines, new_props.max_lines)
      |> Map.put(:max_visible_lines, new_props.max_visible_lines)
      |> Map.put(:placeholder, new_props.placeholder)
      |> Map.put(:enter_submits, new_props.enter_submits)
      |> Map.put(:disabled, new_props.disabled)
      |> Map.put(:style, new_props.style)
      |> Map.put(:focused_style, new_props.focused_style)
      |> Map.put(:placeholder_style, new_props.placeholder_style)
      |> Map.put(:on_change, new_props.on_change)
      |> Map.put(:on_submit, new_props.on_submit)

    # Update value if changed externally
    new_lines = text_to_lines(new_props.value)
    current_text = lines_to_text(state.lines)

    state =
      if new_props.value != current_text do
        %{state | lines: new_lines}
        |> clamp_cursor()
        |> adjust_scroll()
      else
        state
      end

    {:ok, state}
  end

  # ----------------------------------------------------------------------------
  # Event Handling
  # ----------------------------------------------------------------------------

  @impl true
  def handle_event(_event, %{disabled: true} = state) do
    {:ok, state}
  end

  # Arrow keys - cursor movement
  def handle_event(%Event.Key{key: :left}, state) do
    {:ok, move_cursor_left(state)}
  end

  def handle_event(%Event.Key{key: :right}, state) do
    {:ok, move_cursor_right(state)}
  end

  def handle_event(%Event.Key{key: :up}, %{multiline: true} = state) do
    {:ok, move_cursor_up(state)}
  end

  def handle_event(%Event.Key{key: :down}, %{multiline: true} = state) do
    {:ok, move_cursor_down(state)}
  end

  # Home/End
  def handle_event(%Event.Key{key: :home, modifiers: modifiers}, state) do
    if :ctrl in modifiers do
      {:ok, move_to_start(state)}
    else
      {:ok, move_to_line_start(state)}
    end
  end

  def handle_event(%Event.Key{key: :end, modifiers: modifiers}, state) do
    if :ctrl in modifiers do
      {:ok, move_to_end(state)}
    else
      {:ok, move_to_line_end(state)}
    end
  end

  # Backspace
  def handle_event(%Event.Key{key: :backspace}, state) do
    state = delete_backward(state)
    notify_change(state)
    {:ok, state}
  end

  # Delete
  def handle_event(%Event.Key{key: :delete}, state) do
    state = delete_forward(state)
    notify_change(state)
    {:ok, state}
  end

  # Ctrl+Enter - insert newline in multiline mode
  def handle_event(%Event.Key{key: :enter, modifiers: modifiers}, %{multiline: true} = state) do
    if :ctrl in modifiers do
      state = insert_newline(state)
      notify_change(state)
      {:ok, state}
    else
      handle_enter(state)
    end
  end

  # Enter - submit (for single-line mode)
  def handle_event(%Event.Key{key: :enter}, %{multiline: false} = state) do
    notify_submit(state)
    {:ok, state}
  end

  # Escape - blur
  def handle_event(%Event.Key{key: :escape}, state) do
    {:ok, %{state | focused: false}}
  end

  # Character input
  def handle_event(%Event.Key{char: char}, state) when is_binary(char) and char != "" do
    state = insert_char(state, char)
    notify_change(state)
    {:ok, state}
  end

  # Focus events
  def handle_event(%Event.Focus{action: :gained}, state) do
    {:ok, %{state | focused: true}}
  end

  def handle_event(%Event.Focus{action: :lost}, state) do
    {:ok, %{state | focused: false}}
  end

  def handle_event(_event, state) do
    {:ok, state}
  end

  # Helper for Enter key in multiline mode
  defp handle_enter(state) do
    if state.enter_submits do
      notify_submit(state)
      {:ok, state}
    else
      # Multiline without enter_submits: insert newline
      state = insert_newline(state)
      notify_change(state)
      {:ok, state}
    end
  end

  # ----------------------------------------------------------------------------
  # Text Operations
  # ----------------------------------------------------------------------------

  defp text_to_lines(""), do: [""]
  defp text_to_lines(text), do: String.split(text, "\n")

  defp lines_to_text(lines), do: Enum.join(lines, "\n")

  defp current_line(state) do
    Enum.at(state.lines, state.cursor_row, "")
  end

  defp line_count(state), do: length(state.lines)

  defp current_line_length(state) do
    String.length(current_line(state))
  end

  # ----------------------------------------------------------------------------
  # Cursor Movement
  # ----------------------------------------------------------------------------

  defp move_cursor_left(state) do
    cond do
      # Can move left on current line
      state.cursor_col > 0 ->
        %{state | cursor_col: state.cursor_col - 1}

      # At start of line but not first line - go to end of previous line
      state.cursor_row > 0 ->
        prev_row = state.cursor_row - 1
        prev_line_len = String.length(Enum.at(state.lines, prev_row, ""))

        %{state | cursor_row: prev_row, cursor_col: prev_line_len}
        |> adjust_scroll()

      # At very start
      true ->
        state
    end
  end

  defp move_cursor_right(state) do
    line_len = current_line_length(state)

    cond do
      # Can move right on current line
      state.cursor_col < line_len ->
        %{state | cursor_col: state.cursor_col + 1}

      # At end of line but not last line - go to start of next line
      state.multiline and state.cursor_row < line_count(state) - 1 ->
        %{state | cursor_row: state.cursor_row + 1, cursor_col: 0}
        |> adjust_scroll()

      # At very end
      true ->
        state
    end
  end

  defp move_cursor_up(state) do
    if state.cursor_row > 0 do
      new_row = state.cursor_row - 1
      new_line_len = String.length(Enum.at(state.lines, new_row, ""))
      new_col = min(state.cursor_col, new_line_len)

      %{state | cursor_row: new_row, cursor_col: new_col}
      |> adjust_scroll()
    else
      state
    end
  end

  defp move_cursor_down(state) do
    if state.cursor_row < line_count(state) - 1 do
      new_row = state.cursor_row + 1
      new_line_len = String.length(Enum.at(state.lines, new_row, ""))
      new_col = min(state.cursor_col, new_line_len)

      %{state | cursor_row: new_row, cursor_col: new_col}
      |> adjust_scroll()
    else
      state
    end
  end

  defp move_to_line_start(state) do
    %{state | cursor_col: 0}
  end

  defp move_to_line_end(state) do
    %{state | cursor_col: current_line_length(state)}
  end

  defp move_to_start(state) do
    %{state | cursor_row: 0, cursor_col: 0, scroll_offset: 0}
  end

  defp move_to_end(state) do
    last_row = max(0, line_count(state) - 1)
    last_col = String.length(Enum.at(state.lines, last_row, ""))

    %{state | cursor_row: last_row, cursor_col: last_col}
    |> adjust_scroll()
  end

  # ----------------------------------------------------------------------------
  # Text Editing
  # ----------------------------------------------------------------------------

  defp insert_char(state, char) do
    line = current_line(state)
    {before_cursor, after_cursor} = String.split_at(line, state.cursor_col)
    new_line = before_cursor <> char <> after_cursor

    lines = List.replace_at(state.lines, state.cursor_row, new_line)

    %{state | lines: lines, cursor_col: state.cursor_col + String.length(char)}
  end

  defp insert_newline(state) do
    # Check max_lines constraint
    if state.max_lines && line_count(state) >= state.max_lines do
      state
    else
      line = current_line(state)
      {before_cursor, after_cursor} = String.split_at(line, state.cursor_col)

      lines =
        state.lines
        |> List.replace_at(state.cursor_row, before_cursor)
        |> List.insert_at(state.cursor_row + 1, after_cursor)

      %{state | lines: lines, cursor_row: state.cursor_row + 1, cursor_col: 0}
      |> adjust_scroll()
    end
  end

  defp delete_backward(state) do
    cond do
      # Can delete within current line
      state.cursor_col > 0 ->
        line = current_line(state)
        {before_cursor, after_cursor} = String.split_at(line, state.cursor_col)
        new_line = String.slice(before_cursor, 0..-2//1) <> after_cursor
        lines = List.replace_at(state.lines, state.cursor_row, new_line)
        %{state | lines: lines, cursor_col: state.cursor_col - 1}

      # At start of line but not first line - join with previous line
      state.cursor_row > 0 ->
        prev_row = state.cursor_row - 1
        prev_line = Enum.at(state.lines, prev_row, "")
        curr_line = current_line(state)
        new_cursor_col = String.length(prev_line)

        lines =
          state.lines
          |> List.delete_at(state.cursor_row)
          |> List.replace_at(prev_row, prev_line <> curr_line)

        %{state | lines: lines, cursor_row: prev_row, cursor_col: new_cursor_col}
        |> adjust_scroll()

      # At very start - nothing to delete
      true ->
        state
    end
  end

  defp delete_forward(state) do
    line = current_line(state)
    line_len = String.length(line)

    cond do
      # Can delete within current line
      state.cursor_col < line_len ->
        {before_cursor, after_cursor} = String.split_at(line, state.cursor_col)
        new_line = before_cursor <> String.slice(after_cursor, 1..-1//1)
        lines = List.replace_at(state.lines, state.cursor_row, new_line)
        %{state | lines: lines}

      # At end of line but not last line - join with next line
      state.cursor_row < line_count(state) - 1 ->
        next_row = state.cursor_row + 1
        next_line = Enum.at(state.lines, next_row, "")

        lines =
          state.lines
          |> List.delete_at(next_row)
          |> List.replace_at(state.cursor_row, line <> next_line)

        %{state | lines: lines}

      # At very end - nothing to delete
      true ->
        state
    end
  end

  # ----------------------------------------------------------------------------
  # Scrolling
  # ----------------------------------------------------------------------------

  defp adjust_scroll(state) do
    max_visible = state.max_visible_lines

    new_offset =
      cond do
        # Cursor above visible area
        state.cursor_row < state.scroll_offset ->
          state.cursor_row

        # Cursor below visible area
        state.cursor_row >= state.scroll_offset + max_visible ->
          state.cursor_row - max_visible + 1

        # Cursor in visible area
        true ->
          state.scroll_offset
      end

    %{state | scroll_offset: max(0, new_offset)}
  end

  defp clamp_cursor(state) do
    max_row = max(0, line_count(state) - 1)
    new_row = min(state.cursor_row, max_row)
    max_col = String.length(Enum.at(state.lines, new_row, ""))
    new_col = min(state.cursor_col, max_col)

    %{state | cursor_row: new_row, cursor_col: new_col}
  end

  # ----------------------------------------------------------------------------
  # Callbacks
  # ----------------------------------------------------------------------------

  defp notify_change(state) do
    if state.on_change do
      value = lines_to_text(state.lines)
      state.on_change.(value)
    end
  end

  defp notify_submit(state) do
    if state.on_submit do
      value = lines_to_text(state.lines)
      state.on_submit.(value)
    end
  end

  # ----------------------------------------------------------------------------
  # Public API
  # ----------------------------------------------------------------------------

  @doc """
  Get the current text value.
  """
  @spec get_value(map()) :: String.t()
  def get_value(state) do
    lines_to_text(state.lines)
  end

  @doc """
  Set the text value programmatically.
  """
  @spec set_value(map(), String.t()) :: map()
  def set_value(state, value) do
    lines = text_to_lines(value)

    %{state | lines: lines, cursor_row: 0, cursor_col: 0, scroll_offset: 0}
    |> clamp_cursor()
  end

  @doc """
  Clear the text input.
  """
  @spec clear(map()) :: map()
  def clear(state) do
    %{state | lines: [""], cursor_row: 0, cursor_col: 0, scroll_offset: 0}
  end

  @doc """
  Set focus state.
  """
  @spec set_focused(map(), boolean()) :: map()
  def set_focused(state, focused) do
    %{state | focused: focused}
  end

  @doc """
  Get the number of lines.
  """
  @spec get_line_count(map()) :: non_neg_integer()
  def get_line_count(state), do: line_count(state)

  @doc """
  Get the cursor position as {row, col}.
  """
  @spec get_cursor(map()) :: {non_neg_integer(), non_neg_integer()}
  def get_cursor(state), do: {state.cursor_row, state.cursor_col}

  # ----------------------------------------------------------------------------
  # Rendering
  # ----------------------------------------------------------------------------

  @impl true
  def render(state, _area) do
    if empty?(state) and state.placeholder != "" and not state.focused do
      render_placeholder(state)
    else
      render_content(state)
    end
  end

  defp empty?(state) do
    state.lines == [""] or state.lines == []
  end

  defp render_placeholder(state) do
    style = state.placeholder_style || Style.new(fg: :bright_black)
    text(state.placeholder, style)
  end

  defp render_content(state) do
    # Determine visible lines
    total_lines = line_count(state)
    visible_count = min(total_lines, state.max_visible_lines)
    visible_count = max(1, visible_count)

    visible_lines =
      state.lines
      |> Enum.drop(state.scroll_offset)
      |> Enum.take(visible_count)

    # Calculate display height (auto-grow)
    display_height = length(visible_lines)

    # Determine style
    base_style =
      if state.focused do
        state.focused_style || Style.new(fg: :white)
      else
        state.style
      end

    # Render each visible line
    rendered_lines =
      visible_lines
      |> Enum.with_index()
      |> Enum.map(fn {line, idx} ->
        actual_row = idx + state.scroll_offset
        render_line(line, actual_row, state, base_style)
      end)

    # Add scroll indicators if needed
    scroll_indicator = render_scroll_indicator(state, total_lines, visible_count)

    content =
      if scroll_indicator do
        # Stack lines horizontally with scroll indicator
        Enum.map(rendered_lines, fn line_node ->
          stack(:horizontal, [line_node])
        end)
        |> Kernel.++([scroll_indicator])
      else
        rendered_lines
      end

    if display_height == 1 do
      # Single line - just return the text node
      List.first(content) || text("", base_style)
    else
      stack(:vertical, content)
    end
  end

  defp render_line(line, row, state, base_style) do
    # Pad or truncate line to width
    display_line = String.pad_trailing(line, state.width)
    display_line = String.slice(display_line, 0, state.width)

    # Insert cursor if focused and on this row
    if state.focused and row == state.cursor_row do
      render_line_with_cursor(display_line, state.cursor_col, base_style)
    else
      text(display_line, base_style)
    end
  end

  defp render_line_with_cursor(line, cursor_col, base_style) do
    # Split line at cursor position
    {before, at_and_after} = String.split_at(line, cursor_col)

    {cursor_char, after_cursor} =
      if String.length(at_and_after) > 0 do
        {String.at(at_and_after, 0), String.slice(at_and_after, 1..-1//1)}
      else
        {" ", ""}
      end

    # Create cursor style (reverse video)
    cursor_style = Style.new(attrs: [:reverse])

    stack(:horizontal, [
      text(before, base_style),
      text(cursor_char, cursor_style),
      text(after_cursor, base_style)
    ])
  end

  defp render_scroll_indicator(state, total_lines, visible_count) do
    if total_lines > visible_count do
      can_scroll_up = state.scroll_offset > 0
      can_scroll_down = state.scroll_offset + visible_count < total_lines

      indicator =
        cond do
          can_scroll_up and can_scroll_down -> "↕"
          can_scroll_up -> "↑"
          can_scroll_down -> "↓"
          true -> nil
        end

      if indicator do
        text(
          " #{indicator} #{state.scroll_offset + 1}-#{state.scroll_offset + visible_count}/#{total_lines}",
          Style.new(fg: :bright_black)
        )
      else
        nil
      end
    else
      nil
    end
  end
end
