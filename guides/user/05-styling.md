# Styling

TermUI provides a comprehensive styling system for colors, text attributes, and themes.

## Style Basics

Create styles using `Style.new/1`:

```elixir
alias TermUI.Renderer.Style

# Basic style
style = Style.new(fg: :cyan, bg: :black)

# With attributes
style = Style.new(fg: :red, attrs: [:bold, :underline])

# Apply to text
text("Hello, World!", style)
```

## Colors

### Named Colors (16 colors)

Standard terminal colors supported everywhere:

| Color | Normal | Bright |
|-------|--------|--------|
| Black | `:black` | `:bright_black` |
| Red | `:red` | `:bright_red` |
| Green | `:green` | `:bright_green` |
| Yellow | `:yellow` | `:bright_yellow` |
| Blue | `:blue` | `:bright_blue` |
| Magenta | `:magenta` | `:bright_magenta` |
| Cyan | `:cyan` | `:bright_cyan` |
| White | `:white` | `:bright_white` |

```elixir
Style.new(fg: :cyan)
Style.new(fg: :bright_yellow, bg: :blue)
```

### 256-Color Palette

Extended palette for more color options:

```elixir
# Color index 0-255
Style.new(fg: 196)       # Bright red
Style.new(bg: 236)       # Dark gray
```

Color ranges:
- 0-15: Standard colors (same as named)
- 16-231: 6×6×6 color cube
- 232-255: Grayscale ramp

### True Color (24-bit RGB)

Full RGB support on modern terminals:

```elixir
Style.new(fg: {255, 128, 0})     # Orange
Style.new(bg: {30, 30, 30})      # Dark gray
```

### Default Color

Use terminal's default foreground/background:

```elixir
Style.new(fg: :default)
Style.new(bg: :default)
```

## Text Attributes

Modify text appearance:

| Attribute | Effect |
|-----------|--------|
| `:bold` | Bold/bright text |
| `:dim` | Dimmed/faint text |
| `:italic` | Italic text |
| `:underline` | Underlined text |
| `:blink` | Blinking text |
| `:reverse` | Swap foreground/background |
| `:hidden` | Hidden text |
| `:strikethrough` | Strikethrough text |

```elixir
Style.new(attrs: [:bold])
Style.new(attrs: [:bold, :underline])
Style.new(fg: :red, attrs: [:bold, :italic])
```

**Note:** Not all terminals support all attributes. `bold`, `underline`, and `reverse` have the widest support.

## Fluent API

Build styles with method chaining:

```elixir
style = Style.new()
  |> Style.fg(:blue)
  |> Style.bg(:white)
  |> Style.bold()
  |> Style.underline()
```

Available methods:
- `Style.fg(style, color)` - Set foreground
- `Style.bg(style, color)` - Set background
- `Style.bold(style)` - Add bold
- `Style.dim(style)` - Add dim
- `Style.italic(style)` - Add italic
- `Style.underline(style)` - Add underline
- `Style.blink(style)` - Add blink
- `Style.reverse(style)` - Add reverse
- `Style.hidden(style)` - Add hidden
- `Style.strikethrough(style)` - Add strikethrough

## Style Merging

Combine styles with later values overriding earlier:

```elixir
base = Style.new(fg: :white, bg: :black)
highlight = Style.new(fg: :yellow, attrs: [:bold])

merged = Style.merge(base, highlight)
# Result: fg: :yellow, bg: :black, attrs: [:bold]
```

## Using Styles in Views

### Styled Text

```elixir
def view(state) do
  title_style = Style.new(fg: :cyan, attrs: [:bold])
  body_style = Style.new(fg: :white)

  stack(:vertical, [
    text("My Application", title_style),
    text(""),
    text("Welcome!", body_style)
  ])
end
```

### Conditional Styling

```elixir
def view(state) do
  status_style = case state.status do
    :ok -> Style.new(fg: :green)
    :warning -> Style.new(fg: :yellow)
    :error -> Style.new(fg: :red, attrs: [:bold])
  end

  text("Status: #{state.status}", status_style)
end
```

### Style Variables

