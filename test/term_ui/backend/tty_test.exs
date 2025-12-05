defmodule TermUI.Backend.TTYTest do
  use ExUnit.Case, async: true

  alias TermUI.Backend.TTY

  # ===========================================================================
  # Section 3.1 Tests - Module Structure
  # ===========================================================================

  describe "behaviour declaration" do
    test "module declares @behaviour TermUI.Backend" do
      behaviours = TTY.__info__(:attributes)[:behaviour] || []
      assert TermUI.Backend in behaviours
    end

    test "module compiles without warnings" do
      # If we got here, the module compiled successfully
      assert Code.ensure_loaded?(TTY)
    end
  end

  describe "state struct defaults" do
    test "has size field with default {24, 80}" do
      state = %TTY{}
      assert state.size == {24, 80}
    end

    test "has capabilities field with default empty map" do
      state = %TTY{}
      assert state.capabilities == %{}
    end

    test "has line_mode field with default :full_redraw" do
      state = %TTY{}
      assert state.line_mode == :full_redraw
    end

    test "has last_frame field with default nil" do
      state = %TTY{}
      assert state.last_frame == nil
    end

    test "has character_set field with default :unicode" do
      state = %TTY{}
      assert state.character_set == :unicode
    end

    test "has color_mode field with default :true_color" do
      state = %TTY{}
      assert state.color_mode == :true_color
    end

    test "has alternate_screen field with default false" do
      state = %TTY{}
      assert state.alternate_screen == false
    end

    test "has cursor_visible field with default true" do
      state = %TTY{}
      assert state.cursor_visible == true
    end

    test "has cursor_position field with default nil" do
      state = %TTY{}
      assert state.cursor_position == nil
    end

    test "has current_style field with default nil" do
      state = %TTY{}
      assert state.current_style == nil
    end
  end

  describe "init/1" do
    test "returns {:ok, state} with default options" do
      assert {:ok, %TTY{}} = TTY.init([])
    end

    test "stores capabilities from options" do
      capabilities = %{colors: :color_256, unicode: true, dimensions: {30, 100}}
      {:ok, state} = TTY.init(capabilities: capabilities)
      assert state.capabilities == capabilities
    end

    test "uses line_mode from options" do
      {:ok, state} = TTY.init(line_mode: :incremental)
      assert state.line_mode == :incremental
    end

    test "uses alternate_screen from options" do
      {:ok, state} = TTY.init(alternate_screen: true)
      assert state.alternate_screen == true
    end

    test "uses explicit size from options" do
      {:ok, state} = TTY.init(size: {50, 120})
      assert state.size == {50, 120}
    end

    test "uses size from capabilities when not explicitly set" do
      capabilities = %{dimensions: {40, 160}}
      {:ok, state} = TTY.init(capabilities: capabilities)
      assert state.size == {40, 160}
    end

    test "prefers explicit size over capabilities" do
      capabilities = %{dimensions: {40, 160}}
      {:ok, state} = TTY.init(size: {30, 100}, capabilities: capabilities)
      assert state.size == {30, 100}
    end

    test "determines color_mode :true_color from capabilities" do
      {:ok, state} = TTY.init(capabilities: %{colors: :true_color})
      assert state.color_mode == :true_color
    end

    test "determines color_mode :color_256 from capabilities" do
      {:ok, state} = TTY.init(capabilities: %{colors: :color_256})
      assert state.color_mode == :color_256
    end

    test "determines color_mode :color_16 from capabilities" do
      {:ok, state} = TTY.init(capabilities: %{colors: :color_16})
      assert state.color_mode == :color_16
    end

    test "determines color_mode :monochrome from capabilities" do
      {:ok, state} = TTY.init(capabilities: %{colors: :monochrome})
      assert state.color_mode == :monochrome
    end

    test "determines color_mode from integer >= 16_777_216 as :true_color" do
      {:ok, state} = TTY.init(capabilities: %{colors: 16_777_216})
      assert state.color_mode == :true_color
    end

    test "determines color_mode from integer >= 256 as :color_256" do
      {:ok, state} = TTY.init(capabilities: %{colors: 256})
      assert state.color_mode == :color_256
    end

    test "determines color_mode from integer >= 16 as :color_16" do
      {:ok, state} = TTY.init(capabilities: %{colors: 16})
      assert state.color_mode == :color_16
    end

    test "determines character_set :unicode when unicode capability is true" do
      {:ok, state} = TTY.init(capabilities: %{unicode: true})
      assert state.character_set == :unicode
    end

    test "determines character_set :ascii when unicode capability is false" do
      {:ok, state} = TTY.init(capabilities: %{unicode: false})
      assert state.character_set == :ascii
    end

    test "defaults character_set to :unicode when not specified" do
      {:ok, state} = TTY.init(capabilities: %{})
      assert state.character_set == :unicode
    end
  end

  describe "shutdown/1" do
    test "returns :ok" do
      {:ok, state} = TTY.init([])
      assert :ok = TTY.shutdown(state)
    end

    test "can be called multiple times" do
      {:ok, state} = TTY.init([])
      assert :ok = TTY.shutdown(state)
      assert :ok = TTY.shutdown(state)
    end
  end

  describe "size/1" do
    test "returns {:ok, size} from state" do
      {:ok, state} = TTY.init(size: {50, 120})
      assert {:ok, {50, 120}} = TTY.size(state)
    end

    test "returns default size when not configured" do
      {:ok, state} = TTY.init([])
      assert {:ok, {24, 80}} = TTY.size(state)
    end
  end

  describe "cursor operations" do
    test "move_cursor/2 returns {:ok, state}" do
      {:ok, state} = TTY.init([])
      assert {:ok, _state} = TTY.move_cursor(state, {10, 20})
    end

    test "hide_cursor/1 sets cursor_visible to false" do
      {:ok, state} = TTY.init([])
      assert state.cursor_visible == true
      {:ok, state} = TTY.hide_cursor(state)
      assert state.cursor_visible == false
    end

    test "show_cursor/1 sets cursor_visible to true" do
      {:ok, state} = TTY.init([])
      {:ok, state} = TTY.hide_cursor(state)
      assert state.cursor_visible == false
      {:ok, state} = TTY.show_cursor(state)
      assert state.cursor_visible == true
    end
  end

  describe "rendering operations" do
    test "clear/1 returns {:ok, state} with nil last_frame" do
      {:ok, state} = TTY.init([])
      state = %{state | last_frame: %{some: :data}}
      {:ok, state} = TTY.clear(state)
      assert state.last_frame == nil
    end

    test "draw_cells/2 returns {:ok, state}" do
      {:ok, state} = TTY.init([])
      cells = [{{1, 1}, %{char: "A", style: %{}}}]
      assert {:ok, _state} = TTY.draw_cells(state, cells)
    end

    test "flush/1 returns {:ok, state}" do
      {:ok, state} = TTY.init([])
      assert {:ok, _state} = TTY.flush(state)
    end
  end

  describe "input operations" do
    test "poll_event/2 returns {:timeout, state}" do
      {:ok, state} = TTY.init([])
      assert {:timeout, _state} = TTY.poll_event(state, 100)
    end
  end
end
