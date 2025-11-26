# Testing Framework

This guide covers TermUI's testing framework for component and widget testing.

## Overview

TermUI provides a comprehensive testing framework in `TermUI.Test.*` with four key modules:

| Module | Purpose |
|--------|---------|
| `ComponentHarness` | Mount and test components in isolation |
| `TestRenderer` | Capture rendered output for inspection |
| `EventSimulator` | Create synthetic events for testing |
| `Assertions` | TUI-specific test assertions |

## Quick Start

```elixir
defmodule MyWidgetTest do
  use ExUnit.Case, async: true
  use TermUI.Test.Assertions

  alias TermUI.Test.{ComponentHarness, EventSimulator, TestRenderer}

  test "widget renders and responds to events" do
    # Mount component
    {:ok, harness} = ComponentHarness.mount_test(MyWidget, initial_value: 0)

    # Render and check output
    harness = ComponentHarness.render(harness)
    renderer = ComponentHarness.get_renderer(harness)
    assert_text_exists(renderer, "Value: 0")

    # Send event and verify state change
    harness = ComponentHarness.send_event(harness, EventSimulator.simulate_key(:up))
    harness = ComponentHarness.render(harness)
    assert_text_exists(renderer, "Value: 1")

    # Cleanup
    ComponentHarness.unmount(harness)
  end
end
```

## Component Harness

The `ComponentHarness` mounts components in isolation for testing without the full runtime.

### Mounting Components

```elixir
# Basic mount
{:ok, harness} = ComponentHarness.mount_test(MyComponent)

# With props
{:ok, harness} = ComponentHarness.mount_test(MyButton, label: "Click me")

# With custom dimensions
{:ok, harness} = ComponentHarness.mount_test(MyWidget, width: 40, height: 10)
```

### Rendering

```elixir
# Render component
harness = ComponentHarness.render(harness)

# Get render result (the render tree)
render_tree = ComponentHarness.get_render(harness)

# Get all renders (most recent first)
all_renders = ComponentHarness.get_renders(harness)
```

### Sending Events

```elixir
# Single event
harness = ComponentHarness.send_event(harness, event)

# Multiple events
harness = ComponentHarness.send_events(harness, [event1, event2, event3])

# Event + render cycle (common pattern)
harness = ComponentHarness.event_cycle(harness, event)
```

### Inspecting State

```elixir
# Get full state
state = ComponentHarness.get_state(harness)

# Get state at path
value = ComponentHarness.get_state_at(harness, [:counter, :value])

# Direct state manipulation (use sparingly)
harness = ComponentHarness.set_state(harness, %{count: 10})
harness = ComponentHarness.update_state(harness, fn s -> %{s | count: s.count + 1} end)
```

### Cleanup

```elixir
# Always unmount when done
ComponentHarness.unmount(harness)

# Or reset to initial state
{:ok, harness} = ComponentHarness.reset(harness)
```

## Test Renderer

The `TestRenderer` captures rendered output to a buffer for inspection.

### Creating a Renderer

```elixir
{:ok, renderer} = TestRenderer.new(24, 80)  # 24 rows, 80 columns
```

### Writing Content

```elixir
# Write a string
TestRenderer.write_string(renderer, 1, 1, "Hello, World!")

# Set individual cell
TestRenderer.set_cell(renderer, 1, 1, Cell.new("X", fg: :red))

# Clear buffer
TestRenderer.clear(renderer)
```

### Reading Content

```elixir
# Get text at position
text = TestRenderer.get_text_at(renderer, 1, 1, 5)  # "Hello"

# Get entire row
row_text = TestRenderer.get_row_text(renderer, 1)

# Get cell
cell = TestRenderer.get_cell(renderer, 1, 1)

# Get style at position
style = TestRenderer.get_style_at(renderer, 1, 1)
# => %{fg: :red, bg: :default, attrs: MapSet.new([:bold])}
```

### Searching Content

```elixir
# Check if text exists at position
TestRenderer.text_at?(renderer, 1, 1, "Hello")  # true/false

# Check if region contains text
TestRenderer.text_contains?(renderer, 1, 1, 80, "Error")

# Find all occurrences
positions = TestRenderer.find_text(renderer, "Error")
# => [{5, 10}, {12, 3}]
```

