defmodule TermUI.Helpers.BorderHelperTest do
  use ExUnit.Case, async: true

  alias TermUI.Helpers.BorderHelper

  describe "horizontal_line/1" do
    test "creates line of specified width" do
      line = BorderHelper.horizontal_line(5)
      assert String.length(line) == 5
    end

    test "creates empty string for width 0" do
      assert BorderHelper.horizontal_line(0) == ""
    end

    test "uses unicode characters by default" do
      Application.put_env(:term_ui, :character_set, :unicode)
      line = BorderHelper.horizontal_line(3)
      assert line == "───"
    end

    test "uses ascii characters when configured" do
      Application.put_env(:term_ui, :character_set, :ascii)
      line = BorderHelper.horizontal_line(3)
      assert line == "---"
      Application.put_env(:term_ui, :character_set, :unicode)
    end
  end

  describe "vertical_line/1" do
    test "creates list of vertical characters" do
      lines = BorderHelper.vertical_line(3)
      assert length(lines) == 3
    end

    test "creates empty list for height 0" do
      assert BorderHelper.vertical_line(0) == []
    end

    test "uses unicode characters by default" do
      Application.put_env(:term_ui, :character_set, :unicode)
      lines = BorderHelper.vertical_line(2)
      assert lines == ["│", "│"]
    end

    test "uses ascii characters when configured" do
      Application.put_env(:term_ui, :character_set, :ascii)
      lines = BorderHelper.vertical_line(2)
      assert lines == ["|", "|"]
      Application.put_env(:term_ui, :character_set, :unicode)
    end
  end

  describe "box_top/1" do
    test "creates top border with corners" do
      Application.put_env(:term_ui, :character_set, :unicode)
      top = BorderHelper.box_top(10)
      assert String.starts_with?(top, "┌")
      assert String.ends_with?(top, "┐")
      assert String.length(top) == 10
    end

    test "creates ascii top border" do
      Application.put_env(:term_ui, :character_set, :ascii)
      top = BorderHelper.box_top(10)
      assert String.starts_with?(top, "+")
      assert String.ends_with?(top, "+")
      assert String.length(top) == 10
      Application.put_env(:term_ui, :character_set, :unicode)
    end

    test "handles minimum width of 2" do
      top = BorderHelper.box_top(2)
      # Just corners, no inner line
      assert String.length(top) == 2
    end

    test "handles width of 1" do
      top = BorderHelper.box_top(1)
      assert String.length(top) == 1
    end
  end

  describe "box_bottom/1" do
    test "creates bottom border with corners" do
      Application.put_env(:term_ui, :character_set, :unicode)
      bottom = BorderHelper.box_bottom(10)
      assert String.starts_with?(bottom, "└")
      assert String.ends_with?(bottom, "┘")
      assert String.length(bottom) == 10
    end

    test "creates ascii bottom border" do
      Application.put_env(:term_ui, :character_set, :ascii)
      bottom = BorderHelper.box_bottom(10)
      assert String.starts_with?(bottom, "+")
      assert String.ends_with?(bottom, "+")
      Application.put_env(:term_ui, :character_set, :unicode)
    end
  end

  describe "box_top_round/1" do
    test "creates rounded top border" do
      Application.put_env(:term_ui, :character_set, :unicode)
      top = BorderHelper.box_top_round(10)
      assert String.starts_with?(top, "╭")
      assert String.ends_with?(top, "╮")
      assert String.length(top) == 10
    end
  end

  describe "box_bottom_round/1" do
    test "creates rounded bottom border" do
      Application.put_env(:term_ui, :character_set, :unicode)
      bottom = BorderHelper.box_bottom_round(10)
      assert String.starts_with?(bottom, "╰")
      assert String.ends_with?(bottom, "╯")
      assert String.length(bottom) == 10
    end
  end

  describe "left_border/1" do
    test "creates left border without content" do
      Application.put_env(:term_ui, :character_set, :unicode)
      border = BorderHelper.left_border()
      assert border == "│"
    end

    test "creates left border with content" do
      Application.put_env(:term_ui, :character_set, :unicode)
      border = BorderHelper.left_border(" Hello")
      assert border == "│ Hello"
    end
  end

  describe "right_border/1" do
    test "creates right border without content" do
      Application.put_env(:term_ui, :character_set, :unicode)
      border = BorderHelper.right_border()
      assert border == "│"
    end

    test "creates right border with content" do
      Application.put_env(:term_ui, :character_set, :unicode)
      border = BorderHelper.right_border("Hello ")
      assert border == "Hello │"
    end
  end

  describe "bordered_row/3" do
    setup do
      Application.put_env(:term_ui, :character_set, :unicode)
      :ok
    end

    test "creates row with borders and content" do
      row = BorderHelper.bordered_row("Hello", 12)
      assert String.starts_with?(row, "│")
      assert String.ends_with?(row, "│")
      assert String.contains?(row, "Hello")
      assert String.length(row) == 12
    end

    test "pads content to fill width (left align)" do
      row = BorderHelper.bordered_row("Hi", 10)
      assert row == "│Hi      │"
    end

    test "right aligns content" do
      row = BorderHelper.bordered_row("Hi", 10, align: :right)
      assert row == "│      Hi│"
    end

    test "center aligns content" do
      row = BorderHelper.bordered_row("Hi", 10, align: :center)
      assert row == "│   Hi   │"
    end

    test "truncates content if too long" do
      row = BorderHelper.bordered_row("Hello World", 8)
      # Width 8 = 2 borders + 6 inner
      assert String.length(row) == 8
      assert String.starts_with?(row, "│")
      assert String.ends_with?(row, "│")
    end

    test "handles minimum width" do
      row = BorderHelper.bordered_row("Hi", 2)
      assert row == "││"
    end
  end
end
