# Advanced Widgets

TermUI includes advanced widgets for complex UI patterns including navigation, overlays, visualization, data streaming, and BEAM introspection. This guide covers these widgets and how to use them.

## Navigation Widgets

### Tabs

Tabbed interface for organizing content into switchable panels.

```elixir
alias TermUI.Widgets.Tabs

Tabs.render(
  tabs: ["Overview", "Details", "Settings"],
  selected: state.active_tab,
  content: render_tab_content(state)
)
```

**Options:**

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `tabs` | list | required | Tab labels |
| `selected` | integer | 0 | Selected tab index |
| `content` | node | `nil` | Content for selected tab |
| `style` | Style | default | Tab bar style |
| `selected_style` | Style | reverse | Selected tab style |
| `closeable` | boolean | `false` | Show close buttons |

**Example Output:**
```
┌─Overview─┬─Details─┬─Settings─┐
│ Tab content here...           │
```

### Context Menu

Right-click context menu that appears at cursor position.

```elixir
alias TermUI.Widgets.ContextMenu

# In your view, conditionally render
if state.show_context_menu do
  ContextMenu.render(
    items: [
      %{label: "Cut", shortcut: "Ctrl+X", action: :cut},
      %{label: "Copy", shortcut: "Ctrl+C", action: :copy},
      %{label: "Paste", shortcut: "Ctrl+V", action: :paste},
      :separator,
      %{label: "Delete", action: :delete}
    ],
    selected: state.menu_selection,
    position: state.menu_position
  )
end
```

**Options:**

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `items` | list | required | Menu items or `:separator` |
| `selected` | integer | 0 | Selected item index |
| `position` | tuple | `{0, 0}` | `{x, y}` position |
| `style` | Style | default | Menu style |

**Item Structure:**
```elixir
%{
  label: "Menu Item",    # Display text
  shortcut: "Ctrl+X",    # Optional shortcut hint
  action: :action_atom,  # Action identifier
  disabled: false        # Optional disabled state
}
```

## Overlay Widgets

### Alert Dialog

Modal dialog for confirmations and messages with standard button configurations.

```elixir
alias TermUI.Widgets.AlertDialog

# Confirmation dialog
AlertDialog.render(
  type: :confirm,
  title: "Delete File",
  message: "Are you sure you want to delete this file?",
  buttons: :yes_no,
  selected_button: state.selected_button
)

# Error alert
AlertDialog.render(
  type: :error,
  title: "Connection Failed",
  message: "Could not connect to server.",
  buttons: :ok
)
```

**Options:**

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `type` | atom | `:info` | `:info`, `:warning`, `:error`, `:success`, `:confirm` |
| `title` | string | `""` | Dialog title |
| `message` | string | required | Dialog message |
| `buttons` | atom/list | `:ok` | `:ok`, `:ok_cancel`, `:yes_no`, or custom list |
| `selected_button` | integer | 0 | Selected button index |
| `width` | integer | 50 | Dialog width |

**Type Icons:**
- `:info` - ℹ (blue)
- `:warning` - ⚠ (yellow)
- `:error` - ✖ (red)
- `:success` - ✔ (green)
- `:confirm` - ? (cyan)

### Toast

Non-blocking notification that auto-dismisses.

```elixir
alias TermUI.Widgets.Toast

# Add toast to your state
def update(:save_success, state) do
  toast = %{
    id: System.unique_integer(),
    type: :success,
    message: "File saved successfully",
    duration: 3000
  }
  {:ok, %{state | toasts: [toast | state.toasts]}}
end

# Render toasts
def view(state) do
  stack(:vertical, [
    main_content(state),
    Toast.render(toasts: state.toasts, position: :bottom_right)
  ])
end
```

**Options:**

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `toasts` | list | `[]` | List of toast maps |
| `position` | atom | `:bottom_right` | `:top_right`, `:bottom_right`, etc. |
| `max_visible` | integer | 5 | Maximum visible toasts |

**Toast Structure:**
```elixir
%{
  id: unique_id,
  type: :info,        # :info, :success, :warning, :error
  message: "Text",
  duration: 3000      # ms, nil for persistent
}
```

## Visualization Widgets

