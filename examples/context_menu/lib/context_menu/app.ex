defmodule ContextMenu.App do
  @moduledoc """
  Context Menu Widget Example

  This example demonstrates how to use the TermUI.Widgets.ContextMenu widget
  for displaying floating menus at cursor position.

  Features demonstrated:
  - Right-click to show context menu
  - Keyboard navigation (Up/Down)
  - Selection with Enter/Space
  - Close on Escape or outside click
  - Different menu positions
  - Disabled items

  Controls:
  - Right-click: Show context menu at click position
  - 1/2/3: Show context menu at different positions
  - Up/Down: Navigate menu items (when menu visible)
  - Enter/Space: Select item (when menu visible)
  - Escape: Close menu
  - Q: Quit the application
  """

  use TermUI.Elm

  alias TermUI.Event
  alias TermUI.Renderer.Style

  # ----------------------------------------------------------------------------
  # Component Callbacks
  # ----------------------------------------------------------------------------

  @doc """
  Initialize the component state.
  """
  def init(_opts) do
    %{
      # Context menu state
      menu_visible: false,
      menu_position: {0, 0},
      menu_cursor: 0,
      # Result tracking
      last_action: nil,
      click_count: 0
    }
  end

  @doc """
  Convert keyboard events to messages.
  """
  # Menu closed - show menu at different positions
  def event_to_msg(%Event.Key{key: "1"}, state) when not state.menu_visible, do: {:msg, {:show_menu, {5, 5}}}
  def event_to_msg(%Event.Key{key: "2"}, state) when not state.menu_visible, do: {:msg, {:show_menu, {20, 8}}}
  def event_to_msg(%Event.Key{key: "3"}, state) when not state.menu_visible, do: {:msg, {:show_menu, {35, 5}}}

  # Menu controls
  def event_to_msg(%Event.Key{key: :up}, state) when state.menu_visible, do: {:msg, {:move, -1}}
  def event_to_msg(%Event.Key{key: :down}, state) when state.menu_visible, do: {:msg, {:move, 1}}
  def event_to_msg(%Event.Key{key: :enter}, state) when state.menu_visible, do: {:msg, :select}
  def event_to_msg(%Event.Key{key: " "}, state) when state.menu_visible, do: {:msg, :select}
  def event_to_msg(%Event.Key{key: :escape}, state) when state.menu_visible, do: {:msg, :close_menu}

  # Mouse events
  def event_to_msg(%Event.Mouse{action: :click, button: :right, x: x, y: y}, state) when not state.menu_visible do
    {:msg, {:show_menu, {x, y}}}
  end

  def event_to_msg(%Event.Mouse{action: :click, x: x, y: y}, state) when state.menu_visible do
    {:msg, {:menu_click, x, y}}
  end

  def event_to_msg(%Event.Key{key: key}, _state) when key in ["q", "Q"], do: {:msg, :quit}
  def event_to_msg(_event, _state), do: :ignore

  @doc """
  Update state based on messages.
  """
  def update({:show_menu, position}, state) do
    {%{state | menu_visible: true, menu_position: position, menu_cursor: 0}, []}
  end

  def update(:close_menu, state) do
    {%{state | menu_visible: false}, []}
  end

  def update({:move, delta}, state) do
    items = menu_items()
    selectable = Enum.filter(items, &selectable?/1)
    max_idx = length(selectable) - 1
    new_cursor = max(0, min(max_idx, state.menu_cursor + delta))
    {%{state | menu_cursor: new_cursor}, []}
  end

  def update(:select, state) do
    items = menu_items()
    selectable = Enum.filter(items, &selectable?/1)
    selected = Enum.at(selectable, state.menu_cursor)

    if selected && not Map.get(selected, :disabled, false) do
      {%{state | menu_visible: false, last_action: selected.label}, []}
    else
      {state, []}
    end
  end

  def update({:menu_click, x, y}, state) do
    {pos_x, pos_y} = state.menu_position
    items = menu_items()
    menu_width = calculate_menu_width(items)
    menu_height = length(items)

    # Check if click is inside menu
    if x >= pos_x and x < pos_x + menu_width and
         y >= pos_y and y < pos_y + menu_height do
      # Click inside - try to select
      relative_y = y - pos_y
      item = Enum.at(items, relative_y)

      if item && selectable?(item) && not Map.get(item, :disabled, false) do
        {%{state | menu_visible: false, last_action: item.label}, []}
      else
        {state, []}
      end
    else
      # Click outside - close menu
      {%{state | menu_visible: false}, []}
    end
  end

  def update(:quit, state) do
    {state, [:quit]}
  end

  @doc """
  Render the current state to a render tree.
  """
  def view(state) do
    stack(:vertical, [
      # Title
      text("Context Menu Widget Example", Style.new(fg: :cyan, attrs: [:bold])),
      text("", nil),

      # Instructions
      render_instructions(),

      # Menu if visible
      if state.menu_visible do
        render_menu(state)
      else
        text("", nil)
      end,

      # Controls
      render_controls(state)
    ])
  end

  # ----------------------------------------------------------------------------
  # Private Helpers
  # ----------------------------------------------------------------------------

  defp menu_items do
    [
      %{type: :action, id: :cut, label: "Cut", shortcut: "Ctrl+X"},
      %{type: :action, id: :copy, label: "Copy", shortcut: "Ctrl+C"},
      %{type: :action, id: :paste, label: "Paste", shortcut: "Ctrl+V"},
      %{type: :separator, id: :sep1},
      %{type: :action, id: :select_all, label: "Select All", shortcut: "Ctrl+A"},
      %{type: :separator, id: :sep2},
      %{type: :action, id: :disabled_item, label: "Disabled Item", disabled: true},
      %{type: :action, id: :delete, label: "Delete", shortcut: "Del"}
    ]
  end

  defp selectable?(item), do: item.type == :action

  defp calculate_menu_width(items) do
    items
    |> Enum.map(fn item ->
      case item.type do
        :separator -> 3
        _ ->
          label_len = String.length(item.label)
          shortcut_len = String.length(Map.get(item, :shortcut, "") || "")
          4 + label_len + 2 + shortcut_len
      end
    end)
    |> Enum.max(fn -> 20 end)
  end

  defp render_instructions do
    stack(:vertical, [
      text("Right-click anywhere or press 1/2/3 to show context menu", nil),
      text("", nil),
      text("  Position 1: Top-left area (key: 1)", nil),
      text("  Position 2: Center area (key: 2)", nil),
      text("  Position 3: Right area (key: 3)", nil),
      text("", nil)
    ])
  end

  defp render_menu(state) do
    {pos_x, pos_y} = state.menu_position
    items = menu_items()
    width = calculate_menu_width(items)
    selectable_items = Enum.filter(items, &selectable?/1)

    # Build menu rows
    rows =
      items
      |> Enum.map(fn item ->
        render_menu_item(item, selectable_items, state, width)
      end)

    # Build bordered menu
    border_style = Style.new(fg: :white)
    top = "┌" <> String.duplicate("─", width) <> "┐"
    bottom = "└" <> String.duplicate("─", width) <> "┘"

    bordered_rows =
      Enum.map(rows, fn row ->
        stack(:horizontal, [
          text("│", border_style),
          row,
          text("│", border_style)
        ])
      end)

    # Position offset using padding
    v_padding = for _ <- 1..pos_y, do: text("", nil)
    h_padding = String.duplicate(" ", pos_x)

    stack(:vertical,
      v_padding ++
      [
        text(h_padding <> top, border_style),
        stack(:vertical,
          Enum.map(bordered_rows, fn row ->
            stack(:horizontal, [text(h_padding, nil), row])
          end)
        ),
        text(h_padding <> bottom, border_style)
      ]
    )
  end

  defp render_menu_item(%{type: :separator} = _item, _selectable, _state, width) do
    text(String.duplicate("─", width), Style.new(fg: :bright_black))
  end

  defp render_menu_item(item, selectable_items, state, width) do
    is_selected = Enum.at(selectable_items, state.menu_cursor) == item
    is_disabled = Map.get(item, :disabled, false)

    label = item.label
    shortcut = Map.get(item, :shortcut, "") || ""
    padding = width - String.length(label) - String.length(shortcut) - 2
    padding = max(1, padding)

    full_text = " " <> label <> String.duplicate(" ", padding) <> shortcut <> " "

    style =
      cond do
        is_disabled -> Style.new(fg: :bright_black)
        is_selected -> Style.new(fg: :black, bg: :cyan)
        true -> nil
      end

    if style do
      text(full_text, style)
    else
      text(full_text, nil)
    end
  end

  defp render_controls(state) do
    box_width = 50
    inner_width = box_width - 2

    top_border = "┌─ Controls " <> String.duplicate("─", inner_width - 12) <> "─┐"
    bottom_border = "└" <> String.duplicate("─", inner_width) <> "┘"

    stack(:vertical, [
      text("", nil),
      text(top_border, Style.new(fg: :yellow)),
      text("│" <> String.pad_trailing("  Right-click  Show context menu", inner_width) <> "│", nil),
      text("│" <> String.pad_trailing("  1/2/3        Show at preset positions", inner_width) <> "│", nil),
      text("│" <> String.pad_trailing("  ↑/↓          Navigate items (menu open)", inner_width) <> "│", nil),
      text("│" <> String.pad_trailing("  Enter/Space  Select item", inner_width) <> "│", nil),
      text("│" <> String.pad_trailing("  Escape       Close menu", inner_width) <> "│", nil),
      text("│" <> String.pad_trailing("  Q            Quit", inner_width) <> "│", nil),
      text("│" <> String.pad_trailing("", inner_width) <> "│", nil),
      text("│" <> String.pad_trailing("  Last action: #{state.last_action || "(none)"}", inner_width) <> "│", nil),
      text("│" <> String.pad_trailing("  Menu visible: #{state.menu_visible}", inner_width) <> "│", nil),
      text(bottom_border, Style.new(fg: :yellow))
    ])
  end

  # ----------------------------------------------------------------------------
  # Public API
  # ----------------------------------------------------------------------------

  @doc """
  Run the context menu example application.
  """
  def run do
    TermUI.Runtime.run(root: __MODULE__)
  end
end
