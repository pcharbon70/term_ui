# Advanced Widgets

TermUI includes advanced widgets for complex UI patterns including navigation, overlays, visualization, data streaming, and BEAM introspection. This guide covers these widgets and how to use them.

All advanced widgets use the StatefulComponent pattern:

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

## Navigation Widgets

### Tabs

> **Example:** See [`examples/tabs/`](../../examples/tabs/) for a complete demonstration.

Tabbed interface for organizing content into switchable panels.

```elixir
alias TermUI.Widgets.Tabs

# Create props
props = Tabs.new(
  tabs: ["Overview", "Details", "Settings"],
  on_change: fn index -> handle_tab_change(index) end
)

# Initialize and use
{:ok, tabs_state} = Tabs.init(props)
{:ok, tabs_state} = Tabs.handle_event(event, tabs_state)
Tabs.render(tabs_state, %{width: 60, height: 1})
```

**Options:**

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `tabs` | list | required | Tab labels |
| `on_change` | function | `nil` | Tab change callback |
| `style` | Style | default | Tab bar style |
| `selected_style` | Style | reverse | Selected tab style |
| `closeable` | boolean | `false` | Show close buttons |

### Context Menu

> **Example:** See [`examples/context_menu/`](../../examples/context_menu/) for a complete demonstration.

Right-click context menu that appears at cursor position.

```elixir
alias TermUI.Widgets.ContextMenu

# Create props
props = ContextMenu.new(
  items: [
    %{label: "Cut", shortcut: "Ctrl+X", action: :cut},
    %{label: "Copy", shortcut: "Ctrl+C", action: :copy},
    %{label: "Paste", shortcut: "Ctrl+V", action: :paste},
    :separator,
    %{label: "Delete", action: :delete}
  ],
  position: {10, 5},
  on_select: fn action -> handle_menu_action(action) end
)

# Initialize and use
{:ok, menu_state} = ContextMenu.init(props)
{:ok, menu_state} = ContextMenu.handle_event(event, menu_state)
ContextMenu.render(menu_state, %{width: 30, height: 10})
```

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

> **Example:** See [`examples/alert_dialog/`](../../examples/alert_dialog/) for a complete demonstration.

Modal dialog for confirmations and messages with standard button configurations.

```elixir
alias TermUI.Widgets.AlertDialog

# Create props
props = AlertDialog.new(
  type: :confirm,
  title: "Delete File",
  message: "Are you sure you want to delete this file?",
  buttons: :yes_no,
  on_result: fn result -> handle_result(result) end
)

# Initialize and use
{:ok, dialog_state} = AlertDialog.init(props)
{:ok, dialog_state} = AlertDialog.handle_event(event, dialog_state)
AlertDialog.render(dialog_state, %{width: 80, height: 24})
```

**Options:**

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `type` | atom | `:info` | `:info`, `:warning`, `:error`, `:success`, `:confirm` |
| `title` | string | `""` | Dialog title |
| `message` | string | required | Dialog message |
| `buttons` | atom/list | `:ok` | `:ok`, `:ok_cancel`, `:yes_no`, or custom list |
| `on_result` | function | `nil` | Result callback |

**Type Icons:**
- `:info` - ℹ (blue)
- `:warning` - ⚠ (yellow)
- `:error` - ✖ (red)
- `:success` - ✔ (green)
- `:confirm` - ? (cyan)

### Toast

> **Example:** See [`examples/toast/`](../../examples/toast/) for a complete demonstration.

Non-blocking notification that auto-dismisses. Use `ToastManager` to manage multiple toasts with stacking.

```elixir
alias TermUI.Widgets.ToastManager

# Create manager in your init
def init(_opts) do
  %{
    toast_manager: ToastManager.new(
      position: :bottom_right,
      default_duration: 3000,
      max_toasts: 5
    )
  }
end

# Add toasts
def update({:show_toast, type, message}, state) do
  manager = ToastManager.add_toast(state.toast_manager, message, type)
  {%{state | toast_manager: manager}, []}
end

# Update on tick (removes expired toasts)
def update(:tick, state) do
  manager = ToastManager.tick(state.toast_manager)
  {%{state | toast_manager: manager}, []}
end

# Render in view
def view(state) do
  stack(:vertical, [
    render_main_content(state),
    ToastManager.render(state.toast_manager, %{width: 80, height: 24, x: 0, y: 0})
  ])
end
```

