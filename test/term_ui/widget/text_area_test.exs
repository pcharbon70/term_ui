defmodule TermUI.Widget.TextAreaTest do
  use ExUnit.Case, async: true

  alias TermUI.{Event, Frame, Selection}
  alias TermUI.Widget
  alias TermUI.Widget.TextArea

  test "multiline shift navigation, copy, and replacement use grapheme selection" do
    state = TextArea.init(value: "one\ntwo")
    {state, []} = TextArea.update(Event.key(:left, modifiers: [:shift]), state)
    {state, []} = TextArea.update(Event.key(:left, modifiers: [:shift]), state)

    assert Selection.extract(state.selection, state.value) == "wo"
    assert {state, [{:copy, "wo"}]} = TextArea.update(Event.key("c", modifiers: [:ctrl]), state)

    frame = TextArea.view(state, {8, 2})
    assert :reverse in Frame.cell(frame, 2, 2).attrs
    assert :reverse in Frame.cell(frame, 2, 3).attrs

    assert {state, [{:changed, "one\ntX"}]} = TextArea.update(Event.text("X"), state)
    refute Selection.active?(state.selection)
  end

  test "routed mouse press and drag select a visual line" do
    state = TextArea.init(value: "one\ntwo")

    {state, []} =
      Widget.mouse(TextArea, Event.mouse(:press, :left, 0, 1), state, {8, 2})

    {state, []} =
      Widget.mouse(TextArea, Event.mouse(:drag, :left, 3, 1), state, {8, 2})

    assert Selection.extract(state.selection, state.value) == "two"
    assert state.cursor == 7
  end

  test "select all and cut work across newlines" do
    state = TextArea.init(value: "one\ntwo")
    {state, []} = TextArea.update(Event.key("a", modifiers: [:ctrl]), state)

    assert {state, [{:copy, "one\ntwo"}, {:changed, ""}]} =
             TextArea.update(Event.key("x", modifiers: [:ctrl]), state)

    assert state.cursor == 0
  end
end
