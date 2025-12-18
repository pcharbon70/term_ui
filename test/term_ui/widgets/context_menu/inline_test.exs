defmodule TermUI.Widgets.ContextMenu.InlineTest do
  use ExUnit.Case, async: true

  import TermUI.Test.ContextMenuHelpers

  alias TermUI.Widgets.ContextMenu
  alias TermUI.Widgets.ContextMenu.Inline
  alias TermUI.Event
  alias TermUI.Renderer.Style

  # Test helpers

  defp create_test_props(opts \\ []) do
    items =
      Keyword.get(opts, :items, [
        ContextMenu.action(:copy, "Copy"),
        ContextMenu.action(:paste, "Paste"),
        ContextMenu.action(:delete, "Delete")
      ])

    Inline.new(
      items: items,
      on_select: Keyword.get(opts, :on_select),
      on_close: Keyword.get(opts, :on_close),
      orientation: Keyword.get(opts, :orientation, :horizontal)
    )
  end

  # ----------------------------------------------------------------------------
  # Initialization Tests
  # ----------------------------------------------------------------------------

  describe "new/1 and init/1" do
    test "creates props with required items" do
      props = create_test_props()

      assert length(props.items) == 3
      assert props.orientation == :horizontal
    end

    test "accepts vertical orientation" do
      props = create_test_props(orientation: :vertical)

      assert props.orientation == :vertical
    end

    test "init/1 initializes state with cursor on first item" do
      props = create_test_props()
      {:ok, state} = Inline.init(props)

      assert state.cursor == :copy
      assert state.visible == true
    end

    test "init/1 builds number map for selectable items" do
      props = create_test_props()
      {:ok, state} = Inline.init(props)

      assert state.number_map == %{1 => :copy, 2 => :paste, 3 => :delete}
    end

    test "init/1 skips disabled items in number map" do
      items = [
        ContextMenu.action(:copy, "Copy"),
        ContextMenu.action(:paste, "Paste", disabled: true),
        ContextMenu.action(:delete, "Delete")
      ]

      props = create_test_props(items: items)
      {:ok, state} = Inline.init(props)

      # paste is skipped because it's disabled
      assert state.number_map == %{1 => :copy, 2 => :delete}
    end

    test "init/1 skips separators in number map" do
      items = [
        ContextMenu.action(:copy, "Copy"),
        ContextMenu.separator(),
        ContextMenu.action(:paste, "Paste")
      ]

      props = create_test_props(items: items)
      {:ok, state} = Inline.init(props)

      assert state.number_map == %{1 => :copy, 2 => :paste}
    end

    test "init/1 only numbers first 9 items" do
      items =
        for i <- 1..12 do
          ContextMenu.action(:"item_#{i}", "Item #{i}")
        end

      props = create_test_props(items: items)
      {:ok, state} = Inline.init(props)

      # Only first 9 items should be numbered
      assert map_size(state.number_map) == 9
      assert Map.has_key?(state.number_map, 9)
      refute Map.has_key?(state.number_map, 10)
    end
  end

  # ----------------------------------------------------------------------------
  # Rendering Tests
  # ----------------------------------------------------------------------------

  describe "render/2" do
    test "renders items with number prefixes" do
      props = create_test_props()
      {:ok, state} = Inline.init(props)

      render = Inline.render(state, test_area(80, 24))

      # Check it returns a horizontal stack with items
      assert render.type == :stack
      assert render.direction == :horizontal
    end

    test "renders in vertical orientation" do
      props = create_test_props(orientation: :vertical)
      {:ok, state} = Inline.init(props)

      render = Inline.render(state, test_area(80, 24))

      assert render.type == :stack
      assert render.direction == :vertical
    end

    test "returns empty when not visible" do
      props = create_test_props()
      {:ok, state} = Inline.init(props)
      state = Inline.hide(state)

      render = Inline.render(state, test_area(80, 24))

      assert render.type == :empty
    end

    test "renders separators differently in horizontal mode" do
      items = [
        ContextMenu.action(:copy, "Copy"),
        ContextMenu.separator(),
        ContextMenu.action(:paste, "Paste")
      ]

      props = create_test_props(items: items)
      {:ok, state} = Inline.init(props)

      render = Inline.render(state, test_area(80, 24))

      # Should have Copy, spacing, separator, spacing, Paste
      assert render.type == :stack
    end

    test "applies item_style to normal items" do
      item_style = Style.new(fg: :white, bg: :black)

      props =
        Inline.new(
          items: [ContextMenu.action(:copy, "Copy")],
          item_style: item_style
        )

      {:ok, state} = Inline.init(props)
      # Move cursor away from first item to make it normal
      state = %{state | cursor: :other}

      render = Inline.render(state, test_area(80, 24))

      # Extract first item from horizontal stack
      [first_item | _] = render.children
      assert first_item.type == :box
      assert first_item.style == item_style
    end

    test "applies selected_style to cursor item" do
      selected_style = Style.new(fg: :black, bg: :cyan)

      props =
        Inline.new(
          items: [
            ContextMenu.action(:copy, "Copy"),
            ContextMenu.action(:paste, "Paste")
          ],
          selected_style: selected_style
        )

      {:ok, state} = Inline.init(props)
      # Cursor starts at first item (:copy)

      render = Inline.render(state, test_area(80, 24))

      # First item should have selected_style
      [first_item | _] = render.children
      assert first_item.type == :box
      assert first_item.style == selected_style
    end

    test "applies disabled_style to disabled items" do
      disabled_style = Style.new(fg: :bright_black, bg: :black)

      props =
        Inline.new(
          items: [
            ContextMenu.action(:copy, "Copy"),
            ContextMenu.action(:paste, "Paste", disabled: true)
          ],
          disabled_style: disabled_style
        )

      {:ok, state} = Inline.init(props)

      render = Inline.render(state, test_area(80, 24))

      # Second item (after spacing) should have disabled_style
      [_first, _spacing, second_item | _] = render.children
      assert second_item.type == :box
      assert second_item.style == disabled_style
    end

    test "style priority: disabled overrides selected" do
      selected_style = Style.new(fg: :black, bg: :cyan)
      disabled_style = Style.new(fg: :bright_black, bg: :black)

      props =
        Inline.new(
          items: [ContextMenu.action(:paste, "Paste", disabled: true)],
          selected_style: selected_style,
          disabled_style: disabled_style
        )

      {:ok, state} = Inline.init(props)
      # Try to select disabled item
      state = %{state | cursor: :paste}

      render = Inline.render(state, test_area(80, 24))

      # Should use disabled_style, not selected_style
      [first_item | _] = render.children
      assert first_item.type == :box
      assert first_item.style == disabled_style
    end

    test "renders without styles when none provided" do
      props = Inline.new(items: [ContextMenu.action(:copy, "Copy")])
      {:ok, state} = Inline.init(props)

      render = Inline.render(state, test_area(80, 24))

      # Should still render, but without styled wrapper
      [first_item | _] = render.children
      assert first_item.type == :text
    end
  end

  # ----------------------------------------------------------------------------
  # Rendering Content Tests
  # ----------------------------------------------------------------------------

  describe "render/2 content" do
    defp extract_text_content(node) do
      case node.type do
        :text -> node.content
        :box -> extract_text_content(hd(node.children))
        _ -> nil
      end
    end

    test "renders items with correct number prefixes" do
      props = create_test_props()
      {:ok, state} = Inline.init(props)

      render = Inline.render(state, test_area(80, 24))

      # Extract text from first three items (skip spacing elements)
      [item1, _space1, item2, _space2, item3] = render.children

      assert extract_text_content(item1) == "[1] Copy"
      assert extract_text_content(item2) == "[2] Paste"
      assert extract_text_content(item3) == "[3] Delete"
    end

    test "renders separators as vertical lines in horizontal mode" do
      items = [
        ContextMenu.action(:copy, "Copy"),
        ContextMenu.separator(),
        ContextMenu.action(:paste, "Paste")
      ]

      props = create_test_props(items: items)
      {:ok, state} = Inline.init(props)

      render = Inline.render(state, test_area(80, 24))

      # Separator should be between items
      [_item1, _space1, separator, _space2, _item2] = render.children

      assert separator.type == :text
      assert separator.content == "|"
    end

    test "renders separators as horizontal lines in vertical mode" do
      items = [
        ContextMenu.action(:copy, "Copy"),
        ContextMenu.separator(),
        ContextMenu.action(:paste, "Paste")
      ]

      props = create_test_props(items: items, orientation: :vertical)
      {:ok, state} = Inline.init(props)

      render = Inline.render(state, test_area(80, 24))

      # Get middle item (separator)
      [_item1, separator, _item2] = render.children

      assert separator.type == :text
      assert separator.content == "───"
    end

    test "skips numbers for disabled items" do
      items = [
        ContextMenu.action(:copy, "Copy"),
        ContextMenu.action(:paste, "Paste", disabled: true),
        ContextMenu.action(:delete, "Delete")
      ]

      props = create_test_props(items: items)
      {:ok, state} = Inline.init(props)

      render = Inline.render(state, test_area(80, 24))

      # paste should have no number (just spaces)
      [_item1, _space1, item2, _space2, _item3] = render.children

      assert extract_text_content(item2) == "    Paste"
    end

    test "skips numbers for separators" do
      items = [
        ContextMenu.action(:copy, "Copy"),
        ContextMenu.separator()
      ]

      props = create_test_props(items: items)
      {:ok, state} = Inline.init(props)

      render = Inline.render(state, test_area(80, 24))

      # Separator has no number
      [_item1, _space, separator] = render.children

      assert separator.type == :text
      assert separator.content == "|"
    end

    test "limits numbers to 1-9" do
      # Create 10 items
      items =
        for i <- 1..10 do
          ContextMenu.action(:"item_#{i}", "Item #{i}")
        end

      props = create_test_props(items: items)
      {:ok, state} = Inline.init(props)

      render = Inline.render(state, test_area(80, 24))

      # First 9 items should have numbers, 10th should not
      children = render.children
      # Get every odd element (skip spacing)
      items_only = Enum.take_every(children, 2)

      first_nine = Enum.take(items_only, 9)
      tenth = Enum.at(items_only, 9)

      # Verify first 9 have numbers [1] through [9]
      Enum.each(Enum.with_index(first_nine, 1), fn {item, idx} ->
        assert extract_text_content(item) == "[#{idx}] Item #{idx}"
      end)

      # 10th item should have no number (just spaces)
      assert extract_text_content(tenth) == "    Item 10"
    end
  end

  # ----------------------------------------------------------------------------
  # Arrow Key Navigation Tests
  # ----------------------------------------------------------------------------

  describe "arrow key navigation" do
    test "down arrow moves cursor to next item" do
      props = create_test_props()
      {:ok, state} = Inline.init(props)

      assert state.cursor == :copy

      {:ok, state} = Inline.handle_event(%Event.Key{key: :down}, state)

      assert state.cursor == :paste
    end

    test "up arrow moves cursor to previous item" do
      props = create_test_props()
      {:ok, state} = Inline.init(props)
      {:ok, state} = Inline.handle_event(%Event.Key{key: :down}, state)

      assert state.cursor == :paste

      {:ok, state} = Inline.handle_event(%Event.Key{key: :up}, state)

      assert state.cursor == :copy
    end

    test "right arrow moves cursor to next item" do
      props = create_test_props()
      {:ok, state} = Inline.init(props)

      {:ok, state} = Inline.handle_event(%Event.Key{key: :right}, state)

      assert state.cursor == :paste
    end

    test "left arrow moves cursor to previous item" do
      props = create_test_props()
      {:ok, state} = Inline.init(props)
      {:ok, state} = Inline.handle_event(%Event.Key{key: :right}, state)

      {:ok, state} = Inline.handle_event(%Event.Key{key: :left}, state)

      assert state.cursor == :copy
    end

    test "cursor does not go past first item" do
      props = create_test_props()
      {:ok, state} = Inline.init(props)

      {:ok, state} = Inline.handle_event(%Event.Key{key: :up}, state)

      assert state.cursor == :copy
    end

    test "cursor does not go past last item" do
      props = create_test_props()
      {:ok, state} = Inline.init(props)

      {:ok, state} = Inline.handle_event(%Event.Key{key: :down}, state)
      {:ok, state} = Inline.handle_event(%Event.Key{key: :down}, state)
      {:ok, state} = Inline.handle_event(%Event.Key{key: :down}, state)

      assert state.cursor == :delete
    end

    test "navigation skips separators" do
      items = [
        ContextMenu.action(:copy, "Copy"),
        ContextMenu.separator(),
        ContextMenu.action(:paste, "Paste")
      ]

      props = create_test_props(items: items)
      {:ok, state} = Inline.init(props)

      {:ok, state} = Inline.handle_event(%Event.Key{key: :down}, state)

      # Should skip separator and land on paste
      assert state.cursor == :paste
    end

    test "navigation skips disabled items" do
      items = [
        ContextMenu.action(:copy, "Copy"),
        ContextMenu.action(:paste, "Paste", disabled: true),
        ContextMenu.action(:delete, "Delete")
      ]

      props = create_test_props(items: items)
      {:ok, state} = Inline.init(props)

      {:ok, state} = Inline.handle_event(%Event.Key{key: :down}, state)

      # Should skip disabled paste and land on delete
      assert state.cursor == :delete
    end
  end

  # ----------------------------------------------------------------------------
  # Number Key Selection Tests
  # ----------------------------------------------------------------------------

  describe "number key selection" do
    test "pressing '1' selects first item" do
      test_pid = self()
      on_select = fn id -> send(test_pid, {:selected, id}) end

      props = create_test_props(on_select: on_select)
      {:ok, state} = Inline.init(props)

      {:ok, new_state} = Inline.handle_event(%Event.Key{key: "1"}, state)

      assert_receive {:selected, :copy}
      assert new_state.visible == false
    end

    test "pressing '2' selects second item" do
      test_pid = self()
      on_select = fn id -> send(test_pid, {:selected, id}) end

      props = create_test_props(on_select: on_select)
      {:ok, state} = Inline.init(props)

      {:ok, new_state} = Inline.handle_event(%Event.Key{key: "2"}, state)

      assert_receive {:selected, :paste}
      assert new_state.visible == false
    end

    test "pressing '3' selects third item" do
      test_pid = self()
      on_select = fn id -> send(test_pid, {:selected, id}) end

      props = create_test_props(on_select: on_select)
      {:ok, state} = Inline.init(props)

      {:ok, new_state} = Inline.handle_event(%Event.Key{key: "3"}, state)

      assert_receive {:selected, :delete}
      assert new_state.visible == false
    end

    test "pressing invalid number does nothing" do
      test_pid = self()
      on_select = fn id -> send(test_pid, {:selected, id}) end

      props = create_test_props(on_select: on_select)
      {:ok, state} = Inline.init(props)

      {:ok, new_state} = Inline.handle_event(%Event.Key{key: "9"}, state)

      refute_receive {:selected, _}
      assert new_state.visible == true
    end

    test "number keys respect number map (skip disabled)" do
      test_pid = self()
      on_select = fn id -> send(test_pid, {:selected, id}) end

      items = [
        ContextMenu.action(:copy, "Copy"),
        ContextMenu.action(:paste, "Paste", disabled: true),
        ContextMenu.action(:delete, "Delete")
      ]

      props = create_test_props(items: items, on_select: on_select)
      {:ok, state} = Inline.init(props)

      # '2' should select delete (since paste is disabled and skipped)
      {:ok, _state} = Inline.handle_event(%Event.Key{key: "2"}, state)

      assert_receive {:selected, :delete}
    end
  end

  # ----------------------------------------------------------------------------
  # Enter/Space Selection Tests
  # ----------------------------------------------------------------------------

  describe "Enter/Space selection" do
    test "Enter selects current item" do
      test_pid = self()
      on_select = fn id -> send(test_pid, {:selected, id}) end

      props = create_test_props(on_select: on_select)
      {:ok, state} = Inline.init(props)

      {:ok, new_state} = Inline.handle_event(%Event.Key{key: :enter}, state)

      assert_receive {:selected, :copy}
      assert new_state.visible == false
    end

    test "Space selects current item" do
      test_pid = self()
      on_select = fn id -> send(test_pid, {:selected, id}) end

      props = create_test_props(on_select: on_select)
      {:ok, state} = Inline.init(props)

      {:ok, new_state} = Inline.handle_event(%Event.Key{key: " "}, state)

      assert_receive {:selected, :copy}
      assert new_state.visible == false
    end

    test "can navigate then select with Enter" do
      test_pid = self()
      on_select = fn id -> send(test_pid, {:selected, id}) end

      props = create_test_props(on_select: on_select)
      {:ok, state} = Inline.init(props)

      {:ok, state} = Inline.handle_event(%Event.Key{key: :down}, state)
      {:ok, _state} = Inline.handle_event(%Event.Key{key: :enter}, state)

      assert_receive {:selected, :paste}
    end
  end

  # ----------------------------------------------------------------------------
  # Escape Tests
  # ----------------------------------------------------------------------------

  describe "Escape cancels menu" do
    test "Escape closes menu without selection" do
      test_pid = self()
      on_select = fn id -> send(test_pid, {:selected, id}) end
      on_close = fn -> send(test_pid, :closed) end

      props = create_test_props(on_select: on_select, on_close: on_close)
      {:ok, state} = Inline.init(props)

      {:ok, new_state} = Inline.handle_event(%Event.Key{key: :escape}, state)

      refute_receive {:selected, _}
      assert_receive :closed
      assert new_state.visible == false
    end
  end

  # ----------------------------------------------------------------------------
  # Public API Tests
  # ----------------------------------------------------------------------------

  describe "public API" do
    test "visible?/1 returns visibility state" do
      props = create_test_props()
      {:ok, state} = Inline.init(props)

      assert Inline.visible?(state) == true

      state = Inline.hide(state)
      assert Inline.visible?(state) == false
    end

    test "show/1 makes menu visible" do
      props = create_test_props()
      {:ok, state} = Inline.init(props)
      state = Inline.hide(state)

      state = Inline.show(state)

      assert state.visible == true
    end

    test "hide/1 hides menu" do
      props = create_test_props()
      {:ok, state} = Inline.init(props)

      state = Inline.hide(state)

      assert state.visible == false
    end

    test "get_cursor/1 returns current cursor" do
      props = create_test_props()
      {:ok, state} = Inline.init(props)

      assert Inline.get_cursor(state) == :copy

      {:ok, state} = Inline.handle_event(%Event.Key{key: :down}, state)
      assert Inline.get_cursor(state) == :paste
    end
  end
end