Define reusable styles:

```elixir
defmodule MyApp.Styles do
  alias TermUI.Renderer.Style

  def header, do: Style.new(fg: :cyan, attrs: [:bold])
  def label, do: Style.new(fg: :bright_black)
  def value, do: Style.new(fg: :white)
  def error, do: Style.new(fg: :red, attrs: [:bold])
  def success, do: Style.new(fg: :green)
  def selected, do: Style.new(fg: :black, bg: :cyan)
end
```

Usage:

```elixir
alias MyApp.Styles

def view(state) do
  stack(:vertical, [
    text("Dashboard", Styles.header()),
    text("CPU:", Styles.label()),
    text("#{state.cpu}%", Styles.value())
  ])
end
```

## Themes

Create theme maps for consistent styling:

```elixir
defmodule MyApp.Theme do
  alias TermUI.Renderer.Style

  def dark do
    %{
      header: Style.new(fg: :cyan, attrs: [:bold]),
      border: Style.new(fg: :cyan),
      text: Style.new(fg: :white),
      muted: Style.new(fg: :bright_black),
      selected: Style.new(fg: :black, bg: :cyan),
      error: Style.new(fg: :red),
      success: Style.new(fg: :green)
    }
  end

  def light do
    %{
      header: Style.new(fg: :blue, attrs: [:bold]),
      border: Style.new(fg: :blue),
      text: Style.new(fg: :black),
      muted: Style.new(fg: :bright_black),
      selected: Style.new(fg: :white, bg: :blue),
      error: Style.new(fg: :red),
      success: Style.new(fg: :green)
    }
  end
end
```

Usage with theme switching:

```elixir
def init(_opts) do
  %{theme: :dark}
end

def event_to_msg(%Event.Key{key: "t"}, _state), do: {:msg, :toggle_theme}

def update(:toggle_theme, state) do
  new_theme = if state.theme == :dark, do: :light, else: :dark
  {%{state | theme: new_theme}, []}
end

def view(state) do
  theme = case state.theme do
    :dark -> MyApp.Theme.dark()
    :light -> MyApp.Theme.light()
  end

  stack(:vertical, [
    text("My App", theme.header),
    text("Press T to toggle theme", theme.muted)
  ])
end
```

## Widget Styling

Widgets accept styles in their options:

```elixir
alias TermUI.Widgets.Gauge

Gauge.render(
  value: 75,
  width: 20,
  style: Style.new(fg: :green)
)
```

### Color Zones

Some widgets support color zones based on value:

```elixir
Gauge.render(
  value: cpu_percent,
  width: 20,
  zones: [
    {0, Style.new(fg: :green)},    # 0-59%: green
    {60, Style.new(fg: :yellow)},  # 60-79%: yellow
    {80, Style.new(fg: :red)}      # 80-100%: red
  ]
)
```

## Best Practices

### 1. Use Semantic Names

```elixir
# Good - semantic meaning
error_style = Style.new(fg: :red)
success_style = Style.new(fg: :green)

# Avoid - color-focused
red_style = Style.new(fg: :red)
```

### 2. Consider Accessibility

- Ensure sufficient contrast between foreground and background
- Don't rely solely on color to convey information
- Use bold/underline for emphasis in addition to color

### 3. Support Light and Dark

Design themes that work on both light and dark terminal backgrounds:

```elixir
# Works on dark background
Style.new(fg: :white)

# Works on light background
Style.new(fg: :black)

# Works on both (terminal default)
Style.new(fg: :cyan)  # Typically visible on both
```

### 4. Minimize Style Changes

The renderer optimizes style changes, but fewer changes means better performance:

```elixir
# Good - one style for the whole line
text("Label: Value", Style.new(fg: :white))

# Less efficient - multiple style changes
stack(:horizontal, [
  text("Label: ", Style.new(fg: :bright_black)),
  text("Value", Style.new(fg: :white))
])
```

## Next Steps

- [Layout](06-layout.md) - Positioning and sizing
- [Widgets](07-widgets.md) - Pre-built styled components
- [Terminal](08-terminal.md) - Terminal capabilities
