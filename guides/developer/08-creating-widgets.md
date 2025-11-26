# Creating New Widgets

This guide explains how to create new widgets for TermUI and contribute them to the project.

## Widget Types

TermUI supports two types of widgets:

### 1. Stateless Widgets (Display Only)

Simple widgets that render based on input props without maintaining internal state.

**Examples**: Gauge, Sparkline, BarChart, LineChart

**Use when**: The widget only displays data and doesn't need to track interactions.

### 2. Stateful Widgets (Interactive)

Widgets that maintain internal state and handle user events.

**Examples**: Menu, Table, Tabs, Dialog, Viewport

**Use when**: The widget needs to track selection, focus, scroll position, or other interactive state.

## Creating a Stateless Widget

### Step 1: Create the Widget Module

Create a new file in `lib/term_ui/widgets/`:

```elixir
defmodule TermUI.Widgets.MyWidget do
  @moduledoc """
  MyWidget displays [description].

  ## Usage

      MyWidget.render(
        value: 42,
        width: 20,
        style: Style.new(fg: :cyan)
      )

  ## Options

  - `:value` - The value to display (required)
  - `:width` - Widget width (default: 20)
  - `:style` - Style for the widget
  """

  import TermUI.Component.RenderNode

  @doc """
  Renders the widget.

  ## Options

  - `:value` - Required. The value to display.
  - `:width` - Optional. Width in characters (default: 20).
  - `:style` - Optional. Style to apply.
  """
  @spec render(keyword()) :: TermUI.Component.RenderNode.t()
  def render(opts) do
    value = Keyword.fetch!(opts, :value)
    width = Keyword.get(opts, :width, 20)
    style = Keyword.get(opts, :style)

    # Build your render tree
    content = format_value(value, width)

    if style do
      styled(text(content), style)
    else
      text(content)
    end
  end

  # Helper function for convenience
  @doc """
  Renders with default styling.
  """
  def simple(value, opts \\ []) do
    render([{:value, value} | opts])
  end

  # Private helpers
  defp format_value(value, width) do
    value
    |> to_string()
    |> String.pad_trailing(width)
  end
end
```

### Key Points for Stateless Widgets

1. **Import RenderNode helpers**: `import TermUI.Component.RenderNode`
2. **Use `Keyword.fetch!/2`** for required options
3. **Use `Keyword.get/3`** for optional options with defaults
4. **Return a RenderNode struct** from `render/1`
5. **Provide convenience functions** like `simple/2` for common use cases

## Creating a Stateful Widget

### Step 1: Create the Widget Module

```elixir
defmodule TermUI.Widgets.MyStatefulWidget do
  @moduledoc """
  MyStatefulWidget provides [description].

  ## Usage

      MyStatefulWidget.new(
        items: ["one", "two", "three"],
        on_select: fn item -> handle_selection(item) end
      )

  ## Keyboard Controls

  - Up/Down: Navigate items
  - Enter: Select current item
  - Escape: Close
  """

  use TermUI.StatefulComponent

  alias TermUI.Event

  # Constructor for props
  @doc """
  Creates widget props.

  ## Options

  - `:items` - List of items (required)
  - `:on_select` - Callback when item is selected
  - `:style` - Style for normal items
  - `:selected_style` - Style for selected item
  """
  @spec new(keyword()) :: map()
  def new(opts) do
    %{
      items: Keyword.fetch!(opts, :items),
      on_select: Keyword.get(opts, :on_select),
      style: Keyword.get(opts, :style),
      selected_style: Keyword.get(opts, :selected_style)
    }
  end

  # Initialize state from props
  @impl true
  def init(props) do
    state = %{
      items: props.items,
      cursor: 0,
      on_select: props.on_select,
      style: props.style,
      selected_style: props.selected_style
    }

    {:ok, state}
  end

  # Handle keyboard events
  @impl true
  def handle_event(%Event.Key{key: :up}, state) do
    new_cursor = max(0, state.cursor - 1)
    {:ok, %{state | cursor: new_cursor}}
  end

  def handle_event(%Event.Key{key: :down}, state) do
    max_index = length(state.items) - 1
    new_cursor = min(max_index, state.cursor + 1)
    {:ok, %{state | cursor: new_cursor}}
  end

  def handle_event(%Event.Key{key: :enter}, state) do
    if state.on_select do
      item = Enum.at(state.items, state.cursor)
      state.on_select.(item)
    end

    {:ok, state}
  end

  def handle_event(_event, state) do
    {:ok, state}
  end

  # Render the widget
  @impl true
  def render(state, _area) do
    rows =
      state.items
      |> Enum.with_index()
      |> Enum.map(fn {item, index} ->
        render_item(item, index, state)
      end)

    stack(:vertical, rows)
  end

  defp render_item(item, index, state) do
    is_selected = index == state.cursor
    style = if is_selected, do: state.selected_style, else: state.style

    if style do
      styled(text(item), style)
    else
      text(item)
    end
  end
end
```

### Key Points for Stateful Widgets

