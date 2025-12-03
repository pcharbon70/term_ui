# Widgets

TermUI includes pre-built widgets for common UI patterns. This guide covers the available widgets and how to use them.

## Widget Types

TermUI has two types of widgets:

1. **Simple Widgets** - Stateless, render with keyword options (Gauge, Sparkline)
2. **Stateful Widgets** - Use the StatefulComponent pattern with `new/init/handle_event/render`

## Simple Widgets

### Gauge

> **Example:** See [`examples/gauge/`](../../examples/gauge/) for a complete demonstration.

Displays a value as a progress bar with optional color zones.

```elixir
alias TermUI.Widgets.Gauge
alias TermUI.Renderer.Style

# Basic gauge
Gauge.render(value: 75, width: 20)

# With color zones
Gauge.render(
  value: cpu_percent,
  width: 20,
  zones: [
    {0, Style.new(fg: :green)},     # 0-59: green
    {60, Style.new(fg: :yellow)},   # 60-79: yellow
    {80, Style.new(fg: :red)}       # 80-100: red
  ]
)

# With value display
Gauge.render(
  value: 42,
  width: 30,
  show_value: true,
  show_range: true
)
```

**Options:**

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `value` | number | required | Current value (0-100) |
| `width` | integer | 20 | Width in characters |
| `zones` | list | `[]` | Color zones `[{threshold, style}]` |
| `show_value` | boolean | `false` | Display numeric value |
| `show_range` | boolean | `false` | Display min/max |
| `style` | Style | default | Base style |

**Example Output:**
```
[████████████░░░░░░░░] 60%
```

### Sparkline

> **Example:** See [`examples/sparkline/`](../../examples/sparkline/) for a complete demonstration.

Compact inline graph showing trends.

```elixir
alias TermUI.Widgets.Sparkline

# Basic sparkline
Sparkline.render(values: [10, 25, 40, 30, 50, 45, 60])

# With range
Sparkline.render(
  values: history,
  min: 0,
  max: 100,
  style: Style.new(fg: :cyan)
)
```

**Options:**

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `values` | list | required | List of numeric values |
| `min` | number | auto | Minimum value for scaling |
| `max` | number | auto | Maximum value for scaling |
| `style` | Style | default | Color style |

**Example Output:**
```
▁▂▄▃▆▅█
```

Uses Unicode block characters (▁▂▃▄▅▆▇█) to show 8 levels of height.

## Stateful Widgets

Stateful widgets follow the StatefulComponent pattern:

```elixir
# 1. Create props with Widget.new(opts)
props = Widget.new(option: value)

# 2. Initialize state with Widget.init(props)
{:ok, widget_state} = Widget.init(props)

# 3. Handle events with Widget.handle_event(event, state)
{:ok, widget_state} = Widget.handle_event(event, widget_state)

# 4. Render with Widget.render(state, area)
node = Widget.render(widget_state, %{width: 80, height: 24})
```

### Table

> **Example:** See [`examples/table/`](../../examples/table/) for a complete demonstration.

Scrollable data table with selection and sorting.

```elixir
alias TermUI.Widgets.Table
alias TermUI.Widgets.Table.Column

# Create props
props = Table.new(
  columns: [
    Column.new(:name, "Name"),
    Column.new(:age, "Age", width: 10, align: :right),
    Column.new(:city, "City", width: 15)
  ],
  data: [
    %{name: "Alice", age: 30, city: "NYC"},
    %{name: "Bob", age: 25, city: "LA"},
    %{name: "Carol", age: 35, city: "Chicago"}
  ],
  selection_mode: :single,
  on_select: fn row -> IO.inspect(row) end
)

# Initialize
{:ok, table_state} = Table.init(props)

# In your component's event handler
def update({:table_event, event}, state) do
  {:ok, new_table} = Table.handle_event(event, state.table)
  {%{state | table: new_table}, []}
end

# In your view
def view(state) do
  Table.render(state.table, %{width: 60, height: 15})
end
```

