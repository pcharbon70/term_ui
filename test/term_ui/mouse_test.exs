defmodule TermUI.MouseTest do
  use ExUnit.Case, async: true

  alias TermUI.Mouse

  describe "enable_mouse/0" do
    test "returns escape sequences for normal tracking with SGR" do
      seq = Mouse.enable_mouse()
      assert seq =~ "\e[?1000h"
      assert seq =~ "\e[?1006h"
    end
  end

  describe "enable_mouse_button/0" do
    test "returns escape sequences for button motion tracking" do
      seq = Mouse.enable_mouse_button()
      assert seq =~ "\e[?1002h"
      assert seq =~ "\e[?1006h"
    end
  end

  describe "enable_mouse_motion/0" do
    test "returns escape sequences for all motion tracking" do
      seq = Mouse.enable_mouse_motion()
      assert seq =~ "\e[?1003h"
      assert seq =~ "\e[?1006h"
    end
  end

  describe "disable_mouse/0" do
    test "returns escape sequences to disable all tracking" do
      seq = Mouse.disable_mouse()
      assert seq =~ "\e[?1006l"
      assert seq =~ "\e[?1003l"
      assert seq =~ "\e[?1002l"
      assert seq =~ "\e[?1000l"
    end
  end

  describe "sgr_extended_on/0" do
    test "returns SGR Extended mode sequence" do
      assert Mouse.sgr_extended_on() == "\e[?1006h"
    end
  end

  describe "scroll_action?/1" do
    test "returns true for scroll actions" do
      assert Mouse.scroll_action?(:scroll_up)
      assert Mouse.scroll_action?(:scroll_down)
    end

    test "returns false for non-scroll actions" do
      refute Mouse.scroll_action?(:press)
      refute Mouse.scroll_action?(:move)
    end
  end

  describe "click_action?/1" do
    test "returns true for click actions" do
      assert Mouse.click_action?(:press)
      assert Mouse.click_action?(:release)
      assert Mouse.click_action?(:click)
    end

    test "returns false for non-click actions" do
      refute Mouse.click_action?(:move)
      refute Mouse.click_action?(:scroll_up)
    end
  end

  describe "motion_action?/1" do
    test "returns true for motion actions" do
      assert Mouse.motion_action?(:move)
      assert Mouse.motion_action?(:drag)
    end

    test "returns false for non-motion actions" do
      refute Mouse.motion_action?(:press)
      refute Mouse.motion_action?(:scroll_up)
    end
  end

  describe "default_scroll_lines/0" do
    test "returns default scroll amount" do
      assert Mouse.default_scroll_lines() == 3
    end
  end
end