1. **Use the behaviour**: `use TermUI.StatefulComponent`
2. **Provide `new/1`** to create props from options
3. **Implement `init/1`** to initialize state from props
4. **Implement `handle_event/2`** for user interactions
5. **Implement `render/2`** to produce the render tree
6. **Return `{:ok, state}` or `{:ok, state, commands}`** from event handlers

## Writing Tests

**Tests are required for all new widgets.** See [Testing Framework](09-testing-framework.md) for comprehensive testing documentation.

Create a test file in `test/term_ui/widgets/`:

```elixir
defmodule TermUI.Widgets.MyWidgetTest do
  use ExUnit.Case, async: true

  alias TermUI.Widgets.MyWidget

  describe "render/1" do
    test "renders with required options" do
      result = MyWidget.render(value: 42)

      assert result.type == :text
      assert result.content =~ "42"
    end

    test "applies custom width" do
      result = MyWidget.render(value: 1, width: 10)

      assert String.length(result.content) == 10
    end

    test "applies style when provided" do
      style = TermUI.Renderer.Style.new(fg: :red)
      result = MyWidget.render(value: 42, style: style)

      assert result.type == :box
      assert result.style == style
    end

    test "raises on missing required option" do
      assert_raise KeyError, fn ->
        MyWidget.render([])
      end
    end
  end

  describe "simple/2" do
    test "creates widget with defaults" do
      result = MyWidget.simple(100)

      assert result.type == :text
    end
  end
end
```

### Test Categories to Cover

1. **Required options** - Verify required params raise on missing
2. **Default values** - Test behavior with minimal options
3. **All options** - Test each option individually
4. **Edge cases** - Empty data, zero values, extreme values
5. **Styling** - Verify styles are applied correctly
6. **For stateful widgets**:
   - Initial state from props
   - Event handling (keyboard, mouse)
   - State transitions
   - Callback invocation

## File Organization

```
lib/term_ui/widgets/
├── my_widget.ex           # Your widget module

test/term_ui/widgets/
├── my_widget_test.exs     # Your widget tests

examples/my_widget/        # Optional: example application
├── mix.exs
├── run.exs
├── README.md
└── lib/my_widget/
    ├── application.ex
    └── app.ex
```

## Checklist Before Submitting a PR

### Code Quality

- [ ] Widget has comprehensive `@moduledoc` with usage examples
- [ ] All public functions have `@doc` and `@spec`
- [ ] Follows existing code style (run `mix format`)
- [ ] No compiler warnings (`mix compile --warnings-as-errors`)

### Testing

- [ ] Test file exists in `test/term_ui/widgets/`
- [ ] Tests cover all public functions
- [ ] Tests cover edge cases
- [ ] All tests pass (`mix test`)
- [ ] Tests are async when possible (`use ExUnit.Case, async: true`)

### Documentation

- [ ] Module documentation explains the widget's purpose
- [ ] Usage examples in `@moduledoc`
- [ ] All options documented in `render/1` or `new/1`
- [ ] Keyboard controls documented for stateful widgets

### Optional but Appreciated

- [ ] Example application in `examples/`
- [ ] Example has README with installation instructions

## Submitting Your PR

### 1. Fork and Branch

```bash
git checkout -b feature/my-widget
```

### 2. Implement and Test

```bash
# Run tests
mix test test/term_ui/widgets/my_widget_test.exs

# Run all tests
mix test

# Check formatting
mix format --check-formatted

# Check for warnings
mix compile --warnings-as-errors
```

### 3. Commit with Clear Message

```bash
git add lib/term_ui/widgets/my_widget.ex test/term_ui/widgets/my_widget_test.exs
git commit -m "Add MyWidget for [purpose]

- Implements [feature 1]
- Supports [feature 2]
- Includes comprehensive tests"
```

### 4. Create Pull Request

Your PR description should include:

- **What**: Brief description of the widget
- **Why**: Use case or motivation
- **How**: Key implementation details
- **Testing**: How to test the widget
- **Screenshots**: If applicable, show the widget in action

### PR Requirements

1. **Tests must pass** - CI will verify this
2. **Tests must be included** - PRs without tests will not be merged
3. **Code must be formatted** - Run `mix format`
4. **No new warnings** - Compile with `--warnings-as-errors`

## Examples of Good PRs

Look at existing widgets for reference:

- **Simple stateless**: `lib/term_ui/widgets/gauge.ex`
- **Data visualization**: `lib/term_ui/widgets/sparkline.ex`
- **Interactive stateful**: `lib/term_ui/widgets/menu.ex`
- **Complex stateful**: `lib/term_ui/widgets/table.ex`

## Getting Help

- Open an issue to discuss your widget idea before implementing
- Ask questions in the PR if you need guidance
- Review existing widget implementations for patterns

## Next Steps

- [Testing Framework](09-testing-framework.md) - Comprehensive testing guide
- [Architecture Overview](01-architecture-overview.md) - Understand the system
- [Elm Implementation](07-elm-implementation.md) - Learn the component model
- [Rendering Pipeline](03-rendering-pipeline.md) - How widgets become output
