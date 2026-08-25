defmodule Showcase.AppTest do
  use ExUnit.Case, async: true

  alias Showcase.{App, LiveData, SnapshotData}
  alias TermUI.{Command, Event, Frame}

  test "live mode initializes one state owner, one collection, and a recurring timer" do
    {state, commands} = App.init(dimensions: {100, 30})

    assert state.page == :overview
    assert state.data_mode == :live
    assert state.refreshing
    assert map_size(state.page_states) == length(App.pages())

    assert [%Command{kind: :async}, %Command{kind: :timer, value: {1_000, :refresh_timer}}] =
             commands

    frame = App.view(state)
    assert %Frame{width: 100, height: 30} = frame
    assert Frame.row_text(frame, 1) =~ "TermUI Showcase"
    assert Frame.row_text(frame, 2) =~ "1 Overview"
  end

  test "all pages render at normal and compact terminal sizes" do
    initial = App.init(dimensions: {100, 30}, data_mode: :snapshot)

    for {page, _label, _module} <- App.pages(), dimensions <- [{100, 30}, {40, 12}] do
      state = {:select_page, page} |> App.update(initial) |> state_from()
      state = %{state | dimensions: dimensions}
      frame = App.view(state)

      assert {frame.width, frame.height} == dimensions
      assert map_size(frame.cells) > 0
    end
  end

  test "routes text only to the active input widget" do
    state = App.init(dimensions: {90, 26}, data_mode: :snapshot)
    state = {:select_page, :inputs} |> App.update(state) |> state_from()

    state =
      {:page_event, Event.text("A")}
      |> App.update(state)
      |> state_from()

    assert state.page_states.inputs.name.value == "A"
    assert state.page_states.inputs.notes.value =~ "TermUI"
  end

  test "a live snapshot updates every data page" do
    {state, _commands} = App.init(dimensions: {90, 26})
    snapshot = SnapshotData.snapshot()

    state = App.update({:live_snapshot, {:ok, snapshot}}, state)

    refute state.refreshing
    assert state.last_snapshot == snapshot
    assert state.page_states.overview.refreshes == 1
    assert state.page_states.content.refreshes == 1
    assert state.page_states.beam.processes.snapshots == snapshot.processes
    assert state.page_states.beam.cluster.nodes == snapshot.cluster
  end

  test "the refresh timer starts collection without overlapping work" do
    {state, _commands} = App.init(dimensions: {90, 26})

    {^state, [%Command{kind: :timer, value: {1_000, :refresh_timer}}]} =
      App.update(:refresh_timer, state)

    state = App.update({:live_snapshot, {:ok, SnapshotData.snapshot()}}, state)
    {state, commands} = App.update(:refresh_timer, state)

    assert state.refreshing
    assert [%Command{kind: :async}, %Command{kind: :timer}] = commands
  end

  test "Markdown copy output becomes serialized clipboard command data" do
    state = App.init(dimensions: {90, 26}, data_mode: :snapshot)
    state = {:select_page, :content} |> App.update(state) |> state_from()

    {state, [%Command{kind: :clipboard}]} =
      App.update({:page_event, Event.key(:enter)}, state)

    assert state.status == "Copy requested"
  end

  test "the Escape command menu and control keys replace function-key navigation" do
    state = App.init(dimensions: {90, 26}, data_mode: :snapshot)
    assert {:msg, :toggle_command_mode} = App.event_to_msg(Event.key(:escape), state)

    state = App.update(:toggle_command_mode, state)
    assert state.command_mode
    assert {:msg, {:command_key, "4"}} = App.event_to_msg(Event.text("4"), state)

    state = App.update({:command_key, "4"}, state)
    assert state.page == :beam
    refute state.command_mode

    assert {:msg, :next_page} =
             App.event_to_msg(Event.key("n", modifiers: [:ctrl]), %{})

    assert {:msg, :previous_page} =
             App.event_to_msg(Event.key("p", modifiers: [:ctrl]), %{})

    assert {:msg, :refresh} = App.event_to_msg(Event.key("r", modifiers: [:ctrl]), %{})
    assert {:msg, :toggle_theme} = App.event_to_msg(Event.key("t", modifiers: [:ctrl]), %{})
    assert {:msg, :quit} = App.event_to_msg(Event.key("q", modifiers: [:ctrl]), %{})

    assert {:msg, :next_page} =
             App.event_to_msg(Event.key(:right, modifiers: [:ctrl]), %{})

    assert {:msg, {:page_event, %Event.Key{key: :f4}}} =
             App.event_to_msg(Event.key(:f4), %{})

    assert {:msg, {:page_event, %Event.Text{text: "n"}}} =
             App.event_to_msg(Event.text("n"), %{})
  end

  test "the collector returns current local BEAM data" do
    snapshot = LiveData.collect(self())

    assert snapshot.system.process_count > 0
    assert snapshot.system.memory.total > 0
    assert Enum.any?(snapshot.processes, &(&1.pid == inspect(self())))
    assert Enum.any?(snapshot.cluster, &(&1.node == node()))
    assert [%{id: :runtime, children: children}] = snapshot.runtime_tree
    assert is_list(children)
  end

  defp state_from({state, _commands}), do: state
  defp state_from(state), do: state
end