**Options:**

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `columns` | list | required | Column definitions |
| `data` | list | required | List of row maps |
| `selection_mode` | atom | `:single` | `:none`, `:single`, or `:multi` |
| `sortable` | boolean | `true` | Enable column sorting |
| `on_select` | function | `nil` | Selection callback |
| `header_style` | Style | default | Header row style |
| `selected_style` | Style | reverse | Selected row style |

**Keyboard Navigation:**
- Arrow keys: Move selection
- Page Up/Down: Scroll by page
- Home/End: Jump to first/last row
- Enter: Confirm selection
- Space: Toggle selection (multi mode)

### Menu

> **Example:** See [`examples/menu/`](../../examples/menu/) for a complete demonstration.

Hierarchical menu with submenus and keyboard navigation.

```elixir
alias TermUI.Widgets.Menu

# Create props with item constructors
props = Menu.new(
  items: [
    Menu.action(:new, "New File", shortcut: "Ctrl+N"),
    Menu.action(:open, "Open...", shortcut: "Ctrl+O"),
    Menu.separator(),
    Menu.submenu(:recent, "Recent Files", [
      Menu.action(:file1, "document.txt"),
      Menu.action(:file2, "notes.md")
    ]),
    Menu.separator(),
    Menu.checkbox(:autosave, "Auto Save", checked: true),
    Menu.action(:exit, "Exit", shortcut: "Ctrl+Q")
  ],
  on_select: fn id -> handle_menu_action(id) end
)

# Initialize
{:ok, menu_state} = Menu.init(props)

# Handle events and render
{:ok, menu_state} = Menu.handle_event(event, menu_state)
Menu.render(menu_state, %{width: 30, height: 20})
```

**Item Types:**

| Constructor | Description |
|------------|-------------|
| `Menu.action(id, label, opts)` | Selectable menu item |
| `Menu.submenu(id, label, children)` | Item with nested menu |
| `Menu.separator()` | Visual divider |
| `Menu.checkbox(id, label, opts)` | Toggleable item |

**Keyboard Navigation:**
- Up/Down: Move between items
- Enter/Space: Select or expand submenu
- Left: Collapse submenu
- Right: Expand submenu
- Escape: Close menu

### TextInput

> **Example:** See [`examples/text_input/`](../../examples/text_input/) for a complete demonstration.

Single-line and multi-line text input with cursor movement.

```elixir
alias TermUI.Widgets.TextInput

# Create props
props = TextInput.new(
  placeholder: "Enter your name...",
  width: 40,
  multiline: false
)

# Initialize
{:ok, input_state} = TextInput.init(props)

# Handle events
{:ok, input_state} = TextInput.handle_event(event, input_state)

# Get current value
value = TextInput.get_value(input_state)

# Render
TextInput.render(input_state, %{width: 50, height: 1})
```

**Options:**

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `value` | string | `""` | Initial text value |
| `placeholder` | string | `""` | Placeholder text |
| `width` | integer | 40 | Field width |
| `multiline` | boolean | `false` | Enable multi-line mode |
| `max_visible_lines` | integer | 5 | Lines before scrolling |
| `enter_submits` | boolean | `false` | Enter submits vs newline |
| `on_change` | function | `nil` | Value change callback |
| `on_submit` | function | `nil` | Submit callback |

**Keyboard Controls:**
- Left/Right: Move cursor
- Up/Down: Move between lines (multiline)
- Home/End: Start/end of line
- Ctrl+Home/End: Start/end of text
- Backspace/Delete: Delete characters
- Ctrl+Enter: Insert newline (multiline)
- Enter: Submit or newline

**Helper Functions:**

```elixir
# Get current value
TextInput.get_value(state) # => "current text"

# Get cursor position
TextInput.get_cursor(state) # => {row, col}

# Get line count
TextInput.get_line_count(state) # => 3

# Set focus
state = TextInput.set_focused(state, true)

# Clear input
state = TextInput.clear(state)
```

