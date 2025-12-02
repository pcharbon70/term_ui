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
  alias TermUI.Widgets.ContextMenu

  # ----------------------------------------------------------------------------
  # Component Callbacks
  # ----------------------------------------------------------------------------

  @doc """
  Initialize the component state.
  """
  def init(_opts) do
    %{
      # Context menu state (nil when no menu visible)
      menu: nil,
      # Result tracking
      last_action: nil
    }
  end

  @doc """
  Convert keyboard events to messages.
  """
  # Menu closed - show menu at different positions
  def event_to_msg(%Event.Key{key: "1"}, %{menu: nil}), do: {:msg, {:show_menu, {5, 5}}}
  def event_to_msg(%Event.Key{key: "2"}, %{menu: nil}), do: {:msg, {:show_menu, {20, 8}}}
  def event_to_msg(%Event.Key{key: "3"}, %{menu: nil}), do: {:msg, {:show_menu, {35, 5}}}

  # Mouse events - show menu on right-click
  def event_to_msg(%Event.Mouse{action: :click, button: :right, x: x, y: y}, %{menu: nil}) do
    {:msg, {:show_menu, {x, y}}}
  end

  # When menu is visible, forward events to the menu widget
  def event_to_msg(event, %{menu: menu}) when menu != nil, do: {:msg, {:menu_event, event}}

  def event_to_msg(%Event.Key{key: key}, _state) when key in ["q", "Q"], do: {:msg, :quit}
  def event_to_msg(_event, _state), do: :ignore

  @doc """
  Update state based on messages.
  """
  def update({:show_menu, position}, state) do
    {show_menu(state, position), []}
  end

  def update({:menu_event, event}, state) do
    case ContextMenu.handle_event(event, state.menu) do
      {:ok, new_menu} ->
        if ContextMenu.visible?(new_menu) do
          {%{state | menu: new_menu}, []}
        else
          # Menu was closed - capture result if item was selected
          result = ContextMenu.get_cursor(new_menu)
          {%{state | menu: nil, last_action: format_action(result)}, []}
        end
    end
  end

  def update(:quit, state) do
    {state, [:quit]}
  end

  # Helper to create and initialize a context menu
  defp show_menu(state, position) do
    props = ContextMenu.new(
      items: menu_items(),
      position: position,
      selected_style: Style.new(fg: :black, bg: :cyan),
      disabled_style: Style.new(fg: :bright_black)
    )
    {:ok, menu} = ContextMenu.init(props)
    %{state | menu: menu}
  end

  defp menu_items do
    [
      ContextMenu.action(:cut, "Cut", shortcut: "Ctrl+X"),
      ContextMenu.action(:copy, "Copy", shortcut: "Ctrl+C"),
      ContextMenu.action(:paste, "Paste", shortcut: "Ctrl+V"),
      ContextMenu.separator(),
      ContextMenu.action(:select_all, "Select All", shortcut: "Ctrl+A"),
      ContextMenu.separator(),
      ContextMenu.action(:disabled_item, "Disabled Item", disabled: true),
      ContextMenu.action(:delete, "Delete", shortcut: "Del")
    ]
  end

  defp format_action(nil), do: "Cancelled"
  defp format_action(action), do: "Selected: #{action}"

  @doc """
  Render the current state to a render tree.
  """
  def view(state) do
    main_content = render_main_content(state)

    if state.menu != nil do
      stack(:vertical, [
        main_content,
        text("", nil),
        ContextMenu.render(state.menu, %{width: 80, height: 24})
      ])
    else
      main_content
    end
  end

  # ----------------------------------------------------------------------------
  # Private Helpers
  # ----------------------------------------------------------------------------

  defp render_main_content(state) do
    stack(:vertical, [
      # Title
      text("Context Menu Widget Example", Style.new(fg: :cyan, attrs: [:bold])),
      text("", nil),

      # Instructions
      render_instructions(),

      # Controls
      render_controls(state)
    ])
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
      text("│" <> String.pad_trailing("  Menu visible: #{state.menu != nil}", inner_width) <> "│", nil),
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
