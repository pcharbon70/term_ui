# Advanced Widgets

TermUI includes advanced widgets for complex UI patterns including navigation, overlays, visualization, data streaming, and BEAM introspection. This guide covers these widgets and how to use them.

Most interactive advanced widgets use the StatefulComponent pattern. The
`BarChart` and `LineChart` visualization widgets are stateless and render
directly from keyword options.

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

The Elm runtime does not invoke a widget's `mount/1` callback. For widgets with
refresh intervals, schedule a root `TermUI.Command.interval/2` and call the
widget's public `refresh/1` function from `update/2`.

## Navigation Widgets

### Tabs

> **Example:** [`examples/tabs/`](https://github.com/pcharbon70/term_ui/tree/main/examples/tabs/)
> demonstrates the interaction manually; the widget API below is canonical.

Tabbed interface for organizing content into switchable panels.

```elixir
alias TermUI.Widgets.Tabs

# Create props
props = Tabs.new(
  tabs: [
    %{id: :overview, label: "Overview", content: overview_view()},
    %{id: :details, label: "Details", content: details_view()},
    %{id: :settings, label: "Settings", content: settings_view()}
  ],
  on_change: fn tab_id -> handle_tab_change(tab_id) end
)

# Initialize and use
{:ok, tabs_state} = Tabs.init(props)
{:ok, tabs_state} = Tabs.handle_event(event, tabs_state)
Tabs.render(tabs_state, %{width: 60, height: 1})
```

**Options:**

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `tabs` | list | required | Maps containing at least `:id` and `:label` |
| `selected` | term | first enabled tab | Initially selected tab ID |
| `on_change` | function | `nil` | Tab change callback |
| `on_close` | function | `nil` | Callback for closing a closeable tab |
| `tab_style` | Style | theme default | Inactive tab style |
| `selected_style` | Style | theme default | Selected tab style |
| `disabled_style` | Style | theme default | Disabled tab style |

`content`, `disabled`, and `closeable` are per-tab fields, not options to
`Tabs.new/1`.

### Context Menu

> **Example:** See [`examples/context_menu/`](https://github.com/pcharbon70/term_ui/tree/main/examples/context_menu/) for a complete demonstration.

Right-click context menu that appears at cursor position.

```elixir
alias TermUI.Widgets.ContextMenu

# Create props
props = ContextMenu.new(
  items: [
    ContextMenu.action(:cut, "Cut", shortcut: "Ctrl+X"),
    ContextMenu.action(:copy, "Copy", shortcut: "Ctrl+C"),
    ContextMenu.action(:paste, "Paste", shortcut: "Ctrl+V"),
    ContextMenu.separator(),
    ContextMenu.action(:delete, "Delete")
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
  type: :action,
  id: :cut,             # Identifier passed to on_select
  label: "Menu Item",    # Display text
  shortcut: "Ctrl+X",    # Optional shortcut hint
  disabled: false        # Optional disabled state
}
```

## Overlay Widgets

### Alert Dialog

> **Example:** See [`examples/alert_dialog/`](https://github.com/pcharbon70/term_ui/tree/main/examples/alert_dialog/) for a complete demonstration.

Modal dialog for confirmations and messages with standard button configurations.

```elixir
alias TermUI.Widgets.AlertDialog
alias TermUI.Renderer.Style

# Create props
props = AlertDialog.new(
  type: :confirm,
  title: "Delete File",
  message: "Are you sure you want to delete this file?",
  on_result: fn result -> handle_result(result) end
)

# With custom styling
props = AlertDialog.new(
  type: :error,
  title: "Error",
  message: "Something went wrong",
  background_style: Style.new(bg: :bright_black),
  border_style: Style.new(fg: :red, attrs: [:bold]),
  message_style: Style.new(fg: :white),
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
| `type` | atom | required | `:info`, `:success`, `:warning`, `:error`, `:confirm`, `:ok_cancel` |
| `title` | string | required | Dialog title |
| `message` | string | required | Dialog message |
| `on_result` | function | `nil` | Callback with result (`:ok`, `:cancel`, `:yes`, `:no`) |
| `width` | integer | `50` | Dialog width |
| `background_style` | `Style.t()` | `Style.new(bg: :black)` | Dialog background style |
| `border_style` | `Style.t()` | `Style.new(fg: :cyan)` | Border and title style |
| `icon_style` | `Style.t()` | `nil` | Style for the icon |
| `message_style` | `Style.t()` | `nil` | Style for the message |
| `button_style` | `Style.t()` | `nil` | Style for buttons |
| `focused_button_style` | `Style.t()` | `nil` | Style for focused button |

**Representative Unicode type icons:**
- `:info` - ℹ (information)
- `:warning` - ⚠ (warning)
- `:error` - ✖ (error)
- `:success` - ✔ (success)
- `:confirm` - ? (confirmation)
- `:ok_cancel` - ? (OK/Cancel)

**Keyboard Navigation:**
- `Tab` / `Shift+Tab` - Move between buttons
- `Enter` / `Space` - Activate focused button
- `Escape` - Close (same as Cancel/No)
- `Y` / `N` - Yes/No (in confirm dialogs)

### Toast

> **Example:** See [`examples/toast/`](https://github.com/pcharbon70/term_ui/tree/main/examples/toast/) for a complete demonstration.

Non-blocking notification with tick-driven expiration. Use `ToastManager` to
manage multiple toasts with stacking, schedule a root interval, and call
`ToastManager.tick/1` when it fires.

```elixir
alias TermUI.Widgets.ToastManager

# Create manager in your init
def init(_opts) do
  state = %{
    toast_manager: ToastManager.new(
      position: :bottom_right,
      default_duration: 3000,
      max_toasts: 5
    )
  }

  {state, [TermUI.Command.interval(100, :tick)]}
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

> **Example:** See [`examples/bar_chart/`](https://github.com/pcharbon70/term_ui/tree/main/examples/bar_chart/) for a complete demonstration.

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

> **Example:** See [`examples/line_chart/`](https://github.com/pcharbon70/term_ui/tree/main/examples/line_chart/) for a complete demonstration.

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
    %{data: cpu_history},
    %{data: mem_history}
  ],
  width: 60,
  height: 10,
  min: 0,
  max: 100,
  style: Style.new(fg: :green)
)
```

**Options:**

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `data` | list | - | Single series data |
| `series` | list | - | Multiple `%{data: [...]}` series overlaid on one canvas |
| `width` | integer | 40 | Chart width |
| `height` | integer | 10 | Chart height |
| `min` | number | auto | Y-axis minimum |
| `max` | number | auto | Y-axis maximum |
| `show_axis` | boolean | `false` | Draw the bottom axis |
| `style` | Style | `nil` | Style applied to the complete chart |

Multiple series share one Braille canvas. The 1.0 renderer applies one global
`:style`; it does not render each series in a separate color.

### Canvas

> **Example:** See [`examples/canvas/`](https://github.com/pcharbon70/term_ui/tree/main/examples/canvas/) for a complete demonstration.

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
  |> Canvas.draw_text(25, 0, "Title")

Canvas.render(canvas_state, %{width: 60, height: 20})
```

**Drawing Functions:**

| Function | Description |
|----------|-------------|
| `draw_text(state, x, y, text)` | Draw text at position |
| `draw_line(state, x1, y1, x2, y2, char \\ nil)` | Draw a line between points |
| `draw_rect(state, x, y, w, h, border \\ %{})` | Draw a rectangle |
| `fill_rect(state, x, y, w, h, char)` | Fill a rectangle with a character |
| `clear(state)` | Clear the canvas |

## Layout Widgets

### Markdown Viewer

> **Example:** See [`examples/markdown_viewer/`](https://github.com/pcharbon70/term_ui/tree/main/examples/markdown_viewer/) for a complete demonstration.

Scrollable markdown viewer with syntax highlighting for code blocks.

```elixir
alias TermUI.Widgets.MarkdownViewer

# Create props
props = MarkdownViewer.new(
  content: "# Hello World\n\nThis is **bold** and `code`.\n\n```elixir\ndef hello do\n  :world\nend\n```",
  width: 80,
  height: 24,
  on_copy: fn code -> IO.puts("Copied: #{code}") end
)

# Initialize
{:ok, viewer_state} = MarkdownViewer.init(props)

# Handle events and render
{:ok, viewer_state} = MarkdownViewer.handle_event(event, viewer_state)
MarkdownViewer.render(viewer_state, %{width: 80, height: 24})

# Update embedded content through the normal props update callback
new_props = MarkdownViewer.new(content: "# New content", width: 80, height: 24)
{:ok, viewer_state} = MarkdownViewer.update(new_props, viewer_state)
```

**Features:**
- CommonMark parsing through MDEx with the rendered subset listed below
- Syntax highlighting for Elixir and Erlang code blocks
- Scrollable viewport with keyboard navigation
- Focusable code blocks with copy functionality

**Keyboard Controls:**
- `↑/↓` - Scroll by line
- `Page Up/Page Down` - Scroll by page
- `Home/End` - Jump to top/bottom
- `Tab` - Cycle focus through code blocks
- `Shift+Tab` - Reverse cycle through code blocks
- `Enter` / `c` - Invoke `on_copy` for the focused code block
- Mouse wheel - Scroll

**Supported Markdown:**
- Headings (`#`, `##`, etc.)
- Bold (`**text**`), italic (`*text*`)
- Code (`` `inline` ``) and code blocks (fenced with ` ``` `)
- Lists (ordered and unordered)
- Blockquotes (`>`)
- Links (displayed with their URL) and image alt text

**Options:**

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `content` | string | `""` | Markdown content to display |
| `width` | integer | 80 | Display width |
| `height` | integer | 24 | Display height |
| `on_copy` | function | `nil` | Callback when code block copied |

**Helper Functions:**

```elixir
# Update content in an embedded widget
props = MarkdownViewer.new(content: "# Updated content", width: 80, height: 24)
{:ok, state} = MarkdownViewer.update(props, state)
```

### Viewport

> **Example:** See [`examples/viewport/`](https://github.com/pcharbon70/term_ui/tree/main/examples/viewport/) for a complete demonstration.

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

> **Example:** See [`examples/split_pane/`](https://github.com/pcharbon70/term_ui/tree/main/examples/split_pane/) for a complete demonstration.

Resizable split layout for IDE-style interfaces.

```elixir
alias TermUI.Widgets.SplitPane

# Create props
props = SplitPane.new(
  orientation: :horizontal,
  panes: [
    SplitPane.pane(:sidebar, sidebar_view(), size: 0.3, min_size: 10),
    SplitPane.pane(:main, main_view(), size: 0.7, max_size: 80)
  ],
  on_resize: fn panes -> handle_resize(panes) end
)

{:ok, pane_state} = SplitPane.init(props)
{:ok, pane_state} = SplitPane.handle_event(event, pane_state)
SplitPane.render(pane_state, %{width: 100, height: 30})
```

**Options:**

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `orientation` | atom | `:horizontal` | `:horizontal` or `:vertical` |
| `panes` | list | required | Pane maps, normally built with `pane/3` |
| `divider_size` | integer | `1` | Divider thickness |
| `resizable` | boolean | `true` | Allow keyboard/mouse resizing |
| `on_resize` | function | `nil` | Callback receiving updated panes |
| `on_collapse` | function | `nil` | Callback receiving `{id, collapsed}` |
| `persist_key` | term | `nil` | Reserved application metadata; no automatic persistence in 1.0 |

Pane-level `:size`, `:min_size`, `:max_size`, and `:collapsed` values belong to
`SplitPane.pane/3`. Applications can save `SplitPane.get_layout/1` and later
restore it with `SplitPane.set_layout/2`; `persist_key` alone does not do this.

### Tree View

> **Example:** See [`examples/tree_view/`](https://github.com/pcharbon70/term_ui/tree/main/examples/tree_view/) for a complete demonstration.

Hierarchical data with expand/collapse.

```elixir
alias TermUI.Widgets.TreeView

# Create props
props = TreeView.new(
  nodes: [
    TreeView.branch(:src, "src", [
      TreeView.leaf(:main, "main.ex"),
      TreeView.leaf(:utils, "utils.ex")
    ]),
    TreeView.leaf(:readme, "README.md")
  ],
  on_select: fn node -> handle_select(node) end
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

> **Example:** See [`examples/form_builder/`](https://github.com/pcharbon70/term_ui/tree/main/examples/form_builder/) for a complete demonstration.

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

> **Example:** See [`examples/command_palette/`](https://github.com/pcharbon70/term_ui/tree/main/examples/command_palette/) for a complete demonstration.

Searchable command interface with case-insensitive substring filtering.

```elixir
alias TermUI.Widgets.CommandPalette

# Create props
props = CommandPalette.new(
  commands: [
    %{id: :save, label: "/save", action: fn -> save_file() end},
    %{id: :open, label: "/open", action: fn -> open_file() end},
    %{id: :find, label: "/find", action: fn -> find_text() end}
  ],
  max_visible: 8
)

{:ok, palette_state} = CommandPalette.init(props)
{:ok, palette_state} = CommandPalette.handle_event(event, palette_state)
CommandPalette.render(palette_state, %{width: 80, height: 24})
```

Typing filters by case-insensitive label substring. Enter stores the selected label as the query
and hides the palette; it does not invoke `:action` itself. Read the selection
with `CommandPalette.get_selected/1` before forwarding Enter, or interpret the
resulting query in the root, as the example does.

**Command Structure:**
```elixir
%{
  id: :command_id,
  label: "Command Label",
  action: fn -> :ok end     # Application-owned metadata; widget does not call it
}
```

## Data Streaming Widgets

### Log Viewer

> **Example:** See [`examples/log_viewer/`](https://github.com/pcharbon70/term_ui/tree/main/examples/log_viewer/) for a complete demonstration.

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
viewer_state = LogViewer.add_line(viewer_state, %{
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

> **Example:** See [`examples/stream_widget/`](https://github.com/pcharbon70/term_ui/tree/main/examples/stream_widget/) for a complete demonstration.

Bounded stream display with an optional GenStage consumer adapter.

```elixir
alias TermUI.Widgets.StreamWidget

# Create props
props = StreamWidget.new(
  buffer_size: 1000,
  render_rate_ms: 100,
  overflow_strategy: :drop_oldest,
  demand: 10
)

{:ok, stream_state} = StreamWidget.init(props)

# Push data to stream
{:ok, stream_state} = StreamWidget.add_item(stream_state, data_item)

# Handle events and render
{:ok, stream_state} = StreamWidget.handle_event(event, stream_state)
StreamWidget.render(stream_state, %{width: 80, height: 20})
```

**Options:**

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `buffer_size` | integer | 1000 | Maximum buffered items |
| `overflow_strategy` | atom | `:drop_oldest` | `:drop_oldest`, `:drop_newest`, `:block`, or `:sliding`; `:block` rejects new items when full in 1.0 |
| `demand` | integer | `10` | Reserved metadata; configure subscription demand on the consumer |
| `show_stats` | boolean | `true` | Show the statistics row |
| `render_rate_ms` | integer | `100` | Reserved metadata; it does not throttle runtime rendering in 1.0 |
| `item_renderer` | function | built in | Converts an item to display text |
| `on_item` | function | `nil` | Synchronous item callback |
| `on_error` | function | `nil` | Synchronous stream-error callback |

`StreamWidget.Consumer` forwards `{:stream_items, items}` to the PID it is
given. For an embedded widget, pass the runtime/root PID and delegate that
message from the root's optional `handle_info/2` to `StreamWidget.handle_info/2`.
Set `max_demand`/`min_demand` on `Consumer.subscribe/3`; widget buffer occupancy
does not dynamically reconfigure GenStage demand.

## BEAM Introspection Widgets

These widgets leverage Erlang's runtime introspection capabilities for live system visualization.

### Process Monitor

> **Example:** See [`examples/process_monitor/`](https://github.com/pcharbon70/term_ui/tree/main/examples/process_monitor/) for a complete demonstration.

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

# Refresh when the root receives its scheduled message
{:ok, monitor_state} = ProcessMonitor.refresh(monitor_state)

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

> **Example:** See [`examples/supervision_tree_viewer/`](https://github.com/pcharbon70/term_ui/tree/main/examples/supervision_tree_viewer/) for a complete demonstration.

Visualize supervision hierarchies with live status.

```elixir
alias TermUI.Widgets.SupervisionTreeViewer

props = SupervisionTreeViewer.new(
  root: MyApp.Supervisor,
  update_interval: 2000,
  show_workers: true,
  auto_expand: false
)

{:ok, tree_state} = SupervisionTreeViewer.init(props)

# Refresh when the root receives its scheduled message
{:ok, tree_state} = SupervisionTreeViewer.refresh(tree_state)

# Handle events and render
{:ok, tree_state} = SupervisionTreeViewer.handle_event(event, tree_state)
SupervisionTreeViewer.render(tree_state, %{width: 80, height: 25})
```

**Keyboard Controls:**
- `↑/↓` - Navigate tree
- `Left/Right` - Collapse/expand or move through the hierarchy
- `Enter` - Expand/collapse a supervisor or toggle worker details
- `i` - Inspect process state
- `r` - Restart process (with confirmation)
- `R` - Refresh immediately
- `k` - Terminate process (with confirmation)
- `/` - Filter tree
- `Escape` - Clear filter

**Status Indicators:**
- `o [R]` - Running
- `~ [Y]` - Restarting
- `x [T]` - Terminated
- `? [U]` - Undefined

**Strategy Display:**
- `1:1` - one_for_one
- `1:*` - one_for_all
- `1:→` - rest_for_one

### Cluster Dashboard

> **Example:** See [`examples/cluster_dashboard/`](https://github.com/pcharbon70/term_ui/tree/main/examples/cluster_dashboard/) for a complete demonstration.

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

# Refresh when the root receives its scheduled message
{:ok, dashboard_state} = ClusterDashboard.refresh(dashboard_state)

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

    state = %{
      monitor: monitor_state,
      last_refresh: DateTime.utc_now()
    }

    {state, [TermUI.Command.interval(1000, :tick)]}
  end

  def event_to_msg(%Event.Key{key: "q"}, _state), do: {:msg, :quit}
  def event_to_msg(%Event.Key{key: "r"}, _state), do: {:msg, :refresh}
  def event_to_msg(event, _state), do: {:msg, {:monitor_event, event}}

  def update(:quit, state), do: {state, [TermUI.Command.quit()]}

  def update(:refresh, state) do
    {:ok, monitor} = ProcessMonitor.refresh(state.monitor)
    {%{state | monitor: monitor, last_refresh: DateTime.utc_now()}, []}
  end

  def update(:tick, state) do
    {:ok, monitor} = ProcessMonitor.refresh(state.monitor)
    {%{state | monitor: monitor, last_refresh: DateTime.utc_now()}, []}
  end

  def update({:monitor_event, event}, state) do
    {:ok, monitor} = ProcessMonitor.handle_event(event, state.monitor)
    {%{state | monitor: monitor}, []}
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