### Dialog

> **Example:** See [`examples/dialog/`](../../examples/dialog/) for a complete demonstration.

Modal dialog with buttons.

```elixir
alias TermUI.Widgets.Dialog

# Create props
props = Dialog.new(
  title: "Confirm Delete",
  content: text("Are you sure you want to delete this file?"),
  buttons: [
    %{id: :cancel, label: "Cancel"},
    %{id: :confirm, label: "Delete", style: :danger}
  ],
  width: 50,
  on_confirm: fn button_id -> handle_action(button_id) end
)

# Initialize and use
{:ok, dialog_state} = Dialog.init(props)
{:ok, dialog_state} = Dialog.handle_event(event, dialog_state)
Dialog.render(dialog_state, %{width: 80, height: 24})
```

**Options:**

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `title` | string | required | Dialog title |
| `content` | node | `nil` | Dialog body content |
| `buttons` | list | `[{id: :ok, label: "OK"}]` | Button definitions |
| `width` | integer | 40 | Dialog width |
| `closeable` | boolean | `true` | Escape closes dialog |
| `on_close` | function | `nil` | Close callback |
| `on_confirm` | function | `nil` | Button activation callback |

**Keyboard Navigation:**
- Tab/Shift+Tab: Move between buttons
- Enter/Space: Activate focused button
- Escape: Close dialog

### PickList

> **Example:** See [`examples/pick_list/`](../../examples/pick_list/) for a complete demonstration.

Modal selection dialog with type-ahead filtering.

```elixir
alias TermUI.Widget.PickList

# Create props
props = %{
  items: ["Apple", "Banana", "Cherry", "Date", "Elderberry"],
  title: "Select Fruit",
  width: 40,
  height: 12,
  on_select: fn item -> handle_selection(item) end,
  on_cancel: fn -> handle_cancel() end
}

# Initialize
{:ok, picklist_state} = PickList.init(props)

# Handle events
{:ok, picklist_state} = PickList.handle_event(event, picklist_state)

# Render
PickList.render(picklist_state, %{width: 80, height: 24})
```

**Options:**

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `items` | list | required | List of items to display |
| `title` | string | `"Select"` | Modal title |
| `width` | integer | 40 | Modal width |
| `height` | integer | 10 | Modal height |
| `on_select` | function | `nil` | Selection callback `fn item -> ... end` |
| `on_cancel` | function | `nil` | Cancel callback `fn -> ... end` |
| `style` | map | `%{}` | Border/text style |
| `highlight_style` | map | inverted | Selected item style |

**Keyboard Controls:**
- Up/Down: Navigate items
- Page Up/Down: Jump 10 items
- Home/End: Jump to first/last
- Enter: Confirm selection
- Escape: Cancel
- Typing: Filter items (type-ahead)
- Backspace: Remove filter character

## Building Custom Widgets

Create reusable widgets as functions:

```elixir
defmodule MyApp.Widgets do
  import TermUI.Component.Helpers
  alias TermUI.Renderer.Style

  @doc """
  Renders a labeled value pair.
  """
  def labeled_value(label, value, opts \\ []) do
    label_style = Keyword.get(opts, :label_style, Style.new(fg: :bright_black))
    value_style = Keyword.get(opts, :value_style, Style.new(fg: :white))

    stack(:horizontal, [
      text("#{label}: ", label_style),
      text(to_string(value), value_style)
    ])
  end

  @doc """
  Renders a bordered box with title.
  """
  def box(title, content, opts \\ []) do
    width = Keyword.get(opts, :width, 40)
    border_style = Keyword.get(opts, :border_style, Style.new(fg: :cyan))

    inner_width = width - 4
    top_border = "┌─ " <> title <> " " <> String.duplicate("─", inner_width - String.length(title) - 1) <> "┐"
    bottom_border = "└" <> String.duplicate("─", width - 2) <> "┘"

    stack(:vertical, [
      text(top_border, border_style),
      stack(:horizontal, [
        text("│ ", border_style),
        content,
        text(" │", border_style)
      ]),
      text(bottom_border, border_style)
    ])
  end

  @doc """
  Renders a status indicator.
  """
  def status_indicator(status) do
    {symbol, style} = case status do
      :ok -> {"●", Style.new(fg: :green)}
      :warning -> {"●", Style.new(fg: :yellow)}
      :error -> {"●", Style.new(fg: :red)}
      :unknown -> {"○", Style.new(fg: :bright_black)}
    end

    text(symbol, style)
  end
end
```