**ToastManager Options:**

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `position` | atom | `:bottom_right` | Toast position (see below) |
| `max_toasts` | integer | 5 | Maximum simultaneous toasts |
| `default_duration` | integer | 3000 | Default duration in ms |
| `spacing` | integer | 1 | Vertical spacing between toasts |

**Positions:** `:top_left`, `:top_center`, `:top_right`, `:bottom_left`, `:bottom_center`, `:bottom_right`

**Toast Types:** `:info` (ℹ blue), `:success` (✓ green), `:warning` (⚠ yellow), `:error` (✗ red)

**ToastManager Functions:**

```elixir
# Add a toast
manager = ToastManager.add_toast(manager, "Message", :success)
manager = ToastManager.add_toast(manager, "Message", :warning, duration: 5000)

# Update (removes expired toasts)
manager = ToastManager.tick(manager)

# Get visible toast count
count = ToastManager.toast_count(manager)

# Clear all toasts
manager = ToastManager.clear_all(manager)
```

## Visualization Widgets

### Bar Chart

> **Example:** See [`examples/bar_chart/`](../../examples/bar_chart/) for a complete demonstration.

Horizontal or vertical bar chart for categorical data.

```elixir
alias TermUI.Widgets.BarChart

# Render directly (simple widget)
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

**Example Output:**
```
Sales       ████████████████ 150
Marketing   ████████ 80
Engineering █████████████████████ 200
```

### Line Chart

> **Example:** See [`examples/line_chart/`](../../examples/line_chart/) for a complete demonstration.

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
    %{data: cpu_history, style: Style.new(fg: :green)},
    %{data: mem_history, style: Style.new(fg: :yellow)}
  ],
  width: 60,
  height: 10,
  min: 0,
  max: 100
)
```

**Options:**

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `data` | list | - | Single series data |
| `series` | list | - | Multiple series with styles |
| `width` | integer | 40 | Chart width |
| `height` | integer | 8 | Chart height |
| `min` | number | auto | Y-axis minimum |
| `max` | number | auto | Y-axis maximum |

### Canvas

> **Example:** See [`examples/canvas/`](../../examples/canvas/) for a complete demonstration.

Direct drawing surface for custom visualizations.

```elixir
alias TermUI.Widgets.Canvas

# Create canvas props
props = Canvas.new(
  width: 60,
  height: 20
)

{:ok, canvas_state} = Canvas.init(props)

# Draw on canvas
canvas_state = canvas_state
  |> Canvas.draw_rect(0, 0, 59, 19)
  |> Canvas.draw_line(0, 10, 59, 10)
  |> Canvas.draw_text(25, 0, "Title", Style.new(fg: :cyan))

Canvas.render(canvas_state, %{width: 60, height: 20})
```

**Drawing Functions:**

| Function | Description |
|----------|-------------|
| `draw_text(x, y, text, style)` | Draw text at position |
| `draw_line(x1, y1, x2, y2)` | Draw line between points |
| `draw_rect(x, y, w, h, opts)` | Draw rectangle |
| `fill_rect(x, y, w, h, char)` | Fill rectangle with character |
| `clear()` | Clear canvas |

## Layout Widgets

### Viewport

> **Example:** See [`examples/viewport/`](../../examples/viewport/) for a complete demonstration.

Scrollable view of content larger than the display area. The Viewport widget clips content to a visible region and supports both keyboard and mouse scrolling.

```elixir
alias TermUI.Widgets.Viewport

# Create props
props = Viewport.new(
  content: my_large_content(),    # The content to scroll (render node)
  content_width: 200,             # Total width of content
  content_height: 100,            # Total height of content
  width: 60,                      # Viewport width
  height: 20,                     # Viewport height
  scroll_x: 0,                    # Initial horizontal scroll
  scroll_y: 0,                    # Initial vertical scroll
  scroll_bars: :both              # :none, :vertical, :horizontal, or :both
)

{:ok, viewport_state} = Viewport.init(props)
{:ok, viewport_state} = Viewport.handle_event(scroll_event, viewport_state)
Viewport.render(viewport_state, %{width: 60, height: 20})
```

**Keyboard Navigation:**
- Arrow keys: Scroll by one line/column
- Page Up/Down: Scroll by viewport height
- Home/End: Scroll to top/bottom
- Ctrl+Home/End: Scroll to top-left/bottom-right

