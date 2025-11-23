defmodule TermUI.Widget.LabelTest do
  use ExUnit.Case, async: true

  alias TermUI.Component.RenderNode
  alias TermUI.Widget.Label

  @area %{x: 0, y: 0, width: 20, height: 1}

  describe "render/2" do
    test "renders simple text" do
      props = %{text: "Hello"}
      result = Label.render(props, @area)

      assert %RenderNode{type: :cells, cells: cells} = result
      # padded to area width
      assert length(cells) == 20

      # Check first 5 cells contain "Hello"
      chars = Enum.map(Enum.take(cells, 5), fn %{cell: cell} -> cell.char end)
      assert chars == ["H", "e", "l", "l", "o"]
    end

    test "truncates long text with ellipsis" do
      props = %{text: "This is a very long text that should be truncated"}
      result = Label.render(props, @area)

      assert %RenderNode{type: :cells, cells: cells} = result
      assert length(cells) == 20

      # Last character should be ellipsis
      last_cell = List.last(cells)
      assert last_cell.cell.char == "…"
    end

    test "does not truncate when disabled" do
      props = %{text: "Short", truncate: false}
      result = Label.render(props, @area)

      assert %RenderNode{type: :cells, cells: cells} = result
      chars = Enum.map(cells, fn %{cell: cell} -> cell.char end)
      # Should not have ellipsis, just padding
      refute "…" in chars
    end

    test "aligns text left by default" do
      props = %{text: "Hi"}
      result = Label.render(props, @area)

      assert %RenderNode{type: :cells, cells: cells} = result
      [first, second | _rest] = cells
      assert first.cell.char == "H"
      assert second.cell.char == "i"
      assert first.x == 0
    end

    test "aligns text center" do
      props = %{text: "Hi", align: :center}
      result = Label.render(props, @area)

      assert %RenderNode{type: :cells, cells: cells} = result
      # "Hi" is 2 chars, area is 20, so padding is 9 on each side
      # First H should be at position 9
      h_cell = Enum.find(cells, fn c -> c.cell.char == "H" end)
      assert h_cell.x == 9
    end

    test "aligns text right" do
      props = %{text: "Hi", align: :right}
      result = Label.render(props, @area)

      assert %RenderNode{type: :cells, cells: cells} = result
      # H should be at position 18, i at 19
      h_cell = Enum.find(cells, fn c -> c.cell.char == "H" end)
      assert h_cell.x == 18
    end

    test "applies foreground color" do
      props = %{text: "Red", style: %{fg: :red}}
      result = Label.render(props, @area)

      assert %RenderNode{type: :cells, cells: cells} = result
      first_cell = hd(cells)
      assert first_cell.cell.fg == :red
    end

    test "applies background color" do
      props = %{text: "Blue", style: %{bg: :blue}}
      result = Label.render(props, @area)

      assert %RenderNode{type: :cells, cells: cells} = result
      first_cell = hd(cells)
      assert first_cell.cell.bg == :blue
    end

    test "applies bold attribute" do
      props = %{text: "Bold", style: %{bold: true}}
      result = Label.render(props, @area)

      assert %RenderNode{type: :cells, cells: cells} = result
      first_cell = hd(cells)
      assert :bold in first_cell.cell.attrs
    end

    test "wraps text when enabled" do
      area = %{x: 0, y: 0, width: 5, height: 3}
      props = %{text: "HelloWorld", wrap: true}
      result = Label.render(props, area)

      assert %RenderNode{type: :cells, cells: cells} = result
      # Should wrap at 5 chars, so "Hello" on row 0, "World" on row 1
      row0_cells = Enum.filter(cells, fn c -> c.y == 0 end)
      row1_cells = Enum.filter(cells, fn c -> c.y == 1 end)

      row0_chars = Enum.map(row0_cells, fn c -> c.cell.char end)
      row1_chars = Enum.map(row1_cells, fn c -> c.cell.char end)

      assert row0_chars == ["H", "e", "l", "l", "o"]
      assert row1_chars == ["W", "o", "r", "l", "d"]
    end

    test "respects area height when wrapping" do
      area = %{x: 0, y: 0, width: 5, height: 1}
      props = %{text: "HelloWorld", wrap: true}
      result = Label.render(props, area)

      assert %RenderNode{type: :cells, cells: cells} = result
      # Only first line should be rendered
      assert Enum.all?(cells, fn c -> c.y == 0 end)
    end

    test "handles empty text" do
      props = %{text: ""}
      result = Label.render(props, @area)

      assert %RenderNode{type: :cells, cells: cells} = result
      # Should render 20 space characters
      assert Enum.all?(cells, fn c -> c.cell.char == " " end)
    end
  end

  describe "describe/0" do
    test "returns component description" do
      assert Label.describe() == "Label widget for displaying text"
    end
  end
end