### Bar Chart

Horizontal or vertical bar chart for categorical data.

```elixir
alias TermUI.Widgets.BarChart

# Horizontal bar chart
BarChart.render(
  data: [
    %{label: "Sales", value: 150},
    %{label: "Marketing", value: 80},
    %{label: "Engineering", value: 200}
  ],
  width: 40,
  show_values: true,
  show_labels: true
)

# Vertical bar chart
BarChart.render(
  data: data,
  direction: :vertical,
  width: 30,
  height: 10
)

# Simple progress bar
BarChart.bar(value: 75, max: 100, width: 20)
```

**Options:**

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `data` | list | required | List of `%{label, value}` maps |
| `direction` | atom | `:horizontal` | `:horizontal` or `:vertical` |
| `width` | integer | 40 | Chart width |
| `height` | integer | 10 | Chart height (vertical only) |
| `show_values` | boolean | `true` | Display values |
| `show_labels` | boolean | `true` | Display labels |
| `bar_char` | string | `"█"` | Character for filled portion |
| `empty_char` | string | `"░"` | Character for empty portion |

**Example Output:**
```
Sales       ████████████████ 150
Marketing   ████████ 80
Engineering █████████████████████ 200
```

### Line Chart

Line chart using Braille characters for sub-character resolution.

```elixir
alias TermUI.Widgets.LineChart

# Single series
LineChart.render(
  data: [10, 25, 18, 30, 22, 35, 28],
  width: 40,
  height: 8
)

# Multiple series
LineChart.render(
  series: [
    %{data: cpu_history, color: :green},
    %{data: mem_history, color: :yellow}
  ],
  width: 60,
  height: 10,
  min: 0,
  max: 100,
  show_axis: true
)
```

**Options:**

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `data` | list | - | Single series data |
| `series` | list | - | Multiple series with colors |
| `width` | integer | 40 | Chart width |
| `height` | integer | 8 | Chart height |
| `min` | number | auto | Y-axis minimum |
| `max` | number | auto | Y-axis maximum |
| `show_axis` | boolean | `false` | Show axis labels |

**Braille Resolution:**

Each character cell provides 2x4 dot resolution using Unicode Braille patterns (U+2800-U+28FF), enabling smooth line rendering in text mode.

### Canvas

Direct drawing surface for custom visualizations.

```elixir
alias TermUI.Widgets.Canvas

Canvas.render(
  width: 60,
  height: 20,
  draw: fn canvas ->
    canvas
    |> Canvas.draw_rect(0, 0, 59, 19, style: border_style)
    |> Canvas.draw_line(0, 10, 59, 10)
    |> Canvas.draw_text(25, 0, "Title", title_style)
    |> Canvas.draw_braille_line(5, 5, 55, 15)
  end
)
```

**Drawing Functions:**

| Function | Description |
|----------|-------------|
| `draw_text(x, y, text, style)` | Draw text at position |
| `draw_line(x1, y1, x2, y2)` | Draw line between points |
| `draw_rect(x, y, w, h, opts)` | Draw rectangle |
| `draw_braille_line(x1, y1, x2, y2)` | High-resolution Braille line |
| `fill_rect(x, y, w, h, char)` | Fill rectangle with character |
| `clear()` | Clear canvas |

## Layout Widgets

### Viewport

Scrollable view of content larger than the display area.

```elixir
alias TermUI.Widgets.Viewport

Viewport.render(
  content: large_content_node,
  width: 60,
  height: 20,
  scroll_x: state.scroll_x,
  scroll_y: state.scroll_y,
  show_scrollbars: true
)
```

**Options:**

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `content` | node | required | Content to scroll |
| `width` | integer | required | Viewport width |
| `height` | integer | required | Viewport height |
| `scroll_x` | integer | 0 | Horizontal scroll offset |
| `scroll_y` | integer | 0 | Vertical scroll offset |
| `show_scrollbars` | boolean | `true` | Show scroll indicators |

### Split Pane

Resizable split layout for IDE-style interfaces.

