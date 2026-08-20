defmodule TermUI.MouseTest do
  use ExUnit.Case, async: true

  alias TermUI.{Event, Mouse}
  alias TermUI.Mouse.Tracker

  test "routes to the top region and creates local coordinates" do
    regions = [
      Mouse.region(:base, 0, 0, 20, 10),
      Mouse.region(:dialog, 5, 2, 8, 4, z_index: 10)
    ]

    event = Event.mouse(:press, :left, 7, 4)

    assert {:ok, :dialog, %Event.Mouse{x: 2, y: 2}} = Mouse.route(regions, event)
    assert {:ok, region, {2, 2}} = Mouse.hit_test(regions, 7, 4)
    assert region.id == :dialog
  end

  test "equal z-index uses the last composed region" do
    regions = [Mouse.region(:first, 0, 0, 5, 5), Mouse.region(:second, 0, 0, 5, 5)]

    assert {:ok, :second, _event} =
             Mouse.route(regions, Event.mouse(:release, :left, 1, 1))
  end

  test "route all preserves front-to-back order" do
    regions = [
      Mouse.region(:base, 0, 0, 10, 10),
      Mouse.region(:overlay, 0, 0, 10, 10, z_index: 1)
    ]

    assert [{:overlay, %Event.Mouse{}}, {:base, %Event.Mouse{}}] =
             Mouse.route_all(regions, Event.mouse(:move, nil, 2, 3))
  end

  test "tracker reports drag deltas and resets on release" do
    tracker = Tracker.new(drag_threshold: 1)

    {tracker, []} = Tracker.update(tracker, Event.mouse(:press, :left, 2, 3))

    {tracker, events} = Tracker.update(tracker, Event.mouse(:drag, :left, 4, 6))

    assert events == [
             {:drag_start, :left, 2, 3},
             {:drag, :left, 4, 6, 2, 3}
           ]

    assert Tracker.dragging?(tracker)

    {tracker, [{:drag_end, :left, 4, 6}]} =
      Tracker.update(tracker, Event.mouse(:release, :left, 4, 6))

    refute Tracker.dragging?(tracker)
  end

  test "tracker reports hover transitions without a process" do
    tracker = Tracker.new()
    {tracker, [{:hover_enter, :one}]} = Tracker.hover(tracker, :one)

    {tracker, [{:hover_leave, :one}, {:hover_enter, :two}]} =
      Tracker.hover(tracker, :two)

    assert Tracker.hovered(tracker) == :two
  end
end
