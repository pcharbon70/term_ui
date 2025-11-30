defmodule SplitPane.App do
  @moduledoc """
  SplitPane Widget Example

  This example demonstrates how to use the TermUI.Widgets.SplitPane widget
  for creating resizable multi-pane layouts like IDEs.

  Features demonstrated:
  - Horizontal and vertical split orientations
  - Nested splits for complex layouts
  - Keyboard-controlled divider resizing
  - Pane collapse/expand
  - Min/max size constraints
  - Layout persistence

  Controls:
  - Tab: Focus next divider
  - Shift+Tab: Focus previous divider
  - Left/Up: Move divider left/up
  - Right/Down: Move divider right/down
  - Shift+Arrow: Move divider by larger step
  - Enter: Toggle collapse pane after divider
  - Home: Move divider to minimum
  - End: Move divider to maximum
  - H: Switch to horizontal layout
  - V: Switch to vertical layout
  - N: Switch to nested layout (IDE-style)
  - S: Save layout
  - R: Restore layout
  - Q: Quit the application
  """

  use TermUI.Elm

  alias TermUI.Event
  alias TermUI.Renderer.Style
  alias TermUI.Widgets.SplitPane, as: SP

  # ----------------------------------------------------------------------------
  # Component Callbacks
  # ----------------------------------------------------------------------------

  @doc """
  Initialize the component state.
  """
  def init(_opts) do
    %{
      split_state: nil,
      layout_mode: :horizontal,
      saved_layout: nil,
      status_message: "Tab to focus divider, arrows to resize"
    }
  end

  defp build_split_state(:horizontal) do
    props =
      SP.new(
        orientation: :horizontal,
        panes: [
          SP.pane(:left, build_pane_content("Left Pane", :blue),
            size: 0.3,
            min_size: 10,
            max_size: 50
          ),
          SP.pane(:middle, build_pane_content("Middle Pane", :green), size: 0.4),
          SP.pane(:right, build_pane_content("Right Pane", :magenta), size: 0.3, min_size: 10)
        ]
      )

    {:ok, state} = SP.init(props)
    state
  end

  defp build_split_state(:vertical) do
    props =
      SP.new(
        orientation: :vertical,
        panes: [
          SP.pane(:top, build_pane_content("Top Pane", :cyan), size: 0.4, min_size: 5),
          SP.pane(:middle, build_pane_content("Middle Pane", :yellow), size: 0.3),
          SP.pane(:bottom, build_pane_content("Bottom Pane", :red), size: 0.3, min_size: 3)
        ]
      )

    {:ok, state} = SP.init(props)
    state
  end

  defp build_split_state(:nested) do
    # Build an IDE-like layout with nested splits
    # Left sidebar | Main area (top editor / bottom terminal)

    # Inner vertical split for main area
    inner_props =
      SP.new(
        orientation: :vertical,
        panes: [
          SP.pane(:editor, build_pane_content("Editor", :green), size: 0.7, min_size: 5),
          SP.pane(:terminal, build_pane_content("Terminal", :white), size: 0.3, min_size: 3)
        ]
      )

    {:ok, inner_state} = SP.init(inner_props)

    # Outer horizontal split
    outer_props =
      SP.new(
        orientation: :horizontal,
        panes: [
          SP.pane(:sidebar, build_pane_content("Sidebar", :blue), size: 0.2, min_size: 10),
          SP.pane(:main, inner_state, size: 0.8)
        ]
      )

    {:ok, outer_state} = SP.init(outer_props)
    outer_state
  end

  defp build_pane_content(title, color) do
    lines = [
      title,
      String.duplicate("-", String.length(title)),
      "",
      "Content area",
      "Resize with arrows",
      "Enter to collapse"
    ]

    text(Enum.join(lines, "\n"), Style.new(fg: color))
  end

  @doc """
  Convert keyboard events to messages.
  """
  def event_to_msg(%Event.Key{key: key}, _state) when key in ["q", "Q"], do: {:msg, :quit}
  def event_to_msg(%Event.Key{key: key}, _state) when key in ["h", "H"], do: {:msg, :horizontal}
  def event_to_msg(%Event.Key{key: key}, _state) when key in ["v", "V"], do: {:msg, :vertical}
  def event_to_msg(%Event.Key{key: key}, _state) when key in ["n", "N"], do: {:msg, :nested}
  def event_to_msg(%Event.Key{key: key}, _state) when key in ["s", "S"], do: {:msg, :save_layout}
  def event_to_msg(%Event.Key{key: key}, _state) when key in ["r", "R"], do: {:msg, :restore_layout}

  def event_to_msg(event, _state) do
    {:msg, {:split_event, event}}
  end

  @doc """
  Update state based on messages.
  """
  def update(:quit, state) do
    {state, [:quit]}
  end

  def update(:horizontal, state) do
    split_state = build_split_state(:horizontal)
    message = "Switched to horizontal layout"
    {%{state | layout_mode: :horizontal, split_state: split_state, status_message: message}, []}
  end

  def update(:vertical, state) do
    split_state = build_split_state(:vertical)
    message = "Switched to vertical layout"
    {%{state | layout_mode: :vertical, split_state: split_state, status_message: message}, []}
  end

  def update(:nested, state) do
    split_state = build_split_state(:nested)
    message = "Switched to nested IDE layout"
    {%{state | layout_mode: :nested, split_state: split_state, status_message: message}, []}
  end

  def update(:save_layout, state) do
    split_state = ensure_split_state(state)
    layout = SP.get_layout(split_state)
    message = "Layout saved!"
    {%{state | saved_layout: layout, status_message: message}, []}
  end

  def update(:restore_layout, state) do
    split_state = ensure_split_state(state)

    if state.saved_layout do
      split_state = SP.set_layout(split_state, state.saved_layout)
      message = "Layout restored!"
      {%{state | split_state: split_state, status_message: message}, []}
    else
      {%{state | status_message: "No saved layout to restore"}, []}
    end
  end

  def update({:split_event, event}, state) do
    split_state = ensure_split_state(state)
    {:ok, split_state} = SP.handle_event(event, split_state)

    message = get_status_message(split_state)
    {%{state | split_state: split_state, status_message: message}, []}
  end

  defp ensure_split_state(state) do
    state.split_state || build_split_state(state.layout_mode)
  end

  defp get_status_message(split_state) do
    focused = SP.get_focused_divider(split_state)

    if focused != nil do
      "Divider #{focused + 1} focused - arrows to resize, Enter to collapse"
    else
      "Tab to focus divider, arrows to resize"
    end
  end

  @doc """
  Render the current state to a render tree.
  """
  def view(state) do
    split_state = ensure_split_state(state)

    stack(:vertical, [
      # Title
      text("SplitPane Widget Example", Style.new(fg: :cyan, attrs: [:bold])),
      text("", nil),

      # Split pane
      render_split_container(split_state),

      # Status
      text("", nil),
      text(state.status_message, Style.new(fg: :yellow)),

      # Controls
      render_controls(state)
    ])
  end

  defp render_split_container(split_state) do
    # Render the split pane
    split_render = SP.render(split_state, %{x: 0, y: 0, width: 70, height: 15})

    box_width = 72
    inner_width = box_width - 2

    top_border = "+" <> String.duplicate("-", inner_width) <> "+"
    bottom_border = "+" <> String.duplicate("-", inner_width) <> "+"

    stack(:vertical, [
      text(top_border, Style.new(fg: :blue)),
      stack(:horizontal, [
        text("| ", nil),
        split_render,
        text(" |", nil)
      ]),
      text(bottom_border, Style.new(fg: :blue))
    ])
  end

  defp render_controls(state) do
    box_width = 55
    inner_width = box_width - 2

    mode_str =
      case state.layout_mode do
        :horizontal -> "horizontal"
        :vertical -> "vertical"
        :nested -> "nested (IDE)"
      end

    top_border = "+" <> String.duplicate("-", inner_width - 10) <> " Controls " <> "+"
    bottom_border = "+" <> String.duplicate("-", inner_width) <> "+"

    stack(:vertical, [
      text("", nil),
      text(top_border, Style.new(fg: :yellow)),
      text("|" <> String.pad_trailing("  Tab/S-Tab   Focus dividers", inner_width) <> "|", nil),
      text("|" <> String.pad_trailing("  Arrows      Resize focused divider", inner_width) <> "|", nil),
      text("|" <> String.pad_trailing("  Shift+Arr   Large resize step", inner_width) <> "|", nil),
      text("|" <> String.pad_trailing("  Enter       Collapse/expand pane", inner_width) <> "|", nil),
      text("|" <> String.pad_trailing("  Home/End    Min/max position", inner_width) <> "|", nil),
      text("|" <> String.pad_trailing("  H/V/N       Switch layout (#{mode_str})", inner_width) <> "|", nil),
      text("|" <> String.pad_trailing("  S/R         Save/Restore layout", inner_width) <> "|", nil),
      text("|" <> String.pad_trailing("  Q           Quit", inner_width) <> "|", nil),
      text(bottom_border, Style.new(fg: :yellow))
    ])
  end

  # ----------------------------------------------------------------------------
  # Public API
  # ----------------------------------------------------------------------------

  @doc """
  Run the split pane example application.
  """
  def run do
    TermUI.Runtime.run(root: __MODULE__)
  end
end
