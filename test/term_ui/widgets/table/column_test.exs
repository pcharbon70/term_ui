defmodule TermUI.Widgets.Table.ColumnTest do
  use ExUnit.Case, async: true

  alias TermUI.Widgets.Table.Column
  alias TermUI.Layout.Constraint

  describe "new/3" do
    test "creates column with default values" do
      column = Column.new(:name, "Name")

      assert column.key == :name
      assert column.header == "Name"
      assert column.sortable == true
      assert column.align == :left
      assert column.render == nil
      assert %Constraint.Fill{} = column.width
    end

    test "creates column with custom width" do
      column = Column.new(:age, "Age", width: Constraint.length(10))

      assert %Constraint.Length{value: 10} = column.width
    end

    test "creates column with custom render function" do
      render_fn = fn val -> "Value: #{val}" end
      column = Column.new(:value, "Value", render: render_fn)

      assert column.render == render_fn
    end

    test "creates column with custom alignment" do
      column = Column.new(:amount, "Amount", align: :right)

      assert column.align == :right
    end

    test "creates non-sortable column" do
      column = Column.new(:id, "ID", sortable: false)

      assert column.sortable == false
    end
  end

  describe "render_cell/2" do
    test "renders cell with default to_string" do
      column = Column.new(:name, "Name")
      row = %{name: "Alice"}

      assert Column.render_cell(column, row) == "Alice"
    end

    test "renders cell with custom render function" do
      column = Column.new(:age, "Age", render: fn age -> "#{age} years" end)
      row = %{age: 30}

      assert Column.render_cell(column, row) == "30 years"
    end

    test "renders missing value as empty string" do
      column = Column.new(:name, "Name")
      row = %{other: "value"}

      assert Column.render_cell(column, row) == ""
    end

    test "converts non-string values to string" do
      column = Column.new(:count, "Count")
      row = %{count: 42}

      assert Column.render_cell(column, row) == "42"
    end

    test "handles nil values" do
      column = Column.new(:value, "Value")
      row = %{value: nil}

      assert Column.render_cell(column, row) == ""
    end
  end

  describe "align_text/3" do
    test "left aligns text" do
      result = Column.align_text("Hi", 10, :left)

      assert result == "Hi        "
      assert String.length(result) == 10
    end

    test "right aligns text" do
      result = Column.align_text("Hi", 10, :right)

      assert result == "        Hi"
      assert String.length(result) == 10
    end

    test "center aligns text" do
      result = Column.align_text("Hi", 10, :center)

      assert result == "    Hi    "
      assert String.length(result) == 10
    end

    test "truncates text longer than width" do
      result = Column.align_text("Hello, World!", 5, :left)

      assert result == "Hello"
      assert String.length(result) == 5
    end

    test "handles text equal to width" do
      result = Column.align_text("Hello", 5, :left)

      assert result == "Hello"
    end

    test "handles empty text" do
      result = Column.align_text("", 5, :left)

      assert result == "     "
      assert String.length(result) == 5
    end

    test "handles odd-length centering" do
      result = Column.align_text("Hi", 9, :center)

      # "Hi" is 2 chars, 9-2=7, left pad=3, right pad=4
      assert result == "   Hi    "
      assert String.length(result) == 9
    end
  end
end
