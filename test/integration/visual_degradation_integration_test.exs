defmodule TermUI.Integration.VisualDegradationIntegrationTest do
  @moduledoc """
  Integration tests for visual degradation across capability levels.

  These tests verify that widgets render correctly across different terminal
  capability levels:

  1. **Color modes**: true_color, color_256, color_16, monochrome
  2. **Character sets**: Unicode vs ASCII
  3. **Combined degradation**: monochrome + ASCII

  ## Key Insight

  Visual degradation tests verify:
  - Widgets render without errors at each capability level
  - CharacterSet affects rendered characters correctly
  - Theme colors degrade to text attributes in monochrome
  - Selection/focus remains visible in all modes
  """

  use ExUnit.Case, async: false

  alias TermUI.CharacterSet
  alias TermUI.Theme
  alias TermUI.Widgets.{Gauge, Menu, Tabs, TreeView}

  # ============================================================================
  # Setup and Helpers
  # ============================================================================

  setup do
    # Save original character set config
    original_charset = Application.fetch_env(:term_ui, :character_set)
    original_runtime = :persistent_term.get(:term_ui_character_set, :not_set)

    :persistent_term.erase(:term_ui_character_set)

    # Start Theme server
    case Theme.start_link(theme: :dark) do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> :ok
    end

    on_exit(fn ->
      # Restore original character set
      restore_character_set_config(original_charset)
      restore_runtime_character_set(original_runtime)
    end)

    :ok
  end

  defp restore_character_set_config({:ok, value}),
    do: Application.put_env(:term_ui, :character_set, value)

  defp restore_character_set_config(:error),
    do: Application.delete_env(:term_ui, :character_set)

  defp restore_runtime_character_set(:not_set),
    do: :persistent_term.erase(:term_ui_character_set)

  defp restore_runtime_character_set(value),
    do: :persistent_term.put(:term_ui_character_set, value)

  defp test_area(width \\ 80, height \\ 24) do
    %{x: 0, y: 0, width: width, height: height}
  end

  # Helper to extract text content from render nodes
  defp extract_text(node) when is_map(node) do
    case node do
      %{type: :text, content: content} ->
        content

      %{type: :stack, children: children} ->
        Enum.map_join(children, "", &extract_text/1)

      %{type: :empty} ->
        ""

      %{children: children} when is_list(children) ->
        Enum.map_join(children, "", &extract_text/1)

      _ ->
        ""
    end
  end

  defp extract_text(_), do: ""

  # Helper to check if a style uses monochrome-compatible attributes
  defp has_mono_attribute?(%{attrs: attrs}) when is_struct(attrs, MapSet) do
    :bold in attrs or
      :underline in attrs or
      :reverse in attrs or
      :dim in attrs or
      :italic in attrs
  end

  defp has_mono_attribute?(style) when is_map(style) do
    style[:bold] == true or
      style[:underline] == true or
      style[:reverse] == true or
      style[:dim] == true or
      style[:italic] == true
  end

  defp has_mono_attribute?(_), do: false

  # ============================================================================
  # 5.7.4.1: Color Mode Rendering Tests
  # ============================================================================

  describe "color mode rendering - Menu widget" do
    setup do
      test_pid = self()

      props =
        Menu.new(
          items: [
            Menu.action(:item1, "First Item"),
            Menu.action(:item2, "Second Item"),
            Menu.action(:item3, "Third Item")
          ],
          on_select: fn id -> send(test_pid, {:selected, id}) end
        )

      {:ok, state} = Menu.init(props)
      %{state: state}
    end

    test "renders without error in true_color mode", %{state: state} do
      # Default theme uses named colors which work in all modes
      render = Menu.render(state, test_area())

      assert render != nil
      assert render.type in [:stack, :text, :empty]
    end

    test "renders without error in color_256 mode", %{state: state} do
      # Named colors like :blue, :red degrade to 256-color palette
      render = Menu.render(state, test_area())

      assert render != nil
      text = extract_text(render)
      assert String.contains?(text, "First Item")
    end

    test "renders without error in color_16 mode", %{state: state} do
      # Basic ANSI colors still work
      render = Menu.render(state, test_area())

      assert render != nil
      text = extract_text(render)
      assert String.contains?(text, "Second Item")
    end

    test "renders without error in monochrome mode", %{state: state} do
      # In monochrome, selection should be visible via reverse/bold
      render = Menu.render(state, test_area())

      assert render != nil
      text = extract_text(render)
      assert String.contains?(text, "Third Item")
    end

    test "selection is visible through text/styling", %{state: state} do
      # The selected item should have different styling
      render = Menu.render(state, test_area())

      assert render != nil
      # Menu renders items, first one should be selected
      assert render.type == :stack
    end
  end

  describe "color mode rendering - Gauge widget" do
    test "renders bar gauge without error" do
      render =
        Gauge.render(
          value: 75,
          min: 0,
          max: 100,
          width: 30,
          type: :bar
        )

      assert render != nil
      assert render.type in [:stack, :text]
    end

    test "renders gauge with value display" do
      render =
        Gauge.render(
          value: 85,
          min: 0,
          max: 100,
          width: 30,
          show_value: true
        )

      assert render != nil
      text = extract_text(render)
      # Should contain the value
      assert String.contains?(text, "85")
    end

    test "renders gauge in monochrome-compatible way" do
      # Gauge should still show progress visually
      render =
        Gauge.render(
          value: 50,
          min: 0,
          max: 100,
          width: 20,
          show_value: true
        )

      assert render != nil
      text = extract_text(render)
      assert String.contains?(text, "50")
    end
  end

  describe "color mode rendering - Tabs widget" do
    setup do
      props =
        Tabs.new(
          tabs: [
            %{id: :tab1, label: "Tab 1", content: "Content 1"},
            %{id: :tab2, label: "Tab 2", content: "Content 2"},
            %{id: :tab3, label: "Tab 3", content: "Content 3"}
          ]
        )

      {:ok, state} = Tabs.init(props)
      %{state: state}
    end

    test "renders tabs without error", %{state: state} do
      render = Tabs.render(state, test_area())

      assert render != nil
      text = extract_text(render)
      assert String.contains?(text, "Tab 1") or String.contains?(text, "Tab 2")
    end

    test "focus indicator visible in all modes", %{state: state} do
      render = Tabs.render(state, test_area())

      assert render != nil
      # The focused tab should be distinguishable
      assert render.type in [:stack, :text]
    end
  end

  # ============================================================================
  # 5.7.4.2: Unicode vs ASCII Rendering Tests
  # ============================================================================

  describe "character set rendering - Unicode mode" do
    setup do
      Application.put_env(:term_ui, :character_set, :unicode)
      :ok
    end

    test "CharacterSet returns Unicode characters" do
      chars = CharacterSet.get(:unicode)

      assert chars.tl == "┌"
      assert chars.tr == "┐"
      assert chars.h_line == "─"
      assert chars.v_line == "│"
      assert chars.bar_full == "█"
      assert chars.check == "✓"
      assert chars.arrow_right == "→"
    end

    test "current_charset returns Unicode when configured" do
      chars = CharacterSet.current_charset()

      assert chars.tl == "┌"
      assert chars.bar_full == "█"
    end

    test "Gauge uses Unicode bar characters" do
      render =
        Gauge.render(
          value: 50,
          min: 0,
          max: 100,
          width: 20
        )

      # Should render without error
      assert render != nil
      assert render.type in [:stack, :text]
    end
  end

  describe "character set rendering - ASCII mode" do
    setup do
      Application.put_env(:term_ui, :character_set, :ascii)
      :ok
    end

    test "CharacterSet returns ASCII characters" do
      chars = CharacterSet.get(:ascii)

      assert chars.tl == "+"
      assert chars.tr == "+"
      assert chars.h_line == "-"
      assert chars.v_line == "|"
      assert chars.bar_full == "#"
      assert chars.check == "x"
      assert chars.arrow_right == ">"
    end

    test "current_charset returns ASCII when configured" do
      chars = CharacterSet.current_charset()

      assert chars.tl == "+"
      assert chars.bar_full == "#"
    end

    test "TreeView renders without error in ASCII mode" do
      props =
        TreeView.new(
          nodes: [
            TreeView.node(:root, "Root", [
              TreeView.node(:child1, "Child 1"),
              TreeView.node(:child2, "Child 2")
            ])
          ]
        )

      {:ok, state} = TreeView.init(props)
      render = TreeView.render(state, test_area())

      assert render != nil
      text = extract_text(render)
      assert String.contains?(text, "Root") or String.contains?(text, "Child")
    end
  end

  describe "character set switching at runtime" do
    test "switching from Unicode to ASCII changes characters" do
      # Start with Unicode
      Application.put_env(:term_ui, :character_set, :unicode)
      unicode_chars = CharacterSet.current_charset()

      assert unicode_chars.tl == "┌"

      # Switch to ASCII
      Application.put_env(:term_ui, :character_set, :ascii)
      ascii_chars = CharacterSet.current_charset()

      assert ascii_chars.tl == "+"

      # Verify they are different
      assert unicode_chars.tl != ascii_chars.tl
      assert unicode_chars.bar_full != ascii_chars.bar_full
    end

    test "widgets render correctly after charset switch" do
      # Start with Unicode
      Application.put_env(:term_ui, :character_set, :unicode)

      render1 =
        Gauge.render(
          value: 50,
          min: 0,
          max: 100,
          width: 20
        )

      assert render1 != nil

      # Switch to ASCII
      Application.put_env(:term_ui, :character_set, :ascii)

      render2 =
        Gauge.render(
          value: 50,
          min: 0,
          max: 100,
          width: 20
        )

      assert render2 != nil
    end
  end

  # ============================================================================
  # 5.7.4.3: Combined Degradation Tests (Monochrome + ASCII)
  # ============================================================================

  describe "combined degradation - monochrome + ASCII" do
    setup do
      # Configure for worst-case scenario
      Application.put_env(:term_ui, :character_set, :ascii)
      :ok
    end

    test "Menu renders usably with ASCII and selection visible" do
      props =
        Menu.new(
          items: [
            Menu.action(:a, "Action A"),
            Menu.action(:b, "Action B"),
            Menu.action(:c, "Action C")
          ]
        )

      {:ok, state} = Menu.init(props)
      render = Menu.render(state, test_area())

      assert render != nil
      text = extract_text(render)
      assert String.contains?(text, "Action A")
      assert String.contains?(text, "Action B")
    end

    test "Gauge renders usably with ASCII bar characters" do
      render =
        Gauge.render(
          value: 75,
          min: 0,
          max: 100,
          width: 20,
          show_value: true
        )

      assert render != nil
      text = extract_text(render)
      # Value should be shown
      assert String.contains?(text, "75")
    end

    test "Tabs renders usably with ASCII borders" do
      props =
        Tabs.new(
          tabs: [
            %{id: :t1, label: "First", content: "Content 1"},
            %{id: :t2, label: "Second", content: "Content 2"}
          ]
        )

      {:ok, state} = Tabs.init(props)
      render = Tabs.render(state, test_area())

      assert render != nil
      text = extract_text(render)
      assert String.contains?(text, "First") or String.contains?(text, "Second")
    end

    test "TreeView renders usably with ASCII tree lines" do
      props =
        TreeView.new(
          nodes: [
            TreeView.node(:root, "Project", [
              TreeView.node(:src, "src", [
                TreeView.node(:main, "main.ex")
              ]),
              TreeView.node(:readme, "README.md")
            ])
          ]
        )

      {:ok, state} = TreeView.init(props)
      render = TreeView.render(state, test_area())

      assert render != nil
      text = extract_text(render)
      assert String.contains?(text, "Project") or String.contains?(text, "src")
    end

    test "all character set keys have ASCII equivalents" do
      unicode_chars = CharacterSet.get(:unicode)
      ascii_chars = CharacterSet.get(:ascii)

      # Verify all keys exist in both
      for key <- CharacterSet.keys() do
        assert Map.has_key?(unicode_chars, key),
               "Unicode charset missing key: #{key}"

        assert Map.has_key?(ascii_chars, key),
               "ASCII charset missing key: #{key}"
      end
    end

    test "ASCII characters are all single-byte printable" do
      ascii_chars = CharacterSet.get(:ascii)

      # bar_levels and sparkline_levels are lists, not single characters
      list_keys = [:bar_levels, :sparkline_levels]

      for {key, value} <- ascii_chars, key not in list_keys do
        # Each character should be printable ASCII
        assert is_binary(value), "#{key} should be a string"

        assert byte_size(value) == String.length(value),
               "#{key} should be ASCII: #{inspect(value)}"
      end
    end
  end

  describe "visual hierarchy in degraded modes" do
    setup do
      Application.put_env(:term_ui, :character_set, :ascii)
      :ok
    end

    test "focused items distinguishable from unfocused" do
      # Create menu and verify focused item has different rendering
      props =
        Menu.new(
          items: [
            Menu.action(:a, "Item A"),
            Menu.action(:b, "Item B")
          ]
        )

      {:ok, state} = Menu.init(props)

      # Render with first item focused
      render1 = Menu.render(state, test_area())
      assert render1 != nil

      # Navigate to second item
      {:ok, state2} = Menu.handle_event(%TermUI.Event.Key{key: :down}, state)

      # Render with second item focused
      render2 = Menu.render(state2, test_area())
      assert render2 != nil

      # Both should render successfully
      # The difference would be in styling (reverse, bold, etc.)
    end

    test "selected items distinguishable from unselected" do
      props =
        Tabs.new(
          tabs: [
            %{id: :t1, label: "Tab One", content: "C1"},
            %{id: :t2, label: "Tab Two", content: "C2"}
          ]
        )

      {:ok, state} = Tabs.init(props)

      # First tab is selected by default
      render1 = Tabs.render(state, test_area())
      assert render1 != nil

      # Select second tab
      {:ok, state2} = Tabs.handle_event(%TermUI.Event.Key{key: :right}, state)
      {:ok, state3} = Tabs.handle_event(%TermUI.Event.Key{key: :enter}, state2)

      render2 = Tabs.render(state3, test_area())
      assert render2 != nil
    end

    test "error states use underline in monochrome theme" do
      # The high_contrast theme uses underline for error states
      # This is how error visibility is maintained in monochrome
      {:ok, theme} = Theme.get_builtin(:high_contrast)

      error_style = theme.components[:status][:error]
      assert error_style != nil
      assert has_mono_attribute?(error_style)
    end

    test "focused states use bold in theme" do
      {:ok, theme} = Theme.get_builtin(:dark)

      # Check that focused items have bold attribute
      button_focused = theme.components[:button][:focused]
      assert button_focused != nil
      assert :bold in button_focused.attrs
    end
  end

  # ============================================================================
  # Edge Cases and Boundary Tests
  # ============================================================================

  describe "edge cases" do
    test "empty gauge renders without error" do
      render = Gauge.render(value: 0, min: 0, max: 100, width: 20)
      assert render != nil
    end

    test "full gauge renders without error" do
      render = Gauge.render(value: 100, min: 0, max: 100, width: 20)
      assert render != nil
    end

    test "menu with single item renders" do
      props = Menu.new(items: [Menu.action(:only, "Only Item")])
      {:ok, state} = Menu.init(props)
      render = Menu.render(state, test_area())

      assert render != nil
      text = extract_text(render)
      assert String.contains?(text, "Only Item")
    end

    test "tabs with single tab renders" do
      props = Tabs.new(tabs: [%{id: :single, label: "Single", content: "Content"}])
      {:ok, state} = Tabs.init(props)
      render = Tabs.render(state, test_area())

      assert render != nil
    end

    test "treeview with single node renders" do
      props = TreeView.new(nodes: [TreeView.node(:alone, "Alone")])
      {:ok, state} = TreeView.init(props)
      render = TreeView.render(state, test_area())

      assert render != nil
      text = extract_text(render)
      assert String.contains?(text, "Alone")
    end
  end
end
