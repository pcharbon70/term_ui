defmodule TermUI.Backend.RawTest do
  @moduledoc """
  Unit tests for TermUI.Backend.Raw module.

  This test file covers the module structure and behaviour declaration.
  Callback implementation tests will be added in subsequent tasks.
  """

  use ExUnit.Case, async: true

  alias TermUI.Backend.Raw

  describe "module structure (Task 2.1.1)" do
    test "module compiles successfully" do
      assert Code.ensure_loaded?(Raw)
    end

    test "declares @behaviour TermUI.Backend" do
      # Check that the module declares the Backend behaviour
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

    test "has ANSI module aliased" do
      # The module should have access to TermUI.ANSI
      assert Raw.ansi_module() == TermUI.ANSI
    end
  end

  describe "documentation (Task 2.1.1)" do
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

  describe "state structure (Task 2.1.2)" do
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
      {:ok, state} = Raw.init([])
      assert %Raw{} = state
    end

    test "size/1 returns size from state" do
      {:ok, state} = Raw.init([])
      {:ok, size} = Raw.size(state)
      assert size == state.size
    end
  end

  describe "stub callbacks (Task 2.1.1)" do
    # These tests verify the stubs work correctly
    # Full implementation tests will be added in subsequent tasks

    test "init/1 returns {:ok, state}" do
      assert {:ok, _state} = Raw.init([])
    end

    test "init/1 accepts options" do
      assert {:ok, _state} = Raw.init(alternate_screen: false, hide_cursor: true)
    end

    test "shutdown/1 returns :ok" do
      {:ok, state} = Raw.init([])
      assert :ok = Raw.shutdown(state)
    end

    test "size/1 returns result tuple" do
      {:ok, state} = Raw.init([])
      result = Raw.size(state)
      # Stub returns {:error, :enotsup}
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "move_cursor/2 returns {:ok, state}" do
      {:ok, state} = Raw.init([])
      assert {:ok, _updated_state} = Raw.move_cursor(state, {1, 1})
    end

    test "hide_cursor/1 returns {:ok, state}" do
      {:ok, state} = Raw.init([])
      assert {:ok, _updated_state} = Raw.hide_cursor(state)
    end

    test "show_cursor/1 returns {:ok, state}" do
      {:ok, state} = Raw.init([])
      assert {:ok, _updated_state} = Raw.show_cursor(state)
    end

    test "clear/1 returns {:ok, state}" do
      {:ok, state} = Raw.init([])
      assert {:ok, _updated_state} = Raw.clear(state)
    end

    test "draw_cells/2 returns {:ok, state}" do
      {:ok, state} = Raw.init([])
      cells = [{{1, 1}, {"A", :default, :default, []}}]
      assert {:ok, _updated_state} = Raw.draw_cells(state, cells)
    end

    test "flush/1 returns {:ok, state}" do
      {:ok, state} = Raw.init([])
      assert {:ok, _updated_state} = Raw.flush(state)
    end

    test "poll_event/2 returns valid result" do
      {:ok, state} = Raw.init([])
      result = Raw.poll_event(state, 0)
      # Stub returns {:timeout, state}
      assert match?({:ok, _, _}, result) or match?({:timeout, _}, result) or
               match?({:error, _, _}, result)
    end
  end
end
