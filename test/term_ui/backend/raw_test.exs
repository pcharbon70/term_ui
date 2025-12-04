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

  describe "stub callbacks" do
    # Use setup to avoid repeating Raw.init([]) in every test
    setup do
      {:ok, state} = Raw.init(size: {24, 80})
      %{state: state}
    end

    test "shutdown/1 returns :ok", %{state: state} do
      assert :ok = Raw.shutdown(state)
    end

    test "size/1 returns {:ok, size} tuple", %{state: state} do
      assert {:ok, {24, 80}} = Raw.size(state)
    end

    test "move_cursor/2 returns {:ok, state} for valid position", %{state: state} do
      assert {:ok, %Raw{}} = Raw.move_cursor(state, {1, 1})
      assert {:ok, %Raw{}} = Raw.move_cursor(state, {10, 20})
    end

    test "move_cursor/2 enforces positive integer positions", %{state: state} do
      # These should raise FunctionClauseError due to guard clauses
      assert_raise FunctionClauseError, fn -> Raw.move_cursor(state, {0, 1}) end
      assert_raise FunctionClauseError, fn -> Raw.move_cursor(state, {1, 0}) end
      assert_raise FunctionClauseError, fn -> Raw.move_cursor(state, {-1, 1}) end
    end

    test "hide_cursor/1 returns {:ok, state}", %{state: state} do
      assert {:ok, %Raw{}} = Raw.hide_cursor(state)
    end

    test "show_cursor/1 returns {:ok, state}", %{state: state} do
      assert {:ok, %Raw{}} = Raw.show_cursor(state)
    end

    test "clear/1 returns {:ok, state}", %{state: state} do
      assert {:ok, %Raw{}} = Raw.clear(state)
    end

    test "draw_cells/2 returns {:ok, state}", %{state: state} do
      cells = [{{1, 1}, {"A", :default, :default, []}}]
      assert {:ok, %Raw{}} = Raw.draw_cells(state, cells)
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
end
