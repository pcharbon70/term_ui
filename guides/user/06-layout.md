# Layout

TermUI provides a declarative layout system for positioning and sizing components.

## Basic Layout

### Vertical Stacking

Stack elements from top to bottom:

```elixir
stack(:vertical, [
  text("Header"),
  text("Body"),
  text("Footer")
])
```

Output:
```
Header
Body
Footer
```

### Horizontal Stacking

Stack elements from left to right:

```elixir
stack(:horizontal, [
  text("Left"),
  text(" | "),
  text("Right")
])
```

Output:
```
Left | Right
```

### Nested Layouts

Combine stacks for complex layouts:

```elixir
stack(:vertical, [
  text("=== Header ==="),
  stack(:horizontal, [
    text("[Sidebar]"),
    text("  "),
    text("[Main Content]")
  ]),
  text("=== Footer ===")
])
```

Output:
```
=== Header ===
[Sidebar]  [Main Content]
=== Footer ===
```

## Constraints

Control how space is allocated using constraints.

### Fixed Size

Exact number of cells:

```elixir
alias TermUI.Layout.Constraint

stack(:horizontal, [
  {text("Fixed"), Constraint.length(10)},
  {text("Rest"), Constraint.fill()}
])
```

### Percentage

Proportion of available space:

```elixir
stack(:horizontal, [
  {left_panel, Constraint.percentage(30)},
  {right_panel, Constraint.percentage(70)}
])
```

### Fill

Take all remaining space:

```elixir
stack(:horizontal, [
  {sidebar, Constraint.length(20)},    # Fixed 20 columns
  {content, Constraint.fill()}          # Rest of the space
])
```

### Ratio

Proportional distribution:

```elixir
stack(:horizontal, [
  {panel_a, Constraint.ratio(1)},   # 1 part
  {panel_b, Constraint.ratio(2)},   # 2 parts
  {panel_c, Constraint.ratio(1)}    # 1 part
])
# Results in 25%, 50%, 25% distribution
```

### Min and Max

Set bounds on size:

```elixir
# At least 10, at most 50
Constraint.percentage(30)
  |> Constraint.with_min(10)
  |> Constraint.with_max(50)
```

## Common Layout Patterns

### Header-Body-Footer

```elixir
def view(state) do
  stack(:vertical, [
    {render_header(state), Constraint.length(3)},
    {render_body(state), Constraint.fill()},
    {render_footer(state), Constraint.length(1)}
  ])
end

defp render_header(state) do
  text("=== My Application ===", Style.new(fg: :cyan, attrs: [:bold]))
end

defp render_body(state) do
  stack(:vertical, [
    text("Main content here"),
    text("..."),
  ])
end

defp render_footer(state) do
  text("[Q]uit  [H]elp", Style.new(fg: :bright_black))
end
```

### Sidebar Layout

```elixir
def view(state) do
  stack(:horizontal, [
    {render_sidebar(state), Constraint.length(25)},
    {render_main(state), Constraint.fill()}
  ])
end

defp render_sidebar(state) do
  stack(:vertical, [
    text("Navigation", Style.new(attrs: [:bold])),
    text(""),
    text("• Dashboard"),
    text("• Settings"),
    text("• Help")
  ])
end

defp render_main(state) do
  text("Main content area")
end
```

### Two-Column Layout

```elixir
def view(state) do
  stack(:horizontal, [
    {left_column(state), Constraint.percentage(50)},
    {right_column(state), Constraint.percentage(50)}
  ])
end
```

### Dashboard Grid

```elixir
def view(state) do
  stack(:vertical, [
    # Top row - three equal panels
    {stack(:horizontal, [
      {cpu_gauge(state), Constraint.ratio(1)},
      {memory_gauge(state), Constraint.ratio(1)},
      {disk_gauge(state), Constraint.ratio(1)}
    ]), Constraint.length(5)},

    # Bottom row - two panels
    {stack(:horizontal, [
      {process_list(state), Constraint.percentage(60)},
      {network_stats(state), Constraint.percentage(40)}
    ]), Constraint.fill()}
  ])
end
```

### Centered Content

```elixir
def view(state) do
  # Horizontal centering with fill on both sides
  stack(:horizontal, [
    {text(""), Constraint.fill()},
    {render_dialog(state), Constraint.length(40)},
    {text(""), Constraint.fill()}
  ])
end
```

