# Table Widget Example

This example demonstrates how to use the `TermUI.Widgets.Table` widget for displaying tabular data with selection and scrolling.

## Features Demonstrated

- Column definitions with width constraints
- Row selection and keyboard navigation
- Custom cell rendering functions
- Header and row styling
- Scrolling through large datasets

## Installation

```bash
cd examples/table
mix deps.get
```

## Running

```bash
mix run run.exs
```

## Controls

| Key | Action |
|-----|--------|
| ↑/↓ | Move selection up/down |
| Page Up/Down | Scroll by 5 rows |
| Home/End | Jump to first/last row |
| Q | Quit |

## Code Overview

### Defining Columns

```elixir
alias TermUI.Widgets.Table.Column
alias TermUI.Layout.Constraint

columns = [
  # Fixed width column
  Column.new(:id, "ID", width: Constraint.length(4), align: :right),

  # Fill remaining space
  Column.new(:name, "Name", width: Constraint.fill()),

  # Custom render function
  Column.new(:status, "Status",
    width: Constraint.length(10),
    render: fn
      :active -> "● Active"
      :inactive -> "○ Inactive"
      _ -> "Unknown"
    end
  )
]
```

### Column Options

```elixir
Column.new(key, header,
  width: Constraint.length(20),  # Width constraint
  align: :left,                   # :left, :center, or :right
  render: &custom_formatter/1,    # Custom render function
  sortable: true                  # Enable sorting
)
```

### Width Constraints

```elixir
# Fixed width
Constraint.length(20)

# Proportional (ratio of available space)
Constraint.ratio(2)

# Percentage of total width
Constraint.percentage(50)

# Fill remaining space
Constraint.fill()
```

### Data Format

Data is a list of maps where keys match column keys:

```elixir
data = [
  %{id: 1, name: "Alice", email: "alice@example.com", status: :active},
  %{id: 2, name: "Bob", email: "bob@example.com", status: :inactive}
]
```

### Rendering a Cell

```elixir
# Extract and format cell value from a row
cell_text = Column.render_cell(column, row)

# Align text within column width
aligned = Column.align_text(cell_text, width, :left)
```

### Using the Full Table Widget

For interactive tables with built-in selection and sorting:

```elixir
Table.new(
  columns: columns,
  data: data,
  selection_mode: :single,  # :none, :single, or :multi
  sortable: true,
  header_style: Style.new(attrs: [:bold]),
  selected_style: Style.new(bg: :blue)
)
```

## Widget API

See the following files for full API documentation:
- `lib/term_ui/widgets/table.ex` - Main Table widget
- `lib/term_ui/widgets/table/column.ex` - Column specification
