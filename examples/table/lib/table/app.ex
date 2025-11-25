defmodule Table.App do
  @moduledoc """
  Table Widget Example

  This example demonstrates how to use the TermUI.Widgets.Table widget
  for displaying tabular data with selection, sorting, and scrolling.

  Features demonstrated:
  - Column definitions with different widths
  - Row selection and navigation
  - Custom cell rendering
  - Header and row styling

  Note: The Table widget is a StatefulComponent, but in this example
  we demonstrate the simpler approach of rendering it as a static display
  with manual state management.

  Controls:
  - Up/Down: Move selection
  - Page Up/Down: Scroll by page
  - Home/End: Jump to first/last row
  - Q: Quit the application
  """

  @behaviour TermUI.Component

  import TermUI.Component.RenderNode

  alias TermUI.Widgets.Table.Column
  alias TermUI.Layout.Constraint
  alias TermUI.Event
  alias TermUI.Style

  # ----------------------------------------------------------------------------
  # Component Callbacks
  # ----------------------------------------------------------------------------

  @doc """
  Initialize the component state.
  """
  @impl true
  def init(_opts) do
    %{
      data: sample_data(),
      selected: 0,
      scroll_offset: 0,
      visible_rows: 10
    }
  end

  defp sample_data do
    [
      %{id: 1, name: "Alice Johnson", email: "alice@example.com", role: "Admin", status: :active},
      %{id: 2, name: "Bob Smith", email: "bob@example.com", role: "User", status: :active},
      %{id: 3, name: "Charlie Brown", email: "charlie@example.com", role: "User", status: :inactive},
      %{id: 4, name: "Diana Prince", email: "diana@example.com", role: "Moderator", status: :active},
      %{id: 5, name: "Eve Wilson", email: "eve@example.com", role: "User", status: :pending},
      %{id: 6, name: "Frank Miller", email: "frank@example.com", role: "User", status: :active},
      %{id: 7, name: "Grace Lee", email: "grace@example.com", role: "Admin", status: :active},
      %{id: 8, name: "Henry Davis", email: "henry@example.com", role: "User", status: :inactive},
      %{id: 9, name: "Ivy Chen", email: "ivy@example.com", role: "Moderator", status: :active},
      %{id: 10, name: "Jack Taylor", email: "jack@example.com", role: "User", status: :pending},
      %{id: 11, name: "Kate Morgan", email: "kate@example.com", role: "User", status: :active},
      %{id: 12, name: "Leo Anderson", email: "leo@example.com", role: "User", status: :active}
    ]
  end

  @doc """
  Convert keyboard events to messages.
  """
  @impl true
  def event_to_msg(%Event.Key{key: :up}, _state), do: {:msg, {:move, -1}}
  def event_to_msg(%Event.Key{key: :down}, _state), do: {:msg, {:move, 1}}
  def event_to_msg(%Event.Key{key: :page_up}, _state), do: {:msg, {:move, -5}}
  def event_to_msg(%Event.Key{key: :page_down}, _state), do: {:msg, {:move, 5}}
  def event_to_msg(%Event.Key{key: :home}, _state), do: {:msg, :home}
  def event_to_msg(%Event.Key{key: :end}, _state), do: {:msg, :end}
  def event_to_msg(%Event.Key{key: key}, _state) when key in ["q", "Q"], do: {:msg, :quit}
  def event_to_msg(_event, _state), do: :ignore

  @doc """
  Update state based on messages.
  """
  @impl true
  def update({:move, delta}, state) do
    max_index = length(state.data) - 1
    new_selected = max(0, min(max_index, state.selected + delta))

    # Adjust scroll offset to keep selection visible
    new_offset =
      cond do
        new_selected < state.scroll_offset ->
          new_selected

        new_selected >= state.scroll_offset + state.visible_rows ->
          new_selected - state.visible_rows + 1

        true ->
          state.scroll_offset
      end

    {%{state | selected: new_selected, scroll_offset: new_offset}, []}
  end

  def update(:home, state) do
    {%{state | selected: 0, scroll_offset: 0}, []}
  end

  def update(:end, state) do
    max_index = length(state.data) - 1
    new_offset = max(0, max_index - state.visible_rows + 1)
    {%{state | selected: max_index, scroll_offset: new_offset}, []}
  end

  def update(:quit, state) do
    {state, [:quit]}
  end

  @doc """
  Render the current state to a render tree.
  """
  @impl true
  def view(state) do
    # Define columns with different width constraints
    columns = [
      # Fixed width column for ID
      Column.new(:id, "ID", width: Constraint.length(4), align: :right),

      # Fill remaining space for name
      Column.new(:name, "Name", width: Constraint.fill()),

      # Fixed width for email
      Column.new(:email, "Email", width: Constraint.length(25)),

      # Fixed width for role
      Column.new(:role, "Role", width: Constraint.length(12)),

      # Custom render function for status
      Column.new(:status, "Status",
        width: Constraint.length(10),
        render: &format_status/1
      )
    ]

    stack(:vertical, [
      # Title
      styled(
        text("Table Widget Example"),
        Style.new(fg: :cyan, attrs: [:bold])
      ),
      text(""),

      # Header row
      render_header(columns),

      # Separator
      text(String.duplicate("─", 80)),

      # Data rows
      render_rows(state, columns),

      # Footer info
      text(""),
      text("Row #{state.selected + 1} of #{length(state.data)}"),
      text(""),

      # Controls
      styled(
        text("Controls:"),
        Style.new(fg: :yellow)
      ),
      text("  ↑/↓         Move selection"),
      text("  Page Up/Down  Scroll by 5"),
      text("  Home/End    Jump to first/last"),
      text("  Q           Quit")
    ])
  end

  # ----------------------------------------------------------------------------
  # Private Helpers
  # ----------------------------------------------------------------------------

  # Format status values with icons
  defp format_status(:active), do: "● Active"
  defp format_status(:inactive), do: "○ Inactive"
  defp format_status(:pending), do: "◐ Pending"
  defp format_status(other), do: to_string(other)

  # Render the header row
  defp render_header(columns) do
    header_text =
      columns
      |> Enum.map(fn col ->
        width = get_column_width(col)
        Column.align_text(col.header, width, col.align)
      end)
      |> Enum.join(" ")

    styled(
      text(header_text),
      Style.new(fg: :white, attrs: [:bold])
    )
  end

  # Render visible data rows
  defp render_rows(state, columns) do
    visible_data =
      state.data
      |> Enum.with_index()
      |> Enum.slice(state.scroll_offset, state.visible_rows)

    rows =
      Enum.map(visible_data, fn {row, index} ->
        render_row(row, index, columns, state)
      end)

    stack(:vertical, rows)
  end

  # Render a single row
  defp render_row(row, index, columns, state) do
    row_text =
      columns
      |> Enum.map(fn col ->
        width = get_column_width(col)
        cell_text = Column.render_cell(col, row)
        Column.align_text(cell_text, width, col.align)
      end)
      |> Enum.join(" ")

    # Highlight selected row
    if index == state.selected do
      styled(
        text(row_text),
        Style.new(fg: :black, bg: :cyan)
      )
    else
      text(row_text)
    end
  end

  # Get column width (simplified - in real usage would use Constraint.resolve)
  defp get_column_width(col) do
    case col.width do
      %Constraint.Length{value: v} -> v
      %Constraint.Fill{} -> 20
      _ -> 15
    end
  end

  # ----------------------------------------------------------------------------
  # Public API
  # ----------------------------------------------------------------------------

  @doc """
  Run the table example application.
  """
  def run do
    TermUI.run(__MODULE__)
  end
end