```elixir
alias TermUI.Widgets.SplitPane

# Horizontal split (left/right)
SplitPane.render(
  direction: :horizontal,
  first: sidebar_content,
  second: main_content,
  split_position: state.split_pos,  # 0.0 to 1.0
  min_size: 10,
  max_size: 50
)

# Vertical split (top/bottom)
SplitPane.render(
  direction: :vertical,
  first: editor_content,
  second: terminal_content,
  split_position: 0.7
)
```

**Options:**

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `direction` | atom | `:horizontal` | `:horizontal` or `:vertical` |
| `first` | node | required | First pane content |
| `second` | node | required | Second pane content |
| `split_position` | float | 0.5 | Split ratio (0.0-1.0) |
| `min_size` | integer | 5 | Minimum pane size |
| `max_size` | integer | `nil` | Maximum pane size |
| `draggable` | boolean | `true` | Allow resize |

### Tree View

Hierarchical data with expand/collapse.

```elixir
alias TermUI.Widgets.TreeView

TreeView.render(
  data: [
    %{
      label: "src",
      icon: "📁",
      children: [
        %{label: "main.ex", icon: "📄"},
        %{label: "utils.ex", icon: "📄"}
      ]
    },
    %{label: "README.md", icon: "📄"}
  ],
  expanded: state.expanded_nodes,
  selected: state.selected_node
)
```

**Options:**

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `data` | list | required | Tree node list |
| `expanded` | MapSet | `MapSet.new()` | Expanded node IDs |
| `selected` | term | `nil` | Selected node ID |
| `indent` | integer | 2 | Indentation per level |
| `show_icons` | boolean | `true` | Display node icons |

**Node Structure:**
```elixir
%{
  id: unique_id,       # Optional, auto-generated if missing
  label: "Node Name",
  icon: "📁",          # Optional icon
  children: [...]      # Optional child nodes
}
```

## Input Widgets

### Form Builder

Structured forms with validation and multiple field types.

```elixir
alias TermUI.Widgets.FormBuilder

FormBuilder.render(
  fields: [
    %{name: :username, type: :text, label: "Username", required: true},
    %{name: :password, type: :password, label: "Password", required: true},
    %{name: :role, type: :select, label: "Role",
      options: ["Admin", "User", "Guest"]},
    %{name: :notifications, type: :checkbox, label: "Email notifications"},
    %{name: :theme, type: :radio, label: "Theme",
      options: ["Light", "Dark", "System"]}
  ],
  values: state.form_values,
  errors: state.form_errors,
  focused_field: state.focused_field
)
```

**Field Types:**

| Type | Description |
|------|-------------|
| `:text` | Single-line text input |
| `:password` | Masked password input |
| `:checkbox` | Boolean checkbox |
| `:radio` | Radio button group |
| `:select` | Dropdown selection |
| `:multi_select` | Multiple selection |

**Field Options:**
```elixir
%{
  name: :field_name,
  type: :text,
  label: "Field Label",
  required: true,
  placeholder: "Enter value...",
  validation: &String.length(&1) >= 3,
  error_message: "Must be at least 3 characters"
}
```

### Command Palette

VS Code-style command interface with fuzzy search.

```elixir
alias TermUI.Widgets.CommandPalette

CommandPalette.render(
  commands: [
    %{id: :save, label: "Save File", shortcut: "Ctrl+S", category: "File"},
    %{id: :open, label: "Open File", shortcut: "Ctrl+O", category: "File"},
    %{id: :find, label: "Find", shortcut: "Ctrl+F", category: "Edit"},
    %{id: :replace, label: "Find and Replace", shortcut: "Ctrl+H", category: "Edit"}
  ],
  query: state.palette_query,
  selected: state.palette_selection,
  visible: state.palette_open
)
```

**Options:**

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `commands` | list | required | Available commands |
| `query` | string | `""` | Search query |
| `selected` | integer | 0 | Selected result index |
| `visible` | boolean | `false` | Show/hide palette |
| `max_results` | integer | 10 | Maximum visible results |
| `show_recent` | boolean | `true` | Show recent commands |

**Command Structure:**
```elixir
%{
  id: :command_id,
  label: "Command Label",
  shortcut: "Ctrl+K",      # Optional
  category: "Category",     # Optional, for grouping
  description: "Details"    # Optional
}
```

