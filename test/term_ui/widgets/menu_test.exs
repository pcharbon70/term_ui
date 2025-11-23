defmodule TermUI.Widgets.MenuTest do
  use ExUnit.Case, async: true

  alias TermUI.Widgets.Menu
  alias TermUI.Event

  defp test_items do
    [
      Menu.action(:new, "New File", shortcut: "Ctrl+N"),
      Menu.action(:open, "Open...", shortcut: "Ctrl+O"),
      Menu.separator(),
      Menu.action(:save, "Save", shortcut: "Ctrl+S")
    ]
  end

  describe "item constructors" do
    test "action creates action item" do
      item = Menu.action(:test, "Test Label", shortcut: "Ctrl+T")

      assert item.type == :action
      assert item.id == :test
      assert item.label == "Test Label"
      assert item.shortcut == "Ctrl+T"
      assert item.disabled == false
    end

    test "action with disabled option" do
      item = Menu.action(:test, "Test", disabled: true)

      assert item.disabled == true
    end

    test "submenu creates submenu item" do
      children = [Menu.action(:child, "Child")]
      item = Menu.submenu(:parent, "Parent", children)

      assert item.type == :submenu
      assert item.id == :parent
      assert item.label == "Parent"
      assert item.children == children
    end

    test "separator creates separator item" do
      item = Menu.separator()

      assert item.type == :separator
      assert is_reference(item.id)
    end

    test "checkbox creates checkbox item" do
      item = Menu.checkbox(:autosave, "Auto Save", checked: true)

      assert item.type == :checkbox
      assert item.id == :autosave
      assert item.label == "Auto Save"
      assert item.checked == true
    end

    test "checkbox defaults to unchecked" do
      item = Menu.checkbox(:option, "Option")

      assert item.checked == false
    end
  end

  describe "new/1" do
    test "creates menu props with required fields" do
      items = test_items()
      props = Menu.new(items: items)

      assert props.items == items
      assert props.on_select == nil
      assert props.on_toggle == nil
    end

    test "creates menu with callbacks" do
      on_select = fn _ -> :ok end
      on_toggle = fn _, _ -> :ok end

      props =
        Menu.new(
          items: test_items(),
          on_select: on_select,
          on_toggle: on_toggle
        )

      assert props.on_select == on_select
      assert props.on_toggle == on_toggle
    end
  end

  describe "init/1" do
    test "initializes menu state" do
      items = test_items()
      props = Menu.new(items: items)
      {:ok, state} = Menu.init(props)

      assert state.items == items
      assert state.cursor == :new
      assert MapSet.size(state.expanded) == 0
    end

    test "skips separator for initial cursor" do
      items = [
        Menu.separator(),
        Menu.action(:first, "First")
      ]

      props = Menu.new(items: items)
      {:ok, state} = Menu.init(props)

      assert state.cursor == :first
    end
  end

  describe "keyboard navigation" do
    setup do
      props = Menu.new(items: test_items())
      {:ok, state} = Menu.init(props)
      %{state: state}
    end

    test "moves cursor down with arrow key", %{state: state} do
      event = %Event.Key{key: :down}
      {:ok, new_state} = Menu.handle_event(event, state)

      assert new_state.cursor == :open
    end

    test "moves cursor up with arrow key", %{state: state} do
      state = %{state | cursor: :save}
      event = %Event.Key{key: :up}
      {:ok, new_state} = Menu.handle_event(event, state)

      assert new_state.cursor == :open
    end

    test "skips separators during navigation", %{state: state} do
      state = %{state | cursor: :open}
      event = %Event.Key{key: :down}
      {:ok, new_state} = Menu.handle_event(event, state)

      assert new_state.cursor == :save
    end

    test "doesn't move cursor beyond bounds", %{state: state} do
      state = %{state | cursor: :save}
      event = %Event.Key{key: :down}
      {:ok, new_state} = Menu.handle_event(event, state)

      assert new_state.cursor == :save
    end

    test "enter selects action item", %{state: state} do
      selected_id = nil
      on_select = fn id -> send(self(), {:selected, id}) end

      state = %{state | on_select: on_select}
      event = %Event.Key{key: :enter}
      {:ok, _state} = Menu.handle_event(event, state)

      assert_receive {:selected, :new}
    end

    test "escape signals menu close", %{state: state} do
      event = %Event.Key{key: :escape}
      {:ok, _state, effects} = Menu.handle_event(event, state)

      assert Enum.any?(effects, fn
               {:send, _, :menu_close} -> true
               _ -> false
             end)
    end
  end

  describe "submenu handling" do
    setup do
      items = [
        Menu.action(:action1, "Action 1"),
        Menu.submenu(:sub, "Submenu", [
          Menu.action(:child1, "Child 1"),
          Menu.action(:child2, "Child 2")
        ]),
        Menu.action(:action2, "Action 2")
      ]

      props = Menu.new(items: items)
      {:ok, state} = Menu.init(props)
      %{state: state}
    end

    test "right arrow expands submenu", %{state: state} do
      state = %{state | cursor: :sub}
      event = %Event.Key{key: :right}
      {:ok, new_state} = Menu.handle_event(event, state)

      assert Menu.expanded?(new_state, :sub)
    end

    test "left arrow collapses submenu", %{state: state} do
      state = %{state | cursor: :sub, expanded: MapSet.new([:sub])}
      event = %Event.Key{key: :left}
      {:ok, new_state} = Menu.handle_event(event, state)

      assert not Menu.expanded?(new_state, :sub)
    end

    test "enter on submenu expands it", %{state: state} do
      state = %{state | cursor: :sub}
      event = %Event.Key{key: :enter}
      {:ok, new_state} = Menu.handle_event(event, state)

      assert Menu.expanded?(new_state, :sub)
    end

    test "navigation includes children when expanded", %{state: state} do
      state = Menu.expand(state, :sub)
      state = %{state | cursor: :sub}

      event = %Event.Key{key: :down}
      {:ok, new_state} = Menu.handle_event(event, state)

      assert new_state.cursor == :child1
    end
  end

  describe "checkbox handling" do
    setup do
      items = [
        Menu.checkbox(:option1, "Option 1", checked: false),
        Menu.checkbox(:option2, "Option 2", checked: true)
      ]

      props = Menu.new(items: items)
      {:ok, state} = Menu.init(props)
      %{state: state}
    end

    test "enter toggles checkbox", %{state: state} do
      event = %Event.Key{key: :enter}
      {:ok, new_state} = Menu.handle_event(event, state)

      assert Menu.checked?(new_state, :option1)
    end

    test "space toggles checkbox", %{state: state} do
      event = %Event.Key{key: " "}
      {:ok, new_state} = Menu.handle_event(event, state)

      assert Menu.checked?(new_state, :option1)
    end

    test "on_toggle callback is invoked", %{state: state} do
      on_toggle = fn id, checked -> send(self(), {:toggled, id, checked}) end
      state = %{state | on_toggle: on_toggle}

      event = %Event.Key{key: :enter}
      {:ok, _state} = Menu.handle_event(event, state)

      assert_receive {:toggled, :option1, true}
    end

    test "checked? returns checkbox state", %{state: state} do
      assert not Menu.checked?(state, :option1)
      assert Menu.checked?(state, :option2)
    end
  end

  describe "mouse interaction" do
    setup do
      props = Menu.new(items: test_items())
      {:ok, state} = Menu.init(props)
      %{state: state}
    end

    test "click selects item at position", %{state: state} do
      on_select = fn id -> send(self(), {:selected, id}) end
      state = %{state | on_select: on_select}

      # Click on second item (Open)
      event = %Event.Mouse{action: :click, y: 1, x: 5}
      {:ok, new_state} = Menu.handle_event(event, state)

      assert new_state.cursor == :open
      assert_receive {:selected, :open}
    end
  end

  describe "public API" do
    setup do
      items = [
        Menu.action(:action1, "Action 1"),
        Menu.submenu(:sub, "Submenu", [
          Menu.action(:child1, "Child 1")
        ])
      ]

      props = Menu.new(items: items)
      {:ok, state} = Menu.init(props)
      %{state: state}
    end

    test "get_cursor returns current cursor", %{state: state} do
      assert Menu.get_cursor(state) == :action1
    end

    test "expand expands submenu", %{state: state} do
      state = Menu.expand(state, :sub)

      assert Menu.expanded?(state, :sub)
    end

    test "collapse collapses submenu", %{state: state} do
      state = Menu.expand(state, :sub)
      state = Menu.collapse(state, :sub)

      assert not Menu.expanded?(state, :sub)
    end

    test "expanded? returns expansion state", %{state: state} do
      assert not Menu.expanded?(state, :sub)

      state = Menu.expand(state, :sub)
      assert Menu.expanded?(state, :sub)
    end
  end

  describe "render" do
    test "renders menu items" do
      props = Menu.new(items: test_items())
      {:ok, state} = Menu.init(props)
      area = %{x: 0, y: 0, width: 40, height: 20}

      result = Menu.render(state, area)

      assert result.type == :stack
      assert result.direction == :vertical
      assert length(result.children) == 4
    end

    test "renders submenu children when expanded" do
      items = [
        Menu.submenu(:sub, "Submenu", [
          Menu.action(:child1, "Child 1"),
          Menu.action(:child2, "Child 2")
        ])
      ]

      props = Menu.new(items: items)
      {:ok, state} = Menu.init(props)
      state = Menu.expand(state, :sub)
      area = %{x: 0, y: 0, width: 40, height: 20}

      result = Menu.render(state, area)

      # Should show submenu + 2 children
      assert length(result.children) == 3
    end
  end
end