### Snapshots

Snapshots capture buffer state for comparison:

```elixir
# Take snapshot
snapshot = TestRenderer.snapshot(renderer)

# Compare to snapshot
TestRenderer.matches_snapshot?(renderer, snapshot)  # true/false

# Get differences
diffs = TestRenderer.diff_snapshot(renderer, snapshot)
# => [{row, col, expected_cell, actual_cell}, ...]

# Convert to string for debugging
TestRenderer.to_string(renderer)
TestRenderer.snapshot_to_string(snapshot)
```

### Cleanup

```elixir
TestRenderer.destroy(renderer)
```

## Event Simulator

The `EventSimulator` creates synthetic events without terminal input.

### Keyboard Events

```elixir
# Basic key press
event = EventSimulator.simulate_key(:enter)
event = EventSimulator.simulate_key(:up)
event = EventSimulator.simulate_key(:escape)

# Key with character
event = EventSimulator.simulate_key(:a, char: "a")

# Key with modifiers
event = EventSimulator.simulate_key(:c, modifiers: [:ctrl])
event = EventSimulator.simulate_key(:s, modifiers: [:ctrl, :shift])

# Function keys
event = EventSimulator.simulate_function_key(1)   # F1
event = EventSimulator.simulate_function_key(12)  # F12

# Navigation keys
event = EventSimulator.simulate_navigation(:up)
event = EventSimulator.simulate_navigation(:page_down)
event = EventSimulator.simulate_navigation(:home)
```

### Common Shortcuts

```elixir
EventSimulator.simulate_shortcut(:copy)       # Ctrl+C
EventSimulator.simulate_shortcut(:paste)      # Ctrl+V
EventSimulator.simulate_shortcut(:cut)        # Ctrl+X
EventSimulator.simulate_shortcut(:save)       # Ctrl+S
EventSimulator.simulate_shortcut(:quit)       # Ctrl+Q
EventSimulator.simulate_shortcut(:undo)       # Ctrl+Z
EventSimulator.simulate_shortcut(:redo)       # Ctrl+Shift+Z
EventSimulator.simulate_shortcut(:select_all) # Ctrl+A
```

### Typing Text

```elixir
# Simulate typing a string (returns list of events)
events = EventSimulator.simulate_type("Hello")
# => [%Key{key: :h, char: "H"}, %Key{key: :e, char: "e"}, ...]

# Send all events
harness = ComponentHarness.send_events(harness, events)
```

### Key Sequences

```elixir
# Simulate sequence of keys
events = EventSimulator.simulate_sequence([:tab, :tab, :enter])

# With options
events = EventSimulator.simulate_sequence([
  {:a, char: "a"},
  :tab,
  :enter
])
```

### Mouse Events

```elixir
# Click
event = EventSimulator.simulate_click(10, 20)              # left click
event = EventSimulator.simulate_click(10, 20, :right)      # right click
event = EventSimulator.simulate_click(10, 20, :left, modifiers: [:ctrl])

# Double click
event = EventSimulator.simulate_double_click(10, 20)

# Mouse movement
event = EventSimulator.simulate_move(15, 25)

# Drag
event = EventSimulator.simulate_drag(10, 20, :left)

# Scroll
event = EventSimulator.simulate_scroll_up(10, 20)
event = EventSimulator.simulate_scroll_down(10, 20)
```

### Other Events

```elixir
# Focus events
event = EventSimulator.simulate_focus_gained()
event = EventSimulator.simulate_focus_lost()

# Resize
event = EventSimulator.simulate_resize(120, 40)

# Paste
event = EventSimulator.simulate_paste("Pasted content")
```

## Assertions

Import assertions with `use TermUI.Test.Assertions`.

### Text Assertions

```elixir
# Assert exact text at position
assert_text(renderer, 1, 1, "Hello")

# Assert text does NOT appear
refute_text(renderer, 1, 1, "Goodbye")

# Assert region contains text
assert_text_contains(renderer, 1, 1, 80, "Error")
refute_text_contains(renderer, 1, 1, 80, "Success")

# Assert text exists anywhere in buffer
assert_text_exists(renderer, "Error")
refute_text_exists(renderer, "Secret")

# Assert entire row matches
assert_row(renderer, 1, "Hello, World!")
```

