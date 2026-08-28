# TermUI Text Input Example
#
# This example demonstrates text input that works in both modes:
# - Raw mode: Character-by-character input with live editing
# - TTY mode: The same events after cooked input is delivered (often on Enter)
#
# Usage:
#   elixir -r examples/multi_renderer/text_input.ex -e "TextInputExample.run()"
#
# Or run with specific backend:
#   elixir -r examples/multi_renderer/text_input.ex -e "TextInputExample.run(backend: :tty)"

defmodule TextInputExample do
  @moduledoc """
  Text input example demonstrating immediate versus cooked event delivery.

  In raw mode (OTP 28+):
  - See characters appear as you type
  - Use backspace to delete
  - Press Enter to submit

  In TTY mode (fallback):
  - The same stateful widget is used
  - The shell/terminal may buffer input until Enter
  """

  use TermUI.Elm
  alias TermUI.Event
  alias TermUI.Renderer.Style
  alias TermUI.Widgets.TextInput

  # State structure
  # %{
  #   input: map(),
  #   submitted_values: [String.t()],
  #   show_help: boolean()
  # }

  def init(_opts) do
    {:ok, input} =
      TextInput.init(TextInput.new(placeholder: "Enter text...", width: 40))

    %{input: TextInput.set_focused(input, true), submitted_values: [], show_help: true}
  end

  # Event handling
  def event_to_msg(%Event.Key{key: :enter}, _state), do: {:msg, :submit}

  def event_to_msg(%Event.Key{key: "l", modifiers: modifiers} = event, _state) do
    if :ctrl in modifiers, do: {:msg, :clear}, else: {:msg, {:input_event, event}}
  end

  def event_to_msg(%Event.Key{key: "h", modifiers: modifiers} = event, _state) do
    if :ctrl in modifiers, do: {:msg, :toggle_help}, else: {:msg, {:input_event, event}}
  end

  def event_to_msg(%Event.Key{key: "q", modifiers: modifiers} = event, _state) do
    if :ctrl in modifiers, do: {:msg, :quit}, else: {:msg, {:input_event, event}}
  end

  def event_to_msg(event, _state), do: {:msg, {:input_event, event}}

  # State updates
  def update(:submit, state) do
    value = TextInput.get_value(state.input)
    input = state.input |> TextInput.clear() |> TextInput.set_focused(true)
    {%{state | input: input, submitted_values: [value | state.submitted_values]}, []}
  end

  def update(:clear, state) do
    {%{state | submitted_values: []}, []}
  end

  def update(:toggle_help, state) do
    {%{state | show_help: not state.show_help}, []}
  end

  def update(:quit, state) do
    {state, [TermUI.Command.quit()]}
  end

  def update({:input_event, event}, state) do
    {:ok, input} = TextInput.handle_event(event, state.input)
    {%{state | input: input}, []}
  end

  # View rendering
  def view(state) do
    backend_mode = TermUI.App.backend_mode()
    mode_label = mode_label(backend_mode)

    stack(:vertical, [
      # Header
      text(
        "TermUI Text Input Example",
        Style.new()
        |> Style.fg(:green)
        |> Style.bold()
      ),
      text(""),
      text(
        "Mode: " <> mode_label,
        Style.new()
        |> Style.fg(:cyan)
      ),
      text(""),

      # Instructions
      render_help(state.show_help, backend_mode),
      text(""),

      # Text input field
      text("Enter text:"),
      TextInput.render(state.input, %{x: 0, y: 0, width: 40, height: 1}),
      text(""),

      # Submitted values
      if(state.submitted_values == [],
        do: empty(),
        else: render_submitted(state.submitted_values)
      ),
      text(""),

      # Footer
      text(
        "Ctrl+L=clear | Ctrl+H=help | Ctrl+Q=quit",
        Style.new()
        |> Style.fg(:bright_black)
      )
    ])
  end

  defp mode_label(:raw), do: "Raw Mode (character input with live editing)"
  defp mode_label(:tty), do: "TTY Mode (cooked input; delivery may be buffered)"
  defp mode_label(:skip), do: "Test Mode"
  defp mode_label(_), do: "Unknown"

  defp render_help(false, _mode), do: empty()

  defp render_help(true, :raw) do
    stack(:vertical, [
      text("Raw Mode Instructions:"),
      text("  • Type to see characters appear"),
      text("  • Press Enter to submit"),
      text("  • Backspace deletes last character"),
      text("  • Arrow keys move cursor")
    ])
  end

  defp render_help(true, :tty) do
    stack(:vertical, [
      text("TTY Mode Instructions:"),
      text("  • Type your text"),
      text("  • Press Enter to submit"),
      text("  • Editing updates after each event the shell delivers")
    ])
  end

  defp render_help(true, _) do
    box([text("Run without skip_terminal to see input modes")])
  end

  defp render_submitted(values) when length(values) > 5 do
    render_submitted(Enum.take(values, 5))
  end

  defp render_submitted(values) do
    stack(:vertical, [
      text(
        "Submitted Values:",
        Style.new()
        |> Style.fg(:green)
      )
      | Enum.concat(
          values
          |> Enum.reverse()
          |> Enum.map(fn v ->
            text(
              "  • " <> v,
              Style.new()
              |> Style.fg(:yellow)
            )
          end)
        )
    ])
  end

  # Run the application
  def run(opts \\ []) do
    all_opts = Keyword.put_new(opts, :name, :text_input_example)
    TermUI.App.run(__MODULE__, all_opts)
  end
end