**Category Prefixes:**
- `>` - Commands (default)
- `@` - Symbols/functions
- `#` - Tags/labels
- `:` - Line numbers

## Data Streaming Widgets

### Log Viewer

High-performance log viewer with virtual scrolling, search, and filtering.

```elixir
alias TermUI.Widgets.LogViewer

LogViewer.render(
  lines: state.log_lines,
  width: 80,
  height: 20,
  scroll_offset: state.scroll_offset,
  tail_mode: state.tail_mode,
  search: state.search_query,
  filter: state.log_filter
)
```

**Options:**

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `lines` | list | required | Log lines |
| `width` | integer | 80 | Viewer width |
| `height` | integer | 20 | Viewer height |
| `scroll_offset` | integer | 0 | Current scroll position |
| `tail_mode` | boolean | `true` | Auto-scroll to bottom |
| `search` | string | `nil` | Search/highlight pattern |
| `filter` | term | `nil` | Log level filter |
| `wrap_lines` | boolean | `false` | Wrap long lines |
| `show_line_numbers` | boolean | `true` | Show line numbers |

**Log Line Structure:**
```elixir
%{
  timestamp: ~U[2024-01-15 10:30:00Z],
  level: :info,           # :debug, :info, :warning, :error
  message: "Log message",
  source: "MyApp.Worker"  # Optional
}
```

**Keyboard Controls:**
- `↑/↓` - Scroll line by line
- `PgUp/PgDn` - Scroll by page
- `Home/End` - Jump to start/end
- `/` - Start search
- `f` - Toggle filter
- `t` - Toggle tail mode
- `w` - Toggle line wrap

### Stream Widget

GenStage-integrated widget for real-time data streams with backpressure.

```elixir
alias TermUI.Widgets.StreamWidget

# In your application, set up the stream
StreamWidget.render(
  source: MyApp.DataProducer,
  buffer_size: 1000,
  rate_limit: 60,  # updates per second
  paused: state.stream_paused,
  stats: state.show_stats
)
```

**Options:**

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `source` | module/pid | required | GenStage producer |
| `buffer_size` | integer | 1000 | Maximum buffered items |
| `rate_limit` | integer | 60 | Max renders per second |
| `paused` | boolean | `false` | Pause stream |
| `stats` | boolean | `false` | Show throughput stats |
| `overflow` | atom | `:drop_oldest` | `:drop_oldest`, `:drop_newest` |

## BEAM Introspection Widgets

These widgets leverage Erlang's runtime introspection capabilities for live system visualization.

### Process Monitor

Live BEAM process inspection with sorting, filtering, and process control.

```elixir
alias TermUI.Widgets.ProcessMonitor

props = ProcessMonitor.new(
  update_interval: 1000,
  show_system_processes: false,
  thresholds: %{
    queue_warning: 1000,
    queue_critical: 10_000,
    memory_warning: 50_000_000,
    memory_critical: 200_000_000
  }
)

{:ok, monitor_state} = ProcessMonitor.init(props)

# In view
ProcessMonitor.render(monitor_state, %{width: 100, height: 30})
```

**Options:**

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `update_interval` | integer | 1000 | Refresh interval (ms) |
| `show_system_processes` | boolean | `false` | Include system processes |
| `thresholds` | map | defaults | Warning thresholds |
| `on_select` | function | `nil` | Selection callback |
| `on_action` | function | `nil` | Action callback |

**Keyboard Controls:**
- `↑/↓` - Navigate processes
- `Enter` - Toggle details panel
- `s/S` - Cycle sort field / Toggle direction
- `/` - Filter by name
- `k` - Kill process (with confirmation)
- `p` - Pause/resume process
- `l` - Show links/monitors
- `t` - Show stack trace
- `r` - Refresh

**Display Columns:**
- PID
- Name (registered or initial call)
- Reductions
- Memory
- Message Queue
- Status

### Supervision Tree Viewer

Visualize supervision hierarchies with live status.

```elixir
alias TermUI.Widgets.SupervisionTreeViewer

props = SupervisionTreeViewer.new(
  root: MyApp.Supervisor,
  update_interval: 2000,
  show_pids: true,
  expand_all: false
)

{:ok, tree_state} = SupervisionTreeViewer.init(props)

# In view
SupervisionTreeViewer.render(tree_state, %{width: 80, height: 25})
```

