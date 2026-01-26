defmodule TermUI.Widgets.ContextMenu.FactoryTest do
  use ExUnit.Case, async: true

  import TermUI.Test.ContextMenuHelpers

  alias TermUI.Widgets.ContextMenu
  alias TermUI.Widgets.ContextMenu.Factory
  alias TermUI.Widgets.ContextMenu.Inline
  alias TermUI.Capabilities

  # Test helpers

  # Restores an environment variable to its original value (or deletes if it was nil)
  defp restore_env(key, original_value) do
    if original_value do
      System.put_env(key, original_value)
    else
      System.delete_env(key)
    end
  end

  # Executes a test function with mouse support enabled or disabled
  defp with_mouse_support(enabled, fun) do
    # Clear cache and set up test capabilities
    Capabilities.clear_cache()

    # Store original environment
    original_env = %{
      "TERM" => System.get_env("TERM"),
      "COLORTERM" => System.get_env("COLORTERM"),
      "TERM_PROGRAM" => System.get_env("TERM_PROGRAM")
    }

    try do
      if enabled do
        # Set up environment for mouse support (modern terminal)
        System.put_env("TERM", "xterm-256color")
        System.put_env("COLORTERM", "truecolor")
        System.put_env("TERM_PROGRAM", "iTerm.app")
      else
        # Set up environment for no mouse support (basic terminal)
        System.put_env("TERM", "dumb")
        System.delete_env("COLORTERM")
        System.delete_env("TERM_PROGRAM")
      end

      # Clear cache again to pick up new env
      Capabilities.clear_cache()

      fun.()
    after
      # Restore original environment
      Enum.each(original_env, fn {key, value} -> restore_env(key, value) end)
      Capabilities.clear_cache()
    end
  end

  # ----------------------------------------------------------------------------
  # Basic Creation Tests
  # ----------------------------------------------------------------------------

  describe "create/1 basic" do
    test "returns error when items not provided" do
      assert {:error, :missing_items} = Factory.create([])
    end

    test "returns error when items is not a list" do
      assert {:error, :missing_items} = Factory.create(items: "not a list")
    end
  end

  # ----------------------------------------------------------------------------
  # Explicit Mode Tests
  # ----------------------------------------------------------------------------

  describe "create/1 with explicit mode: :inline" do
    test "creates Inline menu" do
      {:ok, {module, props}} =
        Factory.create(
          items: simple_items(),
          mode: :inline
        )

      assert module == Inline
      assert length(props.items) == 3
    end

    test "creates Inline menu even with position provided" do
      {:ok, {module, _props}} =
        Factory.create(
          items: simple_items(),
          mode: :inline,
          position: {10, 5}
        )

      assert module == Inline
    end

    test "passes orientation option to Inline" do
      {:ok, {module, props}} =
        Factory.create(
          items: simple_items(),
          mode: :inline,
          orientation: :vertical
        )

      assert module == Inline
      assert props.orientation == :vertical
    end
  end

  describe "create/1 with explicit mode: :positioned" do
    test "creates ContextMenu with position" do
      {:ok, {module, props}} =
        Factory.create(
          items: simple_items(),
          mode: :positioned,
          position: {10, 5}
        )

      assert module == ContextMenu
      assert props.position == {10, 5}
    end

    test "returns error when position not provided" do
      assert {:error, :missing_position} =
               Factory.create(
                 items: simple_items(),
                 mode: :positioned
               )
    end
  end

  # ----------------------------------------------------------------------------
  # Auto Mode Tests
  # ----------------------------------------------------------------------------

  describe "create/1 with mode: :auto (default)" do
    test "uses positioned mode when position provided" do
      {:ok, {module, props}} =
        Factory.create(
          items: simple_items(),
          position: {10, 5}
        )

      assert module == ContextMenu
      assert props.position == {10, 5}
    end

    test "uses inline mode when no position and mouse not supported" do
      with_mouse_support(false, fn ->
        {:ok, {module, _props}} =
          Factory.create(items: simple_items())

        assert module == Inline
      end)
    end

    test "returns error when no position but mouse is supported" do
      with_mouse_support(true, fn ->
        assert {:error, :position_required} =
                 Factory.create(items: simple_items())
      end)
    end
  end

  # ----------------------------------------------------------------------------
  # Callback Passing Tests
  # ----------------------------------------------------------------------------

  describe "create/1 passes callbacks" do
    test "passes on_select to positioned menu" do
      on_select = fn _id -> :selected end

      {:ok, {_module, props}} =
        Factory.create(
          items: simple_items(),
          position: {10, 5},
          on_select: on_select
        )

      assert props.on_select == on_select
    end

    test "passes on_select to inline menu" do
      on_select = fn _id -> :selected end

      {:ok, {_module, props}} =
        Factory.create(
          items: simple_items(),
          mode: :inline,
          on_select: on_select
        )

      assert props.on_select == on_select
    end

    test "passes on_close to menus" do
      on_close = fn -> :closed end

      {:ok, {_module, props}} =
        Factory.create(
          items: simple_items(),
          mode: :inline,
          on_close: on_close
        )

      assert props.on_close == on_close
    end
  end

  # ----------------------------------------------------------------------------
  # Style Passing Tests
  # ----------------------------------------------------------------------------

  describe "create/1 passes styles" do
    test "passes styles to positioned menu" do
      {:ok, {_module, props}} =
        Factory.create(
          items: simple_items(),
          position: {10, 5},
          item_style: :normal,
          selected_style: :selected,
          disabled_style: :disabled
        )

      assert props.item_style == :normal
      assert props.selected_style == :selected
      assert props.disabled_style == :disabled
    end

    test "passes styles to inline menu" do
      {:ok, {_module, props}} =
        Factory.create(
          items: simple_items(),
          mode: :inline,
          item_style: :normal,
          selected_style: :selected,
          disabled_style: :disabled,
          number_style: :number
        )

      assert props.item_style == :normal
      assert props.selected_style == :selected
      assert props.disabled_style == :disabled
      assert props.number_style == :number
    end
  end

  # ----------------------------------------------------------------------------
  # create!/1 Tests
  # ----------------------------------------------------------------------------

  describe "create!/1" do
    test "returns result on success" do
      {module, props} =
        Factory.create!(
          items: simple_items(),
          mode: :inline
        )

      assert module == Inline
      assert length(props.items) == 3
    end

    test "raises on missing items" do
      assert_raise ArgumentError, ~r/requires :items/, fn ->
        Factory.create!([])
      end
    end

    test "raises on missing position for positioned mode" do
      assert_raise ArgumentError, ~r/requires :position/, fn ->
        Factory.create!(
          items: simple_items(),
          mode: :positioned
        )
      end
    end

    test "raises when mouse supported but no position" do
      with_mouse_support(true, fn ->
        assert_raise ArgumentError, ~r/position/, fn ->
          Factory.create!(items: simple_items())
        end
      end)
    end
  end

  # ----------------------------------------------------------------------------
  # mouse_supported?/0 Tests
  # ----------------------------------------------------------------------------

  describe "mouse_supported?/0" do
    test "returns true when mouse is supported" do
      with_mouse_support(true, fn ->
        assert Factory.mouse_supported?() == true
      end)
    end

    test "returns false when mouse is not supported" do
      with_mouse_support(false, fn ->
        assert Factory.mouse_supported?() == false
      end)
    end
  end

  # ----------------------------------------------------------------------------
  # Integration Tests
  # ----------------------------------------------------------------------------

  describe "integration with actual menu modules" do
    test "created positioned menu can be initialized" do
      {:ok, {module, props}} =
        Factory.create(
          items: simple_items(),
          position: {10, 5}
        )

      assert {:ok, state} = module.init(props)
      assert state.visible == true
      assert state.position == {10, 5}
    end

    test "created inline menu can be initialized" do
      {:ok, {module, props}} =
        Factory.create(
          items: simple_items(),
          mode: :inline
        )

      assert {:ok, state} = module.init(props)
      assert state.visible == true
      assert state.cursor == :copy
    end
  end
end
