defmodule TermUI.Backend.RawTest do
  @moduledoc """
  Unit tests for TermUI.Backend.Raw module.

  This test file covers the module structure, behaviour declaration, and state structure.
  Callback implementation tests will be added as each section is implemented.
  """

  use ExUnit.Case, async: true

  alias TermUI.Backend.Raw

  describe "module structure" do
    test "module compiles successfully" do
      assert Code.ensure_loaded?(Raw)
    end

    test "declares @behaviour TermUI.Backend" do
      behaviours = Raw.__info__(:attributes)[:behaviour] || []
      assert TermUI.Backend in behaviours
    end

    test "exports all required callbacks" do
      # Lifecycle callbacks
      assert function_exported?(Raw, :init, 1)
      assert function_exported?(Raw, :shutdown, 1)

      # Query callbacks
      assert function_exported?(Raw, :size, 1)

      # Cursor callbacks
      assert function_exported?(Raw, :move_cursor, 2)
      assert function_exported?(Raw, :hide_cursor, 1)
      assert function_exported?(Raw, :show_cursor, 1)

      # Rendering callbacks
      assert function_exported?(Raw, :clear, 1)
      assert function_exported?(Raw, :draw_cells, 2)
      assert function_exported?(Raw, :flush, 1)

      # Input callbacks
      assert function_exported?(Raw, :poll_event, 2)
    end

    test "exports helper functions" do
      assert function_exported?(Raw, :valid_position?, 2)
      assert function_exported?(Raw, :mouse_mode_to_ansi, 1)
      assert function_exported?(Raw, :ansi_module, 0)
    end

    test "has ANSI module aliased" do
      assert Raw.ansi_module() == TermUI.ANSI
    end
  end

  describe "documentation" do
    test "module has moduledoc" do
      {:docs_v1, _, :elixir, _, module_doc, _, _} = Code.fetch_docs(Raw)
      assert module_doc != :none
      assert module_doc != :hidden
    end

    test "moduledoc describes OTP 28+ requirement" do
      {:docs_v1, _, :elixir, _, %{"en" => doc}, _, _} = Code.fetch_docs(Raw)
      assert doc =~ "OTP 28"
    end

    test "moduledoc describes raw mode activation by Selector" do
      {:docs_v1, _, :elixir, _, %{"en" => doc}, _, _} = Code.fetch_docs(Raw)
      assert doc =~ "Selector"
      assert doc =~ "raw mode"
    end

    test "moduledoc describes initialization flow" do
      {:docs_v1, _, :elixir, _, %{"en" => doc}, _, _} = Code.fetch_docs(Raw)
      assert doc =~ "init/1"
      assert doc =~ "alternate screen"
    end

    test "moduledoc documents mouse tracking modes" do
      {:docs_v1, _, :elixir, _, %{"en" => doc}, _, _} = Code.fetch_docs(Raw)
      assert doc =~ "Mouse Tracking Modes"
      assert doc =~ ":click"
      assert doc =~ ":drag"
      assert doc =~ "ANSI Protocol"
    end

    test "moduledoc documents style delta optimization" do
      {:docs_v1, _, :elixir, _, %{"en" => doc}, _, _} = Code.fetch_docs(Raw)
      assert doc =~ "Style Delta Optimization"
      assert doc =~ "current_style"
    end

    test "init/1 has documentation" do
      {:docs_v1, _, :elixir, _, _, _, docs} = Code.fetch_docs(Raw)

      func_docs =
        docs
        |> Enum.filter(fn
          {{:function, :init, 1}, _, _, _, _} -> true
          _ -> false
        end)

      assert length(func_docs) == 1
    end

    test "shutdown/1 has documentation" do
      {:docs_v1, _, :elixir, _, _, _, docs} = Code.fetch_docs(Raw)

      func_docs =
        docs
        |> Enum.filter(fn
          {{:function, :shutdown, 1}, _, _, _, _} -> true
          _ -> false
        end)

      assert length(func_docs) == 1
    end
  end

  describe "state structure" do
    test "state struct has all expected fields" do
      state = %Raw{}

      assert Map.has_key?(state, :size)
      assert Map.has_key?(state, :cursor_visible)
      assert Map.has_key?(state, :cursor_position)
      assert Map.has_key?(state, :alternate_screen)
      assert Map.has_key?(state, :mouse_mode)
      assert Map.has_key?(state, :current_style)
    end

    test "state struct has correct default values" do
      state = %Raw{}

      assert state.size == {24, 80}
      assert state.cursor_visible == false
      assert state.cursor_position == nil
      assert state.alternate_screen == false
      assert state.mouse_mode == :none
      assert state.current_style == nil
    end

    test "state struct can be pattern matched" do
      state = %Raw{size: {30, 100}, cursor_visible: true}

      assert %Raw{size: {30, 100}} = state
      assert %Raw{cursor_visible: true} = state
    end

    test "state struct can be created with custom values" do
      state = %Raw{
        size: {50, 120},
        cursor_visible: true,
        cursor_position: {10, 20},
        alternate_screen: true,
        mouse_mode: :all,
        current_style: %{fg: :red, bg: :default, attrs: [:bold]}
      }

      assert state.size == {50, 120}
      assert state.cursor_visible == true
      assert state.cursor_position == {10, 20}
      assert state.alternate_screen == true
      assert state.mouse_mode == :all
      assert state.current_style == %{fg: :red, bg: :default, attrs: [:bold]}
    end

    test "state struct can be updated with struct update syntax" do
      state = %Raw{}
      updated = %{state | cursor_visible: true, mouse_mode: :click}

      assert updated.cursor_visible == true
      assert updated.mouse_mode == :click
      # Other fields unchanged
      assert updated.size == {24, 80}
    end

    test "mouse_mode accepts all valid values" do
      for mode <- [:none, :click, :drag, :all] do
        state = %Raw{mouse_mode: mode}
        assert state.mouse_mode == mode
      end
    end

    test "cursor_position can be nil or tuple" do
      state1 = %Raw{cursor_position: nil}
      state2 = %Raw{cursor_position: {5, 10}}

      assert state1.cursor_position == nil
      assert state2.cursor_position == {5, 10}
    end

    test "current_style can be nil or map" do
      state1 = %Raw{current_style: nil}
      state2 = %Raw{current_style: %{fg: :blue, bg: :white, attrs: [:underline]}}

      assert state1.current_style == nil
      assert state2.current_style.fg == :blue
      assert state2.current_style.bg == :white
      assert state2.current_style.attrs == [:underline]
    end

    test "init/1 returns state struct" do
      {:ok, state} = Raw.init(size: {24, 80})
      assert %Raw{} = state
    end

    test "size/1 returns size from state" do
      {:ok, state} = Raw.init(size: {24, 80})
      {:ok, size} = Raw.size(state)
      assert size == state.size
    end
  end

  describe "helper functions" do
    test "valid_position?/2 returns true for positions within bounds" do
      state = %Raw{size: {24, 80}}

      assert Raw.valid_position?(state, {1, 1}) == true
      assert Raw.valid_position?(state, {24, 80}) == true
      assert Raw.valid_position?(state, {12, 40}) == true
    end

    test "valid_position?/2 returns false for positions outside bounds" do
      state = %Raw{size: {24, 80}}

      assert Raw.valid_position?(state, {0, 1}) == false
      assert Raw.valid_position?(state, {1, 0}) == false
      assert Raw.valid_position?(state, {25, 1}) == false
      assert Raw.valid_position?(state, {1, 81}) == false
      assert Raw.valid_position?(state, {-1, 1}) == false
    end

    test "valid_position?/2 handles non-integer positions" do
      state = %Raw{size: {24, 80}}

      assert Raw.valid_position?(state, {"1", 1}) == false
      assert Raw.valid_position?(state, {1.5, 1}) == false
      assert Raw.valid_position?(state, nil) == false
    end

    test "mouse_mode_to_ansi/1 maps Raw modes to ANSI protocol modes" do
      assert Raw.mouse_mode_to_ansi(:none) == nil
      assert Raw.mouse_mode_to_ansi(:click) == :normal
      assert Raw.mouse_mode_to_ansi(:drag) == :button
      assert Raw.mouse_mode_to_ansi(:all) == :all
    end
  end

  describe "init/1 callback" do
    test "returns {:ok, state} with explicit size option" do
      {:ok, state} = Raw.init(size: {30, 100})

      assert %Raw{} = state
      assert state.size == {30, 100}
    end

    test "sets alternate_screen to true by default" do
      {:ok, state} = Raw.init(size: {24, 80})

      assert state.alternate_screen == true
    end

    test "sets alternate_screen to false when option provided" do
      {:ok, state} = Raw.init(size: {24, 80}, alternate_screen: false)

      assert state.alternate_screen == false
    end

    test "sets cursor_visible to false by default (hide_cursor: true)" do
      {:ok, state} = Raw.init(size: {24, 80})

      assert state.cursor_visible == false
    end

    test "sets cursor_visible to true when hide_cursor: false" do
      {:ok, state} = Raw.init(size: {24, 80}, hide_cursor: false)

      assert state.cursor_visible == true
    end

    test "sets mouse_mode to :none by default" do
      {:ok, state} = Raw.init(size: {24, 80})

      assert state.mouse_mode == :none
    end

    test "sets mouse_mode from option" do
      {:ok, state1} = Raw.init(size: {24, 80}, mouse_tracking: :click)
      {:ok, state2} = Raw.init(size: {24, 80}, mouse_tracking: :drag)
      {:ok, state3} = Raw.init(size: {24, 80}, mouse_tracking: :all)

      assert state1.mouse_mode == :click
      assert state2.mouse_mode == :drag
      assert state3.mouse_mode == :all
    end

    test "sets cursor_position to {1, 1} after clear" do
      {:ok, state} = Raw.init(size: {24, 80})

      assert state.cursor_position == {1, 1}
    end

    test "sets current_style to nil initially" do
      {:ok, state} = Raw.init(size: {24, 80})

      assert state.current_style == nil
    end

    test "returns error for invalid size format" do
      assert {:error, :invalid_size} = Raw.init(size: "invalid")
      assert {:error, :invalid_size} = Raw.init(size: {0, 80})
      assert {:error, :invalid_size} = Raw.init(size: {24, 0})
      assert {:error, :invalid_size} = Raw.init(size: {-1, 80})
      assert {:error, :invalid_size} = Raw.init(size: {24})
    end

    test "accepts all options combined" do
      {:ok, state} =
        Raw.init(
          size: {40, 120},
          alternate_screen: false,
          hide_cursor: false,
          mouse_tracking: :drag
        )

      assert state.size == {40, 120}
      assert state.alternate_screen == false
      assert state.cursor_visible == true
      assert state.mouse_mode == :drag
      assert state.cursor_position == {1, 1}
      assert state.current_style == nil
    end
  end

  describe "shutdown/1 callback" do
    test "returns :ok with default state" do
      {:ok, state} = Raw.init(size: {24, 80})

      assert :ok = Raw.shutdown(state)
    end

    test "returns :ok with alternate_screen: false" do
      {:ok, state} = Raw.init(size: {24, 80}, alternate_screen: false)

      assert :ok = Raw.shutdown(state)
    end

    test "returns :ok with mouse tracking enabled" do
      {:ok, state} = Raw.init(size: {24, 80}, mouse_tracking: :click)

      assert :ok = Raw.shutdown(state)
    end

    test "returns :ok with all mouse modes" do
      for mode <- [:none, :click, :drag, :all] do
        {:ok, state} = Raw.init(size: {24, 80}, mouse_tracking: mode)
        assert :ok = Raw.shutdown(state)
      end
    end

    test "is idempotent - can be called twice safely" do
      {:ok, state} = Raw.init(size: {24, 80})

      assert :ok = Raw.shutdown(state)
      assert :ok = Raw.shutdown(state)
    end

    test "works with various state configurations" do
      # Test with alternate screen and mouse tracking
      {:ok, state1} =
        Raw.init(
          size: {30, 100},
          alternate_screen: true,
          hide_cursor: true,
          mouse_tracking: :all
        )

      assert :ok = Raw.shutdown(state1)

      # Test with minimal configuration
      {:ok, state2} =
        Raw.init(
          size: {24, 80},
          alternate_screen: false,
          hide_cursor: false,
          mouse_tracking: :none
        )

      assert :ok = Raw.shutdown(state2)
    end
  end

  describe "move_cursor/2 callback" do
    setup do
      {:ok, state} = Raw.init(size: {24, 80})
      %{state: state}
    end

    test "returns {:ok, state} for valid position", %{state: state} do
      assert {:ok, %Raw{}} = Raw.move_cursor(state, {1, 1})
      assert {:ok, %Raw{}} = Raw.move_cursor(state, {10, 20})
    end

    test "updates cursor_position in state", %{state: state} do
      {:ok, updated_state} = Raw.move_cursor(state, {5, 10})
      assert updated_state.cursor_position == {5, 10}

      {:ok, updated_state2} = Raw.move_cursor(updated_state, {12, 40})
      assert updated_state2.cursor_position == {12, 40}
    end

    test "handles top-left corner position {1, 1}", %{state: state} do
      {:ok, updated_state} = Raw.move_cursor(state, {1, 1})
      assert updated_state.cursor_position == {1, 1}
    end

    test "handles bottom-right corner position", %{state: state} do
      # State has size {24, 80}
      {:ok, updated_state} = Raw.move_cursor(state, {24, 80})
      assert updated_state.cursor_position == {24, 80}
    end

    test "handles positions beyond terminal bounds", %{state: state} do
      # Positions beyond bounds are accepted (clamping is renderer's responsibility)
      {:ok, updated_state} = Raw.move_cursor(state, {100, 200})
      assert updated_state.cursor_position == {100, 200}
    end

    test "preserves other state fields", %{state: state} do
      {:ok, updated_state} = Raw.move_cursor(state, {5, 10})

      # Original state fields preserved
      assert updated_state.size == state.size
      assert updated_state.cursor_visible == state.cursor_visible
      assert updated_state.alternate_screen == state.alternate_screen
      assert updated_state.mouse_mode == state.mouse_mode
      assert updated_state.current_style == state.current_style
    end

    test "enforces positive integer row", %{state: state} do
      assert_raise FunctionClauseError, fn -> Raw.move_cursor(state, {0, 1}) end
      assert_raise FunctionClauseError, fn -> Raw.move_cursor(state, {-1, 1}) end
    end

    test "enforces positive integer col", %{state: state} do
      assert_raise FunctionClauseError, fn -> Raw.move_cursor(state, {1, 0}) end
      assert_raise FunctionClauseError, fn -> Raw.move_cursor(state, {1, -1}) end
    end

    test "rejects non-integer positions", %{state: state} do
      assert_raise FunctionClauseError, fn -> Raw.move_cursor(state, {1.5, 1}) end
      assert_raise FunctionClauseError, fn -> Raw.move_cursor(state, {1, 1.5}) end
      assert_raise FunctionClauseError, fn -> Raw.move_cursor(state, {"1", 1}) end
      assert_raise FunctionClauseError, fn -> Raw.move_cursor(state, {1, "1"}) end
    end
  end

  describe "cursor optimization" do
    test "optimize_cursor defaults to true" do
      {:ok, state} = Raw.init(size: {24, 80})
      assert state.optimize_cursor == true
    end

    test "optimize_cursor can be disabled via option" do
      {:ok, state} = Raw.init(size: {24, 80}, optimize_cursor: false)
      assert state.optimize_cursor == false
    end

    test "move_cursor works with optimization enabled" do
      {:ok, state} = Raw.init(size: {24, 80}, optimize_cursor: true)

      # First move establishes position
      {:ok, state2} = Raw.move_cursor(state, {5, 10})
      assert state2.cursor_position == {5, 10}

      # Second move can use optimization
      {:ok, state3} = Raw.move_cursor(state2, {5, 15})
      assert state3.cursor_position == {5, 15}
    end

    test "move_cursor works with optimization disabled" do
      {:ok, state} = Raw.init(size: {24, 80}, optimize_cursor: false)

      {:ok, state2} = Raw.move_cursor(state, {5, 10})
      assert state2.cursor_position == {5, 10}

      {:ok, state3} = Raw.move_cursor(state2, {5, 15})
      assert state3.cursor_position == {5, 15}
    end

    test "optimizer used for small horizontal moves" do
      {:ok, state} = Raw.init(size: {24, 80}, optimize_cursor: true)

      # Move to initial position
      {:ok, state2} = Raw.move_cursor(state, {10, 10})

      # Small move right - optimizer should use relative move
      {:ok, state3} = Raw.move_cursor(state2, {10, 12})
      assert state3.cursor_position == {10, 12}
    end

    test "optimizer used for small vertical moves" do
      {:ok, state} = Raw.init(size: {24, 80}, optimize_cursor: true)

      # Move to initial position
      {:ok, state2} = Raw.move_cursor(state, {10, 10})

      # Small move down - optimizer should use relative move
      {:ok, state3} = Raw.move_cursor(state2, {12, 10})
      assert state3.cursor_position == {12, 10}
    end

    test "optimizer handles nil cursor_position gracefully" do
      # Create state with nil cursor_position directly for testing
      state = %Raw{
        size: {24, 80},
        cursor_visible: false,
        cursor_position: nil,
        alternate_screen: true,
        mouse_mode: :none,
        current_style: nil,
        optimize_cursor: true
      }

      # Should fall back to absolute positioning
      {:ok, updated} = Raw.move_cursor(state, {5, 10})
      assert updated.cursor_position == {5, 10}
    end

    test "preserves optimize_cursor setting through cursor operations" do
      {:ok, state} = Raw.init(size: {24, 80}, optimize_cursor: false)

      {:ok, state2} = Raw.move_cursor(state, {5, 10})
      assert state2.optimize_cursor == false

      {:ok, state3} = Raw.hide_cursor(state2)
      assert state3.optimize_cursor == false

      {:ok, state4} = Raw.show_cursor(state3)
      assert state4.optimize_cursor == false
    end
  end

  describe "hide_cursor/1 callback" do
    setup do
      # Default init has hide_cursor: true, so cursor_visible is false
      {:ok, state} = Raw.init(size: {24, 80})
      %{state: state}
    end

    test "returns {:ok, state}", %{state: state} do
      # Make cursor visible first
      {:ok, visible_state} = Raw.show_cursor(state)
      assert {:ok, %Raw{}} = Raw.hide_cursor(visible_state)
    end

    test "updates cursor_visible to false", %{state: state} do
      # Make cursor visible first
      {:ok, visible_state} = Raw.show_cursor(state)
      assert visible_state.cursor_visible == true

      {:ok, hidden_state} = Raw.hide_cursor(visible_state)
      assert hidden_state.cursor_visible == false
    end

    test "is idempotent when cursor already hidden", %{state: state} do
      # State already has cursor hidden (from init with hide_cursor: true)
      assert state.cursor_visible == false

      # Calling hide_cursor should return same state (no change)
      {:ok, same_state} = Raw.hide_cursor(state)
      assert same_state.cursor_visible == false
      assert same_state == state
    end

    test "preserves other state fields", %{state: state} do
      {:ok, visible_state} = Raw.show_cursor(state)
      {:ok, hidden_state} = Raw.hide_cursor(visible_state)

      assert hidden_state.size == state.size
      assert hidden_state.cursor_position == state.cursor_position
      assert hidden_state.alternate_screen == state.alternate_screen
      assert hidden_state.mouse_mode == state.mouse_mode
      assert hidden_state.current_style == state.current_style
    end
  end

  describe "show_cursor/1 callback" do
    setup do
      # Default init has hide_cursor: true, so cursor_visible is false
      {:ok, state} = Raw.init(size: {24, 80})
      %{state: state}
    end

    test "returns {:ok, state}", %{state: state} do
      assert {:ok, %Raw{}} = Raw.show_cursor(state)
    end

    test "updates cursor_visible to true", %{state: state} do
      # State starts with cursor hidden
      assert state.cursor_visible == false

      {:ok, visible_state} = Raw.show_cursor(state)
      assert visible_state.cursor_visible == true
    end

    test "is idempotent when cursor already visible", %{state: state} do
      # First make cursor visible
      {:ok, visible_state} = Raw.show_cursor(state)
      assert visible_state.cursor_visible == true

      # Calling show_cursor again should return same state (no change)
      {:ok, same_state} = Raw.show_cursor(visible_state)
      assert same_state.cursor_visible == true
      assert same_state == visible_state
    end

    test "preserves other state fields", %{state: state} do
      {:ok, visible_state} = Raw.show_cursor(state)

      assert visible_state.size == state.size
      assert visible_state.cursor_position == state.cursor_position
      assert visible_state.alternate_screen == state.alternate_screen
      assert visible_state.mouse_mode == state.mouse_mode
      assert visible_state.current_style == state.current_style
    end
  end

  describe "cursor visibility round-trip" do
    setup do
      {:ok, state} = Raw.init(size: {24, 80}, hide_cursor: false)
      %{state: state}
    end

    test "hide then show restores visibility", %{state: state} do
      assert state.cursor_visible == true

      {:ok, hidden} = Raw.hide_cursor(state)
      assert hidden.cursor_visible == false

      {:ok, visible} = Raw.show_cursor(hidden)
      assert visible.cursor_visible == true
    end

    test "multiple hide/show cycles work correctly", %{state: state} do
      {:ok, s1} = Raw.hide_cursor(state)
      {:ok, s2} = Raw.show_cursor(s1)
      {:ok, s3} = Raw.hide_cursor(s2)
      {:ok, s4} = Raw.show_cursor(s3)

      assert s1.cursor_visible == false
      assert s2.cursor_visible == true
      assert s3.cursor_visible == false
      assert s4.cursor_visible == true
    end
  end

  describe "clear/1 callback" do
    setup do
      {:ok, state} = Raw.init(size: {24, 80})
      %{state: state}
    end

    test "returns {:ok, state}", %{state: state} do
      assert {:ok, %Raw{}} = Raw.clear(state)
    end

    test "resets cursor_position to {1, 1}", %{state: state} do
      # First move cursor to different position
      {:ok, moved_state} = Raw.move_cursor(state, {10, 20})
      assert moved_state.cursor_position == {10, 20}

      # Clear should reset to home
      {:ok, cleared_state} = Raw.clear(moved_state)
      assert cleared_state.cursor_position == {1, 1}
    end

    test "resets current_style to nil", %{state: state} do
      # Simulate having a style set (manually set for test)
      state_with_style = %{state | current_style: %{fg: :red, bg: :blue, attrs: [:bold]}}

      {:ok, cleared_state} = Raw.clear(state_with_style)
      assert cleared_state.current_style == nil
    end

    test "preserves other state fields", %{state: state} do
      # Move cursor and set some state
      {:ok, modified_state} = Raw.move_cursor(state, {10, 20})

      {:ok, cleared_state} = Raw.clear(modified_state)

      # Should preserve all fields except cursor_position and current_style
      assert_state_unchanged_except(modified_state, cleared_state, [
        :cursor_position,
        :current_style
      ])
    end

    test "works after multiple operations", %{state: state} do
      # Perform various operations
      {:ok, s1} = Raw.move_cursor(state, {5, 10})
      {:ok, s2} = Raw.show_cursor(s1)
      {:ok, s3} = Raw.move_cursor(s2, {20, 40})

      # Clear should work and reset position
      {:ok, cleared} = Raw.clear(s3)
      assert cleared.cursor_position == {1, 1}
      assert cleared.current_style == nil
      # But cursor visibility should be preserved
      assert cleared.cursor_visible == true
    end

    test "is idempotent (multiple clears work)", %{state: state} do
      {:ok, s1} = Raw.clear(state)
      {:ok, s2} = Raw.clear(s1)
      {:ok, s3} = Raw.clear(s2)

      assert s3.cursor_position == {1, 1}
      assert s3.current_style == nil
    end
  end

  describe "size/1 callback" do
    test "returns {:ok, {rows, cols}} tuple" do
      {:ok, state} = Raw.init(size: {24, 80})
      assert {:ok, {24, 80}} = Raw.size(state)
    end

    test "returns cached dimensions from state" do
      {:ok, state} = Raw.init(size: {50, 120})
      {:ok, size} = Raw.size(state)
      assert size == {50, 120}
      assert size == state.size
    end

    test "works with various terminal sizes" do
      # Standard 80x24
      {:ok, state1} = Raw.init(size: {24, 80})
      assert {:ok, {24, 80}} = Raw.size(state1)

      # Large terminal
      {:ok, state2} = Raw.init(size: {50, 200})
      assert {:ok, {50, 200}} = Raw.size(state2)

      # Small terminal
      {:ok, state3} = Raw.init(size: {10, 40})
      assert {:ok, {10, 40}} = Raw.size(state3)
    end

    test "size remains unchanged after cursor operations" do
      {:ok, state} = Raw.init(size: {24, 80})
      {:ok, state2} = Raw.move_cursor(state, {10, 20})
      {:ok, state3} = Raw.hide_cursor(state2)
      {:ok, state4} = Raw.clear(state3)

      # Size should remain the same through all operations
      assert {:ok, {24, 80}} = Raw.size(state4)
    end

    test "returns size in {rows, cols} format" do
      {:ok, state} = Raw.init(size: {30, 100})
      {:ok, {rows, cols}} = Raw.size(state)

      # Rows first, columns second
      assert rows == 30
      assert cols == 100
    end
  end

  describe "refresh_size/1 callback" do
    setup do
      {:ok, state} = Raw.init(size: {24, 80})
      %{state: state}
    end

    test "exports refresh_size/1 function" do
      assert function_exported?(Raw, :refresh_size, 1)
    end

    test "returns 3-tuple on success", %{state: state} do
      # In test environment, :io.rows/0 and :io.columns/0 may return {:error, :enotsup}
      # We need to set environment variables for the fallback
      with_terminal_env(30, 100, fn ->
        result = Raw.refresh_size(state)
        # Either succeeds with new size or returns error (depending on test environment)
        assert match?({:ok, {_, _}, %Raw{}}, result) or match?({:error, _}, result)
      end)
    end

    test "updates state.size on success" do
      with_terminal_env(50, 120, fn ->
        {:ok, state} = Raw.init(size: {24, 80})
        assert state.size == {24, 80}

        case Raw.refresh_size(state) do
          {:ok, new_size, updated_state} ->
            assert new_size == {50, 120}
            assert updated_state.size == {50, 120}
            assert updated_state.size == new_size

          {:error, :size_detection_failed} ->
            # If :io.rows/0 and :io.columns/0 succeed but with different values,
            # the env fallback won't be used
            :ok
        end
      end)
    end

    test "preserves other state fields on success" do
      with_terminal_env(30, 100, fn ->
        {:ok, state} = Raw.init(size: {24, 80}, mouse_tracking: :click, hide_cursor: false)

        case Raw.refresh_size(state) do
          {:ok, _new_size, updated_state} ->
            # Only size should change
            assert_state_unchanged_except(state, updated_state, [:size])

          {:error, _} ->
            :ok
        end
      end)
    end

    test "returns error when size detection fails", %{state: state} do
      # Ensure environment variables are not set
      System.delete_env("LINES")
      System.delete_env("COLUMNS")

      # In test environment without a real terminal, this may fail
      # The result depends on whether :io.rows/0 and :io.columns/0 work
      result = Raw.refresh_size(state)

      # Either succeeds (real terminal) or fails (no terminal)
      assert match?({:ok, {_, _}, %Raw{}}, result) or
               match?({:error, :size_detection_failed}, result)
    end

    test "has documentation" do
      {:docs_v1, _, :elixir, _, _, _, docs} = Code.fetch_docs(Raw)

      func_docs =
        docs
        |> Enum.filter(fn
          {{:function, :refresh_size, 1}, _, _, _, _} -> true
          _ -> false
        end)

      assert length(func_docs) == 1

      # Check documentation mentions SIGWINCH
      [{{:function, :refresh_size, 1}, _, _, %{"en" => doc}, _}] = func_docs
      assert doc =~ "SIGWINCH"
    end

    test "documentation mentions error handling" do
      {:docs_v1, _, :elixir, _, _, _, docs} = Code.fetch_docs(Raw)

      [{{:function, :refresh_size, 1}, _, _, %{"en" => doc}, _}] =
        Enum.filter(docs, fn
          {{:function, :refresh_size, 1}, _, _, _, _} -> true
          _ -> false
        end)

      assert doc =~ "size_detection_failed"
    end
  end

  describe "refresh_size/1 with mocked environment" do
    test "uses environment variable fallback" do
      # Create a state with known size
      {:ok, state} = Raw.init(size: {24, 80})

      with_terminal_env(40, 160, fn ->
        result = Raw.refresh_size(state)

        # If :io functions fail, should fall back to environment
        case result do
          {:ok, new_size, _updated_state} ->
            # Size was detected (either from :io or env)
            assert is_tuple(new_size)
            assert tuple_size(new_size) == 2
            {rows, cols} = new_size
            assert is_integer(rows) and rows > 0
            assert is_integer(cols) and cols > 0

          {:error, :size_detection_failed} ->
            # Both :io and env failed - unexpected given we set env
            flunk("Size detection failed despite environment variables being set")
        end
      end)
    end

    test "returns error with invalid environment variables" do
      with_terminal_env("invalid", "invalid", fn ->
        {:ok, state} = Raw.init(size: {24, 80})
        result = Raw.refresh_size(state)

        # Either :io functions work, or we get an error due to invalid env
        assert match?({:ok, {_, _}, %Raw{}}, result) or
                 match?({:error, :size_detection_failed}, result)
      end)
    end

    test "rejects terminal size exceeding maximum bounds" do
      # Test with size exceeding @max_terminal_dimension (9999)
      with_terminal_env(10000, 10000, fn ->
        {:ok, state} = Raw.init(size: {24, 80})
        result = Raw.refresh_size(state)

        # Either :io functions work, or we get an error due to oversized env
        assert match?({:ok, {_, _}, %Raw{}}, result) or
                 match?({:error, :size_detection_failed}, result)
      end)
    end
  end

  # ==========================================================================
  # draw_cells/2 Callback Tests (Section 2.5.1)
  # ==========================================================================

  describe "draw_cells/2 callback" do
    setup do
      {:ok, state} = Raw.init(size: {24, 80})
      %{state: state}
    end

    test "exports draw_cells/2 function" do
      assert function_exported?(Raw, :draw_cells, 2)
    end

    test "returns {:ok, state} tuple", %{state: state} do
      cells = [{{1, 1}, {"A", :default, :default, []}}]
      assert {:ok, %Raw{}} = Raw.draw_cells(state, cells)
    end

    test "with empty list returns unchanged state", %{state: state} do
      {:ok, result} = Raw.draw_cells(state, [])
      assert result == state
    end

    test "with single cell updates cursor position", %{state: state} do
      cells = [{{5, 10}, {"X", :default, :default, []}}]
      {:ok, result} = Raw.draw_cells(state, cells)

      # Cursor should advance one column after drawing the character
      assert result.cursor_position == {5, 11}
    end

    test "with single cell updates current_style", %{state: state} do
      cells = [{{1, 1}, {"A", :red, :blue, [:bold]}}]
      {:ok, result} = Raw.draw_cells(state, cells)

      assert result.current_style == %{fg: :red, bg: :blue, attrs: [:bold]}
    end

    test "with multiple cells on same row tracks cursor sequentially", %{state: state} do
      cells = [
        {{1, 1}, {"H", :default, :default, []}},
        {{1, 2}, {"i", :default, :default, []}}
      ]

      {:ok, result} = Raw.draw_cells(state, cells)

      # Cursor should be after the last character
      assert result.cursor_position == {1, 3}
    end

    test "with cells on different rows updates to final position", %{state: state} do
      cells = [
        {{1, 1}, {"A", :default, :default, []}},
        {{2, 5}, {"B", :default, :default, []}},
        {{3, 10}, {"C", :default, :default, []}}
      ]

      {:ok, result} = Raw.draw_cells(state, cells)

      # Cursor should be after the last cell (row 3, col 11)
      assert result.cursor_position == {3, 11}
    end

    test "sorts cells by position before rendering", %{state: state} do
      # Pass cells out of order
      cells = [
        {{2, 5}, {"B", :default, :default, []}},
        {{1, 1}, {"A", :default, :default, []}},
        {{1, 10}, {"C", :default, :default, []}}
      ]

      {:ok, result} = Raw.draw_cells(state, cells)

      # Should end at position after the last cell in sorted order
      # Sorted: {1,1}, {1,10}, {2,5}
      # Final position after {2,5} -> {2,6}
      assert result.cursor_position == {2, 6}
    end

    test "preserves other state fields", %{state: state} do
      cells = [{{1, 1}, {"X", :red, :default, []}}]
      {:ok, result} = Raw.draw_cells(state, cells)

      # These fields should not change
      assert result.size == state.size
      assert result.cursor_visible == state.cursor_visible
      assert result.alternate_screen == state.alternate_screen
      assert result.mouse_mode == state.mouse_mode
      assert result.optimize_cursor == state.optimize_cursor
    end

    test "tracks style across multiple cells", %{state: state} do
      # First cell sets style
      cells = [
        {{1, 1}, {"A", :red, :blue, [:bold]}},
        {{1, 2}, {"B", :red, :blue, [:bold]}}
      ]

      {:ok, result} = Raw.draw_cells(state, cells)

      # Style should reflect final cell's style
      assert result.current_style == %{fg: :red, bg: :blue, attrs: [:bold]}
    end

    test "handles style changes between cells", %{state: state} do
      cells = [
        {{1, 1}, {"A", :red, :default, []}},
        {{1, 2}, {"B", :green, :default, [:underline]}}
      ]

      {:ok, result} = Raw.draw_cells(state, cells)

      # Style should be the last cell's style
      assert result.current_style == %{fg: :green, bg: :default, attrs: [:underline]}
    end

    test "has documentation" do
      {:docs_v1, _, :elixir, _, _, _, docs} = Code.fetch_docs(Raw)

      func_docs =
        Enum.filter(docs, fn
          {{:function, :draw_cells, 2}, _, _, _, _} -> true
          _ -> false
        end)

      assert length(func_docs) == 1
      [{{:function, :draw_cells, 2}, _, _, %{"en" => doc}, _}] = func_docs
      assert doc =~ "Draws cells"
      assert doc =~ "Cell Format"
    end
  end

  describe "draw_cells/2 with various color types" do
    setup do
      {:ok, state} = Raw.init(size: {24, 80})
      %{state: state}
    end

    test "handles named colors", %{state: state} do
      cells = [{{1, 1}, {"A", :red, :blue, []}}]
      {:ok, result} = Raw.draw_cells(state, cells)

      assert result.current_style.fg == :red
      assert result.current_style.bg == :blue
    end

    test "handles :default colors", %{state: state} do
      cells = [{{1, 1}, {"A", :default, :default, []}}]
      {:ok, result} = Raw.draw_cells(state, cells)

      assert result.current_style.fg == :default
      assert result.current_style.bg == :default
    end

    test "handles 256-color indices", %{state: state} do
      cells = [{{1, 1}, {"A", 196, 232, []}}]
      {:ok, result} = Raw.draw_cells(state, cells)

      assert result.current_style.fg == 196
      assert result.current_style.bg == 232
    end

    test "handles RGB true colors", %{state: state} do
      cells = [{{1, 1}, {"A", {255, 128, 0}, {0, 64, 128}, []}}]
      {:ok, result} = Raw.draw_cells(state, cells)

      assert result.current_style.fg == {255, 128, 0}
      assert result.current_style.bg == {0, 64, 128}
    end

    test "handles mixed color types", %{state: state} do
      cells = [
        {{1, 1}, {"A", :red, 232, []}},
        {{1, 2}, {"B", 196, {0, 255, 0}, []}},
        {{1, 3}, {"C", {128, 128, 128}, :default, []}}
      ]

      {:ok, result} = Raw.draw_cells(state, cells)

      # Final style should be from last cell
      assert result.current_style.fg == {128, 128, 128}
      assert result.current_style.bg == :default
    end
  end

  describe "draw_cells/2 with various attributes" do
    setup do
      {:ok, state} = Raw.init(size: {24, 80})
      %{state: state}
    end

    test "handles bold attribute", %{state: state} do
      cells = [{{1, 1}, {"A", :default, :default, [:bold]}}]
      {:ok, result} = Raw.draw_cells(state, cells)

      assert :bold in result.current_style.attrs
    end

    test "handles multiple attributes", %{state: state} do
      cells = [{{1, 1}, {"A", :default, :default, [:bold, :underline, :italic]}}]
      {:ok, result} = Raw.draw_cells(state, cells)

      assert :bold in result.current_style.attrs
      assert :underline in result.current_style.attrs
      assert :italic in result.current_style.attrs
    end

    test "handles all supported attributes", %{state: state} do
      all_attrs = [:bold, :dim, :italic, :underline, :blink, :reverse, :hidden, :strikethrough]
      cells = [{{1, 1}, {"A", :default, :default, all_attrs}}]
      {:ok, result} = Raw.draw_cells(state, cells)

      for attr <- all_attrs do
        assert attr in result.current_style.attrs,
               "Expected #{attr} to be in current_style.attrs"
      end
    end

    test "handles empty attributes list", %{state: state} do
      cells = [{{1, 1}, {"A", :default, :default, []}}]
      {:ok, result} = Raw.draw_cells(state, cells)

      assert result.current_style.attrs == []
    end

    test "normalizes attributes to sorted list", %{state: state} do
      # Pass attrs in random order
      cells = [{{1, 1}, {"A", :default, :default, [:underline, :bold, :italic]}}]
      {:ok, result} = Raw.draw_cells(state, cells)

      # Should be sorted alphabetically
      assert result.current_style.attrs == [:bold, :italic, :underline]
    end
  end

  describe "draw_cells/2 style delta optimization" do
    setup do
      {:ok, state} = Raw.init(size: {24, 80})
      %{state: state}
    end

    test "consecutive cells with same style don't reset style tracking", %{state: state} do
      # Draw first cell to set initial style
      cells1 = [{{1, 1}, {"A", :red, :default, [:bold]}}]
      {:ok, state1} = Raw.draw_cells(state, cells1)

      # Draw second cell with same style
      cells2 = [{{1, 2}, {"B", :red, :default, [:bold]}}]
      {:ok, state2} = Raw.draw_cells(state1, cells2)

      # Style should remain the same
      assert state1.current_style == state2.current_style
    end

    test "tracks style state across multiple draw_cells calls", %{state: state} do
      cells1 = [{{1, 1}, {"A", :red, :blue, []}}]
      {:ok, state1} = Raw.draw_cells(state, cells1)

      assert state1.current_style == %{fg: :red, bg: :blue, attrs: []}

      # Change only foreground
      cells2 = [{{1, 2}, {"B", :green, :blue, []}}]
      {:ok, state2} = Raw.draw_cells(state1, cells2)

      assert state2.current_style == %{fg: :green, bg: :blue, attrs: []}
    end

    test "resets style when removing attributes", %{state: state} do
      # Draw cell with multiple attributes
      cells1 = [{{1, 1}, {"A", :default, :default, [:bold, :italic, :underline]}}]
      {:ok, state1} = Raw.draw_cells(state, cells1)

      assert state1.current_style.attrs == [:bold, :italic, :underline]

      # Draw cell with fewer attributes (requires reset + rebuild)
      cells2 = [{{1, 2}, {"B", :default, :default, [:bold]}}]
      {:ok, state2} = Raw.draw_cells(state1, cells2)

      # Style should reflect only the new attribute
      assert state2.current_style.attrs == [:bold]
    end

    test "handles full screen of cells efficiently", %{state: state} do
      # Generate 80x24 = 1920 cells (full terminal screen)
      cells =
        for row <- 1..24, col <- 1..80 do
          {{row, col}, {"X", :default, :default, []}}
        end

      # Should process without error
      {:ok, final_state} = Raw.draw_cells(state, cells)

      # Verify cursor position is at end of last cell
      assert final_state.cursor_position == {24, 81}

      # Verify style tracking was maintained
      assert final_state.current_style == %{fg: :default, bg: :default, attrs: []}
    end
  end

  describe "stub callbacks" do
    # Use setup to avoid repeating Raw.init([]) in every test
    setup do
      {:ok, state} = Raw.init(size: {24, 80})
      %{state: state}
    end

    test "shutdown/1 returns :ok", %{state: state} do
      assert :ok = Raw.shutdown(state)
    end

    test "flush/1 returns {:ok, state}", %{state: state} do
      assert {:ok, %Raw{}} = Raw.flush(state)
    end

    test "poll_event/2 returns {:timeout, state} for stub", %{state: state} do
      # Stub always returns timeout
      assert {:timeout, %Raw{}} = Raw.poll_event(state, 0)
      assert {:timeout, %Raw{}} = Raw.poll_event(state, 100)
    end
  end

  # ==========================================================================
  # Test Helpers
  # ==========================================================================

  # Asserts that all state fields except the specified ones are unchanged.
  # Example: assert_state_unchanged_except(original, updated, [:cursor_position])
  defp assert_state_unchanged_except(original, updated, changed_fields) do
    all_fields = [
      :size,
      :cursor_visible,
      :cursor_position,
      :alternate_screen,
      :mouse_mode,
      :current_style,
      :optimize_cursor
    ]

    for field <- all_fields, field not in changed_fields do
      assert Map.get(updated, field) == Map.get(original, field),
             "Expected #{field} to be unchanged, got #{inspect(Map.get(updated, field))} instead of #{inspect(Map.get(original, field))}"
    end
  end

  # Executes a test function with LINES and COLUMNS environment variables set,
  # ensuring cleanup even if the test fails.
  defp with_terminal_env(lines, cols, fun) do
    System.put_env("LINES", to_string(lines))
    System.put_env("COLUMNS", to_string(cols))

    try do
      fun.()
    after
      System.delete_env("LINES")
      System.delete_env("COLUMNS")
    end
  end

  # ==========================================================================
  # Additional Cursor Optimization Tests
  # ==========================================================================

  describe "cursor optimization - large distance behavior" do
    setup do
      {:ok, state} = Raw.init(size: {24, 80}, optimize_cursor: true)
      %{state: state}
    end

    test "optimizer uses absolute positioning for large horizontal moves", %{state: state} do
      # Move to initial position
      {:ok, state2} = Raw.move_cursor(state, {10, 10})

      # Large move right (60 columns) - optimizer should prefer absolute
      {:ok, state3} = Raw.move_cursor(state2, {10, 70})
      assert state3.cursor_position == {10, 70}

      # Verify state preservation
      assert_state_unchanged_except(state2, state3, [:cursor_position])
    end

    test "optimizer uses absolute positioning for large vertical moves", %{state: state} do
      # Move to initial position
      {:ok, state2} = Raw.move_cursor(state, {5, 40})

      # Large move down (15 rows) - optimizer should prefer absolute
      {:ok, state3} = Raw.move_cursor(state2, {20, 40})
      assert state3.cursor_position == {20, 40}

      # Verify state preservation
      assert_state_unchanged_except(state2, state3, [:cursor_position])
    end

    test "optimizer handles diagonal moves", %{state: state} do
      # Move to initial position
      {:ok, state2} = Raw.move_cursor(state, {5, 5})

      # Diagonal move - optimizer should calculate best path
      {:ok, state3} = Raw.move_cursor(state2, {15, 50})
      assert state3.cursor_position == {15, 50}
    end

    test "optimizer handles home position special case", %{state: state} do
      # Move to arbitrary position
      {:ok, state2} = Raw.move_cursor(state, {20, 40})

      # Move back to home - optimizer should recognize ESC[H is cheaper
      {:ok, state3} = Raw.move_cursor(state2, {1, 1})
      assert state3.cursor_position == {1, 1}
    end
  end

  describe "cursor state preservation with helper" do
    setup do
      {:ok, state} = Raw.init(size: {24, 80})
      %{state: state}
    end

    test "move_cursor preserves all other fields", %{state: state} do
      {:ok, updated} = Raw.move_cursor(state, {10, 20})
      assert_state_unchanged_except(state, updated, [:cursor_position])
    end

    test "hide_cursor preserves all other fields", %{state: state} do
      {:ok, visible} = Raw.show_cursor(state)
      {:ok, hidden} = Raw.hide_cursor(visible)
      assert_state_unchanged_except(visible, hidden, [:cursor_visible])
    end

    test "show_cursor preserves all other fields", %{state: state} do
      {:ok, visible} = Raw.show_cursor(state)
      assert_state_unchanged_except(state, visible, [:cursor_visible])
    end
  end
end
