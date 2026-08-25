defmodule Showcase.AppTest do
  use ExUnit.Case, async: true

  alias Showcase.App
  alias TermUI.{Command, Event, Frame}

  test "initializes one state owner and a recurring timer" do
    {state, [%Command{kind: :timer, value: {500, :tick}}]} =
      App.init(dimensions: {100, 30})

    assert state.page == :overview
    assert map_size(state.page_states) == length(App.pages())

    frame = App.view(state)
    assert %Frame{width: 100, height: 30} = frame
    assert Frame.row_text(frame, 1) =~ "TermUI Showcase"
  end

  test "all pages render at normal and compact terminal sizes" do
    {initial, _commands} = App.init(dimensions: {100, 30})

    for {page, _label, _module} <- App.pages(), dimensions <- [{100, 30}, {40, 12}] do
      state = {:select_page, page} |> App.update(initial) |> state_from()
      state = %{state | dimensions: dimensions}
      frame = App.view(state)

      assert {frame.width, frame.height} == dimensions
      assert map_size(frame.cells) > 0
    end
  end

  test "routes text only to the active input widget" do
    {state, _commands} = App.init(dimensions: {90, 26})
    state = {:select_page, :inputs} |> App.update(state) |> state_from()

    state =
      {:page_event, Event.text("A")}
      |> App.update(state)
      |> state_from()

    assert state.page_states.inputs.name.value == "A"
    assert state.page_states.inputs.notes.value =~ "TermUI"
  end

  test "a live tick updates only the active page and schedules the next tick" do
    {state, _commands} = App.init(dimensions: {90, 26})
    previous = state.page_states.overview.tick

    {state, [%Command{kind: :timer, value: {500, :tick}}]} = App.update(:tick, state)

    assert state.page_states.overview.tick == previous + 1
  end

  test "Markdown copy output becomes serialized clipboard command data" do
    {state, _commands} = App.init(dimensions: {90, 26})
    state = {:select_page, :content} |> App.update(state) |> state_from()

    {state, [%Command{kind: :clipboard}]} =
      App.update({:page_event, Event.key(:enter)}, state)

    assert state.status == "Copy requested"
  end

  test "function keys select pages and control keys stay global" do
    assert {:msg, {:select_page, :beam}} = App.event_to_msg(Event.key(:f4), %{})
    assert {:msg, :toggle_theme} = App.event_to_msg(Event.key(:f9), %{})
    assert {:msg, :quit} = App.event_to_msg(Event.key(:f10), %{})
    assert {:msg, :quit} = App.event_to_msg(Event.key(:escape), %{})

    assert {:msg, :next_page} =
             App.event_to_msg(Event.key("n", modifiers: [:ctrl]), %{})

    assert {:msg, {:page_event, %Event.Text{text: "n"}}} =
             App.event_to_msg(Event.text("n"), %{})
  end

  defp state_from({state, _commands}), do: state
  defp state_from(state), do: state
end
