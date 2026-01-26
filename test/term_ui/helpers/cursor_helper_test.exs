defmodule TermUI.Helpers.CursorHelperTest do
  use ExUnit.Case, async: true

  alias TermUI.Helpers.CursorHelper

  describe "move_down/4" do
    test "moves cursor down by one" do
      assert CursorHelper.move_down(0, 1, 4) == 1
      assert CursorHelper.move_down(2, 1, 4) == 3
    end

    test "moves cursor down by multiple positions" do
      assert CursorHelper.move_down(0, 3, 4) == 3
      assert CursorHelper.move_down(1, 2, 4) == 3
    end

    test "clamps to max when exceeding" do
      assert CursorHelper.move_down(4, 1, 4) == 4
      assert CursorHelper.move_down(3, 5, 4) == 4
    end

    test "wraps to beginning when enabled" do
      assert CursorHelper.move_down(4, 1, 4, wrap: true) == 0
      assert CursorHelper.move_down(3, 3, 4, wrap: true) == 1
    end

    test "handles step of 0" do
      assert CursorHelper.move_down(2, 0, 4) == 2
    end
  end

  describe "move_up/4" do
    test "moves cursor up by one" do
      assert CursorHelper.move_up(2, 1, 4) == 1
      assert CursorHelper.move_up(4, 1, 4) == 3
    end

    test "moves cursor up by multiple positions" do
      assert CursorHelper.move_up(4, 3, 4) == 1
      assert CursorHelper.move_up(3, 2, 4) == 1
    end

    test "clamps to 0 when going below" do
      assert CursorHelper.move_up(0, 1, 4) == 0
      assert CursorHelper.move_up(1, 5, 4) == 0
    end

    test "wraps to end when enabled" do
      assert CursorHelper.move_up(0, 1, 4, wrap: true) == 4
      assert CursorHelper.move_up(0, 2, 4, wrap: true) == 3
    end

    test "handles step of 0" do
      assert CursorHelper.move_up(2, 0, 4) == 2
    end
  end

  describe "clamp_cursor/3" do
    test "clamps cursor above max" do
      assert CursorHelper.clamp_cursor(5, 0, 3) == 3
      assert CursorHelper.clamp_cursor(10, 0, 3) == 3
    end

    test "clamps cursor below min" do
      assert CursorHelper.clamp_cursor(-1, 0, 3) == 0
      assert CursorHelper.clamp_cursor(-10, 0, 3) == 0
    end

    test "returns cursor when in range" do
      assert CursorHelper.clamp_cursor(0, 0, 3) == 0
      assert CursorHelper.clamp_cursor(2, 0, 3) == 2
      assert CursorHelper.clamp_cursor(3, 0, 3) == 3
    end

    test "handles custom min" do
      assert CursorHelper.clamp_cursor(0, 1, 5) == 1
      assert CursorHelper.clamp_cursor(3, 1, 5) == 3
    end
  end

  describe "wrap_cursor/3" do
    test "wraps cursor above max" do
      assert CursorHelper.wrap_cursor(4, 0, 3) == 0
      assert CursorHelper.wrap_cursor(5, 0, 3) == 1
      assert CursorHelper.wrap_cursor(7, 0, 3) == 3
    end

    test "wraps cursor below min" do
      assert CursorHelper.wrap_cursor(-1, 0, 3) == 3
      assert CursorHelper.wrap_cursor(-2, 0, 3) == 2
      assert CursorHelper.wrap_cursor(-4, 0, 3) == 0
    end

    test "returns cursor when in range" do
      assert CursorHelper.wrap_cursor(0, 0, 3) == 0
      assert CursorHelper.wrap_cursor(2, 0, 3) == 2
      assert CursorHelper.wrap_cursor(3, 0, 3) == 3
    end

    test "handles custom min" do
      assert CursorHelper.wrap_cursor(6, 1, 5) == 1
      assert CursorHelper.wrap_cursor(0, 1, 5) == 5
    end
  end

  describe "move_to_next_valid/5" do
    test "finds next valid position going down" do
      # Position 1 is invalid
      valid? = fn pos -> pos != 1 end
      assert CursorHelper.move_to_next_valid(0, :down, 4, valid?) == 2
    end

    test "finds next valid position going up" do
      # Position 2 is invalid
      valid? = fn pos -> pos != 2 end
      assert CursorHelper.move_to_next_valid(3, :up, 4, valid?) == 1
    end

    test "skips multiple invalid positions" do
      # Positions 1 and 2 are invalid
      valid? = fn pos -> pos not in [1, 2] end
      assert CursorHelper.move_to_next_valid(0, :down, 4, valid?) == 3
    end

    test "wraps when enabled" do
      # Positions 3 and 4 are invalid
      valid? = fn pos -> pos not in [3, 4] end
      assert CursorHelper.move_to_next_valid(2, :down, 4, valid?, wrap: true) == 0
    end

    test "returns nil when no valid position found" do
      # All positions invalid
      valid? = fn _pos -> false end
      assert CursorHelper.move_to_next_valid(0, :down, 4, valid?) == nil
    end
  end

  describe "first_valid/2" do
    test "finds first valid position" do
      valid? = fn pos -> pos >= 2 end
      assert CursorHelper.first_valid(4, valid?) == 2
    end

    test "returns 0 when first position is valid" do
      valid? = fn _pos -> true end
      assert CursorHelper.first_valid(4, valid?) == 0
    end

    test "returns nil when no valid positions" do
      valid? = fn _pos -> false end
      assert CursorHelper.first_valid(4, valid?) == nil
    end
  end

  describe "last_valid/2" do
    test "finds last valid position" do
      valid? = fn pos -> pos <= 2 end
      assert CursorHelper.last_valid(4, valid?) == 2
    end

    test "returns max when last position is valid" do
      valid? = fn _pos -> true end
      assert CursorHelper.last_valid(4, valid?) == 4
    end

    test "returns nil when no valid positions" do
      valid? = fn _pos -> false end
      assert CursorHelper.last_valid(4, valid?) == nil
    end
  end
end
