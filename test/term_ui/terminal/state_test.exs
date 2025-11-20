defmodule TermUI.Terminal.StateTest do
  use ExUnit.Case, async: true

  alias TermUI.Terminal.State

  describe "new/0" do
    test "creates state with default values" do
      state = State.new()

      assert state.raw_mode_active == false
      assert state.alternate_screen_active == false
      assert state.cursor_visible == true
      assert state.mouse_tracking == :off
      assert state.bracketed_paste == false
      assert state.focus_events == false
      assert state.original_settings == nil
      assert state.size == nil
      assert state.resize_callbacks == []
    end
  end

  describe "new/2" do
    test "creates state with specified size" do
      state = State.new(24, 80)

      assert state.size == {24, 80}
      assert state.raw_mode_active == false
    end

    test "accepts various terminal sizes" do
      state = State.new(50, 200)
      assert state.size == {50, 200}
    end
  end
end
