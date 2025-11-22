defmodule TermUI.Integration.AdvancedWidgetsTest do
  use ExUnit.Case, async: true

  alias TermUI.Component.RenderNode
  alias TermUI.Layout.Constraint
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
      data = for i <- 1..100, do: %{id: i, name: "Item #{i}"}

      columns = [
        Column.new(:id, "ID", width: Constraint.length(10)),
        Column.new(:name, "Name", width: Constraint.length(30))
      ]

      props = Table.new(data: data, columns: columns)
      {:ok, state} = Table.init(props)

      assert length(state.data) == 100
      assert state.scroll_offset == 0

      area = %{width: 80, height: 24}
      output = Table.render(state, area)
      assert output != nil
    end

    test "handles large dataset efficiently" do
      # Generate 1000 rows
      data = for i <- 1..1000, do: %{id: i, name: "Item #{i}"}
      columns = [Column.new(:id, "ID", width: Constraint.length(10))]

      props = Table.new(data: data, columns: columns)
      {:ok, state} = Table.init(props)

      assert length(state.data) == 1000

      # Rendering should work without issue
      area = %{width: 80, height: 24}
      output = Table.render(state, area)
      assert output != nil
    end
  end

  describe "tabs widget integration" do
    test "initializes and renders" do
      tabs = [
        %{id: :tab1, label: "Tab 1"},
        %{id: :tab2, label: "Tab 2"}
      ]

      props = Tabs.new(tabs: tabs)
      {:ok, state} = Tabs.init(props)

      assert length(state.tabs) == 2

      area = %{width: 80, height: 24}
      output = Tabs.render(state, area)
      assert output != nil
    end
  end

  describe "dialog widget integration" do
    test "initializes and renders" do
      props =
        Dialog.new(
          title: "Test Dialog",
          content: RenderNode.text("Dialog content"),
          buttons: [%{id: :ok, label: "OK"}, %{id: :cancel, label: "Cancel"}]
        )

      {:ok, state} = Dialog.init(props)

      assert state.title == "Test Dialog"
      assert state.visible == true

      area = %{width: 80, height: 24}
      output = Dialog.render(state, area)
      assert output != nil

      # Test when not visible
      state = %{state | visible: false}
      output = Dialog.render(state, area)
      assert output != nil
    end
  end

  describe "visualization widgets integration" do
    test "bar chart renders data" do
      data = [
        %{label: "A", value: 10},
        %{label: "B", value: 25},
        %{label: "C", value: 15}
      ]

      # BarChart is stateless - just call render directly
      output = BarChart.render(data: data, width: 40, height: 10)
      assert output != nil
    end

    test "sparkline renders values" do
      values = [5, 10, 3, 8, 15, 7, 12]

      # Sparkline is stateless - just call render directly
      output = Sparkline.render(values: values)
      assert output != nil
    end

    test "gauge renders value" do
      # Gauge is stateless - just call render directly
      output =
        Gauge.render(
          value: 75,
          min: 0,
          max: 100,
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

      area = %{width: 80, height: 24}
      output = Viewport.render(state, area)
      assert output != nil
    end

    test "canvas drawing operations" do
      props = Canvas.new(width: 40, height: 20)
      {:ok, state} = Canvas.init(props)

      # Draw operations
      state = Canvas.clear(state)
      state = Canvas.draw_text(state, 5, 3, "Hello")
      state = Canvas.draw_line(state, 0, 0, 10, 10)

      area = %{width: 40, height: 20}
      output = Canvas.render(state, area)
      assert output != nil
    end
  end
end
