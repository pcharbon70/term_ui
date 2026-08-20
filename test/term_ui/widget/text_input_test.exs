defmodule TermUI.Widget.TextInputTest do
  use ExUnit.Case, async: true

  alias TermUI.{Event, Frame, Selection}
  alias TermUI.Widget
  alias TermUI.Widget.{Button, TextInput}

  test "the parent can own all widget state and messages" do
    state = TextInput.init(placeholder: "name", max_length: 4)
    assert {"name    ", 1} = TextInput.row(state, 8)

    assert {state1, [{:changed, "a界"}]} = TextInput.update(Event.text("a界"), state)
    assert {"a界     ", 4} = TextInput.row(state1, 8)

    frame = TextInput.view(state1, {8, 1})
    assert frame.cursor == {4, 1}
    assert TermUI.Frame.row_text(frame, 1) == "a界     "

    assert {state2, [{:changed, "a"}]} = TextInput.update(Event.key(:backspace), state1)
    assert {state3, [{:submit, "a"}]} = TextInput.update(Event.key(:enter), state2)
    assert state3.value == "a"
  end

  test "paste is sanitized and bounded by graphemes" do
    state = TextInput.init(max_length: 3)
    assert {state1, [{:changed, "abc"}]} = TextInput.update(Event.paste("a\nbcdef"), state)
    assert state1.cursor == 3
  end

  test "shift navigation selects graphemes and input replaces the selection" do
    state = TextInput.init(value: "a界🙂z")
    {state, []} = TextInput.update(Event.key(:left, modifiers: [:shift]), state)
    {state, []} = TextInput.update(Event.key(:left, modifiers: [:shift]), state)

    assert Selection.range(state.selection) == {2, 4}
    assert Selection.extract(state.selection, state.value) == "🙂z"
    assert {state, [{:copy, "🙂z"}]} = TextInput.update(Event.key("c", modifiers: [:ctrl]), state)

    frame = TextInput.view(state, {8, 1})
    assert :reverse in Frame.cell(frame, 1, 4).attrs
    assert :reverse in Frame.cell(frame, 1, 6).attrs

    assert {state, [{:changed, "a界X"}]} = TextInput.update(Event.text("X"), state)
    refute Selection.active?(state.selection)
    assert state.cursor == 3
  end

  test "select all and cut return clipboard data and a changed value" do
    state = TextInput.init(value: "hello")
    {state, []} = TextInput.update(Event.key("a", modifiers: [:ctrl]), state)

    assert {state, [{:copy, "hello"}, {:changed, ""}]} =
             TextInput.update(Event.key("x", modifiers: [:ctrl]), state)

    assert state.cursor == 0
    refute Selection.active?(state.selection)
  end

  test "routed local mouse events set and extend selection" do
    state = TextInput.init(value: "abcd")

    {state, []} =
      Widget.mouse(TextInput, Event.mouse(:press, :left, 0, 0), state, {4, 1})

    {state, []} =
      Widget.mouse(TextInput, Event.mouse(:drag, :left, 3, 0), state, {4, 1})

    assert Selection.extract(state.selection, state.value) == "bc"
    assert state.cursor == 3
  end

  test "widgets without a specialized mouse callback use update" do
    button = Button.init(id: :save, label: "Save")

    assert {_button, [{:pressed, :save}]} =
             Widget.mouse(Button, Event.mouse(:release, :left, 1, 0), button, {10, 1})
  end
end
