defmodule TermUI.Widgets.ContextMenuTest do
  use ExUnit.Case, async: true

  alias TermUI.Event
  alias TermUI.Widgets.ContextMenu

  defp test_items do
    [
      ContextMenu.action(:cut, "Cut", shortcut: "Ctrl+X"),
      ContextMenu.action(:copy, "Copy", shortcut: "Ctrl+C"),
      ContextMenu.action(:paste, "Paste", shortcut: "Ctrl+V"),
      ContextMenu.separator(),
      ContextMenu.action(:select_all, "Select All", shortcut: "Ctrl+A")
    ]
  end

  describe "item constructors" do
    test "action creates action item" do
      item = ContextMenu.action(:test, "Test Label", shortcut: "Ctrl+T")

      assert item.type == :action
      assert item.id == :test
      assert item.label == "Test Label"
      assert item.shortcut == "Ctrl+T"
      assert item.disabled == false
    end

    test "action with disabled option" do
      item = ContextMenu.action(:test, "Test", disabled: true)

      assert item.disabled == true
    end

    test "separator creates separator item" do
      item = ContextMenu.separator()

      assert item.type == :separator
      assert is_reference(item.id)
    end
  end

  describe "new/1" do
    test "creates context menu props with required fields" do
      items = test_items()
      props = ContextMenu.new(items: items, position: {10, 20})

      assert props.items == items
      assert props.position == {10, 20}
      assert props.on_select == nil
      assert props.on_close == nil
    end

    test "creates context menu with callbacks" do
      on_select = fn _ -> :ok end
      on_close = fn -> :ok end

      props =
        ContextMenu.new(
          items: test_items(),
          position: {0, 0},
          on_select: on_select,
          on_close: on_close
        )

      assert props.on_select == on_select
      assert props.on_close == on_close
    end
  end

  describe "init/1" do
    test "initializes context menu state" do
      items = test_items()
      props = ContextMenu.new(items: items, position: {10, 20})
      {:ok, state} = ContextMenu.init(props)

      assert state.items == items
      assert state.position == {10, 20}
      assert state.cursor == :cut
      assert state.visible == true
    end

    test "skips separator for initial cursor" do
      items = [
        ContextMenu.separator(),
        ContextMenu.action(:first, "First")
      ]

      props = ContextMenu.new(items: items, position: {0, 0})
      {:ok, state} = ContextMenu.init(props)

      assert state.cursor == :first
    end
  end

  describe "keyboard navigation" do
    setup do
      props = ContextMenu.new(items: test_items(), position: {0, 0})
      {:ok, state} = ContextMenu.init(props)
      %{state: state}
    end

    test "moves cursor down with arrow key", %{state: state} do
      event = %Event.Key{key: :down}
      {:ok, new_state} = ContextMenu.handle_event(event, state)

      assert new_state.cursor == :copy
    end

    test "moves cursor up with arrow key", %{state: state} do
      state = %{state | cursor: :copy}
      event = %Event.Key{key: :up}
      {:ok, new_state} = ContextMenu.handle_event(event, state)

      assert new_state.cursor == :cut
    end

    test "skips separators during navigation", %{state: state} do
      state = %{state | cursor: :paste}
      event = %Event.Key{key: :down}
      {:ok, new_state} = ContextMenu.handle_event(event, state)

      assert new_state.cursor == :select_all
    end

    test "doesn't move cursor beyond bounds", %{state: state} do
      state = %{state | cursor: :select_all}
      event = %Event.Key{key: :down}
      {:ok, new_state} = ContextMenu.handle_event(event, state)

      assert new_state.cursor == :select_all
    end

    test "enter selects item and closes menu", %{state: state} do
      on_select = fn id -> send(self(), {:selected, id}) end
      state = %{state | on_select: on_select}

      event = %Event.Key{key: :enter}
      {:ok, new_state} = ContextMenu.handle_event(event, state)

      assert_receive {:selected, :cut}
      assert not ContextMenu.visible?(new_state)
    end

    test "space selects item and closes menu", %{state: state} do
      on_select = fn id -> send(self(), {:selected, id}) end
      state = %{state | on_select: on_select}

      event = %Event.Key{key: " "}
      {:ok, new_state} = ContextMenu.handle_event(event, state)

      assert_receive {:selected, :cut}
      assert not ContextMenu.visible?(new_state)
    end

    test "escape closes menu", %{state: state} do
      on_close = fn -> send(self(), :closed) end
      state = %{state | on_close: on_close}

      event = %Event.Key{key: :escape}
      {:ok, new_state} = ContextMenu.handle_event(event, state)

      assert_receive :closed
      assert not ContextMenu.visible?(new_state)
    end
  end

  describe "mouse interaction" do
    setup do
      props = ContextMenu.new(items: test_items(), position: {10, 5})
      {:ok, state} = ContextMenu.init(props)
      %{state: state}
    end

    test "click inside menu selects item", %{state: state} do
      on_select = fn id -> send(self(), {:selected, id}) end
      state = %{state | on_select: on_select}

      # Click on second item (Copy) at position relative to menu
      event = %Event.Mouse{action: :press, x: 15, y: 6}
      {:ok, new_state} = ContextMenu.handle_event(event, state)

      assert_receive {:selected, :copy}
      assert not ContextMenu.visible?(new_state)
    end

    test "click outside menu closes it", %{state: state} do
      on_close = fn -> send(self(), :closed) end
      state = %{state | on_close: on_close}

      # Click outside menu bounds
      event = %Event.Mouse{action: :press, x: 100, y: 100}
      {:ok, new_state} = ContextMenu.handle_event(event, state)

      assert_receive :closed
      assert not ContextMenu.visible?(new_state)
    end

    test "click on disabled item does nothing", %{state: _state} do
      items = [
        ContextMenu.action(:enabled, "Enabled"),
        ContextMenu.action(:disabled, "Disabled", disabled: true)
      ]

      props = ContextMenu.new(items: items, position: {0, 0})
      {:ok, state} = ContextMenu.init(props)

      # Click on disabled item
      event = %Event.Mouse{action: :press, x: 5, y: 1}
      {:ok, new_state} = ContextMenu.handle_event(event, state)

      # Menu should still be visible
      assert ContextMenu.visible?(new_state)
    end

    test "click on separator does nothing", %{state: state} do
      # Click on separator (y=3 relative to position y=5, so y=8)
      event = %Event.Mouse{action: :press, x: 15, y: 8}
      {:ok, new_state} = ContextMenu.handle_event(event, state)

      # Menu should still be visible
      assert ContextMenu.visible?(new_state)
    end
  end

  describe "public API" do
    setup do
      props = ContextMenu.new(items: test_items(), position: {10, 20})
      {:ok, state} = ContextMenu.init(props)
      %{state: state}
    end

    test "visible? returns visibility state", %{state: state} do
      assert ContextMenu.visible?(state)
    end

    test "show makes menu visible", %{state: state} do
      state = %{state | visible: false}
      state = ContextMenu.show(state)

      assert ContextMenu.visible?(state)
    end

    test "hide makes menu invisible", %{state: state} do
      state = ContextMenu.hide(state)

      assert not ContextMenu.visible?(state)
    end

    test "set_position updates position", %{state: state} do
      state = ContextMenu.set_position(state, {50, 60})

      assert state.position == {50, 60}
    end

    test "get_cursor returns current cursor", %{state: state} do
      assert ContextMenu.get_cursor(state) == :cut
    end
  end

  describe "render" do
    test "renders context menu at position" do
      props = ContextMenu.new(items: test_items(), position: {10, 20})
      {:ok, state} = ContextMenu.init(props)
      area = %{x: 0, y: 0, width: 80, height: 40}

      result = ContextMenu.render(state, area)

      assert result.type == :overlay
      assert result.x == 10
      assert result.y == 20
      assert result.z == 100
    end

    test "renders empty when not visible" do
      props = ContextMenu.new(items: test_items(), position: {10, 20})
      {:ok, state} = ContextMenu.init(props)
      state = ContextMenu.hide(state)
      area = %{x: 0, y: 0, width: 80, height: 40}

      result = ContextMenu.render(state, area)

      assert result.type == :empty
    end

    test "renders all menu items" do
      props = ContextMenu.new(items: test_items(), position: {0, 0})
      {:ok, state} = ContextMenu.init(props)
      area = %{x: 0, y: 0, width: 80, height: 40}

      result = ContextMenu.render(state, area)

      # Content should be a stack with 5 items
      assert result.content.type == :stack
      assert length(result.content.children) == 5
    end
  end

  describe "disabled items" do
    test "disabled items are skipped during navigation" do
      items = [
        ContextMenu.action(:first, "First"),
        ContextMenu.action(:disabled, "Disabled", disabled: true),
        ContextMenu.action(:last, "Last")
      ]

      props = ContextMenu.new(items: items, position: {0, 0})
      {:ok, state} = ContextMenu.init(props)

      event = %Event.Key{key: :down}
      {:ok, new_state} = ContextMenu.handle_event(event, state)

      assert new_state.cursor == :last
    end

    test "disabled items cannot be selected" do
      items = [
        ContextMenu.action(:disabled, "Disabled", disabled: true)
      ]

      props = ContextMenu.new(items: items, position: {0, 0})
      {:ok, state} = ContextMenu.init(props)
      on_select = fn id -> send(self(), {:selected, id}) end
      state = %{state | on_select: on_select, cursor: :disabled}

      event = %Event.Key{key: :enter}
      {:ok, _state} = ContextMenu.handle_event(event, state)

      refute_receive {:selected, _}
    end
  end
end
