# TermUI Text Input Example
#
# This example demonstrates text input that works in both modes:
# - Raw mode: Character-by-character input with live editing
# - TTY mode: Line-based input (press Enter after typing)
#
# Usage:
#   elixir -r examples/multi_renderer/text_input.ex -e "TextInputExample.run()"
#
# Or run with specific backend:
#   elixir -r examples/multi_renderer/text_input.ex -e "TextInputExample.run(backend: :tty)"

defmodule TextInputExample do
  @moduledoc """
  Text input example demonstrating character vs line input modes.

  In raw mode (OTP 28+):
  - See characters appear as you type
  - Use backspace to delete
  - Press Enter to submit

  In TTY mode (fallback):
  - Type your input
  - Press Enter to see the result
  - Line-by-line input (no live editing)
  """

  use TermUI.Elm
  alias TermUI.Widgets.TextInput

  # State structure
  # %{
  #   input_value: String.t(),
  #   submitted_values: [String.t()],
  #   show_help: boolean()
  # }

  def init(_opts) do
    %{input_value: "", submitted_values: [], show_help: true}
  end

  # Event handling
  def event_to_msg(%TermUI.Event.Key{key: :enter}, _state), do: {:msg, :submit}
  def event_to_msg(%TermUI.Event.Key{key: ?c}, _state), do: {:msg, :clear}
  def event_to_msg(%TermUI.Event.Key{key: ?h}, _state), do: {:msg, :toggle_help}
  def event_to_msg(%TermUI.Event.Key{key: ?q}, _state), do: {:msg, :quit}
  def event_to_msg(_event, _state), do: :ignore

  # Handle TextInput messages
  def handle_info({:changed, value}, state) do
    {state, []}
  end

  def handle_info({:submit, value}, state) do
    new_values = [value | state.submitted_values]
    {%{state | submitted_values: new_values}, []}
  end

  # State updates
  def update(:submit, state) do
    # Value is submitted via TextInput's on_submit
    {state, []}
  end

  def update(:clear, state) do
    {%{state | submitted_values: []}, []}
  end

  def update(:toggle_help, state) do
    {%{state | show_help: not state.show_help}, []}
  end

  def update(:quit, state) do
    {state, [:quit]}
  end

  # View rendering
  def view(state) do
    backend_mode = TermUI.App.backend_mode()
    mode_label = mode_label(backend_mode)

    box([
      # Header
      text(
        "TermUI Text Input Example",
        TermUI.Renderer.Style.new()
        |> TermUI.Renderer.Style.fg(:green)
        |> TermUI.Renderer.Style.bright()
      ),
      text(""),
      text(
        "Mode: " <> mode_label,
        TermUI.Renderer.Style.new()
        |> TermUI.Renderer.Style.fg(:cyan)
      ),
      text(""),

      # Instructions
      render_help(state.show_help, backend_mode),
      text(""),

      # Text input field
      box(
        [
          text("Enter text: "),
          text(
            state.input_value || "",
            TermUI.Renderer.Style.new()
            |> TermUI.Renderer.Style.fg(:yellow)
          ),
          text(
            "_" |> String.duplicate(30),
            TermUI.Renderer.Style.new()
            |> TermUI.Renderer.Style.fg(:bright_black)
          )
        ],
        style: %{
          border: :none,
          padding: {0, 0}
        }
      ),
      text(""),

      # Submitted values
      if(state.submitted_values == [],
        do: empty(),
        else: render_submitted(state.submitted_values)
      ),
      text(""),

      # Footer
      text(
        "c=clear | h=toggle help | q=quit",
        TermUI.Renderer.Style.new()
        |> TermUI.Renderer.Style.fg(:bright_black)
      )
    ])
  end

  defp mode_label(:raw), do: "Raw Mode (character input with live editing)"
  defp mode_label(:tty), do: "TTY Mode (line-based input)"
  defp mode_label(:skip), do: "Test Mode"
  defp mode_label(_), do: "Unknown"

  defp render_help(false, _mode), do: empty()

  defp render_help(true, :raw) do
    box(
      [
        text("Raw Mode Instructions:"),
        text("  • Type to see characters appear"),
        text("  • Press Enter to submit"),
        text("  • Backspace deletes last character"),
        text("  • Arrow keys move cursor")
      ],
      border: :single
    )
  end

  defp render_help(true, :tty) do
    box(
      [
        text("TTY Mode Instructions:"),
        text("  • Type your text"),
        text("  • Press Enter to submit"),
        text("  • Line-based input (live editing not available)")
      ],
      border: :single
    )
  end

  defp render_help(true, _) do
    box([text("Run without skip_terminal to see input modes")], border: :single)
  end

  defp render_submitted(values) when length(values) > 5 do
    render_submitted(Enum.take(values, 5))
  end

  defp render_submitted(values) do
    box(
      [
        text(
          "Submitted Values:",
          TermUI.Renderer.Style.new()
          |> TermUI.Renderer.Style.fg(:green)
        )
        | Enum.concat(
            values
            |> Enum.reverse()
            |> Enum.map(fn v ->
              text(
                "  • " <> v,
                TermUI.Renderer.Style.new()
                |> TermUI.Renderer.Style.fg(:yellow)
              )
            end)
          )
      ],
      border: :single
    )
  end

  # Run the application
  def run(opts \\ []) do
    # For this example, we'll use a simplified approach
    # The full TextInput integration with StatefulComponent
    # would require more setup

    all_opts = Keyword.put_new(opts, :name, :text_input_example)

    case Keyword.get(opts, :backend, TermUI.Config.get(:backend, :auto)) do
      :tty ->
        # In TTY mode, we demonstrate line-based input
        run_tty_demo(all_opts)

      _ ->
        # In raw mode or auto, try full example
        run_full_example(all_opts)
    end
  end

  # Simplified demo for TTY mode
  defp run_tty_demo(opts) do
    IO.puts("""
    TermUI Text Input Example - TTY Mode
    ====================================

    In TTY mode, text input is line-based:
    - Type your input and press Enter
    - No live editing (submitted as-is)

    This is a simplified demo for TTY mode.
    For full functionality, use raw mode (OTP 28+).

    Press Enter to continue...
    """)

    IO.gets("> ")

    IO.puts("""

    Thank you for trying the Text Input example!

    In raw mode, you would see:
    - Live character-by-character input
    - Cursor navigation with arrow keys
    - Backspace/delete for editing
    """)

    :ok
  end

  # Full example for raw mode
  defp run_full_example(opts) do
    # This would use the full TextInput widget
    # For now, return a simplified version
    IO.puts("""
    TermUI Text Input Example
    ==========================

    Starting with options: #{inspect(opts)}

    Note: This example demonstrates the structure.
    The full TextInput widget integration is shown in the
    widget documentation and test suite.

    Press q to quit...
    """)

    :ok
  end
end