## Rectangle Alignment

`TermUI.Layout.Alignment` is a lower-level helper for repositioning rectangles
after constraints have been solved. It is not an option accepted by the
`text/2` render helper.

```elixir
alias TermUI.Layout.{Alignment, Constraint, Solver}

area = %{x: 0, y: 0, width: 80, height: 10}
constraints = [Constraint.length(10), Constraint.length(20)]
rects = Solver.solve_to_rects(constraints, area, :horizontal)

Alignment.apply(rects, area,
  direction: :horizontal,
  justify: :center,
  align: :start
)
```

For aligned text inside a fixed width, pad the string yourself with
`String.pad_leading/2` or `String.pad_trailing/2`, or use a widget that exposes
alignment explicitly, such as `TermUI.Widgets.Table.Column`.

## Box Drawing

Create bordered containers:

```elixir
alias TermUI.CharacterSet

def render_box(title, content) do
  chars = CharacterSet.current_charset()

  stack(:vertical, [
    text(chars.top_left <> chars.horizontal <> " #{title} " <>
      String.duplicate(chars.horizontal, 20) <> chars.top_right),
    stack(:horizontal, [
      text(chars.vertical <> " "),
      content,
      text(" " <> chars.vertical)
    ]),
    text(chars.bottom_left <> String.duplicate(chars.horizontal, 24) <>
      chars.bottom_right)
  ])
end
```

## Responsive Layouts

Adapt layout based on terminal size:

```elixir
def view(%{width: width} = state) when width < 80 do
  # Narrow layout - vertical stacking
  stack(:vertical, [
    render_sidebar(state),
    render_main(state)
  ])
end

def view(state) do
  # Wide layout - horizontal stacking
  stack(:horizontal, [
    {render_sidebar(state), Constraint.length(25)},
    {render_main(state), Constraint.fill()}
  ])
end
```

Handle resize events:

```elixir
def event_to_msg(%Event.Resize{width: w, height: h}, _state) do
  {:msg, {:resize, w, h}}
end

def update({:resize, width, height}, state) do
  {%{state | width: width, height: height}, []}
end
```

## Empty Space

Add spacing between elements:

```elixir
# Empty line
text("")

# Multiple empty lines
stack(:vertical, [
  text("First"),
  text(""),
  text(""),
  text("Second")
])

# Horizontal space
stack(:horizontal, [
  text("Label:"),
  text("   "),  # 3 spaces
  text("Value")
])
```

## Conditional Rendering

Show/hide elements based on state:

```elixir
def view(state) do
  stack(:vertical, [
    text("Header"),
    if state.show_details do
      render_details(state)
    else
      text("")
    end,
    text("Footer")
  ])
end
```

Or use list filtering:

```elixir
def view(state) do
  elements = [
    text("Header"),
    state.show_details && render_details(state),
    text("Footer")
  ]

  stack(:vertical, Enum.filter(elements, & &1))
end
```

## Performance Tips

### 1. Avoid Deep Nesting

Flatten layouts where possible:

```elixir
# Less efficient
stack(:vertical, [
  stack(:vertical, [
    stack(:vertical, [
      text("Deeply nested")
    ])
  ])
])

# More efficient
stack(:vertical, [
  text("Flat")
])
```

### 2. Use Constraints Sparingly

Only specify constraints when needed:

```elixir
# Simple case - no constraints needed
stack(:vertical, [
  text("Line 1"),
  text("Line 2")
])

# Complex case - constraints needed
stack(:horizontal, [
  {sidebar, Constraint.length(20)},
  {content, Constraint.fill()}
])
```

### 3. Reuse Static Nodes

For layouts that don't change often:

```elixir
def view(state) do
  stack(:vertical, [
    render_static_header(),
    render_dynamic_content(state)
  ])
end

# A module attribute constructs this immutable node at compile time.
@header text("My Application", Style.new(fg: :cyan))
defp render_static_header, do: @header
```

The runtime does not automatically memoize individual view functions. It
avoids the entire render pass while the root is not dirty; explicit
`TermUI.ViewCache` use is available for lower-level integrations.

## Next Steps

- [Widgets](07-widgets.md) - Pre-built layout-aware components
- [Styling](05-styling.md) - Visual styling
- [Events](04-events.md) - Handle resize events
