# Basic TermUI Example - List Navigation
#
# This example demonstrates a simple list navigation application
# that handles the same normalized events in raw mode (full terminal control)
# and TTY mode (possibly line-buffered input with graceful degradation).
#
# Usage:
#   elixir -r examples/multi_renderer/basic.ex -e "Basic.run()"
#
# Or run with specific backend:
#   elixir -r examples/multi_renderer/basic.ex -e "Basic.run(backend: :tty)"

defmodule Basic do
  @moduledoc """
  A simple list navigation example that works in both raw and TTY modes.

  In raw mode: Use arrow keys to navigate, Enter to select
  In TTY mode: Type single character commands (j/k, then Enter)
  """

  use TermUI.Elm

  # Sample list of items
  @items [
    "Item 1: Learn TermUI",
    "Item 2: Build TUI apps",
    "Item 3: Master Elm Architecture",
    "Item 4: Create widgets",
    "Item 5: Test your apps"
  ]

  # State structure
  # %{
  #   selected_index: integer(),
  #   show_details: boolean()
  # }

  def init(_opts) do
    %{selected_index: 0, show_details: false}
  end

  # Event handling - works in both raw and TTY modes
  def event_to_msg(%TermUI.Event.Key{key: :up}, _state), do: {:msg, :up}
  def event_to_msg(%TermUI.Event.Key{key: :down}, _state), do: {:msg, :down}
  def event_to_msg(%TermUI.Event.Key{key: :enter}, _state), do: {:msg, :toggle_details}
  def event_to_msg(%TermUI.Event.Key{key: ?q}, _state), do: {:msg, :quit}
  def event_to_msg(%TermUI.Event.Key{key: ?j}, _state), do: {:msg, :down}
  def event_to_msg(%TermUI.Event.Key{key: ?k}, _state), do: {:msg, :up}
  def event_to_msg(_event, _state), do: :ignore

  # State updates
  def update(:up, state) do
    new_index = max(0, state.selected_index - 1)
    {%{state | selected_index: new_index}, []}
  end

  def update(:down, state) do
    new_index = min(length(@items) - 1, state.selected_index + 1)
    {%{state | selected_index: new_index}, []}
  end

  def update(:toggle_details, state) do
    {%{state | show_details: not state.show_details}, []}
  end

  def update(:quit, state) do
    {state, [:quit]}
  end

  # View rendering
  def view(state) do
    selected_item = Enum.at(@items, state.selected_index)

    box([
      text("TermUI Basic Example - List Navigation",
        TermUI.Renderer.Style.new()
        |> TermUI.Renderer.Style.fg(:green)
        |> TermUI.Renderer.Style.bright()
      ),
      text(""),
      text("Use ↑/↓ or j/k to navigate, Enter for details, q to quit",
        TermUI.Renderer.Style.new()
        |> TermUI.Renderer.Style.fg(:cyan)
      ),
      text(""),
      text("─" |> String.duplicate(40),
        TermUI.Renderer.Style.new()
        |> TermUI.Renderer.Style.fg(:bright_black)
      ),
      text(""),
      render_list(@items, state.selected_index),
      text(""),
      text("─" |> String.duplicate(40),
        TermUI.Renderer.Style.new()
        |> TermUI.Renderer.Style.fg(:bright_black)
      ),
      text(""),
      render_details(selected_item, state.show_details),
      text(""),
      render_footer(state)
    ])
  end

  # Render the list with selection indicator
  defp render_list(items, selected_index) do
    items
    |> Enum.with_index()
    |> Enum.map(fn {item, index} ->
      prefix = if index == selected_index, do: "► ", else: "  "
      style =
        if index == selected_index do
          TermUI.Renderer.Style.new()
          |> TermUI.Renderer.Style.fg(:yellow)
          |> TermUI.Renderer.Style.bright()
        else
          TermUI.Renderer.Style.new()
        end

      text(prefix <> item, style)
    end)
  end

  # Render details section
  defp render_details(_item, false), do: empty()

  defp render_details(item, true) do
    box([
      text("Selected:"),
      text("  " <> item,
        TermUI.Renderer.Style.new()
        |> TermUI.Renderer.Style.fg(:yellow)
      )
    ],
    border: :single,
    padding: {0, 1}
    )
  end

  # Render footer with backend mode info
  defp render_footer(state) do
    mode = TermUI.App.backend_mode() || :unknown
    mode_text =
      case mode do
        :raw -> "Raw Mode (full terminal control)"
        :tty -> "TTY Mode (line-based input)"
        :skip -> "Test Mode"
        _ -> "Unknown Mode"
      end

    text("Mode: " <> mode_text,
      TermUI.Renderer.Style.new()
      |> TermUI.Renderer.Style.fg(:bright_black)
    )
  end

  # Run the application
  def run(opts \\ []) do
    # Combine with default options for example
    all_opts = Keyword.put_new(opts, :name, :basic_example)
    TermUI.App.run(__MODULE__, all_opts)
  end
end
