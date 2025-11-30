# Widgets

TermUI includes pre-built widgets for common UI patterns. This guide covers the available widgets and how to use them.

## Gauge

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

## Sparkline

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

## Table

Scrollable data table with selection.

```elixir
alias TermUI.Widgets.Table

data = [
  %{name: "Alice", age: 30, city: "NYC"},
  %{name: "Bob", age: 25, city: "LA"},
  %{name: "Carol", age: 35, city: "Chicago"}
]

Table.render(
  data: data,
  columns: [
    %{key: :name, header: "Name", width: 15},
    %{key: :age, header: "Age", width: 5},
    %{key: :city, header: "City", width: 12}
  ],
  selected: state.selected_row,
  height: 10
)
```

**Options:**

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `data` | list | required | List of row maps |
| `columns` | list | required | Column definitions |
| `selected` | integer | `nil` | Selected row index |
| `height` | integer | 10 | Visible rows |
| `header_style` | Style | bold | Header row style |
| `row_style` | Style | default | Normal row style |
| `selected_style` | Style | reverse | Selected row style |

**Column Definition:**

```elixir
%{
  key: :field_name,        # Key in data map
  header: "Display Name",  # Column header text
  width: 15,               # Column width
  align: :left             # :left, :center, :right
}
```

## Menu

Vertical or horizontal menu selection.

```elixir
alias TermUI.Widgets.Menu

Menu.render(
  items: ["File", "Edit", "View", "Help"],
  selected: state.selected_index,
  direction: :vertical
)
```

**Options:**

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `items` | list | required | Menu item labels |
| `selected` | integer | 0 | Selected item index |
| `direction` | atom | `:vertical` | `:vertical` or `:horizontal` |
| `style` | Style | default | Normal item style |
| `selected_style` | Style | reverse | Selected item style |

## TextInput

Single-line text input field.

```elixir
alias TermUI.Widgets.TextInput

TextInput.render(
  value: state.input_text,
  cursor_position: state.cursor_pos,
  width: 30,
  placeholder: "Enter name..."
)
```

**Options:**

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `value` | string | `""` | Current text value |
| `cursor_position` | integer | 0 | Cursor position |
| `width` | integer | 20 | Field width |
| `placeholder` | string | `""` | Placeholder text |
| `style` | Style | default | Text style |
| `focused` | boolean | `false` | Show cursor |

**Handling Input:**

```elixir
def event_to_msg(%Event.Key{key: :left}, state) do
  {:msg, :cursor_left}
end

def event_to_msg(%Event.Key{key: :right}, state) do
  {:msg, :cursor_right}
end

def event_to_msg(%Event.Key{key: :backspace}, state) do
  {:msg, :backspace}
end

def event_to_msg(%Event.Key{char: char}, state) when is_binary(char) do
  {:msg, {:insert, char}}
end

def update(:cursor_left, state) do
  pos = max(0, state.cursor_pos - 1)
  {%{state | cursor_pos: pos}, []}
end

def update({:insert, char}, state) do
  {before, after} = String.split_at(state.input, state.cursor_pos)
  new_input = before <> char <> after
  {%{state | input: new_input, cursor_pos: state.cursor_pos + 1}, []}
end
```

## Progress

Progress indicator with bar or spinner mode.

```elixir
alias TermUI.Widgets.Progress

# Progress bar
Progress.render(
  mode: :bar,
  value: 0.75,
  width: 30
)

# Spinner (indeterminate)
Progress.render(
  mode: :spinner,
  frame: state.spinner_frame
)
```

**Options:**

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `mode` | atom | `:bar` | `:bar` or `:spinner` |
| `value` | float | 0.0 | Progress 0.0-1.0 (bar mode) |
| `frame` | integer | 0 | Animation frame (spinner) |
| `width` | integer | 20 | Bar width |
| `style` | Style | default | Color style |

## Dialog

Modal dialog box.

```elixir
alias TermUI.Widgets.Dialog

Dialog.render(
  title: "Confirm",
  content: "Are you sure you want to delete?",
  buttons: ["Cancel", "Delete"],
  selected_button: state.selected_button,
  width: 40
)
```

**Options:**

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `title` | string | `""` | Dialog title |
| `content` | string | `""` | Dialog body text |
| `buttons` | list | `["OK"]` | Button labels |
| `selected_button` | integer | 0 | Selected button index |
| `width` | integer | 40 | Dialog width |

## Building Custom Widgets

Create reusable widgets as functions:

```elixir
defmodule MyApp.Widgets do
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
    title_style = Keyword.get(opts, :title_style, Style.new(fg: :cyan, attrs: [:bold]))

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

    # Process table
    box("Processes", Table.render(
      data: state.processes,
      columns: @process_columns,
      selected: state.selected_process,
      height: 10
    ))
  ])
end
```

## Next Steps

- [Advanced Widgets](10-advanced-widgets.md) - Navigation, visualization, streaming, and BEAM introspection widgets
- [Styling](05-styling.md) - Customize widget appearance
- [Layout](06-layout.md) - Position widgets
- [Events](04-events.md) - Handle widget interactions