**Mouse Support:**
- Mouse wheel: Scroll vertically
- Click on scroll bar track: Page scroll
- Drag scroll bar thumb: Direct scroll positioning

**Helper Functions:**

```elixir
# Get current scroll position
{x, y} = Viewport.get_scroll(state)

# Set scroll position (clamped to valid range)
state = Viewport.set_scroll(state, 50, 100)

# Scroll to make a position visible
state = Viewport.scroll_into_view(state, target_x, target_y)

# Update content
state = Viewport.set_content(state, new_content)

# Update content dimensions
state = Viewport.set_content_size(state, new_width, new_height)

# Check if scrollable
Viewport.can_scroll_vertical?(state)    # true/false
Viewport.can_scroll_horizontal?(state)  # true/false
```

**Complete Example:**

```elixir
defmodule MyApp do
  use TermUI.Elm
  alias TermUI.Widgets.Viewport

  def init(_opts) do
    # Create large scrollable content
    content = generate_large_content()

    props = Viewport.new(
      content: content,
      content_width: 200,
      content_height: 500,
      width: 60,
      height: 20,
      scroll_bars: :both
    )

    {:ok, viewport} = Viewport.init(props)
    %{viewport: viewport}
  end

  def event_to_msg(event, _state) do
    {:msg, {:viewport_event, event}}
  end

  def update({:viewport_event, event}, state) do
    {:ok, new_viewport} = Viewport.handle_event(event, state.viewport)
    {%{state | viewport: new_viewport}, []}
  end

  def view(state) do
    Viewport.render(state.viewport, %{width: 60, height: 20})
  end

  defp generate_large_content do
    lines = for i <- 1..500 do
      {:text, "Line #{i}: Lorem ipsum dolor sit amet, consectetur adipiscing elit"}
    end
    stack(:vertical, lines)
  end
end
```

### Split Pane

> **Example:** See [`examples/split_pane/`](../../examples/split_pane/) for a complete demonstration.

Resizable split layout for IDE-style interfaces.

```elixir
alias TermUI.Widgets.SplitPane

# Create props
props = SplitPane.new(
  direction: :horizontal,
  initial_ratio: 0.3,
  min_size: 10,
  max_size: 50,
  on_resize: fn ratio -> handle_resize(ratio) end
)

{:ok, pane_state} = SplitPane.init(props)
{:ok, pane_state} = SplitPane.handle_event(event, pane_state)
SplitPane.render(pane_state, %{width: 100, height: 30})
```

**Options:**

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `direction` | atom | `:horizontal` | `:horizontal` or `:vertical` |
| `initial_ratio` | float | 0.5 | Split ratio (0.0-1.0) |
| `min_size` | integer | 5 | Minimum pane size |
| `max_size` | integer | `nil` | Maximum pane size |
| `draggable` | boolean | `true` | Allow resize |

### Tree View

> **Example:** See [`examples/tree_view/`](../../examples/tree_view/) for a complete demonstration.

Hierarchical data with expand/collapse.

```elixir
alias TermUI.Widgets.TreeView

# Create props
props = TreeView.new(
  data: [
    %{
      id: :src,
      label: "src",
      icon: "📁",
      children: [
        %{id: :main, label: "main.ex", icon: "📄"},
        %{id: :utils, label: "utils.ex", icon: "📄"}
      ]
    },
    %{id: :readme, label: "README.md", icon: "📄"}
  ],
  on_select: fn node_id -> handle_select(node_id) end
)

{:ok, tree_state} = TreeView.init(props)
{:ok, tree_state} = TreeView.handle_event(event, tree_state)
TreeView.render(tree_state, %{width: 40, height: 20})
```

**Node Structure:**
```elixir
%{
  id: unique_id,       # Required
  label: "Node Name",
  icon: "📁",          # Optional icon
  children: [...]      # Optional child nodes
}
```

## Input Widgets

### Form Builder

> **Example:** See [`examples/form_builder/`](../../examples/form_builder/) for a complete demonstration.

Structured forms with validation and multiple field types.