defmodule TermUI.Mouse.TrackerTest do
  use ExUnit.Case, async: true

  alias TermUI.Mouse.Tracker
  alias TermUI.Event

  describe "new/1" do
    test "creates new tracker with defaults" do
      tracker = Tracker.new()

      refute Tracker.dragging?(tracker)
      assert Tracker.button_down(tracker) == nil
      assert Tracker.hovered_component(tracker) == nil
    end

    test "accepts drag threshold option" do
      tracker = Tracker.new(drag_threshold: 10)
      assert tracker.drag_threshold == 10
    end
  end

  describe "process/2 with press" do
    test "records button down and position" do
      tracker = Tracker.new()
      event = Event.mouse(:press, :left, 10, 20)

      {tracker, events} = Tracker.process(tracker, event)

      assert Tracker.button_down(tracker) == :left
      assert tracker.press_position == {10, 20}
      assert events == []
    end
  end

  describe "process/2 with release" do
    test "clears button down state" do
      tracker = Tracker.new()
      press = Event.mouse(:press, :left, 10, 20)
      release = Event.mouse(:release, :left, 10, 20)

      {tracker, _} = Tracker.process(tracker, press)
      {tracker, events} = Tracker.process(tracker, release)

      assert Tracker.button_down(tracker) == nil
      assert events == []
    end

    test "emits drag_end if dragging" do
      tracker = Tracker.new(drag_threshold: 1)
      press = Event.mouse(:press, :left, 10, 20)
      move = Event.mouse(:move, nil, 15, 25)
      release = Event.mouse(:release, :left, 15, 25)

      {tracker, _} = Tracker.process(tracker, press)
      {tracker, _} = Tracker.process(tracker, move)
      {tracker, events} = Tracker.process(tracker, release)

      assert events == [{:drag_end, :left, 15, 25}]
      refute Tracker.dragging?(tracker)
    end
  end

  describe "process/2 with move" do
    test "starts drag when threshold exceeded" do
      tracker = Tracker.new(drag_threshold: 3)
      press = Event.mouse(:press, :left, 10, 20)
      move = Event.mouse(:move, nil, 15, 20)

      {tracker, _} = Tracker.process(tracker, press)
      {tracker, events} = Tracker.process(tracker, move)

      assert Tracker.dragging?(tracker)
      assert [{:drag_start, :left, 10, 20}, {:drag_move, :left, 15, 20, 5, 0}] = events
    end

    test "does not start drag before threshold" do
      tracker = Tracker.new(drag_threshold: 10)
      press = Event.mouse(:press, :left, 10, 20)
      move = Event.mouse(:move, nil, 12, 21)

      {tracker, _} = Tracker.process(tracker, press)
      {tracker, events} = Tracker.process(tracker, move)

      refute Tracker.dragging?(tracker)
      assert events == []
    end

    test "emits drag_move when already dragging" do
      tracker = Tracker.new(drag_threshold: 1)
      press = Event.mouse(:press, :left, 10, 20)
      move1 = Event.mouse(:move, nil, 15, 25)
      move2 = Event.mouse(:move, nil, 20, 30)

      {tracker, _} = Tracker.process(tracker, press)
      {tracker, _} = Tracker.process(tracker, move1)
      {tracker, events} = Tracker.process(tracker, move2)

      assert [{:drag_move, :left, 20, 30, 5, 5}] = events
    end

    test "no events when no button pressed" do
      tracker = Tracker.new()
      move = Event.mouse(:move, nil, 10, 20)

      {_tracker, events} = Tracker.process(tracker, move)

      assert events == []
    end
  end

  describe "update_hover/2" do
    test "emits enter event when hovering new component" do
      tracker = Tracker.new()

      {tracker, events} = Tracker.update_hover(tracker, :button1)

      assert Tracker.hovered_component(tracker) == :button1
      assert events == [{:hover_enter, :button1}]
    end

    test "emits leave then enter when changing component" do
      tracker = Tracker.new()

      {tracker, _} = Tracker.update_hover(tracker, :button1)
      {tracker, events} = Tracker.update_hover(tracker, :button2)

      assert Tracker.hovered_component(tracker) == :button2
      assert events == [{:hover_leave, :button1}, {:hover_enter, :button2}]
    end

    test "emits leave event when leaving component" do
      tracker = Tracker.new()

      {tracker, _} = Tracker.update_hover(tracker, :button1)
      {tracker, events} = Tracker.update_hover(tracker, nil)

      assert Tracker.hovered_component(tracker) == nil
      assert events == [{:hover_leave, :button1}]
    end

    test "no events when component unchanged" do
      tracker = Tracker.new()

      {tracker, _} = Tracker.update_hover(tracker, :button1)
      {_tracker, events} = Tracker.update_hover(tracker, :button1)

      assert events == []
    end
  end

  describe "reset_drag/1" do
    test "clears drag state" do
      tracker = Tracker.new(drag_threshold: 1)
      press = Event.mouse(:press, :left, 10, 20)
      move = Event.mouse(:move, nil, 15, 25)

      {tracker, _} = Tracker.process(tracker, press)
      {tracker, _} = Tracker.process(tracker, move)

      assert Tracker.dragging?(tracker)

      tracker = Tracker.reset_drag(tracker)

      refute Tracker.dragging?(tracker)
      assert Tracker.button_down(tracker) == nil
    end
  end
end

