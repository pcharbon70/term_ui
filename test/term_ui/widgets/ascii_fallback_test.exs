defmodule TermUI.Widgets.AsciiFallbackTest do
  @moduledoc """
  Tests that widgets render correctly with ASCII character set fallback.

  These tests verify that when CharacterSet is configured for ASCII mode,
  widgets produce valid ASCII output without Unicode characters.
  """
  use ExUnit.Case, async: false

  alias TermUI.CharacterSet
  alias TermUI.Theme
  alias TermUI.Widgets.Dialog
  alias TermUI.Widgets.Gauge
  alias TermUI.Widgets.Menu
  alias TermUI.Widgets.Sparkline
  alias TermUI.Widgets.Table
  alias TermUI.Widgets.Table.Column
  alias TermUI.Widgets.Toast
  alias TermUI.Widgets.TreeView
  alias TermUI.Layout.Constraint

  # Helper to extract all text content from a render tree
  defp extract_text(node), do: extract_text(node, []) |> Enum.reverse() |> Enum.join("")

  # Handle maps with :type field (most render nodes)
  defp extract_text(%{type: :text, content: content}, acc) when is_binary(content) do
    [content | acc]
  end

  defp extract_text(%{type: :stack, children: children}, acc) do
    Enum.reduce(children, acc, &extract_text/2)
  end

  defp extract_text(%{type: :overlay, content: content}, acc) do
    extract_text(content, acc)
  end

  defp extract_text(%{type: :styled, child: child}, acc) do
    extract_text(child, acc)
  end

  defp extract_text(%{type: :box, children: children}, acc) do
    Enum.reduce(children, acc, &extract_text/2)
  end

  defp extract_text(_node, acc), do: acc

  setup do
    # Start Theme server for color support (ignore if already started)
    case Theme.start_link(theme: :dark) do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> :ok
    end

    # Save original config
    original = Application.get_env(:term_ui, :character_set)

    # Set ASCII mode for these tests
    Application.put_env(:term_ui, :character_set, :ascii)

    on_exit(fn ->
      # Restore original config
      if original do
        Application.put_env(:term_ui, :character_set, original)
      else
        Application.delete_env(:term_ui, :character_set)
      end
    end)

    :ok
  end

  describe "CharacterSet ASCII mode" do
    test "current/0 returns :ascii when configured" do
      assert CharacterSet.current() == :ascii
    end

    test "current_charset/0 returns ASCII characters" do
      chars = CharacterSet.current_charset()
      assert chars.tl == "+"
      assert chars.h_line == "-"
      assert chars.v_line == "|"
    end
  end

  # ===========================================================================
  # Box-Drawing Character Tests (Task 5.5.3.1)
  # ===========================================================================

  describe "box-drawing ASCII fallback" do
    test "Dialog renders borders with +, -, |" do
      props = Dialog.new(title: "Test", width: 20)
      {:ok, state} = Dialog.init(props)
      area = %{x: 0, y: 0, width: 80, height: 24}

      result = Dialog.render(state, area)
      text = extract_text(result)

      # Verify ASCII box characters are used
      assert String.contains?(text, "+"), "Border should contain + for corners"
      assert String.contains?(text, "-"), "Border should contain - for horizontal lines"
      assert String.contains?(text, "|"), "Border should contain | for vertical lines"

      # Verify no Unicode box-drawing characters
      refute String.contains?(text, "┌"), "Should not contain Unicode corner ┌"
      refute String.contains?(text, "─"), "Should not contain Unicode horizontal ─"
      refute String.contains?(text, "│"), "Should not contain Unicode vertical │"
    end

    test "Toast renders borders with +, -, |" do
      props =
        Toast.new(
          message: "Test message",
          type: :info,
          duration: nil
        )

      {:ok, state} = Toast.init(props)
      area = %{x: 0, y: 0, width: 80, height: 24}

      result = Toast.render(state, area)
      text = extract_text(result)

      # Verify ASCII box characters
      assert String.contains?(text, "+"), "Toast border should use + for corners"
      assert String.contains?(text, "-"), "Toast border should use - for horizontal"
      assert String.contains?(text, "|"), "Toast border should use | for vertical"

      # Verify no Unicode
      refute String.contains?(text, "┌"), "Should not contain Unicode corner"
      refute String.contains?(text, "─"), "Should not contain Unicode horizontal"
    end

    test "Menu separator renders with - instead of ─" do
      items = [
        Menu.action(:item1, "Item 1"),
        Menu.separator(),
        Menu.action(:item2, "Item 2")
      ]

      props = Menu.new(items: items)
      {:ok, state} = Menu.init(props)
      area = %{x: 0, y: 0, width: 40, height: 20}

      result = Menu.render(state, area)
      text = extract_text(result)

      # Separator should use ASCII dash
      assert String.contains?(text, "-"), "Separator should use ASCII dash"
      refute String.contains?(text, "─"), "Should not contain Unicode horizontal line"
    end
  end

  # ===========================================================================
  # Arrow/Indicator Character Tests (Task 5.5.3.2)
  # ===========================================================================

  describe "arrow ASCII fallback" do
    test "Table sort arrows render as ^, v" do
      columns = [
        Column.new(:name, "Name", width: Constraint.length(20)),
        Column.new(:value, "Value", width: Constraint.length(10))
      ]

      data = [
        %{name: "Item 1", value: 10},
        %{name: "Item 2", value: 20}
      ]

      props = Table.new(columns: columns, data: data)
      {:ok, state} = Table.init(props)

      # Set sorting state manually
      state = %{state | sort_column: :name, sort_direction: :asc}

      area = %{x: 0, y: 0, width: 80, height: 20}

      result = Table.render(state, area)
      text = extract_text(result)

      # Ascending sort should show ^
      assert String.contains?(text, "^") or String.contains?(text, "v"),
             "Sort indicator should use ASCII arrow"

      refute String.contains?(text, "↑"), "Should not contain Unicode up arrow"
      refute String.contains?(text, "↓"), "Should not contain Unicode down arrow"
    end

    test "TreeView expand/collapse renders as >, v" do
      nodes = [
        TreeView.node(:parent, "Parent",
          children: [
            TreeView.node(:child, "Child")
          ]
        )
      ]

      props = TreeView.new(nodes: nodes)
      {:ok, state} = TreeView.init(props)

      # Expand the parent
      state = TreeView.expand(state, :parent)

      area = %{x: 0, y: 0, width: 40, height: 20}
      result = TreeView.render(state, area)
      text = extract_text(result)

      # Expanded node should show v, collapsed should show >
      assert String.contains?(text, "v") or String.contains?(text, ">"),
             "Expand/collapse should use ASCII indicators"

      refute String.contains?(text, "▶"), "Should not contain Unicode triangle right"
      refute String.contains?(text, "▼"), "Should not contain Unicode triangle down"
    end

    test "Menu submenu arrow renders as >" do
      items = [
        Menu.submenu(:sub, "Submenu", [
          Menu.action(:sub_item, "Sub Item")
        ])
      ]

      props = Menu.new(items: items)
      {:ok, state} = Menu.init(props)
      area = %{x: 0, y: 0, width: 40, height: 20}

      result = Menu.render(state, area)
      text = extract_text(result)

      # Collapsed submenu should show >
      assert String.contains?(text, ">"), "Submenu indicator should use ASCII >"
      refute String.contains?(text, "▶"), "Should not contain Unicode triangle"
    end

    test "Menu checkbox renders with x instead of ✓" do
      items = [
        Menu.checkbox(:check1, "Option 1", checked: true),
        Menu.checkbox(:check2, "Option 2", checked: false)
      ]

      props = Menu.new(items: items)
      {:ok, state} = Menu.init(props)
      area = %{x: 0, y: 0, width: 40, height: 20}

      result = Menu.render(state, area)
      text = extract_text(result)

      # Checked item should use ASCII x
      assert String.contains?(text, "[x]") or String.contains?(text, "x"),
             "Checkbox should use ASCII x for check"

      refute String.contains?(text, "✓"), "Should not contain Unicode checkmark"
    end
  end

  # ===========================================================================
  # Progress Bar Character Tests (Task 5.5.3.3)
  # ===========================================================================

  describe "progress bar ASCII fallback" do
    test "Gauge renders bar with # and ." do
      result =
        Gauge.render(
          value: 50,
          min: 0,
          max: 100,
          width: 20,
          show_value: false,
          show_range: false
        )

      text = extract_text(result)

      # Bar should use ASCII characters
      assert String.contains?(text, "#") or String.contains?(text, "."),
             "Gauge should use ASCII bar characters"

      refute String.contains?(text, "█"), "Should not contain Unicode full block"
      refute String.contains?(text, "░"), "Should not contain Unicode light shade"
    end

    test "Gauge bar_full character is #" do
      chars = CharacterSet.current_charset()
      assert chars.bar_full == "#"
    end

    test "Gauge bar_empty character is ." do
      chars = CharacterSet.current_charset()
      assert chars.bar_empty == "."
    end

    test "Sparkline levels use ASCII characters" do
      chars = CharacterSet.current_charset()
      levels = chars.sparkline_levels

      assert is_list(levels)
      assert length(levels) == 5, "ASCII sparkline should have 5 levels"

      # Verify all levels are ASCII printable
      for level <- levels do
        assert byte_size(level) == 1, "Each level should be single ASCII byte"
        assert String.printable?(level), "Level should be printable"
      end

      # Verify no Unicode sparkline characters
      refute "▁" in levels, "Should not contain Unicode lower one eighth"
      refute "█" in levels, "Should not contain Unicode full block"
    end

    test "Sparkline.bar_characters returns ASCII levels" do
      levels = Sparkline.bar_characters()

      assert is_list(levels)
      assert length(levels) == 5

      # Expected ASCII levels: ["_", ".", ":", "=", "#"]
      for level <- levels do
        assert level in ["_", ".", ":", "=", "#", " "],
               "Sparkline level #{inspect(level)} should be ASCII"
      end
    end

    test "Sparkline renders with ASCII characters" do
      data = [1, 3, 5, 2, 4, 6, 3, 5]

      result =
        Sparkline.render(
          data: data,
          width: 8,
          height: 1
        )

      text = extract_text(result)

      # Should not contain Unicode sparkline characters
      refute String.contains?(text, "▁"), "Should not contain Unicode lower block"
      refute String.contains?(text, "▂"), "Should not contain Unicode lower 2/8"
      refute String.contains?(text, "▃"), "Should not contain Unicode lower 3/8"
      refute String.contains?(text, "▄"), "Should not contain Unicode lower half"
      refute String.contains?(text, "▅"), "Should not contain Unicode lower 5/8"
      refute String.contains?(text, "▆"), "Should not contain Unicode lower 6/8"
      refute String.contains?(text, "▇"), "Should not contain Unicode lower 7/8"
    end
  end

  # ===========================================================================
  # Icon Character Tests
  # ===========================================================================

  describe "icon ASCII fallback" do
    test "info icon renders as i" do
      chars = CharacterSet.current_charset()
      assert chars.info == "i"
    end

    test "warning icon renders as !" do
      chars = CharacterSet.current_charset()
      assert chars.warning == "!"
    end

    test "check mark renders as x" do
      chars = CharacterSet.current_charset()
      assert chars.check == "x"
    end

    test "cross mark renders as X" do
      chars = CharacterSet.current_charset()
      assert chars.cross_mark == "X"
    end

    test "Toast info type uses ASCII icon" do
      props =
        Toast.new(
          message: "Info message",
          type: :info,
          duration: nil
        )

      {:ok, state} = Toast.init(props)
      area = %{x: 0, y: 0, width: 80, height: 24}

      result = Toast.render(state, area)
      text = extract_text(result)

      # Should not contain Unicode info icon
      refute String.contains?(text, "ℹ"), "Should not contain Unicode info icon"
    end
  end

  # ===========================================================================
  # Comprehensive ASCII-only verification
  # ===========================================================================

  describe "no Unicode characters in ASCII mode" do
    @unicode_box_chars ["┌", "┐", "└", "┘", "─", "│", "├", "┤", "┬", "┴", "┼"]
    @unicode_arrows ["↑", "↓", "←", "→", "↕"]
    @unicode_triangles ["▲", "▼", "◀", "▶"]
    @unicode_blocks ["█", "░", "▏", "▎", "▍", "▌", "▋", "▊", "▉"]
    @unicode_sparkline ["▁", "▂", "▃", "▄", "▅", "▆", "▇"]
    @unicode_symbols ["✓", "✗", "●", "○", "►", "ℹ", "⚠", "⟳", "…", "•"]
    @unicode_rounded ["╭", "╮", "╰", "╯"]

    @all_unicode_chars @unicode_box_chars ++
                         @unicode_arrows ++
                         @unicode_triangles ++
                         @unicode_blocks ++
                         @unicode_sparkline ++
                         @unicode_symbols ++
                         @unicode_rounded

    test "CharacterSet ASCII has no Unicode characters" do
      chars = CharacterSet.get(:ascii)

      for {key, value} <- chars do
        case key do
          k when k in [:bar_levels, :sparkline_levels] ->
            for level <- value do
              for unicode_char <- @all_unicode_chars do
                refute String.contains?(level, unicode_char),
                       "#{key} level contains Unicode char #{unicode_char}"
              end
            end

          _ ->
            for unicode_char <- @all_unicode_chars do
              refute String.contains?(value, unicode_char),
                     "#{key} (#{inspect(value)}) contains Unicode char #{unicode_char}"
            end
        end
      end
    end
  end
end