```elixir
alias TermUI.Widgets.FormBuilder

# Create props
props = FormBuilder.new(
  fields: [
    %{id: :username, type: :text, label: "Username", required: true},
    %{id: :password, type: :password, label: "Password", required: true,
      validators: [&validate_password/1]},
    %{id: :role, type: :select, label: "Role",
      options: [{"admin", "Admin"}, {"user", "User"}]},
    %{id: :notifications, type: :checkbox, label: "Email notifications"},
    %{id: :theme, type: :radio, label: "Theme",
      options: [{"light", "Light"}, {"dark", "Dark"}]}
  ],
  submit_label: "Register",
  label_width: 15,
  field_width: 30
)

{:ok, form_state} = FormBuilder.init(props)

# Handle events
{:ok, form_state} = FormBuilder.handle_event(event, form_state)

# Get form values
values = FormBuilder.get_values(form_state)

# Render
FormBuilder.render(form_state, %{width: 60, height: 20})
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
  id: :field_name,
  type: :text,
  label: "Field Label",
  required: true,
  placeholder: "Enter value...",
  validators: [&custom_validator/1],
  visible_when: fn values -> values[:other_field] == true end
}
```

### Command Palette

> **Example:** See [`examples/command_palette/`](../../examples/command_palette/) for a complete demonstration.

VS Code-style command interface with fuzzy search.

```elixir
alias TermUI.Widgets.CommandPalette

# Create props
props = CommandPalette.new(
  commands: [
    %{id: :save, label: "Save File", shortcut: "Ctrl+S", category: :file},
    %{id: :open, label: "Open File", shortcut: "Ctrl+O", category: :file},
    %{id: :find, label: "Find", shortcut: "Ctrl+F", category: :edit},
    %{id: :replace, label: "Find and Replace", shortcut: "Ctrl+H", category: :edit}
  ],
  on_select: fn command_id -> execute_command(command_id) end,
  on_close: fn -> hide_palette() end,
  placeholder: "Type a command..."
)

{:ok, palette_state} = CommandPalette.init(props)
{:ok, palette_state} = CommandPalette.handle_event(event, palette_state)
CommandPalette.render(palette_state, %{width: 80, height: 24})
```

**Command Structure:**
```elixir
%{
  id: :command_id,
  label: "Command Label",
  shortcut: "Ctrl+K",      # Optional
  category: :file,         # Optional, for grouping
  description: "Details"   # Optional
}
```

## Data Streaming Widgets

### Log Viewer

> **Example:** See [`examples/log_viewer/`](../../examples/log_viewer/) for a complete demonstration.

High-performance log viewer with virtual scrolling, search, and filtering.

```elixir
alias TermUI.Widgets.LogViewer

# Create props
props = LogViewer.new(
  max_lines: 10000,
  wrap_lines: false,
  show_line_numbers: true,
  show_timestamps: true
)

{:ok, viewer_state} = LogViewer.init(props)

# Add log lines
viewer_state = LogViewer.append_line(viewer_state, %{
  timestamp: DateTime.utc_now(),
  level: :info,
  message: "Application started",
  source: "MyApp"
})

# Handle events and render
{:ok, viewer_state} = LogViewer.handle_event(event, viewer_state)
LogViewer.render(viewer_state, %{width: 100, height: 30})
```

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

> **Example:** See [`examples/stream_widget/`](../../examples/stream_widget/) for a complete demonstration.

GenStage-integrated widget for real-time data streams with backpressure.

```elixir
alias TermUI.Widgets.StreamWidget

# Create props
props = StreamWidget.new(
  buffer_size: 1000,
  rate_limit: 60,  # updates per second
  overflow: :drop_oldest
)

{:ok, stream_state} = StreamWidget.init(props)

# Push data to stream
stream_state = StreamWidget.push(stream_state, data_item)

# Handle events and render
{:ok, stream_state} = StreamWidget.handle_event(event, stream_state)
StreamWidget.render(stream_state, %{width: 80, height: 20})
```

**Options:**

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `buffer_size` | integer | 1000 | Maximum buffered items |
| `rate_limit` | integer | 60 | Max renders per second |
| `overflow` | atom | `:drop_oldest` | `:drop_oldest`, `:drop_newest` |

## BEAM Introspection Widgets

These widgets leverage Erlang's runtime introspection capabilities for live system visualization.

### Process Monitor

> **Example:** See [`examples/process_monitor/`](../../examples/process_monitor/) for a complete demonstration.

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

