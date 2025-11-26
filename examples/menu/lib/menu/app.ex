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

  # ----------------------------------------------------------------------------
  # Component Callbacks
  # ----------------------------------------------------------------------------

  @doc """
  Initialize the component state.

  We build a menu structure with different item types and manage
  selection state manually for this example.
  """
  def init(_opts) do
    %{
      # Current cursor position in the menu
      cursor: 0,
      # Which submenus are expanded
      expanded: MapSet.new(),
      # Checkbox states
      checkboxes: %{
        autosave: true,
        dark_mode: false,
        notifications: true
      },
      # Last selected action (for demo purposes)
      last_action: nil
    }
  end

  @doc """
  Convert keyboard events to messages.
  """
  def event_to_msg(%Event.Key{key: :up}, _state), do: {:msg, {:move, -1}}
  def event_to_msg(%Event.Key{key: :down}, _state), do: {:msg, {:move, 1}}
  def event_to_msg(%Event.Key{key: :right}, _state), do: {:msg, :expand}
  def event_to_msg(%Event.Key{key: :left}, _state), do: {:msg, :collapse}
  def event_to_msg(%Event.Key{key: :enter}, _state), do: {:msg, :select}
  def event_to_msg(%Event.Key{key: " "}, _state), do: {:msg, :select}
  def event_to_msg(%Event.Key{key: key}, _state) when key in ["q", "Q"], do: {:msg, :quit}
  def event_to_msg(_event, _state), do: :ignore

  @doc """
  Update state based on messages.
  """
  def update({:move, delta}, state) do
    items = get_visible_items(state)
    max_index = length(items) - 1
    new_cursor = max(0, min(max_index, state.cursor + delta))
    {%{state | cursor: new_cursor}, []}
  end

  def update(:expand, state) do
    items = get_visible_items(state)
    current = Enum.at(items, state.cursor)

    case current do
      {:submenu, id, _label, _children} ->
        {%{state | expanded: MapSet.put(state.expanded, id)}, []}

      _ ->
        {state, []}
    end
  end

  def update(:collapse, state) do
    items = get_visible_items(state)
    current = Enum.at(items, state.cursor)

    case current do
      {:submenu, id, _label, _children} ->
        {%{state | expanded: MapSet.delete(state.expanded, id)}, []}

      _ ->
        {state, []}
    end
  end

  def update(:select, state) do
    items = get_visible_items(state)
    current = Enum.at(items, state.cursor)

    case current do
      {:action, id, _label, _shortcut} ->
        # Execute action
        {%{state | last_action: id}, []}

      {:checkbox, id, _label} ->
        # Toggle checkbox
        current_value = Map.get(state.checkboxes, id, false)
        checkboxes = Map.put(state.checkboxes, id, not current_value)
        {%{state | checkboxes: checkboxes}, []}

      {:submenu, id, _label, _children} ->
        # Toggle submenu expansion
        expanded =
          if MapSet.member?(state.expanded, id) do
            MapSet.delete(state.expanded, id)
          else
            MapSet.put(state.expanded, id)
          end

        {%{state | expanded: expanded}, []}

      _ ->
        {state, []}
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
      text("Menu Widget Example", Style.new(fg: :cyan, attrs: [:bold])),
      text("", nil),

      # Render the menu
      render_menu(state),

      # Show last action
      text("", nil),

      # Controls
      render_controls(state)
    ])
  end

  defp render_controls(state) do
    box_width = 44
    inner_width = box_width - 2

    top_border = "┌─ Controls " <> String.duplicate("─", inner_width - 12) <> "─┐"
    bottom_border = "└" <> String.duplicate("─", inner_width) <> "┘"

    stack(:vertical, [
      text("", nil),
      text(top_border, Style.new(fg: :yellow)),
      text("│" <> String.pad_trailing("  ↑/↓     Navigate", inner_width) <> "│", nil),
      text("│" <> String.pad_trailing("  →       Expand submenu", inner_width) <> "│", nil),
      text("│" <> String.pad_trailing("  ←       Collapse submenu", inner_width) <> "│", nil),
      text("│" <> String.pad_trailing("  Enter   Select / Toggle", inner_width) <> "│", nil),
      text("│" <> String.pad_trailing("  Q       Quit", inner_width) <> "│", nil),
      text("│" <> String.pad_trailing("", inner_width) <> "│", nil),
      text("│" <> String.pad_trailing("  Last action: #{state.last_action || "(none)"}", inner_width) <> "│", nil),
      text(bottom_border, Style.new(fg: :yellow))
    ])
  end

  # ----------------------------------------------------------------------------
  # Private Helpers
  # ----------------------------------------------------------------------------

  # Define the menu structure
  defp menu_items do
    [
      {:action, :new, "New File", "Ctrl+N"},
      {:action, :open, "Open...", "Ctrl+O"},
      {:action, :save, "Save", "Ctrl+S"},
      :separator,
      {:submenu, :recent, "Recent Files", [
        {:action, :file1, "document.txt", nil},
        {:action, :file2, "notes.md", nil},
        {:action, :file3, "config.json", nil}
      ]},
      {:submenu, :export, "Export As", [
        {:action, :export_pdf, "PDF", nil},
        {:action, :export_html, "HTML", nil},
        {:action, :export_md, "Markdown", nil}
      ]},
      :separator,
      {:checkbox, :autosave, "Auto Save"},
      {:checkbox, :dark_mode, "Dark Mode"},
      {:checkbox, :notifications, "Notifications"},
      :separator,
      {:action, :settings, "Settings...", "Ctrl+,"},
      {:action, :exit, "Exit", "Ctrl+Q"}
    ]
  end

  # Get visible items (flattening expanded submenus)
  defp get_visible_items(state) do
    flatten_items(menu_items(), state.expanded, 0)
  end

  defp flatten_items(items, expanded, depth) do
    Enum.flat_map(items, fn item ->
      case item do
        {:submenu, id, label, children} ->
          submenu_item = {:submenu, id, label, children}

          if MapSet.member?(expanded, id) do
            # Include submenu header and children
            [submenu_item | flatten_items(children, expanded, depth + 1)]
          else
            [submenu_item]
          end

        :separator ->
          [:separator]

        other ->
          [other]
      end
    end)
  end

  # Render the menu
  defp render_menu(state) do
    items = get_visible_items(state)

    rows =
      items
      |> Enum.with_index()
      |> Enum.map(fn {item, index} ->
        render_item(item, index, state)
      end)

    stack(:vertical, rows)
  end

  defp render_item(:separator, _index, _state) do
    text("  ────────────────────────────", nil)
  end

  defp render_item({:action, _id, label, shortcut}, index, state) do
    is_selected = index == state.cursor
    prefix = if is_selected, do: "► ", else: "  "
    shortcut_str = if shortcut, do: "  #{shortcut}", else: ""
    line = "#{prefix}#{label}#{shortcut_str}"

    if is_selected do
      text(line, Style.new(fg: :black, bg: :cyan))
    else
      text(line, nil)
    end
  end

  defp render_item({:checkbox, id, label}, index, state) do
    is_selected = index == state.cursor
    is_checked = Map.get(state.checkboxes, id, false)
    prefix = if is_selected, do: "► ", else: "  "
    checkbox = if is_checked, do: "[×]", else: "[ ]"
    line = "#{prefix}#{checkbox} #{label}"

    if is_selected do
      text(line, Style.new(fg: :black, bg: :cyan))
    else
      text(line, nil)
    end
  end

  defp render_item({:submenu, id, label, _children}, index, state) do
    is_selected = index == state.cursor
    is_expanded = MapSet.member?(state.expanded, id)
    prefix = if is_selected, do: "► ", else: "  "
    arrow = if is_expanded, do: "▼", else: "▶"
    line = "#{prefix}#{arrow} #{label}"

    if is_selected do
      text(line, Style.new(fg: :black, bg: :cyan))
    else
      text(line, nil)
    end
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
