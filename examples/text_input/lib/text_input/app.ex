defmodule TextInput.App do
  @moduledoc """
  TextInput Widget Example

  This example demonstrates how to use the TermUI.Widgets.TextInput widget
  for single-line and multi-line text input.

  Features demonstrated:
  - Single-line text input
  - Multi-line text input with Ctrl+Enter for newlines
  - Auto-growing height
  - Scrollable area after max_visible_lines
  - Placeholder text
  - Focus states
  - Reading current value with get_value/1

  Controls:
  - Arrow keys: Move cursor
  - Home/End: Move to start/end of line
  - Ctrl+Home/End: Move to start/end of text (multiline)
  - Backspace/Delete: Delete characters
  - Ctrl+Enter: Insert newline (multiline mode)
  - Enter: Submit (single-line) or newline (multiline)
  - Tab: Switch between inputs
  - Escape: Blur input
  - Q: Quit the application
  """

  use TermUI.Elm

  alias TermUI.Event
  alias TermUI.Renderer.Style
  alias TermUI.Widgets.TextInput, as: TI

  # ----------------------------------------------------------------------------
  # Component Callbacks
  # ----------------------------------------------------------------------------

  @doc """
  Initialize the component state.
  """
  def init(_opts) do
    # Single-line input
    single_props =
      TI.new(
        placeholder: "Enter your name...",
        width: 40
      )

    {:ok, single_state} = TI.init(single_props)

    # Multi-line input (with scrolling after 5 lines)
    multi_props =
      TI.new(
        placeholder: "Enter your message...",
        width: 50,
        multiline: true,
        max_visible_lines: 5
      )

    {:ok, multi_state} = TI.init(multi_props)

    # Multi-line with enter_submits (like a chat input)
    chat_props =
      TI.new(
        placeholder: "Type a message and press Enter...",
        width: 50,
        multiline: true,
        max_visible_lines: 3,
        enter_submits: true
      )

    {:ok, chat_state} = TI.init(chat_props)

    %{
      # Input states
      single_input: TI.set_focused(single_state, true),
      multi_input: multi_state,
      chat_input: chat_state,

      # Track which input is focused
      focused_input: :single,

      # Chat messages history
      chat_messages: [],
      last_action: "Ready"
    }
  end

  @doc """
  Convert keyboard events to messages.
  """
  def event_to_msg(%Event.Key{key: key}, %{focused_input: nil}) when key in ["q", "Q"] do
    {:msg, :quit}
  end

  def event_to_msg(%Event.Key{key: key}, %{focused_input: :single}) when key in ["q", "Q"] do
    # Only quit if input is empty
    {:msg, :check_quit_single}
  end

  def event_to_msg(%Event.Key{key: key}, _state) when key in ["q", "Q"] do
    # In multi/chat, Q is just a character
    {:msg, {:input_event, %Event.Key{key: key, char: key}}}
  end

  def event_to_msg(%Event.Key{key: :tab}, _state) do
    {:msg, :next_input}
  end

  def event_to_msg(%Event.Key{key: :enter}, %{focused_input: :single} = state) do
    # Submit single-line input
    {:msg, {:submit_single, TI.get_value(state.single_input)}}
  end

  def event_to_msg(%Event.Key{key: :enter}, %{focused_input: :chat} = state) do
    # Submit chat message (enter_submits is true)
    {:msg, {:submit_chat, TI.get_value(state.chat_input)}}
  end

  def event_to_msg(event, _state) do
    {:msg, {:input_event, event}}
  end

  @doc """
  Update state based on messages.
  """
  def update(:quit, state) do
    {state, [:quit]}
  end

  def update(:check_quit_single, state) do
    # Only quit if single input is empty, otherwise treat as character
    if TI.get_value(state.single_input) == "" do
      {state, [:quit]}
    else
      # Pass Q as a character to the input
      {:ok, new_input} = TI.handle_event(%Event.Key{key: "q", char: "q"}, state.single_input)
      {%{state | single_input: new_input, last_action: "Typing..."}, []}
    end
  end

  def update(:next_input, state) do
    # Cycle through inputs: single -> multi -> chat -> single
    {next_focused, state} =
      case state.focused_input do
        :single ->
          {:multi,
           %{
             state
             | single_input: TI.set_focused(state.single_input, false),
               multi_input: TI.set_focused(state.multi_input, true)
           }}

        :multi ->
          {:chat,
           %{
             state
             | multi_input: TI.set_focused(state.multi_input, false),
               chat_input: TI.set_focused(state.chat_input, true)
           }}

        :chat ->
          {:single,
           %{
             state
             | chat_input: TI.set_focused(state.chat_input, false),
               single_input: TI.set_focused(state.single_input, true)
           }}
      end

    {%{state | focused_input: next_focused, last_action: "Switched to #{next_focused} input"}, []}
  end

  def update({:submit_single, value}, state) do
    action =
      if value == "" do
        "Single input: (empty - nothing to submit)"
      else
        "Submitted: \"#{value}\""
      end

    {%{state | last_action: action}, []}
  end

  def update({:submit_chat, value}, state) do
    if String.trim(value) != "" do
      messages = state.chat_messages ++ [value]
      # Clear the chat input
      chat_input = TI.clear(state.chat_input)

      {%{
         state
         | chat_messages: Enum.take(messages, -5),
           chat_input: chat_input,
           last_action: "Message sent: #{String.slice(value, 0, 20)}..."
       }, []}
    else
      {%{state | last_action: "Chat: (empty - nothing to send)"}, []}
    end
  end

  def update({:input_event, event}, state) do
    # Route event to focused input
    case state.focused_input do
      :single ->
        {:ok, new_input} = TI.handle_event(event, state.single_input)
        {%{state | single_input: new_input, last_action: "Typing..."}, []}

      :multi ->
        {:ok, new_input} = TI.handle_event(event, state.multi_input)
        {%{state | multi_input: new_input, last_action: "Typing..."}, []}

      :chat ->
        {:ok, new_input} = TI.handle_event(event, state.chat_input)
        {%{state | chat_input: new_input, last_action: "Typing..."}, []}
    end
  end

  def update(_msg, state) do
    {state, []}
  end

  @doc """
  Render the current state to a render tree.
  """
  def view(state) do
    stack(:vertical, [
      # Title
      text("TextInput Widget Example", Style.new(fg: :cyan, attrs: [:bold])),
      text(""),

      # Instructions
      render_instructions(),
      text(""),

      # Single-line input section
      render_single_input(state),
      text(""),

      # Multi-line input section
      render_multi_input(state),
      text(""),

      # Chat-style input section
      render_chat_input(state),
      text(""),

      # Status
      render_status(state)
    ])
  end

  # ----------------------------------------------------------------------------
  # Private Helpers
  # ----------------------------------------------------------------------------

  # Border character sets (matching TermUI.Widget.Block)
  @border_rounded %{tl: "╭", tr: "╮", bl: "╰", br: "╯", h: "─", v: "│"}
  @border_single %{tl: "┌", tr: "┐", bl: "└", br: "┘", h: "─", v: "│"}

  defp render_instructions do
    b = @border_rounded
    inner_width = 53

    label = " Controls "
    left_pad = 2
    right_pad = inner_width - left_pad - String.length(label)

    top = b.tl <> String.duplicate(b.h, left_pad) <> label <> String.duplicate(b.h, right_pad) <> b.tr
    bot = b.bl <> String.duplicate(b.h, inner_width) <> b.br

    stack(:vertical, [
      text(top, Style.new(fg: :yellow)),
      text(b.v <> String.pad_trailing("  Arrow keys       Move cursor", inner_width) <> b.v, nil),
      text(b.v <> String.pad_trailing("  Home/End         Move to start/end of line", inner_width) <> b.v, nil),
      text(b.v <> String.pad_trailing("  Ctrl+Home/End    Move to start/end of text", inner_width) <> b.v, nil),
      text(b.v <> String.pad_trailing("  Backspace/Del    Delete characters", inner_width) <> b.v, nil),
      text(b.v <> String.pad_trailing("  Ctrl+Enter       Insert newline (multiline)", inner_width) <> b.v, nil),
      text(b.v <> String.pad_trailing("  Enter            Submit (single/chat) or newline", inner_width) <> b.v, nil),
      text(b.v <> String.pad_trailing("  Tab              Switch between inputs", inner_width) <> b.v, nil),
      text(b.v <> String.pad_trailing("  Q                Quit (when input is empty)", inner_width) <> b.v, nil),
      text(bot, Style.new(fg: :yellow))
    ])
  end

  defp render_single_input(state) do
    focused = state.focused_input == :single
    b = @border_single
    border_style = if focused, do: Style.new(fg: :green), else: Style.new(fg: :blue)

    current_value = TI.get_value(state.single_input)
    inner_width = 52

    label = " Single-line Input (Enter to submit) "
    left_pad = 2
    right_pad = inner_width - left_pad - String.length(label)

    top = b.tl <> String.duplicate(b.h, left_pad) <> label <> String.duplicate(b.h, right_pad) <> b.tr
    bot = b.bl <> String.duplicate(b.h, inner_width) <> b.br

    stack(:vertical, [
      text(top, border_style),
      stack(:horizontal, [
        text(b.v <> " ", border_style),
        TI.render(state.single_input, %{width: 50, height: 1}),
        text(" " <> b.v, border_style)
      ]),
      text(b.v <> String.pad_trailing("  Value: \"#{String.slice(current_value, 0, 40)}\"", inner_width) <> b.v, Style.new(fg: :bright_black)),
      text(bot, border_style)
    ])
  end

  defp render_multi_input(state) do
    focused = state.focused_input == :multi
    b = @border_single
    border_style = if focused, do: Style.new(fg: :green), else: Style.new(fg: :blue)

    line_count = TI.get_line_count(state.multi_input)
    {cursor_row, cursor_col} = TI.get_cursor(state.multi_input)

    inner_width = 62

    label = " Multi-line Input (Ctrl+Enter for newline) "
    left_pad = 2
    right_pad = inner_width - left_pad - String.length(label)

    top = b.tl <> String.duplicate(b.h, left_pad) <> label <> String.duplicate(b.h, right_pad) <> b.tr
    bot = b.bl <> String.duplicate(b.h, inner_width) <> b.br

    input_view = TI.render(state.multi_input, %{width: 60, height: 5})

    stack(:vertical, [
      text(top, border_style),
      stack(:horizontal, [
        text(b.v <> " ", border_style),
        input_view,
        text(" " <> b.v, border_style)
      ]),
      text(b.v <> String.pad_trailing("  Lines: #{line_count}, Cursor: row #{cursor_row + 1}, col #{cursor_col + 1}", inner_width) <> b.v, Style.new(fg: :bright_black)),
      text(bot, border_style)
    ])
  end

  defp render_chat_input(state) do
    focused = state.focused_input == :chat
    b = @border_single
    border_style = if focused, do: Style.new(fg: :green), else: Style.new(fg: :blue)

    inner_width = 62

    label = " Chat Input (Enter submits, Ctrl+Enter for newline) "
    left_pad = 2
    right_pad = inner_width - left_pad - String.length(label)

    top = b.tl <> String.duplicate(b.h, left_pad) <> label <> String.duplicate(b.h, right_pad) <> b.tr
    bot = b.bl <> String.duplicate(b.h, inner_width) <> b.br

    input_view = TI.render(state.chat_input, %{width: 60, height: 3})

    stack(:vertical, [
      text(top, border_style),
      render_chat_messages(state.chat_messages, inner_width, b, border_style),
      stack(:horizontal, [
        text(b.v <> " ", border_style),
        input_view,
        text(" " <> b.v, border_style)
      ]),
      text(bot, border_style)
    ])
  end

  defp render_chat_messages([], inner_width, b, border_style) do
    stack(:vertical, [
      text(b.v <> String.pad_trailing("  (no messages yet)", inner_width) <> b.v, border_style)
    ])
  end

  defp render_chat_messages(messages, inner_width, b, _border_style) do
    message_nodes =
      Enum.map(messages, fn msg ->
        # Truncate long messages
        display_msg =
          if String.length(msg) > 50,
            do: String.slice(msg, 0, 47) <> "...",
            else: msg

        content = "  > #{display_msg}"
        text(b.v <> String.pad_trailing(content, inner_width) <> b.v, Style.new(fg: :cyan))
      end)

    stack(:vertical, message_nodes)
  end

  defp render_status(state) do
    stack(:horizontal, [
      text("Status: ", Style.new(fg: :yellow)),
      text(state.last_action, Style.new(fg: :white))
    ])
  end

  # ----------------------------------------------------------------------------
  # Public API
  # ----------------------------------------------------------------------------

  @doc """
  Run the text input example application.
  """
  def run do
    TermUI.Runtime.run(root: __MODULE__)
  end
end