Usage:

```elixir
import MyApp.Widgets

def view(state) do
  stack(:vertical, [
    box("System Status", stack(:vertical, [
      stack(:horizontal, [
        status_indicator(:ok),
        text(" "),
        labeled_value("CPU", "#{state.cpu}%")
      ]),
      stack(:horizontal, [
        status_indicator(:warning),
        text(" "),
        labeled_value("Memory", "#{state.memory}%")
      ])
    ]))
  ])
end
```

## Widget Composition

Combine widgets for complex UIs:

```elixir
alias TermUI.Widgets.{Gauge, Sparkline, Table}

def view(state) do
  stack(:vertical, [
    # Header with gauges
    stack(:horizontal, [
      box("CPU", Gauge.render(value: state.cpu, width: 15)),
      box("Memory", Gauge.render(value: state.mem, width: 15))
    ]),

    # Sparkline history
    box("Network", stack(:vertical, [
      stack(:horizontal, [
        text("RX: "),
        Sparkline.render(values: state.rx_history)
      ]),
      stack(:horizontal, [
        text("TX: "),
        Sparkline.render(values: state.tx_history)
      ])
    ])),

    # Process table (stateful widget)
    Table.render(state.table, %{width: 60, height: 10})
  ])
end
```

## Full Example: Component with TextInput

```elixir
defmodule MyApp.SearchForm do
  use TermUI.Elm

  alias TermUI.Event
  alias TermUI.Widgets.TextInput

  def init(_opts) do
    props = TextInput.new(
      placeholder: "Search...",
      width: 40
    )
    {:ok, input_state} = TextInput.init(props)

    %{
      input: TextInput.set_focused(input_state, true),
      results: []
    }
  end

  def event_to_msg(%Event.Key{key: :enter}, state) do
    query = TextInput.get_value(state.input)
    {:msg, {:search, query}}
  end

  def event_to_msg(%Event.Key{key: "q"}, %{input: input}) do
    # Only quit if input is empty
    if TextInput.get_value(input) == "" do
      {:msg, :quit}
    else
      {:msg, {:input_event, %Event.Key{key: "q", char: "q"}}}
    end
  end

  def event_to_msg(event, _state) do
    {:msg, {:input_event, event}}
  end

  def update(:quit, state), do: {state, [:quit]}

  def update({:input_event, event}, state) do
    {:ok, new_input} = TextInput.handle_event(event, state.input)
    {%{state | input: new_input}, []}
  end

  def update({:search, query}, state) do
    results = perform_search(query)
    {%{state | results: results}, []}
  end

  def view(state) do
    stack(:vertical, [
      text("Search:", Style.new(fg: :cyan)),
      TextInput.render(state.input, %{width: 50, height: 1}),
      text(""),
      render_results(state.results)
    ])
  end

  defp perform_search(query), do: []
  defp render_results([]), do: text("No results")
  defp render_results(results) do
    stack(:vertical, Enum.map(results, &text(&1)))
  end
end
```

## Next Steps

- [Advanced Widgets](10-advanced-widgets.md) - Navigation, visualization, streaming, and BEAM introspection widgets
- [Styling](05-styling.md) - Customize widget appearance
- [Layout](06-layout.md) - Position widgets
- [Events](04-events.md) - Handle widget interactions
