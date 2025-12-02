defmodule Menu.App do
  @moduledoc """
  Menu Widget Example

  This example demonstrates how to use the TermUI.Widgets.Menu widget
  for displaying hierarchical menus with various item types.

  Features demonstrated:
  - Action items (selectable menu items)
  - Submenus (nested menus)
  - Separators (visual dividers)
  - Checkboxes (toggleable items)
  - Keyboard navigation
  - Shortcut display

  Controls:
  - Up/Down: Navigate between items
  - Right: Expand submenu
  - Left: Collapse submenu
  - Enter/Space: Select item or toggle checkbox
  - Q: Quit the application
  """

  use TermUI.Elm

  alias TermUI.Event
  alias TermUI.Renderer.Style
  alias TermUI.Widgets.Menu

  # ----------------------------------------------------------------------------
  # Component Callbacks
  # ----------------------------------------------------------------------------

  @doc """
  Initialize the component state.
  """
  def init(_opts) do
    props =
      Menu.new(
        items: menu_items(),
        selected_style: Style.new(fg: :black, bg: :cyan),
        disabled_style: Style.new(fg: :bright_black)
      )

    {:ok, menu_state} = Menu.init(props)

    %{
      menu: menu_state,
      last_action: nil
    }
  end

  defp menu_items do
    [
      Menu.action(:new, "New File", shortcut: "Ctrl+N"),
      Menu.action(:open, "Open...", shortcut: "Ctrl+O"),
      Menu.action(:save, "Save", shortcut: "Ctrl+S"),
      Menu.separator(),
      Menu.submenu(:recent, "Recent Files", [
        Menu.action(:file1, "document.txt"),
        Menu.action(:file2, "notes.md"),
        Menu.action(:file3, "config.json")
      ]),
      Menu.submenu(:export, "Export As", [
        Menu.action(:export_pdf, "PDF"),
        Menu.action(:export_html, "HTML"),
        Menu.action(:export_md, "Markdown")
      ]),
      Menu.separator(),
      Menu.checkbox(:autosave, "Auto Save", checked: true),
      Menu.checkbox(:dark_mode, "Dark Mode"),
      Menu.checkbox(:notifications, "Notifications", checked: true),
      Menu.separator(),
      Menu.action(:settings, "Settings...", shortcut: "Ctrl+,"),
      Menu.action(:exit, "Exit", shortcut: "Ctrl+Q")
    ]
  end

  @doc """
  Convert keyboard events to messages.
  """
  def event_to_msg(%Event.Key{key: key}, _state) when key in ["q", "Q"], do: {:msg, :quit}

  def event_to_msg(event, _state) do
    {:msg, {:menu_event, event}}
  end

  @doc """
  Update state based on messages.
  """
  def update(:quit, state) do
    {state, [:quit]}
  end

  def update({:menu_event, %Event.Key{key: key} = event}, state) when key in [:enter, " "] do
    # Track what item was selected before handling the event
    cursor = Menu.get_cursor(state.menu)
    {:ok, menu} = Menu.handle_event(event, state.menu)

    # Update last_action if it was an action item
    last_action =
      case get_item_type(state.menu, cursor) do
        :action -> cursor
        _ -> state.last_action
      end

    {%{state | menu: menu, last_action: last_action}, []}
  end

  def update({:menu_event, event}, state) do
    {:ok, menu} = Menu.handle_event(event, state.menu)
    {%{state | menu: menu}, []}
  end

  defp get_item_type(menu, id) do
    menu.items
    |> find_item(id)
    |> case do
      %{type: type} -> type
      _ -> nil
    end
  end

  defp find_item(items, id) do
    Enum.find_value(items, fn item ->
      cond do
        item.id == id -> item
        item.type == :submenu -> find_item(item.children, id)
        true -> nil
      end
    end)
  end

  @doc """
  Render the current state to a render tree.
  """
  def view(state) do
    stack(:vertical, [
      # Title
      text("Menu Widget Example", Style.new(fg: :cyan, attrs: [:bold])),
      text("", nil),

      # Render the menu
      Menu.render(state.menu, %{width: 40, height: 20}),

      # Show last action
      text("", nil),

      # Controls
      render_controls(state)
    ])
  end

  defp render_controls(state) do
    box_width = 50
    inner_width = box_width - 2

    top_border = "+" <> String.duplicate("-", inner_width - 10) <> " Controls " <> "+"
    bottom_border = "+" <> String.duplicate("-", inner_width) <> "+"

    # Get checkbox states from the menu widget
    autosave = Menu.checked?(state.menu, :autosave)
    dark_mode = Menu.checked?(state.menu, :dark_mode)
    notifications = Menu.checked?(state.menu, :notifications)

    stack(:vertical, [
      text("", nil),
      text(top_border, Style.new(fg: :yellow)),
      text("|" <> String.pad_trailing("  Up/Down     Navigate", inner_width) <> "|", nil),
      text("|" <> String.pad_trailing("  Right       Expand submenu", inner_width) <> "|", nil),
      text("|" <> String.pad_trailing("  Left        Collapse submenu", inner_width) <> "|", nil),
      text("|" <> String.pad_trailing("  Enter       Select / Toggle", inner_width) <> "|", nil),
      text("|" <> String.pad_trailing("  Q           Quit", inner_width) <> "|", nil),
      text("|" <> String.pad_trailing("", inner_width) <> "|", nil),
      text("|" <> String.pad_trailing("  Last action: #{state.last_action || "(none)"}", inner_width) <> "|", nil),
      text("|" <> String.pad_trailing("", inner_width) <> "|", nil),
      text("|" <> String.pad_trailing("  Checkboxes:", inner_width) <> "|", nil),
      text("|" <> String.pad_trailing("    Auto Save: #{autosave}", inner_width) <> "|", nil),
      text("|" <> String.pad_trailing("    Dark Mode: #{dark_mode}", inner_width) <> "|", nil),
      text("|" <> String.pad_trailing("    Notifications: #{notifications}", inner_width) <> "|", nil),
      text(bottom_border, Style.new(fg: :yellow))
    ])
  end

  # ----------------------------------------------------------------------------
  # Public API
  # ----------------------------------------------------------------------------

  @doc """
  Run the menu example application.
  """
  def run do
    TermUI.Runtime.run(root: __MODULE__)
  end
end