# Handle timer messages for auto-refresh
{:ok, monitor_state} = ProcessMonitor.handle_info(:refresh, monitor_state)

# Handle events and render
{:ok, monitor_state} = ProcessMonitor.handle_event(event, monitor_state)
ProcessMonitor.render(monitor_state, %{width: 100, height: 30})
```

**Keyboard Controls:**
- `↑/↓` - Navigate processes
- `Enter` - Toggle details panel
- `s/S` - Cycle sort field / Toggle direction
- `/` - Filter by name
- `k` - Kill process (with confirmation)
- `r` - Refresh

**Display Columns:**
- PID
- Name (registered or initial call)
- Reductions
- Memory
- Message Queue
- Status

### Supervision Tree Viewer

> **Example:** See [`examples/supervision_tree_viewer/`](../../examples/supervision_tree_viewer/) for a complete demonstration.

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

# Handle timer messages for auto-refresh
{:ok, tree_state} = SupervisionTreeViewer.handle_info(:refresh, tree_state)

# Handle events and render
{:ok, tree_state} = SupervisionTreeViewer.handle_event(event, tree_state)
SupervisionTreeViewer.render(tree_state, %{width: 80, height: 25})
```

**Keyboard Controls:**
- `↑/↓` - Navigate tree
- `Enter` - Expand/collapse node
- `e/c` - Expand/collapse all
- `i` - Inspect process state
- `r` - Restart process (with confirmation)
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

### Cluster Dashboard

> **Example:** See [`examples/cluster_dashboard/`](../../examples/cluster_dashboard/) for a complete demonstration.

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

# Handle timer messages for auto-refresh
{:ok, dashboard_state} = ClusterDashboard.handle_info(:refresh, dashboard_state)

# Handle events and render
{:ok, dashboard_state} = ClusterDashboard.handle_event(event, dashboard_state)
ClusterDashboard.render(dashboard_state, %{width: 100, height: 30})
```

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
- `r` - Refresh

**Features:**
- Network partition detection
- Node health metrics (memory, processes, schedulers)
- Connection event history

## Full Example: Using BEAM Introspection Widgets

```elixir
defmodule MyApp.SystemMonitor do
  use TermUI.Elm

  alias TermUI.Event
  alias TermUI.Widgets.ProcessMonitor
  alias TermUI.Renderer.Style

  def init(_opts) do
    props = ProcessMonitor.new(
      update_interval: 1000,
      show_system_processes: false
    )
    {:ok, monitor_state} = ProcessMonitor.init(props)

    %{
      monitor: monitor_state,
      last_refresh: DateTime.utc_now()
    }
  end

  def event_to_msg(%Event.Key{key: "q"}, _state), do: {:msg, :quit}
  def event_to_msg(%Event.Key{key: "r"}, _state), do: {:msg, :refresh}
  def event_to_msg(event, _state), do: {:msg, {:monitor_event, event}}

  def update(:quit, state), do: {state, [:quit]}

  def update(:refresh, state) do
    {:ok, monitor} = ProcessMonitor.handle_info(:refresh, state.monitor)
    {%{state | monitor: monitor, last_refresh: DateTime.utc_now()}, []}
  end

  def update({:monitor_event, event}, state) do
    {:ok, monitor} = ProcessMonitor.handle_event(event, state.monitor)
    {%{state | monitor: monitor}, []}
  end

  # Auto-refresh timer
  def handle_info(:tick, state) do
    {:ok, monitor} = ProcessMonitor.handle_info(:refresh, state.monitor)
    {%{state | monitor: monitor, last_refresh: DateTime.utc_now()},
     [Command.timer(1000, :tick)]}
  end

  def view(state) do
    stack(:vertical, [
      text("System Monitor", Style.new(fg: :cyan, attrs: [:bold])),
      text("Last refresh: #{state.last_refresh}", Style.new(fg: :bright_black)),
      text(""),
      ProcessMonitor.render(state.monitor, %{width: 100, height: 25}),
      text(""),
      text("[R] Refresh  [Q] Quit", Style.new(fg: :bright_black))
    ])
  end
end
```

## Next Steps

- [Widgets](07-widgets.md) - Basic widgets guide
- [Styling](05-styling.md) - Customize widget appearance
- [Layout](06-layout.md) - Position widgets
- [Events](04-events.md) - Handle widget interactions
