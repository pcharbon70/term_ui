defmodule TermUI.Integration.AdvancedWidgetsTest do
  @moduledoc """
  Integration tests for advanced widgets.

  Tests verify that Phase 6 widgets (Table, Tabs, Dialog, visualization widgets,
  and scrollable widgets) can be properly initialized and rendered. These are
  smoke tests ensuring basic functionality works correctly.
  """

  # async: true because widgets are stateless and tests create isolated instances
  use ExUnit.Case, async: true

  @default_area %{width: 80, height: 24}

  alias TermUI.Component.RenderNode
  alias TermUI.Event
  alias TermUI.Layout.Constraint
  alias TermUI.Test.Factories
  alias TermUI.Widgets.BarChart
  alias TermUI.Widgets.Canvas
  alias TermUI.Widgets.Dialog
  alias TermUI.Widgets.Gauge
  alias TermUI.Widgets.Sparkline
  alias TermUI.Widgets.Table
  alias TermUI.Widgets.Table.Column
  alias TermUI.Widgets.Tabs
  alias TermUI.Widgets.Viewport

  describe "table widget integration" do
    test "initializes and renders with data" do
      data = Factories.sample_table_data()
      columns = Factories.default_table_columns()

      props = Table.new(data: data, columns: columns)
      {:ok, state} = Table.init(props)

      assert length(state.data) == 100
      assert state.scroll_offset == 0

      output = Table.render(state, @default_area)
      assert output != nil
    end

    test "handles large dataset efficiently" do
      data = Factories.sample_table_data(1000)
      columns = [Column.new(:id, "ID", width: Constraint.length(10))]

      props = Table.new(data: data, columns: columns)
      {:ok, state} = Table.init(props)

      assert length(state.data) == 1000

      output = Table.render(state, @default_area)
      assert output != nil
    end

    test "handles keyboard navigation" do
      data = Factories.sample_table_data(50)
      columns = Factories.default_table_columns()

      props = Table.new(data: data, columns: columns)
      {:ok, state} = Table.init(props)

      # Navigate down
      {:ok, state} = Table.handle_event(Event.key(:down), state)
      assert state.cursor == 1

      # Navigate up
      {:ok, state} = Table.handle_event(Event.key(:up), state)
      assert state.cursor == 0

      # Page down
      {:ok, state} = Table.handle_event(Event.key(:page_down), state)
      assert state.cursor > 0
    end

    test "handles empty data" do
      columns = Factories.default_table_columns()

      props = Table.new(data: [], columns: columns)
      {:ok, state} = Table.init(props)

      assert state.data == []
      assert state.cursor == 0

      output = Table.render(state, @default_area)
      assert output != nil
    end
  end

  describe "tabs widget integration" do
    test "initializes and renders" do
      tabs = Factories.sample_tabs()

      props = Tabs.new(tabs: tabs)
      {:ok, state} = Tabs.init(props)

      assert length(state.tabs) == 3
      assert state.selected == :tab1

      output = Tabs.render(state, @default_area)
      assert output != nil
    end

    test "handles tab navigation events" do
      tabs = Factories.sample_tabs()

      props = Tabs.new(tabs: tabs)
      {:ok, state} = Tabs.init(props)

      # Handle right key event
      {:ok, new_state} = Tabs.handle_event(Event.key(:right), state)
      assert is_map(new_state)

      # Handle left key event
      {:ok, new_state} = Tabs.handle_event(Event.key(:left), new_state)
      assert is_map(new_state)

      # Render after events
      output = Tabs.render(new_state, @default_area)
      assert output != nil
    end

    test "handles single tab" do
      props = Tabs.new(tabs: [%{id: :only, label: "Only Tab"}])
      {:ok, state} = Tabs.init(props)

      assert length(state.tabs) == 1
      assert state.selected == :only

      output = Tabs.render(state, @default_area)
      assert output != nil
    end
  end

  describe "dialog widget integration" do
    test "initializes and renders" do
      props =
        Dialog.new(
          title: "Test Dialog",
          content: RenderNode.text("Dialog content"),
          buttons: Factories.sample_dialog_buttons()
        )

      {:ok, state} = Dialog.init(props)

      assert state.title == "Test Dialog"
      assert state.visible == true
      assert length(state.buttons) == 2

      output = Dialog.render(state, @default_area)
      assert output != nil
    end

    test "handles visibility toggle" do
      props =
        Dialog.new(
          title: "Toggle Dialog",
          content: RenderNode.text("Content"),
          buttons: Factories.sample_dialog_buttons()
        )

      {:ok, state} = Dialog.init(props)
      assert state.visible == true

      # Hide dialog
      state = %{state | visible: false}
      output = Dialog.render(state, @default_area)
      assert output != nil

      # Show dialog
      state = %{state | visible: true}
      output = Dialog.render(state, @default_area)
      assert output != nil
    end

    test "handles keyboard navigation events" do
      props =
        Dialog.new(
          title: "Button Nav",
          content: RenderNode.text("Content"),
          buttons: Factories.sample_dialog_buttons()
        )

      {:ok, state} = Dialog.init(props)

      # Handle tab key event
      {:ok, new_state} = Dialog.handle_event(Event.key(:tab), state)
      assert is_map(new_state)

      # Handle shift+tab key event
      {:ok, new_state} = Dialog.handle_event(Event.key(:tab, modifiers: [:shift]), new_state)
      assert is_map(new_state)

      # Render after events
      output = Dialog.render(new_state, @default_area)
      assert output != nil
    end

    test "handles single button" do
      props =
        Dialog.new(
          title: "Single Button",
          content: RenderNode.text("Content"),
          buttons: [%{id: :ok, label: "OK"}]
        )

      {:ok, state} = Dialog.init(props)
      assert length(state.buttons) == 1

      output = Dialog.render(state, @default_area)
      assert output != nil
    end
  end

  describe "visualization widgets integration" do
    test "bar chart renders data" do
      data = Factories.sample_chart_data()

      output = BarChart.render(data: data, width: 40, height: 10)
      assert output != nil
    end

    test "bar chart handles empty data" do
      output = BarChart.render(data: [], width: 40, height: 10)
      assert output != nil
    end

    test "bar chart handles single value" do
      output = BarChart.render(data: [%{label: "X", value: 100}], width: 40, height: 10)
      assert output != nil
    end

    test "sparkline renders values" do
      values = Factories.sample_sparkline_values()

      output = Sparkline.render(values: values)
      assert output != nil
    end

    test "sparkline handles empty values" do
      output = Sparkline.render(values: [])
      assert output != nil
    end

    test "sparkline handles single value" do
      output = Sparkline.render(values: [42])
      assert output != nil
    end

    test "gauge renders value" do
      output =
        Gauge.render(
          value: 75,
          min: 0,
          max: 100,
          width: 30
        )

      assert output != nil
    end

    test "gauge handles boundary values" do
      # Minimum value
      output = Gauge.render(value: 0, min: 0, max: 100, width: 30)
      assert output != nil

      # Maximum value
      output = Gauge.render(value: 100, min: 0, max: 100, width: 30)
      assert output != nil

      # Value at 50%
      output = Gauge.render(value: 50, min: 0, max: 100, width: 30)
      assert output != nil
    end

    test "gauge handles custom range" do
      output =
        Gauge.render(
          value: 500,
          min: 100,
          max: 1000,
          width: 30
        )

      assert output != nil
    end
  end

  describe "scrollable widgets integration" do
    test "viewport initializes and renders" do
      props =
        Viewport.new(
          content: RenderNode.text("Viewport content"),
          content_width: 200,
          content_height: 100,
          width: 80,
          height: 24
        )

      {:ok, state} = Viewport.init(props)

      assert state.scroll_x == 0
      assert state.scroll_y == 0

      output = Viewport.render(state, @default_area)
      assert output != nil
    end

    test "viewport handles scrolling" do
      props =
        Viewport.new(
          content: RenderNode.text("Large content"),
          content_width: 200,
          content_height: 100,
          width: 80,
          height: 24
        )

      {:ok, state} = Viewport.init(props)

      # Scroll down
      {:ok, state} = Viewport.handle_event(Event.key(:down), state)
      assert state.scroll_y > 0

      # Scroll right
      {:ok, state} = Viewport.handle_event(Event.key(:right), state)
      assert state.scroll_x > 0

      # Scroll back
      {:ok, state} = Viewport.handle_event(Event.key(:up), state)
      {:ok, state} = Viewport.handle_event(Event.key(:left), state)

      output = Viewport.render(state, @default_area)
      assert output != nil
    end

    test "viewport handles content smaller than view" do
      props =
        Viewport.new(
          content: RenderNode.text("Small"),
          content_width: 10,
          content_height: 5,
          width: 80,
          height: 24
        )

      {:ok, state} = Viewport.init(props)

      output = Viewport.render(state, @default_area)
      assert output != nil
    end

    test "canvas drawing operations" do
      props = Canvas.new(width: 40, height: 20)
      {:ok, state} = Canvas.init(props)

      # Draw operations
      state = Canvas.clear(state)
      state = Canvas.draw_text(state, 5, 3, "Hello")
      state = Canvas.draw_line(state, 0, 0, 10, 10)

      output = Canvas.render(state, %{width: 40, height: 20})
      assert output != nil
    end

    test "canvas handles multiple drawing operations" do
      props = Canvas.new(width: 40, height: 20)
      {:ok, state} = Canvas.init(props)

      # Multiple draw operations
      state = Canvas.clear(state)
      state = Canvas.draw_text(state, 0, 0, "Top Left")
      state = Canvas.draw_text(state, 35, 0, "Top Right")
      state = Canvas.draw_text(state, 0, 19, "Bottom Left")
      state = Canvas.draw_line(state, 0, 10, 39, 10)

      output = Canvas.render(state, %{width: 40, height: 20})
      assert output != nil
    end

    test "canvas handles empty canvas" do
      props = Canvas.new(width: 40, height: 20)
      {:ok, state} = Canvas.init(props)

      # Render without any drawing
      output = Canvas.render(state, %{width: 40, height: 20})
      assert output != nil
    end
  end
end
