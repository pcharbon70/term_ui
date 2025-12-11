defmodule TermUI.Widgets.ContextMenu.BehaviorTest do
  use ExUnit.Case, async: true

  alias TermUI.Widgets.ContextMenu
  alias TermUI.Widgets.ContextMenu.Behavior

  # ----------------------------------------------------------------------------
  # Test Helpers
  # ----------------------------------------------------------------------------

  defp test_items do
    [
      ContextMenu.action(:copy, "Copy"),
      ContextMenu.separator(),
      ContextMenu.action(:paste, "Paste", disabled: true),
      ContextMenu.action(:delete, "Delete")
    ]
  end

  defp simple_items do
    [
      ContextMenu.action(:copy, "Copy"),
      ContextMenu.action(:paste, "Paste"),
      ContextMenu.action(:delete, "Delete")
    ]
  end

  # ----------------------------------------------------------------------------
  # selectable?/1 Tests
  # ----------------------------------------------------------------------------

  describe "selectable?/1" do
    test "returns true for action items" do
      item = ContextMenu.action(:copy, "Copy")
      assert Behavior.selectable?(item) == true
    end

    test "returns false for disabled action items" do
      item = ContextMenu.action(:paste, "Paste", disabled: true)
      assert Behavior.selectable?(item) == false
    end

    test "returns false for separators" do
      item = ContextMenu.separator()
      assert Behavior.selectable?(item) == false
    end

    test "returns true for enabled action with shortcut" do
      item = ContextMenu.action(:copy, "Copy", shortcut: "Ctrl+C")
      assert Behavior.selectable?(item) == true
    end
  end

  # ----------------------------------------------------------------------------
  # find_first_selectable/1 Tests
  # ----------------------------------------------------------------------------

  describe "find_first_selectable/1" do
    test "finds first selectable item in mixed list" do
      items = test_items()
      assert Behavior.find_first_selectable(items) == :copy
    end

    test "skips separators and disabled items" do
      items = [
        ContextMenu.separator(),
        ContextMenu.action(:disabled, "Disabled", disabled: true),
        ContextMenu.action(:enabled, "Enabled")
      ]

      assert Behavior.find_first_selectable(items) == :enabled
    end

    test "returns nil when no selectable items exist" do
      items = [
        ContextMenu.separator(),
        ContextMenu.action(:disabled, "Disabled", disabled: true)
      ]

      assert Behavior.find_first_selectable(items) == nil
    end

    test "returns first item when all are selectable" do
      items = simple_items()
      assert Behavior.find_first_selectable(items) == :copy
    end

    test "returns nil for empty list" do
      assert Behavior.find_first_selectable([]) == nil
    end
  end

  # ----------------------------------------------------------------------------
  # move_cursor/2 Tests
  # ----------------------------------------------------------------------------

  describe "move_cursor/2" do
    test "moves cursor forward by one item" do
      state = %{
        items: simple_items(),
        cursor: :copy
      }

      new_state = Behavior.move_cursor(state, 1)
      assert new_state.cursor == :paste
    end

    test "moves cursor backward by one item" do
      state = %{
        items: simple_items(),
        cursor: :paste
      }

      new_state = Behavior.move_cursor(state, -1)
      assert new_state.cursor == :copy
    end

    test "clamps cursor at end when moving forward" do
      state = %{
        items: simple_items(),
        cursor: :delete
      }

      new_state = Behavior.move_cursor(state, 1)
      assert new_state.cursor == :delete
    end

    test "clamps cursor at beginning when moving backward" do
      state = %{
        items: simple_items(),
        cursor: :copy
      }

      new_state = Behavior.move_cursor(state, -1)
      assert new_state.cursor == :copy
    end

    test "skips separators when moving forward" do
      items = [
        ContextMenu.action(:copy, "Copy"),
        ContextMenu.separator(),
        ContextMenu.action(:paste, "Paste")
      ]

      state = %{items: items, cursor: :copy}

      new_state = Behavior.move_cursor(state, 1)
      assert new_state.cursor == :paste
    end

    test "skips disabled items when moving forward" do
      items = [
        ContextMenu.action(:copy, "Copy"),
        ContextMenu.action(:disabled, "Disabled", disabled: true),
        ContextMenu.action(:paste, "Paste")
      ]

      state = %{items: items, cursor: :copy}

      new_state = Behavior.move_cursor(state, 1)
      assert new_state.cursor == :paste
    end

    test "returns unchanged state when cursor is nil" do
      state = %{
        items: simple_items(),
        cursor: nil
      }

      new_state = Behavior.move_cursor(state, 1)
      assert new_state == state
    end

    test "returns unchanged state when cursor not in items" do
      state = %{
        items: simple_items(),
        cursor: :nonexistent
      }

      new_state = Behavior.move_cursor(state, 1)
      assert new_state == state
    end

    test "handles multiple moves in sequence" do
      state = %{
        items: simple_items(),
        cursor: :copy
      }

      state = Behavior.move_cursor(state, 1)
      assert state.cursor == :paste

      state = Behavior.move_cursor(state, 1)
      assert state.cursor == :delete

      state = Behavior.move_cursor(state, -1)
      assert state.cursor == :paste
    end
  end

  # ----------------------------------------------------------------------------
  # select_at_cursor/1 Tests
  # ----------------------------------------------------------------------------

  describe "select_at_cursor/1" do
    test "calls on_select callback and closes menu" do
      test_pid = self()

      state = %{
        items: simple_items(),
        cursor: :copy,
        on_select: fn id -> send(test_pid, {:selected, id}) end,
        on_close: nil,
        visible: true
      }

      new_state = Behavior.select_at_cursor(state)

      assert_received {:selected, :copy}
      assert new_state.visible == false
    end

    test "does not call on_select for disabled items but still closes menu" do
      test_pid = self()

      items = [
        ContextMenu.action(:paste, "Paste", disabled: true)
      ]

      state = %{
        items: items,
        cursor: :paste,
        on_select: fn id -> send(test_pid, {:selected, id}) end,
        on_close: nil,
        visible: true
      }

      new_state = Behavior.select_at_cursor(state)

      refute_received {:selected, _}
      assert new_state.visible == false
    end

    test "does not call on_select for separators" do
      test_pid = self()
      separator = ContextMenu.separator()

      state = %{
        items: [separator],
        cursor: separator.id,
        on_select: fn id -> send(test_pid, {:selected, id}) end,
        on_close: nil,
        visible: true
      }

      new_state = Behavior.select_at_cursor(state)

      refute_received {:selected, _}
      assert new_state == state
    end

    test "works without on_select callback" do
      state = %{
        items: simple_items(),
        cursor: :copy,
        on_select: nil,
        on_close: nil,
        visible: true
      }

      new_state = Behavior.select_at_cursor(state)
      assert new_state.visible == false
    end

    test "calls on_close callback when closing menu" do
      test_pid = self()

      state = %{
        items: simple_items(),
        cursor: :copy,
        on_select: nil,
        on_close: fn -> send(test_pid, :closed) end,
        visible: true
      }

      Behavior.select_at_cursor(state)

      assert_received :closed
    end

    test "returns unchanged state for nonexistent cursor" do
      state = %{
        items: simple_items(),
        cursor: :nonexistent,
        on_select: fn _ -> :ok end,
        on_close: nil,
        visible: true
      }

      new_state = Behavior.select_at_cursor(state)
      assert new_state == state
    end
  end

  # ----------------------------------------------------------------------------
  # close_menu/1 Tests
  # ----------------------------------------------------------------------------

  describe "close_menu/1" do
    test "sets visible to false" do
      state = %{visible: true, on_close: nil}
      new_state = Behavior.close_menu(state)
      assert new_state.visible == false
    end

    test "calls on_close callback" do
      test_pid = self()

      state = %{
        visible: true,
        on_close: fn -> send(test_pid, :closed) end
      }

      Behavior.close_menu(state)

      assert_received :closed
    end

    test "works without on_close callback" do
      state = %{visible: true, on_close: nil}
      new_state = Behavior.close_menu(state)
      assert new_state.visible == false
    end

    test "preserves other state fields" do
      state = %{
        visible: true,
        on_close: nil,
        cursor: :copy,
        items: simple_items()
      }

      new_state = Behavior.close_menu(state)

      assert new_state.visible == false
      assert new_state.cursor == :copy
      assert new_state.items == simple_items()
    end
  end

  # ----------------------------------------------------------------------------
  # Integration Tests
  # ----------------------------------------------------------------------------

  describe "integration" do
    test "typical menu interaction flow" do
      test_pid = self()

      state = %{
        items: simple_items(),
        cursor: Behavior.find_first_selectable(simple_items()),
        on_select: fn id -> send(test_pid, {:selected, id}) end,
        on_close: fn -> send(test_pid, :closed) end,
        visible: true
      }

      # Cursor starts at first item
      assert state.cursor == :copy

      # Move down twice
      state = Behavior.move_cursor(state, 1)
      assert state.cursor == :paste

      state = Behavior.move_cursor(state, 1)
      assert state.cursor == :delete

      # Select current item
      state = Behavior.select_at_cursor(state)

      assert_received {:selected, :delete}
      assert_received :closed
      assert state.visible == false
    end

    test "escape without selection" do
      test_pid = self()

      state = %{
        items: simple_items(),
        cursor: :copy,
        on_select: fn id -> send(test_pid, {:selected, id}) end,
        on_close: fn -> send(test_pid, :closed) end,
        visible: true
      }

      # Close without selecting
      state = Behavior.close_menu(state)

      refute_received {:selected, _}
      assert_received :closed
      assert state.visible == false
    end
  end
end
