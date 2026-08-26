defmodule TermUI.LayoutTest do
  use ExUnit.Case, async: true

  alias TermUI.{Frame, Layout, Mouse}

  test "creates, insets, and clips zero-based rectangles" do
    root = Layout.new({12, 8})

    assert root == {0, 0, 12, 8}
    assert Layout.dimensions(root) == {12, 8}
    assert Layout.inset(root, 2) == {2, 2, 8, 4}
    assert Layout.inset(root, {1, 2, 3, 4}) == {4, 1, 6, 4}
    assert Layout.inset(root, {20, 20, 20, 20}) == {12, 8, 0, 0}
    assert Layout.at({2, 3, 5, 4}, {3, 2}, {8, 8}) == {5, 5, 2, 2}
  end

  test "allocates fixed and weighted row tracks with stable remainders" do
    assert Layout.row({2, 3, 11, 4}, [3, :fill, {:weight, 2}], gap: 1) == [
             {2, 3, 3, 4},
             {6, 3, 2, 4},
             {9, 3, 4, 4}
           ]

    assert Layout.row({0, 0, 7, 1}, [:fill, :fill, :fill]) == [
             {0, 0, 3, 1},
             {3, 0, 2, 1},
             {5, 0, 2, 1}
           ]

    assert Layout.column({0, 0, 2, 5}, [{:weight, 3}, :fill]) == [
             {0, 0, 2, 4},
             {0, 4, 2, 1}
           ]

    assert Layout.row({0, 0, 5, 1}, []) == []
  end

  test "keeps zero-sized overflow tracks inside the parent" do
    assert Layout.row({0, 0, 5, 2}, [4, 4, :fill], gap: 2) == [
             {0, 0, 1, 2},
             {3, 0, 0, 2},
             {5, 0, 0, 2}
           ]

    assert Layout.column({1, 2, 3, 4}, [4, 4], gap: 3) == [
             {1, 2, 3, 1},
             {1, 6, 3, 0}
           ]
  end

  test "builds a row-major grid and handles empty input" do
    assert Layout.grid({0, 0, 9, 5}, 5, columns: 3, column_gap: 1, row_gap: 1) == [
             {0, 0, 3, 2},
             {4, 0, 2, 2},
             {7, 0, 2, 2},
             {0, 3, 3, 2},
             {4, 3, 2, 2}
           ]

    assert Layout.grid({0, 0, 9, 5}, 0) == []
    assert Layout.grid({0, 0, 10, 4}, 1, columns: 2) == [{0, 0, 5, 4}]
    assert Layout.grid({0, 0, 10, 4}, 1, columns: 2, rows: 2) == [{0, 0, 5, 2}]
    assert Layout.grid({0, 0, 9, 5}, 1, columns: 100_000_000) == [{0, 0, 1, 5}]

    assert length(Layout.grid({0, 0, 8, 4}, 5, columns: 2, rows: 2)) == 4

    assert_raise ArgumentError, fn -> Layout.grid({0, 0, 9, 5}, 1, columns: 0) end
    assert_raise ArgumentError, fn -> Layout.grid({0, 0, 9, 5}, 1, rows: 0) end
    assert_raise ArgumentError, fn -> Layout.row({0, 0, 9, 5}, [:fill], gap: 1.5) end
  end

  test "places clipped frames and creates matching mouse regions" do
    base = Frame.new(6, 3)
    child = Frame.from_rows(["abcd", "efgh"], 4, 2)
    frame = Layout.place(base, child, {4, 1, 4, 2})

    assert Frame.row_text(frame, 2) == "    ab"
    assert Frame.row_text(frame, 3) == "    ef"

    region = Layout.region(:body, {4, 1, 2, 2}, z_index: 3, metadata: %{kind: :panel})
    assert region.z_index == 3
    assert region.metadata == %{kind: :panel}
    assert Mouse.contains?(region, 5, 2)
    assert Layout.region(:empty, {0, 0, 0, 2}) == nil
    assert Layout.region(:empty, {0, 0, 2, 0}) == nil
    assert Layout.place(frame, child, {0, 0, 0, 2}) == frame
    assert Layout.place(frame, child, {0, 0, 2, 0}) == frame
    assert Layout.place(frame, child, {99, 99, 10_000, 10_000}) == frame

    oversized = Layout.place(Frame.new(2, 2), child, {1, 1, 10_000, 10_000})
    assert Frame.cell(oversized, 2, 2).char == "a"
  end
end