**Options:**

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `root` | pid/atom | required | Root supervisor |
| `update_interval` | integer | 2000 | Refresh interval (ms) |
| `show_pids` | boolean | `true` | Display PIDs |
| `expand_all` | boolean | `false` | Start expanded |
| `on_select` | function | `nil` | Selection callback |

**Keyboard Controls:**
- `↑/↓` - Navigate tree
- `Enter` - Expand/collapse node
- `e/c` - Expand/collapse all
- `i` - Inspect process state
- `r` - Restart process (with confirmation)
- `t` - Terminate process (with confirmation)
- `/` - Filter tree
- `Escape` - Clear filter

**Status Indicators:**
- `●` Running (green)
- `↻` Restarting (yellow)
- `✖` Terminated (red)
- `?` Undefined (gray)

**Strategy Display:**
- `1:1` - one_for_one
- `1:*` - one_for_all
- `1:→` - rest_for_one
- `1:1+` - simple_one_for_one

### Cluster Dashboard

Distributed Erlang cluster visualization.

```elixir
alias TermUI.Widgets.ClusterDashboard

props = ClusterDashboard.new(
  update_interval: 2000,
  show_health_metrics: true,
  show_pg_groups: true,
  show_global_names: true
)

{:ok, dashboard_state} = ClusterDashboard.init(props)

# In view
ClusterDashboard.render(dashboard_state, %{width: 100, height: 30})
```

**Options:**

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `update_interval` | integer | 2000 | Refresh interval (ms) |
| `show_health_metrics` | boolean | `true` | Fetch node metrics |
| `show_pg_groups` | boolean | `true` | Show :pg groups |
| `show_global_names` | boolean | `true` | Show :global names |
| `on_node_select` | function | `nil` | Selection callback |

**View Modes:**
- **Nodes** - Connected nodes with status and metrics
- **Globals** - `:global` registered names
- **PG Groups** - `:pg` process groups
- **Events** - Connection/disconnection log

**Keyboard Controls:**
- `↑/↓` - Navigate list
- `Enter` - Toggle details
- `n` - Nodes view
- `g` - Globals view
- `p` - PG groups view
- `e` - Events view
- `i` - Inspect selected node
- `r` - Refresh

**Features:**
- Network partition detection
- Node health metrics (memory, processes, schedulers)
- Connection event history
- RPC interface for remote inspection

## StatefulComponent Pattern

Advanced widgets use the `StatefulComponent` behavior for managing internal state. Here's the pattern:

```elixir
# Initialize
props = Widget.new(option: value)
{:ok, widget_state} = Widget.init(props)

# Handle events
{:ok, widget_state} = Widget.handle_event(event, widget_state)

# Handle messages (for timers, etc.)
{:ok, widget_state} = Widget.handle_info(message, widget_state)

# Render
node = Widget.render(widget_state, area)
```

**Integration with Elm:**

```elixir
defmodule MyApp do
  use TermUI.Elm
  alias TermUI.Widgets.ProcessMonitor

  def init(_args) do
    props = ProcessMonitor.new(update_interval: 1000)
    {:ok, monitor_state} = ProcessMonitor.init(props)
    {:ok, %{monitor: monitor_state}}
  end

  def update({:key, key_event}, state) do
    event = %TermUI.Event.Key{key: key_event.key, char: key_event.char}
    {:ok, monitor_state} = ProcessMonitor.handle_event(event, state.monitor)
    {:ok, %{state | monitor: monitor_state}}
  end

  def update(:refresh, state) do
    {:ok, monitor_state} = ProcessMonitor.handle_info(:refresh, state.monitor)
    {:ok, %{state | monitor: monitor_state}}
  end

  def view(state) do
    ProcessMonitor.render(state.monitor, %{width: 100, height: 30})
  end
end
```

## Next Steps

- [Widgets](07-widgets.md) - Basic widgets guide
- [Styling](05-styling.md) - Customize widget appearance
- [Layout](06-layout.md) - Position widgets
- [Events](04-events.md) - Handle widget interactions
