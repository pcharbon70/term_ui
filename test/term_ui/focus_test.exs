defmodule TermUI.FocusTest do
  use ExUnit.Case, async: true

  alias TermUI.Focus

  describe "enable/0" do
    test "returns correct escape sequence" do
      assert Focus.enable() == "\e[?1004h"
    end
  end

  describe "disable/0" do
    test "returns correct escape sequence" do
      assert Focus.disable() == "\e[?1004l"
    end
  end

  describe "gained_sequence/0" do
    test "returns focus gained sequence" do
      assert Focus.gained_sequence() == "\e[I"
    end
  end

  describe "lost_sequence/0" do
    test "returns focus lost sequence" do
      assert Focus.lost_sequence() == "\e[O"
    end
  end

  describe "supported?/0" do
    test "returns boolean" do
      result = Focus.supported?()
      assert is_boolean(result)
    end
  end

  describe "parse/1" do
    test "parses focus gained sequence" do
      assert Focus.parse("\e[I") == {:focus, :gained}
    end

    test "parses focus lost sequence" do
      assert Focus.parse("\e[O") == {:focus, :lost}
    end

    test "returns nil for non-focus input" do
      assert Focus.parse("hello") == nil
      assert Focus.parse("\e[A") == nil
    end
  end
end

defmodule TermUI.Focus.TrackerTest do
  use ExUnit.Case, async: true

  alias TermUI.Focus.Tracker

  describe "start_link/1" do
    test "starts tracker" do
      {:ok, tracker} = Tracker.start_link()
      assert is_pid(tracker)
    end

    test "starts with registered name" do
      {:ok, _} = Tracker.start_link(name: :test_focus_tracker)
      assert is_pid(Process.whereis(:test_focus_tracker))
      GenServer.stop(:test_focus_tracker)
    end

    test "starts with initial focus state" do
      {:ok, tracker} = Tracker.start_link(initial_focus: false)
      refute Tracker.has_focus?(tracker)
    end
  end

  describe "has_focus?/1" do
    test "returns true by default" do
      {:ok, tracker} = Tracker.start_link()
      assert Tracker.has_focus?(tracker)
    end

    test "returns initial focus state" do
      {:ok, tracker} = Tracker.start_link(initial_focus: false)
      refute Tracker.has_focus?(tracker)
    end
  end

  describe "set_focus/2" do
    test "updates focus state" do
      {:ok, tracker} = Tracker.start_link()

      Tracker.set_focus(tracker, false)
      refute Tracker.has_focus?(tracker)

      Tracker.set_focus(tracker, true)
      assert Tracker.has_focus?(tracker)
    end
  end

  describe "on_focus_gained/2" do
    test "registers and executes action on focus gained" do
      {:ok, tracker} = Tracker.start_link(initial_focus: false)

      test_pid = self()

      Tracker.on_focus_gained(tracker, fn ->
        send(test_pid, :focus_gained)
      end)

      Tracker.set_focus(tracker, true)

      assert_receive :focus_gained, 100
    end

    test "does not execute when focus already gained" do
      {:ok, tracker} = Tracker.start_link(initial_focus: true)

      test_pid = self()

      Tracker.on_focus_gained(tracker, fn ->
        send(test_pid, :focus_gained)
      end)

      Tracker.set_focus(tracker, true)

      refute_receive :focus_gained, 50
    end

    test "registers multiple actions" do
      {:ok, tracker} = Tracker.start_link(initial_focus: false)

      test_pid = self()

      Tracker.on_focus_gained(tracker, fn ->
        send(test_pid, :action1)
      end)

      Tracker.on_focus_gained(tracker, fn ->
        send(test_pid, :action2)
      end)

      Tracker.set_focus(tracker, true)

      assert_receive :action1, 100
      assert_receive :action2, 100
    end
  end

  describe "on_focus_lost/2" do
    test "registers and executes action on focus lost" do
      {:ok, tracker} = Tracker.start_link(initial_focus: true)

      test_pid = self()

      Tracker.on_focus_lost(tracker, fn ->
        send(test_pid, :focus_lost)
      end)

      Tracker.set_focus(tracker, false)

      assert_receive :focus_lost, 100
    end

    test "does not execute when focus already lost" do
      {:ok, tracker} = Tracker.start_link(initial_focus: false)

      test_pid = self()

      Tracker.on_focus_lost(tracker, fn ->
        send(test_pid, :focus_lost)
      end)

      Tracker.set_focus(tracker, false)

      refute_receive :focus_lost, 50
    end
  end

  describe "clear_actions/1" do
    test "clears all registered actions" do
      {:ok, tracker} = Tracker.start_link(initial_focus: false)

      test_pid = self()

      Tracker.on_focus_gained(tracker, fn ->
        send(test_pid, :should_not_receive)
      end)

      Tracker.clear_actions(tracker)
      Tracker.set_focus(tracker, true)

      refute_receive :should_not_receive, 50
    end
  end

  describe "paused?/1 and set_paused/2" do
    test "returns false by default" do
      {:ok, tracker} = Tracker.start_link()
      refute Tracker.paused?(tracker)
    end

    test "sets paused state" do
      {:ok, tracker} = Tracker.start_link()

      Tracker.set_paused(tracker, true)
      assert Tracker.paused?(tracker)

      Tracker.set_paused(tracker, false)
      refute Tracker.paused?(tracker)
    end
  end

  describe "reduced_framerate?/1 and set_reduced_framerate/2" do
    test "returns false by default" do
      {:ok, tracker} = Tracker.start_link()
      refute Tracker.reduced_framerate?(tracker)
    end

    test "sets reduced framerate state" do
      {:ok, tracker} = Tracker.start_link()

      Tracker.set_reduced_framerate(tracker, true)
      assert Tracker.reduced_framerate?(tracker)

      Tracker.set_reduced_framerate(tracker, false)
      refute Tracker.reduced_framerate?(tracker)
    end
  end

  describe "enable_auto_pause/1" do
    test "pauses on focus lost and resumes on focus gained" do
      {:ok, tracker} = Tracker.start_link(initial_focus: true)

      Tracker.enable_auto_pause(tracker)

      refute Tracker.paused?(tracker)

      Tracker.set_focus(tracker, false)
      assert Tracker.paused?(tracker)

      Tracker.set_focus(tracker, true)
      refute Tracker.paused?(tracker)
    end
  end

  describe "enable_auto_reduce_framerate/1" do
    test "reduces framerate on focus lost and restores on focus gained" do
      {:ok, tracker} = Tracker.start_link(initial_focus: true)

      Tracker.enable_auto_reduce_framerate(tracker)

      refute Tracker.reduced_framerate?(tracker)

      Tracker.set_focus(tracker, false)
      assert Tracker.reduced_framerate?(tracker)

      Tracker.set_focus(tracker, true)
      refute Tracker.reduced_framerate?(tracker)
    end
  end

  describe "error handling" do
    test "continues after action raises error" do
      {:ok, tracker} = Tracker.start_link(initial_focus: false)

      test_pid = self()

      # First action raises
      Tracker.on_focus_gained(tracker, fn ->
        raise "boom"
      end)

      # Second action should still execute
      Tracker.on_focus_gained(tracker, fn ->
        send(test_pid, :second_action)
      end)

      Tracker.set_focus(tracker, true)

      assert_receive :second_action, 100
    end
  end

  describe "integration" do
    test "full focus workflow" do
      {:ok, tracker} = Tracker.start_link(initial_focus: true)

      test_pid = self()
      state = %{saved: false, refreshed: false}

      # Register autosave on focus lost
      Tracker.on_focus_lost(tracker, fn ->
        send(test_pid, {:state_update, :saved})
      end)

      # Register refresh on focus gained
      Tracker.on_focus_gained(tracker, fn ->
        send(test_pid, {:state_update, :refreshed})
      end)

      # Enable auto pause
      Tracker.enable_auto_pause(tracker)

      # Lose focus
      Tracker.set_focus(tracker, false)
      assert_receive {:state_update, :saved}, 100
      assert Tracker.paused?(tracker)

      # Gain focus
      Tracker.set_focus(tracker, true)
      assert_receive {:state_update, :refreshed}, 100
      refute Tracker.paused?(tracker)
    end
  end
end
