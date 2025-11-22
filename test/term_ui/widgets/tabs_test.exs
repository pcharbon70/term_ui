defmodule TermUI.Widgets.TabsTest do
  use ExUnit.Case, async: true

  alias TermUI.Widgets.Tabs
  alias TermUI.Event

  @test_tabs [
    %{id: :home, label: "Home", content: {:text, "Home content"}},
    %{id: :settings, label: "Settings", content: {:text, "Settings content"}},
    %{id: :about, label: "About", content: {:text, "About content"}}
  ]

  describe "new/1" do
    test "creates tabs props with required fields" do
      props = Tabs.new(tabs: @test_tabs)

      assert props.tabs == @test_tabs
      assert props.selected == :home
      assert props.on_change == nil
    end

    test "creates tabs with initial selection" do
      props = Tabs.new(tabs: @test_tabs, selected: :settings)

      assert props.selected == :settings
    end

    test "creates tabs with callbacks" do
      on_change = fn _ -> :ok end
      props = Tabs.new(tabs: @test_tabs, on_change: on_change)

      assert props.on_change == on_change
    end

    test "selects first enabled tab when all specified tabs disabled" do
      tabs = [
        %{id: :disabled1, label: "Disabled 1", disabled: true},
        %{id: :enabled, label: "Enabled"},
        %{id: :disabled2, label: "Disabled 2", disabled: true}
      ]

      props = Tabs.new(tabs: tabs)

      assert props.selected == :enabled
    end
  end

  describe "init/1" do
    test "initializes tabs state" do
      props = Tabs.new(tabs: @test_tabs)
      {:ok, state} = Tabs.init(props)

      assert state.tabs == @test_tabs
      assert state.selected == :home
      assert state.focused == :home
    end
  end

  describe "keyboard navigation" do
    setup do
      props = Tabs.new(tabs: @test_tabs)
      {:ok, state} = Tabs.init(props)
      %{state: state}
    end

    test "moves focus right with arrow key", %{state: state} do
      event = %Event.Key{key: :right}
      {:ok, new_state} = Tabs.handle_event(event, state)

      assert new_state.focused == :settings
    end

    test "moves focus left with arrow key", %{state: state} do
      state = %{state | focused: :settings}
      event = %Event.Key{key: :left}
      {:ok, new_state} = Tabs.handle_event(event, state)

      assert new_state.focused == :home
    end

    test "wraps focus from last to first", %{state: state} do
      state = %{state | focused: :about}
      event = %Event.Key{key: :right}
      {:ok, new_state} = Tabs.handle_event(event, state)

      assert new_state.focused == :home
    end

    test "wraps focus from first to last", %{state: state} do
      event = %Event.Key{key: :left}
      {:ok, new_state} = Tabs.handle_event(event, state)

      assert new_state.focused == :about
    end

    test "home key moves to first tab", %{state: state} do
      state = %{state | focused: :about}
      event = %Event.Key{key: :home}
      {:ok, new_state} = Tabs.handle_event(event, state)

      assert new_state.focused == :home
    end

    test "end key moves to last tab", %{state: state} do
      event = %Event.Key{key: :end}
      {:ok, new_state} = Tabs.handle_event(event, state)

      assert new_state.focused == :about
    end

    test "enter selects focused tab", %{state: state} do
      state = %{state | focused: :settings}
      event = %Event.Key{key: :enter}
      {:ok, new_state} = Tabs.handle_event(event, state)

      assert new_state.selected == :settings
    end

    test "space selects focused tab", %{state: state} do
      state = %{state | focused: :about}
      event = %Event.Key{key: " "}
      {:ok, new_state} = Tabs.handle_event(event, state)

      assert new_state.selected == :about
    end

    test "skips disabled tabs during navigation", %{state: _state} do
      tabs = [
        %{id: :first, label: "First"},
        %{id: :disabled, label: "Disabled", disabled: true},
        %{id: :last, label: "Last"}
      ]

      props = Tabs.new(tabs: tabs)
      {:ok, state} = Tabs.init(props)

      event = %Event.Key{key: :right}
      {:ok, new_state} = Tabs.handle_event(event, state)

      assert new_state.focused == :last
    end
  end

  describe "mouse interaction" do
    setup do
      props = Tabs.new(tabs: @test_tabs)
      {:ok, state} = Tabs.init(props)
      %{state: state}
    end

    test "click selects tab at position", %{state: state} do
      # Tab labels: " Home " (7), " Settings " (11), " About " (8)
      # Click on Settings tab (around x=10)
      event = %Event.Mouse{action: :click, x: 10, y: 0}
      {:ok, new_state} = Tabs.handle_event(event, state)

      assert new_state.selected == :settings
      assert new_state.focused == :settings
    end

    test "click on disabled tab does nothing", %{state: _state} do
      tabs = [
        %{id: :enabled, label: "Enabled"},
        %{id: :disabled, label: "Disabled", disabled: true}
      ]

      props = Tabs.new(tabs: tabs)
      {:ok, state} = Tabs.init(props)

      # Click on disabled tab
      event = %Event.Mouse{action: :click, x: 12, y: 0}
      {:ok, new_state} = Tabs.handle_event(event, state)

      assert new_state.selected == :enabled
    end
  end

  describe "public API" do
    setup do
      props = Tabs.new(tabs: @test_tabs)
      {:ok, state} = Tabs.init(props)
      %{state: state}
    end

    test "get_selected returns current selection", %{state: state} do
      assert Tabs.get_selected(state) == :home
    end

    test "select changes selection", %{state: state} do
      state = Tabs.select(state, :about)

      assert state.selected == :about
      assert state.focused == :about
    end

    test "select ignores disabled tab", %{state: _state} do
      tabs = [
        %{id: :enabled, label: "Enabled"},
        %{id: :disabled, label: "Disabled", disabled: true}
      ]

      props = Tabs.new(tabs: tabs)
      {:ok, state} = Tabs.init(props)

      state = Tabs.select(state, :disabled)

      assert state.selected == :enabled
    end

    test "add_tab appends new tab", %{state: state} do
      new_tab = %{id: :help, label: "Help"}
      state = Tabs.add_tab(state, new_tab)

      assert Tabs.tab_count(state) == 4
      assert List.last(state.tabs).id == :help
    end

    test "remove_tab removes tab by id", %{state: state} do
      state = Tabs.remove_tab(state, :settings)

      assert Tabs.tab_count(state) == 2
      assert not Enum.any?(state.tabs, &(&1.id == :settings))
    end

    test "remove_tab selects first enabled when selected tab removed", %{state: state} do
      state = %{state | selected: :settings}
      state = Tabs.remove_tab(state, :settings)

      assert state.selected == :home
    end

    test "tab_count returns number of tabs", %{state: state} do
      assert Tabs.tab_count(state) == 3
    end
  end

  describe "render" do
    test "renders tab bar with labels" do
      props = Tabs.new(tabs: @test_tabs)
      {:ok, state} = Tabs.init(props)
      area = %{x: 0, y: 0, width: 80, height: 10}

      result = Tabs.render(state, area)

      assert result.type == :stack
      assert result.direction == :vertical
      assert length(result.children) == 2
    end

    test "renders content for selected tab" do
      props = Tabs.new(tabs: @test_tabs, selected: :settings)
      {:ok, state} = Tabs.init(props)
      area = %{x: 0, y: 0, width: 80, height: 10}

      result = Tabs.render(state, area)

      # Second child is content
      content = Enum.at(result.children, 1)
      assert content == {:text, "Settings content"}
    end
  end
end
