defmodule TermUI.Widget.DiffViewerTest do
  use ExUnit.Case, async: true

  alias TermUI.{Event, Frame}
  alias TermUI.Widget.DiffViewer

  test "compares two texts with line numbers and changed-line pairing" do
    state = DiffViewer.init(before: "same\nold\nend", after: "same\nnew\nend", context: 3)

    assert Enum.any?(
             state.rows,
             &(&1.kind == :changed and &1.old_text == "old" and &1.new_text == "new")
           )

    frame = DiffViewer.view(state, {50, 10})
    text = Enum.map_join(1..frame.height, "\n", &Frame.row_text(frame, &1))
    assert text =~ "-old"
    assert text =~ "+new"
  end

  test "switches to a side-by-side frame" do
    state = DiffViewer.init(before: "old", after: "new")
    assert {state, [{:mode, :split}]} = DiffViewer.update(Event.text("s"), state)

    frame = DiffViewer.view(state, {60, 5})
    assert Frame.row_text(frame, 1) =~ "before"
    assert Frame.row_text(frame, 1) =~ "after"
    assert Frame.row_text(frame, 2) =~ "old"
    assert Frame.row_text(frame, 2) =~ "new"
  end

  test "renders an existing unified diff and collapses long context" do
    diff = """
    --- a/file
    +++ b/file
    @@ -1,8 +1,8 @@
     one
     two
     three
     four
    -old
    +new
     five
     six
    """

    state = DiffViewer.init(unified_diff: diff, context: 1)
    assert Enum.any?(state.rows, &(&1.kind == :fold))
    assert %Frame{} = DiffViewer.view(state, {50, 12})
  end

  test "unified parsing removes only one content marker" do
    diff = """
    --- a/file
    +++ b/file
    @@ -1,3 +1,3 @@
    +++literal
    ---literal
       indented
    """

    state = DiffViewer.init(unified_diff: diff, context: 3)

    assert Enum.any?(state.rows, &(&1.kind == :added and &1.new_text == "++literal"))
    assert Enum.any?(state.rows, &(&1.kind == :removed and &1.old_text == "--literal"))

    assert Enum.any?(
             state.rows,
             &(&1.kind == :context and &1.old_text == "  indented")
           )
  end

  test "file-header text inside a hunk remains added or removed content" do
    diff = """
    --- a/file
    +++ b/file
    @@ -1 +1 @@
    --- literal
    +++ literal
    """

    state = DiffViewer.init(unified_diff: diff, context: 3)

    assert Enum.any?(state.rows, &(&1.kind == :removed and &1.old_text == "-- literal"))
    assert Enum.any?(state.rows, &(&1.kind == :added and &1.new_text == "++ literal"))
  end
end