defmodule TermUI.Mouse.RouterTest do
  use ExUnit.Case, async: true

  alias TermUI.Mouse.Router
  alias TermUI.Event

  describe "hit_test/3" do
    test "finds component at position" do
      components = %{
        button1: %{bounds: %{x: 0, y: 0, width: 10, height: 5}, z_index: 0}
      }

      assert {_, _, _} = Router.hit_test(components, 5, 2)
    end

    test "returns nil when no component at position" do
      components = %{
        button1: %{bounds: %{x: 0, y: 0, width: 10, height: 5}, z_index: 0}
      }

      assert nil == Router.hit_test(components, 20, 20)
    end

    test "returns topmost component when overlapping" do
      components = %{
        bottom: %{bounds: %{x: 0, y: 0, width: 20, height: 20}, z_index: 0},
        top: %{bounds: %{x: 5, y: 5, width: 10, height: 10}, z_index: 1}
      }

      {id, _, _} = Router.hit_test(components, 10, 10)
      assert id == :top
    end

    test "returns local coordinates" do
      components = %{
        button: %{bounds: %{x: 10, y: 20, width: 30, height: 15}, z_index: 0}
      }

      {_id, local_x, local_y} = Router.hit_test(components, 15, 25)
      assert local_x == 5
      assert local_y == 5
    end
  end

  describe "route/2" do
    test "routes event to component with transformed coordinates" do
      components = %{
        button: %{bounds: %{x: 10, y: 20, width: 30, height: 15}, z_index: 0}
      }

      event = Event.mouse(:click, :left, 15, 25)
      {id, transformed} = Router.route(components, event)

      assert id == :button
      assert transformed.x == 5
      assert transformed.y == 5
      assert transformed.action == :click
    end

    test "returns nil when no component at position" do
      components = %{
        button: %{bounds: %{x: 10, y: 20, width: 30, height: 15}, z_index: 0}
      }

      event = Event.mouse(:click, :left, 0, 0)
      assert nil == Router.route(components, event)
    end
  end

  describe "hit_test_all/3" do
    test "returns all components at position ordered by z-index" do
      components = %{
        bottom: %{bounds: %{x: 0, y: 0, width: 20, height: 20}, z_index: 0},
        middle: %{bounds: %{x: 0, y: 0, width: 20, height: 20}, z_index: 1},
        top: %{bounds: %{x: 0, y: 0, width: 20, height: 20}, z_index: 2}
      }

      results = Router.hit_test_all(components, 10, 10)
      ids = Enum.map(results, fn {id, _, _} -> id end)

      assert ids == [:top, :middle, :bottom]
    end
  end

  describe "to_local/3" do
    test "transforms global to local coordinates" do
      bounds = %{x: 10, y: 20, width: 30, height: 15}

      {local_x, local_y} = Router.to_local(bounds, 25, 30)

      assert local_x == 15
      assert local_y == 10
    end
  end

  describe "to_global/3" do
    test "transforms local to global coordinates" do
      bounds = %{x: 10, y: 20, width: 30, height: 15}

      {global_x, global_y} = Router.to_global(bounds, 5, 5)

      assert global_x == 15
      assert global_y == 25
    end
  end

  describe "point_in_bounds?/3" do
    test "returns true for point inside bounds" do
      bounds = %{x: 10, y: 20, width: 30, height: 15}

      assert Router.point_in_bounds?(15, 25, bounds)
      assert Router.point_in_bounds?(10, 20, bounds)  # top-left corner
      assert Router.point_in_bounds?(39, 34, bounds)  # just inside bottom-right
    end

    test "returns false for point outside bounds" do
      bounds = %{x: 10, y: 20, width: 30, height: 15}

      refute Router.point_in_bounds?(5, 25, bounds)   # left
      refute Router.point_in_bounds?(50, 25, bounds)  # right
      refute Router.point_in_bounds?(15, 10, bounds)  # above
      refute Router.point_in_bounds?(15, 40, bounds)  # below
      refute Router.point_in_bounds?(40, 35, bounds)  # bottom-right (exclusive)
    end
  end

  describe "bounds_overlap?/2" do
    test "returns true for overlapping bounds" do
      a = %{x: 0, y: 0, width: 20, height: 20}
      b = %{x: 10, y: 10, width: 20, height: 20}

      assert Router.bounds_overlap?(a, b)
    end

    test "returns false for non-overlapping bounds" do
      a = %{x: 0, y: 0, width: 10, height: 10}
      b = %{x: 20, y: 20, width: 10, height: 10}

      refute Router.bounds_overlap?(a, b)
    end

    test "returns false for adjacent bounds" do
      a = %{x: 0, y: 0, width: 10, height: 10}
      b = %{x: 10, y: 0, width: 10, height: 10}

      refute Router.bounds_overlap?(a, b)
    end
  end

  describe "clip_to_bounds/3" do
    test "clips coordinates to be within bounds" do
      bounds = %{x: 10, y: 20, width: 30, height: 15}

      # Inside - unchanged
      assert Router.clip_to_bounds(15, 25, bounds) == {15, 25}

      # Outside left
      assert Router.clip_to_bounds(5, 25, bounds) == {10, 25}

      # Outside right
      assert Router.clip_to_bounds(50, 25, bounds) == {39, 25}

      # Outside above
      assert Router.clip_to_bounds(15, 10, bounds) == {15, 20}

      # Outside below
      assert Router.clip_to_bounds(15, 50, bounds) == {15, 34}
    end
  end
end
