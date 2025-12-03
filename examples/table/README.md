# Table Widget Example

A demonstration of the TermUI Table widget for displaying tabular data with selection, sorting, and scrolling.

## Widget Overview

The Table widget provides efficient display of structured data in a tabular format with virtual scrolling, making it suitable for both small datasets and large collections (10,000+ rows). It supports flexible column layouts, custom cell rendering, row selection, and keyboard/mouse navigation.

**Key Features:**
- Virtual scrolling for large datasets
- Flexible column layout (fixed, proportional, percentage widths)
- Row selection (single or multi-select)
- Custom cell rendering functions
- Keyboard and mouse navigation
- Alternating row styles
- Header and row styling

**When to Use:**
- Displaying lists of records
- Data browsers and explorers
- Log viewers
- Database query results
- Any structured data display

## Widget Options

The `Table.new/1` function accepts these options:

- `:columns` - List of Column specifications (required)
- `:data` - List of row maps (required)
- `:selection_mode` - `:none`, `:single`, or `:multi` (default: `:single`)
- `:sortable` - Enable column sorting (default: true)
- `:on_select` - Callback when selection changes: `fn selected_rows -> ... end`
- `:on_sort` - Callback when sort changes: `fn {column, direction} -> ... end`
- `:header_style` - Style for header row
- `:row_style` - Style for data rows
- `:selected_style` - Style for selected rows
- `:alternating` - Alternating row backgrounds (default: false)

**Column Specification** using `Column.new(key, header, opts)`:

- `key` - Map key to extract value from row data
- `header` - Header text to display
- `:width` - Column width constraint:
  - `Constraint.length(n)` - Fixed width in characters
  - `Constraint.percentage(p)` - Percentage of total width
  - `Constraint.fill()` - Fill remaining space
  - `Constraint.ratio(r)` - Proportional width
- `:align` - Text alignment: `:left`, `:right`, or `:center` (default: `:left`)
- `:render` - Custom render function: `fn value -> String.t()`

## Example Structure

This example consists of:

- `lib/table/app.ex` - Main application demonstrating:
  - Basic table with multiple columns
  - Mixed column widths (fixed and fill)
  - Custom cell rendering (status with icons)
  - Row selection and navigation
  - Scrolling through data
- `mix.exs` - Mix project configuration
- `run.exs` - Helper script to run the example

## Running the Example

From this directory:

```bash
# Install dependencies
mix deps.get

# Run with the helper script
elixir run.exs

# Or run directly with mix
mix run -e "Table.App.run()" --no-halt
```

## Controls

| Key | Action |
|-----|--------|
| ↑/↓ | Move selection up/down |
| Page Up/Down | Scroll by 5 rows |
| Home/End | Jump to first/last row |
| Q | Quit |

## Code Examples

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

## Column Layout

The example demonstrates different column width strategies:

1. **ID Column** - Fixed width (4 characters, right-aligned)
2. **Name Column** - Fills remaining space
3. **Email Column** - Fixed width (25 characters)
4. **Role Column** - Fixed width (12 characters)
5. **Status Column** - Fixed width (10 characters) with custom rendering

## Custom Cell Rendering

The Status column demonstrates custom rendering with icons:

- **● Active** - Green indicator for active users
- **○ Inactive** - White indicator for inactive users
- **◐ Pending** - Half-filled indicator for pending users

This shows how to transform data values into formatted display text with visual indicators.

## Note on Implementation

This example demonstrates a simplified approach where the Table widget is rendered as a static display with manual state management in the app. For production use with stateful components, the Table widget can be integrated as a StatefulComponent with automatic state handling for selection, sorting, and scrolling.

## Widget API

See the following files for full API documentation:
- `lib/term_ui/widgets/table.ex` - Main Table widget
- `lib/term_ui/widgets/table/column.ex` - Column specification