### Style Assertions

```elixir
# Assert foreground color
assert_style(renderer, 1, 1, fg: :red)

# Assert background color
assert_style(renderer, 1, 1, bg: :white)

# Assert multiple style properties
assert_style(renderer, 1, 1, fg: :red, bg: :white, attrs: [:bold])

# Assert single attribute
assert_attr(renderer, 1, 1, :bold)
refute_attr(renderer, 1, 1, :underline)
```

### State Assertions

```elixir
# Assert state at path
assert_state(state, [:counter, :value], 42)
refute_state(state, [:counter, :value], 0)

# Assert state exists (not nil)
assert_state_exists(state, [:user, :name])
```

### Snapshot Assertions

```elixir
# Take snapshot
snapshot = TestRenderer.snapshot(renderer)

# ... perform operations ...

# Assert matches snapshot
assert_snapshot(renderer, snapshot)
```

### Buffer Assertions

```elixir
# Assert buffer is empty
assert_empty(renderer)
```

## Testing Patterns

### Testing State Transitions

```elixir
test "counter increments on up arrow" do
  {:ok, harness} = ComponentHarness.mount_test(Counter, initial: 0)

  # Initial state
  assert ComponentHarness.get_state(harness).count == 0

  # Send event
  harness = ComponentHarness.send_event(harness, EventSimulator.simulate_key(:up))

  # Verify state changed
  assert ComponentHarness.get_state(harness).count == 1
end
```

### Testing Rendered Output

```elixir
test "displays current count" do
  {:ok, harness} = ComponentHarness.mount_test(Counter, initial: 42)
  harness = ComponentHarness.render(harness)

  renderer = ComponentHarness.get_renderer(harness)
  assert_text_exists(renderer, "Count: 42")
end
```

### Testing Event Sequences

```elixir
test "navigation through menu" do
  {:ok, harness} = ComponentHarness.mount_test(Menu, items: ["A", "B", "C"])

  # Navigate down twice
  harness =
    harness
    |> ComponentHarness.event_cycle(EventSimulator.simulate_key(:down))
    |> ComponentHarness.event_cycle(EventSimulator.simulate_key(:down))

  # Should be on third item
  assert ComponentHarness.get_state(harness).selected == 2
end
```

### Testing with Snapshots

```elixir
test "render output matches expected" do
  {:ok, harness} = ComponentHarness.mount_test(MyWidget)
  harness = ComponentHarness.render(harness)

  renderer = ComponentHarness.get_renderer(harness)
  snapshot = TestRenderer.snapshot(renderer)

  # Store snapshot for regression testing
  # In real tests, you'd load this from a file
  expected = %{
    rows: 24,
    cols: 80,
    cells: %{...}
  }

  assert_snapshot(renderer, expected)
end
```

### Testing Edge Cases

```elixir
test "handles empty list" do
  {:ok, harness} = ComponentHarness.mount_test(List, items: [])
  harness = ComponentHarness.render(harness)

  renderer = ComponentHarness.get_renderer(harness)
  assert_text_exists(renderer, "No items")
end

test "handles boundary navigation" do
  {:ok, harness} = ComponentHarness.mount_test(List, items: ["Only item"])

  # Try to go down when already at bottom
  harness = ComponentHarness.send_event(harness, EventSimulator.simulate_key(:down))

  # Should stay at 0
  assert ComponentHarness.get_state(harness).selected == 0
end
```

## Best Practices

1. **Use `async: true`** for isolated tests
2. **Always call `unmount/1`** to clean up resources
3. **Test state and render separately** for clarity
4. **Use `event_cycle/2`** for common send-event-then-render pattern
5. **Prefer event simulation** over direct state manipulation
6. **Use assertions** for clear failure messages
7. **Test edge cases**: empty data, boundaries, invalid input

## Next Steps

- [Creating Widgets](08-creating-widgets.md) - Widget implementation guide
- [Architecture Overview](01-architecture-overview.md) - System architecture
