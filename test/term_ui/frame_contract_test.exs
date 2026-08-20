defmodule TermUI.FrameContractTest do
  use ExUnit.Case, async: true

  alias TermUI.{Cell, Frame, Style}

  test "normalizes existing cells before they reach a backend" do
    unsafe = %Cell{char: "\e]52;c;payload\a", width: 1}
    frame = Frame.new(4, 1, cells: %{{1, 1} => unsafe})

    assert Frame.row_text(frame, 1) == "    "
    refute inspect(Frame.cells(frame)) =~ "52;c"
  end

  test "normalizes text, wide graphemes, combining graphemes, and the cursor" do
    frame = Frame.from_rows(["a界b", "e\u0301"], 4, 2, cursor: {99, 2})

    assert frame.width == 4
    assert frame.height == 2
    assert frame.cursor == {4, 2}
    assert %Cell{char: "界", width: 2} = Frame.cell(frame, 1, 2)
    assert %Cell{wide_placeholder: true} = Frame.cell(frame, 1, 3)
    assert %Cell{char: "e\u0301", width: 1} = Frame.cell(frame, 2, 1)
    assert Frame.row_text(frame, 1) == "a界b"
  end

  test "accepts styled spans as the same cell frame representation" do
    style = Style.new() |> Style.fg(:green) |> Style.bold()
    frame = Frame.from_rows([[{"ok", style}, "!"]], 4, 1)

    assert %Cell{char: "o", fg: :green, attrs: attrs} = Frame.cell(frame, 1, 1)
    assert :bold in attrs
    assert Frame.row_text(frame, 1) == "ok! "
  end

  test "safe tiny frames and frame comparison clear old content" do
    old = Frame.from_rows(["x"], 1, 1)
    new = Frame.from_rows([""], 1, 1, cursor: {9, 9})

    assert new.cursor == {1, 1}
    assert Frame.diff(old, new) == [{{1, 1}, {" ", :default, :default, []}}]
  end

  test "one cell contains one grapheme and updates its display width" do
    assert %Cell{char: "a", width: 1} = Cell.new("abc")
    assert %Cell{char: "界", width: 2} = Cell.put_char(Cell.new("a"), "界more")
  end

  test "overlays one canonical frame and moves its cursor" do
    base = Frame.from_rows(["xxxx", "xxxx"], 4, 2)
    child = Frame.from_rows(["界"], 2, 1, cursor: {1, 1})
    frame = Frame.overlay(base, child, 2, 2)

    assert Frame.row_text(frame, 1) == "xxxx"
    assert Frame.row_text(frame, 2) == "x界x"
    assert frame.cursor == {2, 2}
  end
end
