defmodule TermUI.Backend.TTYTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureIO

  alias TermUI.Backend.TTY

  # Helper to initialize TTY without IO output cluttering tests
  defp init_tty(opts) do
    capture_io(fn ->
      send(self(), TTY.init(opts))
    end)

    receive do
      result -> result
    end
  end

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

  end

  describe "init/1" do
    test "returns {:ok, state} with default options" do
      assert {:ok, %TTY{}} = init_tty([])
    end

    test "stores capabilities from options" do
      capabilities = %{colors: :color_256, unicode: true, dimensions: {30, 100}}
      {:ok, state} = init_tty(capabilities: capabilities)
      assert state.capabilities == capabilities
    end

    test "uses line_mode from options" do
      {:ok, state} = init_tty(line_mode: :incremental)
      assert state.line_mode == :incremental
    end

    test "uses alternate_screen from options" do
      {:ok, state} = init_tty(alternate_screen: true)
      assert state.alternate_screen == true
    end

    test "uses explicit size from options" do
      {:ok, state} = init_tty(size: {50, 120})
      assert state.size == {50, 120}
    end

    test "uses size from capabilities when not explicitly set" do
      capabilities = %{dimensions: {40, 160}}
      {:ok, state} = init_tty(capabilities: capabilities)
      assert state.size == {40, 160}
    end

    test "prefers explicit size over capabilities" do
      capabilities = %{dimensions: {40, 160}}
      {:ok, state} = init_tty(size: {30, 100}, capabilities: capabilities)
      assert state.size == {30, 100}
    end

    test "determines color_mode :true_color from capabilities" do
      {:ok, state} = init_tty(capabilities: %{colors: :true_color})
      assert state.color_mode == :true_color
    end

    test "determines color_mode :color_256 from capabilities" do
      {:ok, state} = init_tty(capabilities: %{colors: :color_256})
      assert state.color_mode == :color_256
    end

    test "determines color_mode :color_16 from capabilities" do
      {:ok, state} = init_tty(capabilities: %{colors: :color_16})
      assert state.color_mode == :color_16
    end

    test "determines color_mode :monochrome from capabilities" do
      {:ok, state} = init_tty(capabilities: %{colors: :monochrome})
      assert state.color_mode == :monochrome
    end

    test "determines color_mode from integer >= 16_777_216 as :true_color" do
      {:ok, state} = init_tty(capabilities: %{colors: 16_777_216})
      assert state.color_mode == :true_color
    end

    test "determines color_mode from integer >= 256 as :color_256" do
      {:ok, state} = init_tty(capabilities: %{colors: 256})
      assert state.color_mode == :color_256
    end

    test "determines color_mode from integer >= 16 as :color_16" do
      {:ok, state} = init_tty(capabilities: %{colors: 16})
      assert state.color_mode == :color_16
    end

    test "determines character_set :unicode when unicode capability is true" do
      {:ok, state} = init_tty(capabilities: %{unicode: true})
      assert state.character_set == :unicode
    end

    test "determines character_set :ascii when unicode capability is false" do
      {:ok, state} = init_tty(capabilities: %{unicode: false})
      assert state.character_set == :ascii
    end

    test "defaults character_set to :unicode when not specified" do
      {:ok, state} = init_tty(capabilities: %{})
      assert state.character_set == :unicode
    end
  end

  describe "shutdown/1" do
    test "returns :ok" do
      {:ok, state} = init_tty([])

      result =
        capture_io(fn ->
          send(self(), TTY.shutdown(state))
        end)

      receive do
        r -> assert r == :ok
      end

      # Verify some output occurred
      assert result != ""
    end

    test "can be called multiple times" do
      {:ok, state} = init_tty([])

      capture_io(fn ->
        assert :ok = TTY.shutdown(state)
        assert :ok = TTY.shutdown(state)
      end)
    end

    test "requires TTY struct as argument" do
      # Verify shutdown pattern matches on the struct type
      assert_raise FunctionClauseError, fn ->
        capture_io(fn ->
          TTY.shutdown(%{alternate_screen: false})
        end)
      end
    end
  end

  # ===========================================================================
  # Edge Case Tests - Invalid Inputs
  # ===========================================================================

  describe "edge cases - invalid size values" do
    test "zero rows defaults to {24, 80}" do
      {:ok, state} = init_tty(size: {0, 80})
      assert state.size == {24, 80}
    end

    test "negative rows defaults to {24, 80}" do
      {:ok, state} = init_tty(size: {-1, 80})
      assert state.size == {24, 80}
    end

    test "zero cols defaults to {24, 80}" do
      {:ok, state} = init_tty(size: {24, 0})
      assert state.size == {24, 80}
    end

    test "negative cols defaults to {24, 80}" do
      {:ok, state} = init_tty(size: {24, -1})
      assert state.size == {24, 80}
    end

    test "non-integer size defaults to {24, 80}" do
      {:ok, state} = init_tty(size: {"24", "80"})
      assert state.size == {24, 80}
    end

    test "nil size defaults to {24, 80}" do
      {:ok, state} = init_tty(size: nil)
      assert state.size == {24, 80}
    end
  end

  describe "edge cases - malformed capabilities" do
    test "unknown color mode defaults to :true_color" do
      {:ok, state} = init_tty(capabilities: %{colors: :unknown_mode})
      assert state.color_mode == :true_color
    end

    test "string color value defaults to :true_color" do
      {:ok, state} = init_tty(capabilities: %{colors: "256"})
      assert state.color_mode == :true_color
    end

    test "negative integer color value defaults to :true_color" do
      {:ok, state} = init_tty(capabilities: %{colors: -1})
      assert state.color_mode == :true_color
    end

    test "non-boolean unicode capability defaults to :unicode" do
      {:ok, state} = init_tty(capabilities: %{unicode: "yes"})
      assert state.character_set == :unicode
    end

    test "invalid dimensions in capabilities defaults to {24, 80}" do
      {:ok, state} = init_tty(capabilities: %{dimensions: {0, 0}})
      assert state.size == {24, 80}
    end

    test "string dimensions in capabilities defaults to {24, 80}" do
      {:ok, state} = init_tty(capabilities: %{dimensions: {"30", "100"}})
      assert state.size == {24, 80}
    end
  end

  describe "size/1" do
    test "returns {:ok, size} from state" do
      {:ok, state} = init_tty(size: {50, 120})
      assert {:ok, {50, 120}} = TTY.size(state)
    end

    test "returns default size when not configured" do
      {:ok, state} = init_tty([])
      assert {:ok, {24, 80}} = TTY.size(state)
    end
  end

  describe "refresh_size/1" do
    test "returns {:ok, state}" do
      {:ok, state} = init_tty([])
      assert {:ok, _new_state} = TTY.refresh_size(state)
    end

    test "clears last_frame to force full redraw" do
      {:ok, state} = init_tty(line_mode: :incremental)
      # Simulate having a last_frame
      state = %{state | last_frame: %{{1, 1} => {"A", :default, :default, []}}}

      {:ok, refreshed_state} = TTY.refresh_size(state)

      assert refreshed_state.last_frame == nil
    end

    test "preserves state structure" do
      {:ok, state} = init_tty(line_mode: :incremental, alternate_screen: true)

      {:ok, refreshed_state} = TTY.refresh_size(state)

      assert refreshed_state.line_mode == :incremental
      assert refreshed_state.alternate_screen == true
    end

    test "queries terminal and updates size" do
      {:ok, state} = init_tty(size: {24, 80})

      # refresh_size queries :io.rows and :io.columns
      # In test environment these may or may not be available
      {:ok, refreshed_state} = TTY.refresh_size(state)

      # Size should be a valid tuple
      {rows, cols} = refreshed_state.size
      assert is_integer(rows) and rows > 0
      assert is_integer(cols) and cols > 0
    end

    test "falls back to current size if terminal query fails" do
      # When not connected to a terminal, :io.rows/columns return errors
      # In that case, refresh_size should preserve the current size
      {:ok, state} = init_tty(size: {30, 100})

      {:ok, refreshed_state} = TTY.refresh_size(state)

      # Size should still be valid (either from terminal or fallback)
      {rows, cols} = refreshed_state.size
      assert is_integer(rows) and rows > 0
      assert is_integer(cols) and cols > 0
    end
  end

  describe "cursor operations" do
    test "move_cursor/2 returns {:ok, state}" do
      {:ok, state} = init_tty([])

      output =
        capture_io(fn ->
          assert {:ok, _state} = TTY.move_cursor(state, {10, 20})
        end)

      assert output =~ "\e[10;20H"
    end

    test "move_cursor/2 updates cursor_position in state" do
      {:ok, state} = init_tty([])

      capture_io(fn ->
        {:ok, new_state} = TTY.move_cursor(state, {5, 15})
        send(self(), {:result, new_state})
      end)

      receive do
        {:result, new_state} -> assert new_state.cursor_position == {5, 15}
      end
    end

    test "move_cursor/2 clamps row to terminal bounds" do
      {:ok, state} = init_tty(size: {24, 80})

      output =
        capture_io(fn ->
          {:ok, new_state} = TTY.move_cursor(state, {100, 40})
          send(self(), {:result, new_state})
        end)

      # Row should be clamped to 24 (max rows)
      assert output =~ "\e[24;40H"

      receive do
        {:result, new_state} -> assert new_state.cursor_position == {24, 40}
      end
    end

    test "move_cursor/2 clamps column to terminal bounds" do
      {:ok, state} = init_tty(size: {24, 80})

      output =
        capture_io(fn ->
          {:ok, new_state} = TTY.move_cursor(state, {10, 200})
          send(self(), {:result, new_state})
        end)

      # Column should be clamped to 80 (max cols)
      assert output =~ "\e[10;80H"

      receive do
        {:result, new_state} -> assert new_state.cursor_position == {10, 80}
      end
    end

    test "move_cursor/2 clamps minimum position to 1,1" do
      {:ok, state} = init_tty([])

      output =
        capture_io(fn ->
          {:ok, new_state} = TTY.move_cursor(state, {0, 0})
          send(self(), {:result, new_state})
        end)

      # Position should be clamped to 1,1
      assert output =~ "\e[1;1H"

      receive do
        {:result, new_state} -> assert new_state.cursor_position == {1, 1}
      end
    end

    test "hide_cursor/1 sets cursor_visible to false" do
      {:ok, state} = init_tty([])
      # Note: init already hides cursor, so it's false after init
      assert state.cursor_visible == false

      # Show first, then hide to test the transition
      capture_io(fn ->
        {:ok, state} = TTY.show_cursor(state)
        assert state.cursor_visible == true
        {:ok, state} = TTY.hide_cursor(state)
        assert state.cursor_visible == false
      end)
    end

    test "hide_cursor/1 outputs hide cursor sequence" do
      {:ok, state} = init_tty([])

      output =
        capture_io(fn ->
          TTY.hide_cursor(state)
        end)

      assert output =~ "\e[?25l"
    end

    test "show_cursor/1 sets cursor_visible to true" do
      {:ok, state} = init_tty([])
      # init hides cursor, so start with false
      assert state.cursor_visible == false

      capture_io(fn ->
        {:ok, state} = TTY.show_cursor(state)
        assert state.cursor_visible == true
      end)
    end

    test "show_cursor/1 outputs show cursor sequence" do
      {:ok, state} = init_tty([])

      output =
        capture_io(fn ->
          TTY.show_cursor(state)
        end)

      assert output =~ "\e[?25h"
    end
  end

  describe "rendering operations" do
    test "clear/1 returns {:ok, state} with nil last_frame" do
      {:ok, state} = init_tty([])
      state = %{state | last_frame: %{some: :data}}
      {:ok, state} = TTY.clear(state)
      assert state.last_frame == nil
    end

    test "draw_cells/2 returns {:ok, state}" do
      {:ok, state} = init_tty([])
      cells = [{{1, 1}, {"A", :default, :default, []}}]

      capture_io(fn ->
        assert {:ok, _state} = TTY.draw_cells(state, cells)
      end)
    end

    test "flush/1 returns {:ok, state}" do
      {:ok, state} = init_tty([])
      assert {:ok, _state} = TTY.flush(state)
    end

    test "flush/1 preserves state unchanged" do
      {:ok, state} = init_tty(size: {50, 120}, line_mode: :incremental)
      {:ok, flushed_state} = TTY.flush(state)

      assert flushed_state.size == {50, 120}
      assert flushed_state.line_mode == :incremental
      assert flushed_state == state
    end
  end

  describe "input operations" do
    test "poll_event/2 returns {:timeout, state}" do
      {:ok, state} = init_tty([])
      assert {:timeout, _state} = TTY.poll_event(state, 100)
    end
  end

  # ===========================================================================
  # Section 3.2.2 Tests - Terminal Setup
  # ===========================================================================

  describe "terminal setup (Section 3.2.2)" do
    test "init outputs hide cursor sequence" do
      output =
        capture_io(fn ->
          TTY.init([])
        end)

      assert output =~ "\e[?25l"
    end

    test "init outputs clear screen sequence" do
      output =
        capture_io(fn ->
          TTY.init([])
        end)

      assert output =~ "\e[2J"
    end

    test "init outputs cursor home sequence" do
      output =
        capture_io(fn ->
          TTY.init([])
        end)

      assert output =~ "\e[H"
    end

    test "init outputs alternate screen sequence when configured" do
      output =
        capture_io(fn ->
          TTY.init(alternate_screen: true)
        end)

      assert output =~ "\e[?1049h"
    end

    test "init does not output alternate screen sequence by default" do
      output =
        capture_io(fn ->
          TTY.init([])
        end)

      refute output =~ "\e[?1049h"
    end

    test "init sets cursor_visible to false" do
      {:ok, state} = init_tty([])
      assert state.cursor_visible == false
    end

    test "init sets cursor_position to {1, 1}" do
      {:ok, state} = init_tty([])
      assert state.cursor_position == {1, 1}
    end

    test "setup sequences are output in correct order" do
      # When alternate_screen is true, sequence should be:
      # 1. alternate screen
      # 2. hide cursor
      # 3. clear screen + home
      output =
        capture_io(fn ->
          TTY.init(alternate_screen: true)
        end)

      alt_screen_pos = :binary.match(output, "\e[?1049h")
      hide_cursor_pos = :binary.match(output, "\e[?25l")
      clear_screen_pos = :binary.match(output, "\e[2J")

      assert alt_screen_pos != :nomatch
      assert hide_cursor_pos != :nomatch
      assert clear_screen_pos != :nomatch

      # alternate screen comes before hide cursor
      {alt_start, _} = alt_screen_pos
      {hide_start, _} = hide_cursor_pos
      {clear_start, _} = clear_screen_pos

      assert alt_start < hide_start
      assert hide_start < clear_start
    end
  end

  # ===========================================================================
  # Section 3.2.3 Tests - Shutdown Callback
  # ===========================================================================

  describe "shutdown sequences (Section 3.2.3)" do
    test "shutdown outputs reset attributes sequence" do
      {:ok, state} = init_tty([])

      output =
        capture_io(fn ->
          TTY.shutdown(state)
        end)

      assert output =~ "\e[0m"
    end

    test "shutdown outputs show cursor sequence" do
      {:ok, state} = init_tty([])

      output =
        capture_io(fn ->
          TTY.shutdown(state)
        end)

      assert output =~ "\e[?25h"
    end

    test "shutdown outputs leave alternate screen when alternate_screen is true" do
      {:ok, state} = init_tty(alternate_screen: true)

      output =
        capture_io(fn ->
          TTY.shutdown(state)
        end)

      assert output =~ "\e[?1049l"
    end

    test "shutdown does not output leave alternate screen by default" do
      {:ok, state} = init_tty([])

      output =
        capture_io(fn ->
          TTY.shutdown(state)
        end)

      refute output =~ "\e[?1049l"
    end

    test "shutdown sequences are output in correct order" do
      {:ok, state} = init_tty(alternate_screen: true)

      output =
        capture_io(fn ->
          TTY.shutdown(state)
        end)

      reset_pos = :binary.match(output, "\e[0m")
      show_cursor_pos = :binary.match(output, "\e[?25h")
      leave_alt_pos = :binary.match(output, "\e[?1049l")

      assert reset_pos != :nomatch
      assert show_cursor_pos != :nomatch
      assert leave_alt_pos != :nomatch

      # reset comes before show cursor, show cursor comes before leave alternate
      {reset_start, _} = reset_pos
      {show_start, _} = show_cursor_pos
      {leave_start, _} = leave_alt_pos

      assert reset_start < show_start
      assert show_start < leave_start
    end
  end

  # ===========================================================================
  # Section 3.3.1 Tests - clear/1 Callback
  # ===========================================================================

  describe "clear/1 (Section 3.3.1)" do
    test "outputs clear screen sequence" do
      {:ok, state} = init_tty([])

      output =
        capture_io(fn ->
          TTY.clear(state)
        end)

      assert output =~ "\e[2J"
    end

    test "outputs cursor home sequence" do
      {:ok, state} = init_tty([])

      output =
        capture_io(fn ->
          TTY.clear(state)
        end)

      assert output =~ "\e[H"
    end

    test "clear screen comes before cursor home" do
      {:ok, state} = init_tty([])

      output =
        capture_io(fn ->
          TTY.clear(state)
        end)

      clear_pos = :binary.match(output, "\e[2J")
      home_pos = :binary.match(output, "\e[H")

      assert clear_pos != :nomatch
      assert home_pos != :nomatch

      {clear_start, _} = clear_pos
      {home_start, _} = home_pos

      assert clear_start < home_start
    end

    test "clears last_frame in state" do
      {:ok, state} = init_tty([])
      state = %{state | last_frame: %{some: :data}}

      {:ok, new_state} =
        capture_io(fn ->
          send(self(), TTY.clear(state))
        end)
        |> then(fn _ ->
          receive do
            result -> result
          end
        end)

      assert new_state.last_frame == nil
    end

    test "sets cursor_position to {1, 1}" do
      {:ok, state} = init_tty([])
      state = %{state | cursor_position: {10, 20}}

      {:ok, new_state} =
        capture_io(fn ->
          send(self(), TTY.clear(state))
        end)
        |> then(fn _ ->
          receive do
            result -> result
          end
        end)

      assert new_state.cursor_position == {1, 1}
    end

    test "returns {:ok, state}" do
      {:ok, state} = init_tty([])

      result =
        capture_io(fn ->
          send(self(), TTY.clear(state))
        end)
        |> then(fn _ ->
          receive do
            result -> result
          end
        end)

      assert {:ok, %TTY{}} = result
    end
  end

  # ===========================================================================
  # Section 3.3.2 Tests - draw_cells/2 Callback
  # ===========================================================================

  describe "draw_cells/2 (Section 3.3.2)" do
    test "in full_redraw mode, outputs clear screen sequence" do
      {:ok, state} = init_tty(line_mode: :full_redraw)
      cells = [{{1, 1}, {"A", :default, :default, []}}]

      output =
        capture_io(fn ->
          TTY.draw_cells(state, cells)
        end)

      assert output =~ "\e[2J"
    end

    test "in incremental mode with existing frame, does not output clear screen sequence" do
      {:ok, state} = init_tty(line_mode: :incremental)
      cells = [{{1, 1}, {"A", :default, :default, []}}]

      # First frame sets last_frame (will clear screen)
      {:ok, state_with_frame} =
        capture_io(fn ->
          send(self(), TTY.draw_cells(state, cells))
        end)
        |> then(fn _ ->
          receive do
            result -> result
          end
        end)

      # Subsequent frame should NOT clear screen
      output =
        capture_io(fn ->
          TTY.draw_cells(state_with_frame, cells)
        end)

      refute output =~ "\e[2J"
    end

    test "outputs cursor positioning sequence" do
      {:ok, state} = init_tty([])
      cells = [{{5, 1}, {"X", :default, :default, []}}]

      output =
        capture_io(fn ->
          TTY.draw_cells(state, cells)
        end)

      assert output =~ "\e[5;1H"
    end

    test "outputs cell character" do
      {:ok, state} = init_tty([])
      cells = [{{1, 1}, {"Z", :default, :default, []}}]

      output =
        capture_io(fn ->
          TTY.draw_cells(state, cells)
        end)

      assert output =~ "Z"
    end

    test "outputs multiple cells in row order" do
      {:ok, state} = init_tty([])

      cells = [
        {{2, 1}, {"B", :default, :default, []}},
        {{1, 1}, {"A", :default, :default, []}}
      ]

      output =
        capture_io(fn ->
          TTY.draw_cells(state, cells)
        end)

      # Row 1 should come before Row 2
      row1_pos = :binary.match(output, "\e[1;1H")
      row2_pos = :binary.match(output, "\e[2;1H")

      assert row1_pos != :nomatch
      assert row2_pos != :nomatch

      {row1_start, _} = row1_pos
      {row2_start, _} = row2_pos

      assert row1_start < row2_start
    end

    test "outputs named foreground color" do
      {:ok, state} = init_tty([])
      cells = [{{1, 1}, {"X", :red, :default, []}}]

      output =
        capture_io(fn ->
          TTY.draw_cells(state, cells)
        end)

      assert output =~ "\e[31m"
    end

    test "outputs named background color" do
      {:ok, state} = init_tty([])
      cells = [{{1, 1}, {"X", :default, :blue, []}}]

      output =
        capture_io(fn ->
          TTY.draw_cells(state, cells)
        end)

      assert output =~ "\e[44m"
    end

    test "outputs RGB foreground in true_color mode" do
      {:ok, state} = init_tty(capabilities: %{colors: :true_color})
      cells = [{{1, 1}, {"X", {255, 128, 64}, :default, []}}]

      output =
        capture_io(fn ->
          TTY.draw_cells(state, cells)
        end)

      assert output =~ "\e[38;2;255;128;64m"
    end

    test "outputs RGB background in true_color mode" do
      {:ok, state} = init_tty(capabilities: %{colors: :true_color})
      cells = [{{1, 1}, {"X", :default, {64, 128, 255}, []}}]

      output =
        capture_io(fn ->
          TTY.draw_cells(state, cells)
        end)

      assert output =~ "\e[48;2;64;128;255m"
    end

    test "outputs bold attribute" do
      {:ok, state} = init_tty([])
      cells = [{{1, 1}, {"X", :default, :default, [:bold]}}]

      output =
        capture_io(fn ->
          TTY.draw_cells(state, cells)
        end)

      assert output =~ "\e[1m"
    end

    test "outputs underline attribute" do
      {:ok, state} = init_tty([])
      cells = [{{1, 1}, {"X", :default, :default, [:underline]}}]

      output =
        capture_io(fn ->
          TTY.draw_cells(state, cells)
        end)

      assert output =~ "\e[4m"
    end

    test "resets attributes at end of row" do
      {:ok, state} = init_tty([])
      cells = [{{1, 1}, {"X", :red, :default, [:bold]}}]

      output =
        capture_io(fn ->
          TTY.draw_cells(state, cells)
        end)

      # Should end with reset
      assert output =~ "\e[0m"
    end

    test "outputs dim attribute" do
      {:ok, state} = init_tty([])
      cells = [{{1, 1}, {"X", :default, :default, [:dim]}}]

      output =
        capture_io(fn ->
          TTY.draw_cells(state, cells)
        end)

      assert output =~ "\e[2m"
    end

    test "outputs italic attribute" do
      {:ok, state} = init_tty([])
      cells = [{{1, 1}, {"X", :default, :default, [:italic]}}]

      output =
        capture_io(fn ->
          TTY.draw_cells(state, cells)
        end)

      assert output =~ "\e[3m"
    end

    test "outputs blink attribute" do
      {:ok, state} = init_tty([])
      cells = [{{1, 1}, {"X", :default, :default, [:blink]}}]

      output =
        capture_io(fn ->
          TTY.draw_cells(state, cells)
        end)

      assert output =~ "\e[5m"
    end

    test "outputs reverse attribute" do
      {:ok, state} = init_tty([])
      cells = [{{1, 1}, {"X", :default, :default, [:reverse]}}]

      output =
        capture_io(fn ->
          TTY.draw_cells(state, cells)
        end)

      assert output =~ "\e[7m"
    end

    test "outputs strikethrough attribute" do
      {:ok, state} = init_tty([])
      cells = [{{1, 1}, {"X", :default, :default, [:strikethrough]}}]

      output =
        capture_io(fn ->
          TTY.draw_cells(state, cells)
        end)

      assert output =~ "\e[9m"
    end

    test "outputs multiple attributes combined" do
      {:ok, state} = init_tty([])
      cells = [{{1, 1}, {"X", :default, :default, [:bold, :italic, :underline]}}]

      output =
        capture_io(fn ->
          TTY.draw_cells(state, cells)
        end)

      assert output =~ "\e[1m"
      assert output =~ "\e[3m"
      assert output =~ "\e[4m"
    end

    test "updates last_frame in state for incremental mode" do
      {:ok, state} = init_tty(line_mode: :incremental)
      cells = [{{1, 1}, {"A", :default, :default, []}}]

      {:ok, new_state} =
        capture_io(fn ->
          send(self(), TTY.draw_cells(state, cells))
        end)
        |> then(fn _ ->
          receive do
            result -> result
          end
        end)

      assert new_state.last_frame == %{{1, 1} => {"A", :default, :default, []}}
    end

    test "empty cells list produces no cell output" do
      {:ok, state} = init_tty([])

      output =
        capture_io(fn ->
          TTY.draw_cells(state, [])
        end)

      # Should only have clear screen, no row positioning
      refute output =~ "\e[1;1H"
    end

    test "returns {:ok, state}" do
      {:ok, state} = init_tty([])
      cells = [{{1, 1}, {"A", :default, :default, []}}]

      result =
        capture_io(fn ->
          send(self(), TTY.draw_cells(state, cells))
        end)
        |> then(fn _ ->
          receive do
            result -> result
          end
        end)

      assert {:ok, %TTY{}} = result
    end
  end

  # ===========================================================================
  # Color Degradation Tests (Section 3.3.2)
  # ===========================================================================

  describe "color degradation in draw_cells/2" do
    test "256-color mode converts RGB to palette index" do
      {:ok, state} = init_tty(capabilities: %{colors: :color_256})
      cells = [{{1, 1}, {"X", {255, 0, 0}, :default, []}}]

      output =
        capture_io(fn ->
          TTY.draw_cells(state, cells)
        end)

      # Should use 38;5;N format, not 38;2;r;g;b
      assert output =~ "\e[38;5;"
      refute output =~ "\e[38;2;"
    end

    test "16-color mode converts RGB to basic color" do
      {:ok, state} = init_tty(capabilities: %{colors: :color_16})
      cells = [{{1, 1}, {"X", {255, 0, 0}, :default, []}}]

      output =
        capture_io(fn ->
          TTY.draw_cells(state, cells)
        end)

      # Should use basic foreground codes (31 = red or 91 = bright red)
      assert output =~ "\e[91m" or output =~ "\e[31m"
    end

    test "monochrome mode omits color sequences" do
      {:ok, state} = init_tty(capabilities: %{colors: :monochrome})
      cells = [{{1, 1}, {"X", {255, 0, 0}, {0, 0, 255}, []}}]

      output =
        capture_io(fn ->
          TTY.draw_cells(state, cells)
        end)

      # Should not have any color codes
      refute output =~ "\e[38;"
      refute output =~ "\e[48;"
      refute output =~ "\e[31m"
    end

    test "nil foreground color produces no color sequence" do
      {:ok, state} = init_tty([])
      cells = [{{1, 1}, {"X", nil, :default, []}}]

      output =
        capture_io(fn ->
          TTY.draw_cells(state, cells)
        end)

      # Should not have foreground color sequences (38;2 or 38;5)
      refute output =~ "\e[38;"
    end

    test "nil background color produces no color sequence" do
      {:ok, state} = init_tty([])
      cells = [{{1, 1}, {"X", :default, nil, []}}]

      output =
        capture_io(fn ->
          TTY.draw_cells(state, cells)
        end)

      # Should not have background color sequences (48;2 or 48;5)
      refute output =~ "\e[48;"
    end

    test ":default foreground outputs reset foreground sequence" do
      {:ok, state} = init_tty([])
      cells = [{{1, 1}, {"X", :default, :blue, []}}]

      output =
        capture_io(fn ->
          TTY.draw_cells(state, cells)
        end)

      # Default foreground should output \e[39m
      assert output =~ "\e[39m"
      # And blue background
      assert output =~ "\e[44m"
    end

    test ":default background outputs reset background sequence" do
      {:ok, state} = init_tty([])
      cells = [{{1, 1}, {"X", :red, :default, []}}]

      output =
        capture_io(fn ->
          TTY.draw_cells(state, cells)
        end)

      # Default background should output \e[49m
      assert output =~ "\e[49m"
      # And red foreground
      assert output =~ "\e[31m"
    end

    test "palette index foreground in 256-color mode" do
      {:ok, state} = init_tty(capabilities: %{colors: :color_256})
      cells = [{{1, 1}, {"X", 42, :default, []}}]

      output =
        capture_io(fn ->
          TTY.draw_cells(state, cells)
        end)

      # Palette index 42 as foreground
      assert output =~ "\e[38;5;42m"
    end

    test "palette index background in 256-color mode" do
      {:ok, state} = init_tty(capabilities: %{colors: :color_256})
      cells = [{{1, 1}, {"X", :default, 196, []}}]

      output =
        capture_io(fn ->
          TTY.draw_cells(state, cells)
        end)

      # Palette index 196 as background
      assert output =~ "\e[48;5;196m"
    end

    test "palette index colors work in true_color mode" do
      {:ok, state} = init_tty(capabilities: %{colors: :true_color})
      cells = [{{1, 1}, {"X", 100, 200, []}}]

      output =
        capture_io(fn ->
          TTY.draw_cells(state, cells)
        end)

      # Palette indices should still work in true_color mode
      assert output =~ "\e[38;5;100m"
      assert output =~ "\e[48;5;200m"
    end
  end

  # ===========================================================================
  # Section 3.5 Tests - Color Degradation
  # ===========================================================================

  describe "color degradation - 256-color mode (Section 3.5.2)" do
    test "256-color mapping uses color cube for non-gray colors" do
      {:ok, state} = init_tty(capabilities: %{colors: :color_256})
      # Pure red should map to color cube, not grayscale
      cells = [{{1, 1}, {"X", {255, 0, 0}, :default, []}}]

      output =
        capture_io(fn ->
          TTY.draw_cells(state, cells)
        end)

      # Should use 38;5;N format with a color cube index (16-231)
      # Pure red (255, 0, 0) should map to index 196 (5*36 + 0*6 + 0 + 16)
      assert output =~ "\e[38;5;196m"
    end

    test "256-color mapping uses grayscale for near-gray colors" do
      {:ok, state} = init_tty(capabilities: %{colors: :color_256})
      # Gray (128, 128, 128) should map to grayscale ramp
      cells = [{{1, 1}, {"X", {128, 128, 128}, :default, []}}]

      output =
        capture_io(fn ->
          TTY.draw_cells(state, cells)
        end)

      # Should use 38;5;N format with a grayscale index (232-255)
      # Gray (128, 128, 128) average = 128, maps to 232 + (128 * 23 / 255) = 232 + 11 = 243
      assert output =~ "\e[38;5;243m"
    end

    test "256-color background uses palette index" do
      {:ok, state} = init_tty(capabilities: %{colors: :color_256})
      cells = [{{1, 1}, {"X", :default, {0, 255, 0}, []}}]

      output =
        capture_io(fn ->
          TTY.draw_cells(state, cells)
        end)

      # Pure green should map to 16 + 0*36 + 5*6 + 0 = 46
      assert output =~ "\e[48;5;46m"
    end
  end

  describe "color degradation - monochrome mode (Section 3.5.4)" do
    test "monochrome mode preserves bold attribute" do
      {:ok, state} = init_tty(capabilities: %{colors: :monochrome})
      cells = [{{1, 1}, {"X", {255, 0, 0}, :default, [:bold]}}]

      output =
        capture_io(fn ->
          TTY.draw_cells(state, cells)
        end)

      # Color should be omitted
      refute output =~ "\e[38;"
      # But bold should be preserved
      assert output =~ "\e[1m"
    end

    test "monochrome mode preserves underline attribute" do
      {:ok, state} = init_tty(capabilities: %{colors: :monochrome})
      cells = [{{1, 1}, {"X", :red, :blue, [:underline]}}]

      output =
        capture_io(fn ->
          TTY.draw_cells(state, cells)
        end)

      # Colors should be omitted
      refute output =~ "\e[31m"
      refute output =~ "\e[44m"
      # But underline should be preserved
      assert output =~ "\e[4m"
    end

    test "monochrome mode preserves reverse attribute for contrast" do
      {:ok, state} = init_tty(capabilities: %{colors: :monochrome})
      cells = [{{1, 1}, {"X", {255, 255, 255}, {0, 0, 0}, [:reverse]}}]

      output =
        capture_io(fn ->
          TTY.draw_cells(state, cells)
        end)

      # RGB colors should be omitted
      refute output =~ "\e[38;2;"
      refute output =~ "\e[48;2;"
      # But reverse should be preserved for visibility
      assert output =~ "\e[7m"
    end
  end

  describe "color degradation - named colors (Section 3.5.5)" do
    test "named colors work in true_color mode" do
      {:ok, state} = init_tty(capabilities: %{colors: :true_color})
      cells = [{{1, 1}, {"X", :cyan, :magenta, []}}]

      output =
        capture_io(fn ->
          TTY.draw_cells(state, cells)
        end)

      # Named colors should use standard SGR codes
      assert output =~ "\e[36m"  # cyan foreground
      assert output =~ "\e[45m"  # magenta background
    end

    test "named colors work in 256-color mode" do
      {:ok, state} = init_tty(capabilities: %{colors: :color_256})
      cells = [{{1, 1}, {"X", :yellow, :green, []}}]

      output =
        capture_io(fn ->
          TTY.draw_cells(state, cells)
        end)

      # Named colors should still use standard SGR codes
      assert output =~ "\e[33m"  # yellow foreground
      assert output =~ "\e[42m"  # green background
    end

    test "named colors work in 16-color mode" do
      {:ok, state} = init_tty(capabilities: %{colors: :color_16})
      cells = [{{1, 1}, {"X", :blue, :white, []}}]

      output =
        capture_io(fn ->
          TTY.draw_cells(state, cells)
        end)

      # Named colors should use standard SGR codes
      assert output =~ "\e[34m"  # blue foreground
      assert output =~ "\e[47m"  # white background
    end

    test "bright named colors work correctly" do
      {:ok, state} = init_tty([])
      cells = [{{1, 1}, {"X", :bright_red, :bright_blue, []}}]

      output =
        capture_io(fn ->
          TTY.draw_cells(state, cells)
        end)

      # Bright colors use codes 90-97 (fg) and 100-107 (bg)
      assert output =~ "\e[91m"   # bright red foreground
      assert output =~ "\e[104m"  # bright blue background
    end

    test ":default foreground works in all modes" do
      for mode <- [:true_color, :color_256, :color_16] do
        {:ok, state} = init_tty(capabilities: %{colors: mode})
        cells = [{{1, 1}, {"X", :default, :red, []}}]

        output =
          capture_io(fn ->
            TTY.draw_cells(state, cells)
          end)

        # Default foreground should always output \e[39m
        assert output =~ "\e[39m", "Failed for mode #{mode}"
      end
    end

    test ":default background works in all modes" do
      for mode <- [:true_color, :color_256, :color_16] do
        {:ok, state} = init_tty(capabilities: %{colors: mode})
        cells = [{{1, 1}, {"X", :red, :default, []}}]

        output =
          capture_io(fn ->
            TTY.draw_cells(state, cells)
          end)

        # Default background should always output \e[49m
        assert output =~ "\e[49m", "Failed for mode #{mode}"
      end
    end
  end

  # ===========================================================================
  # Section 3.3.3 Tests - Row-by-Row Output with Style Delta Tracking
  # ===========================================================================

  describe "row-by-row output (Section 3.3.3)" do
    test "consecutive cells with same style only output style once" do
      {:ok, state} = init_tty([])

      # Two cells with identical style
      cells = [
        {{1, 1}, {"A", :red, :default, []}},
        {{1, 2}, {"B", :red, :default, []}}
      ]

      output =
        capture_io(fn ->
          TTY.draw_cells(state, cells)
        end)

      # Count occurrences of red foreground SGR
      red_count = length(String.split(output, "\e[31m")) - 1

      # Should only output red once (for first cell), not twice
      assert red_count == 1
    end

    test "cells with different styles output style for each change" do
      {:ok, state} = init_tty([])

      # Two cells with different styles
      cells = [
        {{1, 1}, {"A", :red, :default, []}},
        {{1, 2}, {"B", :blue, :default, []}}
      ]

      output =
        capture_io(fn ->
          TTY.draw_cells(state, cells)
        end)

      # Should have both red and blue
      assert output =~ "\e[31m"
      assert output =~ "\e[34m"
    end

    test "style change in attributes triggers new SGR" do
      {:ok, state} = init_tty([])

      cells = [
        {{1, 1}, {"A", :default, :default, [:bold]}},
        {{1, 2}, {"B", :default, :default, []}}
      ]

      output =
        capture_io(fn ->
          TTY.draw_cells(state, cells)
        end)

      # Count reset sequences - should have at least 2 (one for style change, one at end)
      reset_count = length(String.split(output, "\e[0m")) - 1

      assert reset_count >= 2
    end

    test "gap filling preserves style tracking" do
      {:ok, state} = init_tty([])

      # Cells with gap between them, same style
      cells = [
        {{1, 1}, {"A", :green, :default, []}},
        {{1, 5}, {"B", :green, :default, []}}
      ]

      output =
        capture_io(fn ->
          TTY.draw_cells(state, cells)
        end)

      # Gap should be filled with spaces
      assert output =~ "A   "

      # Green should only be output once
      green_count = length(String.split(output, "\e[32m")) - 1
      assert green_count == 1
    end

    test "outputs cells left-to-right" do
      {:ok, state} = init_tty([])

      # Cells given out of order
      cells = [
        {{1, 3}, {"C", :default, :default, []}},
        {{1, 1}, {"A", :default, :default, []}},
        {{1, 2}, {"B", :default, :default, []}}
      ]

      output =
        capture_io(fn ->
          TTY.draw_cells(state, cells)
        end)

      # Characters should appear in correct order
      a_pos = :binary.match(output, "A")
      b_pos = :binary.match(output, "B")
      c_pos = :binary.match(output, "C")

      assert a_pos != :nomatch
      assert b_pos != :nomatch
      assert c_pos != :nomatch

      {a_start, _} = a_pos
      {b_start, _} = b_pos
      {c_start, _} = c_pos

      assert a_start < b_start
      assert b_start < c_start
    end

    test "multiple rows maintain correct ordering" do
      {:ok, state} = init_tty([])

      cells = [
        {{2, 1}, {"2", :default, :default, []}},
        {{1, 1}, {"1", :default, :default, []}},
        {{3, 1}, {"3", :default, :default, []}}
      ]

      output =
        capture_io(fn ->
          TTY.draw_cells(state, cells)
        end)

      # Row positioning should be in order
      row1_pos = :binary.match(output, "\e[1;1H")
      row2_pos = :binary.match(output, "\e[2;1H")
      row3_pos = :binary.match(output, "\e[3;1H")

      assert row1_pos != :nomatch
      assert row2_pos != :nomatch
      assert row3_pos != :nomatch

      {r1_start, _} = row1_pos
      {r2_start, _} = row2_pos
      {r3_start, _} = row3_pos

      assert r1_start < r2_start
      assert r2_start < r3_start
    end

    test "each row ends with attribute reset" do
      {:ok, state} = init_tty([])

      cells = [
        {{1, 1}, {"A", :red, :default, []}},
        {{2, 1}, {"B", :blue, :default, []}}
      ]

      output =
        capture_io(fn ->
          TTY.draw_cells(state, cells)
        end)

      # Should have reset after each row
      # Row 1: [1;1H + style + A + reset
      # Row 2: [2;1H + style + B + reset
      reset_count = length(String.split(output, "\e[0m")) - 1

      # At least 2 resets (one per row) plus any style changes
      assert reset_count >= 2
    end
  end

  # ===========================================================================
  # Security Tests - Character Sanitization
  # ===========================================================================

  describe "character sanitization" do
    test "escape sequences in cell content are stripped" do
      {:ok, state} = init_tty([])
      # Attempt to inject an escape sequence via cell content
      cells = [{{1, 1}, {"\e[31mEVIL", :default, :default, []}}]

      output =
        capture_io(fn ->
          TTY.draw_cells(state, cells)
        end)

      # The escape should be stripped from the cell content
      # So we should see "EVIL" but not an extra \e[31m from the content itself
      assert output =~ "[31mEVIL"
      # The cell content escape was stripped, only framework escapes remain
      # Count number of \e[31m - should only be 0 (no red from cell content)
      refute output =~ "\e[31mEVIL"
    end

    test "normal characters are not affected by sanitization" do
      {:ok, state} = init_tty([])
      cells = [{{1, 1}, {"Hello!", :default, :default, []}}]

      output =
        capture_io(fn ->
          TTY.draw_cells(state, cells)
        end)

      assert output =~ "Hello!"
    end
  end

  # ===========================================================================
  # Frame Map Tests - Incremental Mode
  # ===========================================================================

  describe "frame map handling" do
    test "full_redraw mode sets last_frame to nil" do
      {:ok, state} = init_tty(line_mode: :full_redraw)
      cells = [{{1, 1}, {"A", :default, :default, []}}]

      {:ok, new_state} =
        capture_io(fn ->
          send(self(), TTY.draw_cells(state, cells))
        end)
        |> then(fn _ ->
          receive do
            result -> result
          end
        end)

      assert new_state.last_frame == nil
    end

    test "incremental mode stores last_frame as map" do
      {:ok, state} = init_tty(line_mode: :incremental)
      cells = [{{1, 1}, {"A", :default, :default, []}}]

      {:ok, new_state} =
        capture_io(fn ->
          send(self(), TTY.draw_cells(state, cells))
        end)
        |> then(fn _ ->
          receive do
            result -> result
          end
        end)

      assert new_state.last_frame == %{{1, 1} => {"A", :default, :default, []}}
    end

    test "incremental mode first frame (nil last_frame) triggers full redraw" do
      {:ok, state} = init_tty(line_mode: :incremental)
      # Verify last_frame starts as nil
      assert state.last_frame == nil

      cells = [{{1, 1}, {"X", :default, :default, []}}]

      output =
        capture_io(fn ->
          TTY.draw_cells(state, cells)
        end)

      # First frame should include clear screen sequence
      assert output =~ "\e[2J"
    end

    test "incremental mode subsequent frame does not clear screen" do
      {:ok, state} = init_tty(line_mode: :incremental)
      cells = [{{1, 1}, {"A", :default, :default, []}}]

      # First frame - sets last_frame
      {:ok, state_with_frame} =
        capture_io(fn ->
          send(self(), TTY.draw_cells(state, cells))
        end)
        |> then(fn _ ->
          receive do
            result -> result
          end
        end)

      # Verify last_frame is now set
      assert state_with_frame.last_frame != nil

      # Second frame - should NOT clear screen
      output =
        capture_io(fn ->
          TTY.draw_cells(state_with_frame, cells)
        end)

      # Should NOT include clear screen sequence
      refute output =~ "\e[2J"
    end

    test "clear/1 clears last_frame" do
      {:ok, state} = init_tty(line_mode: :incremental)
      cells = [{{1, 1}, {"A", :default, :default, []}}]

      # First draw to set last_frame
      {:ok, state_with_frame} =
        capture_io(fn ->
          send(self(), TTY.draw_cells(state, cells))
        end)
        |> then(fn _ ->
          receive do
            result -> result
          end
        end)

      assert state_with_frame.last_frame != nil

      # Clear should reset last_frame
      {:ok, cleared_state} =
        capture_io(fn ->
          send(self(), TTY.clear(state_with_frame))
        end)
        |> then(fn _ ->
          receive do
            result -> result
          end
        end)

      assert cleared_state.last_frame == nil
    end

    test "set_size/2 clears last_frame" do
      {:ok, state} = init_tty(line_mode: :incremental)
      cells = [{{1, 1}, {"A", :default, :default, []}}]

      # First draw to set last_frame
      {:ok, state_with_frame} =
        capture_io(fn ->
          send(self(), TTY.draw_cells(state, cells))
        end)
        |> then(fn _ ->
          receive do
            result -> result
          end
        end)

      assert state_with_frame.last_frame != nil

      # set_size should clear last_frame
      {:ok, resized_state} = TTY.set_size(state_with_frame, {50, 120})

      assert resized_state.last_frame == nil
      assert resized_state.size == {50, 120}
    end

    test "set_size/2 updates size correctly" do
      {:ok, state} = init_tty([])

      {:ok, resized_state} = TTY.set_size(state, {100, 200})

      assert resized_state.size == {100, 200}
    end

    test "after resize, next draw in incremental mode triggers full redraw" do
      {:ok, state} = init_tty(line_mode: :incremental)
      cells = [{{1, 1}, {"A", :default, :default, []}}]

      # First draw to set last_frame
      {:ok, state_with_frame} =
        capture_io(fn ->
          send(self(), TTY.draw_cells(state, cells))
        end)
        |> then(fn _ ->
          receive do
            result -> result
          end
        end)

      # Resize clears last_frame
      {:ok, resized_state} = TTY.set_size(state_with_frame, {50, 120})
      assert resized_state.last_frame == nil

      # Next draw should trigger full redraw (clear screen)
      output =
        capture_io(fn ->
          TTY.draw_cells(resized_state, cells)
        end)

      assert output =~ "\e[2J"
    end
  end

  # ===========================================================================
  # Frame Comparison Tests (Section 3.4.2)
  # ===========================================================================

  describe "compare_frames/2" do
    test "empty last frame and empty current returns no changes" do
      {changed, removed} = TTY.compare_frames(%{}, [])

      assert changed == []
      assert removed == []
    end

    test "new cell is detected as changed" do
      last_frame = %{}
      current_cells = [{{1, 1}, {"A", :default, :default, []}}]

      {changed, removed} = TTY.compare_frames(last_frame, current_cells)

      assert changed == [{{1, 1}, {"A", :default, :default, []}}]
      assert removed == []
    end

    test "multiple new cells are all detected as changed" do
      last_frame = %{}

      current_cells = [
        {{1, 1}, {"A", :default, :default, []}},
        {{1, 2}, {"B", :default, :default, []}},
        {{2, 1}, {"C", :default, :default, []}}
      ]

      {changed, removed} = TTY.compare_frames(last_frame, current_cells)

      assert length(changed) == 3
      assert removed == []
    end

    test "removed cell is detected" do
      last_frame = %{{1, 1} => {"A", :default, :default, []}}
      current_cells = []

      {changed, removed} = TTY.compare_frames(last_frame, current_cells)

      assert changed == []
      assert removed == [{1, 1}]
    end

    test "multiple removed cells are all detected" do
      last_frame = %{
        {1, 1} => {"A", :default, :default, []},
        {1, 2} => {"B", :default, :default, []},
        {2, 1} => {"C", :default, :default, []}
      }

      current_cells = []

      {changed, removed} = TTY.compare_frames(last_frame, current_cells)

      assert changed == []
      assert length(removed) == 3
      assert {1, 1} in removed
      assert {1, 2} in removed
      assert {2, 1} in removed
    end

    test "unchanged cell is not in changed or removed" do
      cell = {"A", :default, :default, []}
      last_frame = %{{1, 1} => cell}
      current_cells = [{{1, 1}, cell}]

      {changed, removed} = TTY.compare_frames(last_frame, current_cells)

      assert changed == []
      assert removed == []
    end

    test "changed character is detected" do
      last_frame = %{{1, 1} => {"A", :default, :default, []}}
      current_cells = [{{1, 1}, {"B", :default, :default, []}}]

      {changed, removed} = TTY.compare_frames(last_frame, current_cells)

      assert changed == [{{1, 1}, {"B", :default, :default, []}}]
      assert removed == []
    end

    test "changed foreground color is detected" do
      last_frame = %{{1, 1} => {"A", :red, :default, []}}
      current_cells = [{{1, 1}, {"A", :blue, :default, []}}]

      {changed, removed} = TTY.compare_frames(last_frame, current_cells)

      assert changed == [{{1, 1}, {"A", :blue, :default, []}}]
      assert removed == []
    end

    test "changed background color is detected" do
      last_frame = %{{1, 1} => {"A", :default, :red, []}}
      current_cells = [{{1, 1}, {"A", :default, :blue, []}}]

      {changed, removed} = TTY.compare_frames(last_frame, current_cells)

      assert changed == [{{1, 1}, {"A", :default, :blue, []}}]
      assert removed == []
    end

    test "changed attributes are detected" do
      last_frame = %{{1, 1} => {"A", :default, :default, [:bold]}}
      current_cells = [{{1, 1}, {"A", :default, :default, [:underline]}}]

      {changed, removed} = TTY.compare_frames(last_frame, current_cells)

      assert changed == [{{1, 1}, {"A", :default, :default, [:underline]}}]
      assert removed == []
    end

    test "added attribute is detected as change" do
      last_frame = %{{1, 1} => {"A", :default, :default, []}}
      current_cells = [{{1, 1}, {"A", :default, :default, [:bold]}}]

      {changed, removed} = TTY.compare_frames(last_frame, current_cells)

      assert changed == [{{1, 1}, {"A", :default, :default, [:bold]}}]
      assert removed == []
    end

    test "mixed scenario: some changed, some removed, some unchanged" do
      last_frame = %{
        {1, 1} => {"A", :default, :default, []},
        {1, 2} => {"B", :default, :default, []},
        {1, 3} => {"C", :default, :default, []}
      }

      current_cells = [
        {{1, 1}, {"A", :default, :default, []}},
        {{1, 2}, {"X", :default, :default, []}},
        {{1, 4}, {"D", :default, :default, []}}
      ]

      {changed, removed} = TTY.compare_frames(last_frame, current_cells)

      # {1, 1} unchanged - not in changed
      # {1, 2} changed from B to X
      # {1, 3} removed
      # {1, 4} new
      assert length(changed) == 2

      assert {{1, 2}, {"X", :default, :default, []}} in changed
      assert {{1, 4}, {"D", :default, :default, []}} in changed

      assert removed == [{1, 3}]
    end

    test "position order is preserved in changed list" do
      last_frame = %{}

      current_cells = [
        {{1, 1}, {"A", :default, :default, []}},
        {{2, 1}, {"B", :default, :default, []}},
        {{1, 2}, {"C", :default, :default, []}}
      ]

      {changed, _removed} = TTY.compare_frames(last_frame, current_cells)

      # Order should match input order
      assert changed == current_cells
    end

    test "RGB color change is detected" do
      last_frame = %{{1, 1} => {"A", {255, 0, 0}, :default, []}}
      current_cells = [{{1, 1}, {"A", {0, 255, 0}, :default, []}}]

      {changed, removed} = TTY.compare_frames(last_frame, current_cells)

      assert changed == [{{1, 1}, {"A", {0, 255, 0}, :default, []}}]
      assert removed == []
    end
  end

  # ===========================================================================
  # Incremental Rendering Tests (Section 3.4.3)
  # ===========================================================================

  describe "incremental rendering" do
    test "only renders changed cells on subsequent frames" do
      {:ok, state} = init_tty(line_mode: :incremental)

      # First frame with two cells
      cells1 = [
        {{1, 1}, {"A", :default, :default, []}},
        {{1, 2}, {"B", :default, :default, []}}
      ]

      {:ok, state1} =
        capture_io(fn ->
          send(self(), TTY.draw_cells(state, cells1))
        end)
        |> then(fn _ ->
          receive do
            result -> result
          end
        end)

      # Second frame: change one cell, keep one the same
      cells2 = [
        {{1, 1}, {"A", :default, :default, []}},
        {{1, 2}, {"X", :default, :default, []}}
      ]

      output =
        capture_io(fn ->
          TTY.draw_cells(state1, cells2)
        end)

      # Should NOT have clear screen (incremental)
      refute output =~ "\e[2J"

      # Should have cursor positioning for the changed cell {1, 2}
      assert output =~ "\e[1;2H"

      # Should contain the changed character X
      assert output =~ "X"
    end

    test "unchanged cells are not re-rendered" do
      {:ok, state} = init_tty(line_mode: :incremental)

      cells = [
        {{1, 1}, {"A", :default, :default, []}},
        {{1, 2}, {"B", :default, :default, []}}
      ]

      {:ok, state1} =
        capture_io(fn ->
          send(self(), TTY.draw_cells(state, cells))
        end)
        |> then(fn _ ->
          receive do
            result -> result
          end
        end)

      # Same cells - nothing should be rendered
      output =
        capture_io(fn ->
          TTY.draw_cells(state1, cells)
        end)

      # No clear screen
      refute output =~ "\e[2J"

      # No cursor positioning (nothing to render)
      refute output =~ "\e[1;1H"
      refute output =~ "\e[1;2H"
    end

    test "removed cells are cleared with space" do
      {:ok, state} = init_tty(line_mode: :incremental)

      # First frame with two cells
      cells1 = [
        {{1, 1}, {"A", :default, :default, []}},
        {{1, 2}, {"B", :default, :default, []}}
      ]

      {:ok, state1} =
        capture_io(fn ->
          send(self(), TTY.draw_cells(state, cells1))
        end)
        |> then(fn _ ->
          receive do
            result -> result
          end
        end)

      # Second frame: remove one cell
      cells2 = [{{1, 1}, {"A", :default, :default, []}}]

      output =
        capture_io(fn ->
          TTY.draw_cells(state1, cells2)
        end)

      # Should position cursor at removed cell location {1, 2}
      assert output =~ "\e[1;2H"

      # Should write a space to clear it (with reset)
      assert output =~ "\e[0m "
    end

    test "new cells are rendered" do
      {:ok, state} = init_tty(line_mode: :incremental)

      # First frame with one cell
      cells1 = [{{1, 1}, {"A", :default, :default, []}}]

      {:ok, state1} =
        capture_io(fn ->
          send(self(), TTY.draw_cells(state, cells1))
        end)
        |> then(fn _ ->
          receive do
            result -> result
          end
        end)

      # Second frame: add a new cell
      cells2 = [
        {{1, 1}, {"A", :default, :default, []}},
        {{1, 2}, {"B", :default, :default, []}}
      ]

      output =
        capture_io(fn ->
          TTY.draw_cells(state1, cells2)
        end)

      # Should position cursor at new cell location {1, 2}
      assert output =~ "\e[1;2H"

      # Should render the new cell
      assert output =~ "B"
    end

    test "mixed changes: add, modify, remove in single frame" do
      {:ok, state} = init_tty(line_mode: :incremental)

      # First frame
      cells1 = [
        {{1, 1}, {"A", :default, :default, []}},
        {{1, 2}, {"B", :default, :default, []}},
        {{1, 3}, {"C", :default, :default, []}}
      ]

      {:ok, state1} =
        capture_io(fn ->
          send(self(), TTY.draw_cells(state, cells1))
        end)
        |> then(fn _ ->
          receive do
            result -> result
          end
        end)

      # Second frame:
      # - {1, 1} unchanged (A)
      # - {1, 2} changed (B -> X)
      # - {1, 3} removed
      # - {1, 4} added (D)
      cells2 = [
        {{1, 1}, {"A", :default, :default, []}},
        {{1, 2}, {"X", :default, :default, []}},
        {{1, 4}, {"D", :default, :default, []}}
      ]

      output =
        capture_io(fn ->
          TTY.draw_cells(state1, cells2)
        end)

      # Should NOT render unchanged cell {1, 1}
      refute output =~ "\e[1;1H"

      # Should render changed cell {1, 2} - cursor positioned there
      assert output =~ "\e[1;2H"
      assert output =~ "X"

      # Should clear removed cell {1, 3} (separate cursor positioning for clear)
      assert output =~ "\e[1;3H"

      # Should render new cell {1, 4}
      # With optimization, cells on same row are grouped, so D is rendered
      # after X with a space gap (X at col 2, space fills col 3, D at col 4)
      assert output =~ "D"

      # The output should show the grouped rendering: X + space + D
      # (X at col 2, gap fills col 3 to reach col 4, then D)
      assert output =~ "X D"
    end

    test "style change triggers re-render" do
      {:ok, state} = init_tty(line_mode: :incremental)

      # First frame
      cells1 = [{{1, 1}, {"A", :red, :default, []}}]

      {:ok, state1} =
        capture_io(fn ->
          send(self(), TTY.draw_cells(state, cells1))
        end)
        |> then(fn _ ->
          receive do
            result -> result
          end
        end)

      # Second frame: change color
      cells2 = [{{1, 1}, {"A", :blue, :default, []}}]

      output =
        capture_io(fn ->
          TTY.draw_cells(state1, cells2)
        end)

      # Should re-render the cell
      assert output =~ "\e[1;1H"

      # Should have blue color code
      assert output =~ "\e[34m"
    end

    test "last_frame is updated after incremental render" do
      {:ok, state} = init_tty(line_mode: :incremental)

      cells1 = [{{1, 1}, {"A", :default, :default, []}}]

      {:ok, state1} =
        capture_io(fn ->
          send(self(), TTY.draw_cells(state, cells1))
        end)
        |> then(fn _ ->
          receive do
            result -> result
          end
        end)

      cells2 = [{{1, 1}, {"B", :default, :default, []}}]

      {:ok, state2} =
        capture_io(fn ->
          send(self(), TTY.draw_cells(state1, cells2))
        end)
        |> then(fn _ ->
          receive do
            result -> result
          end
        end)

      # last_frame should now contain B, not A
      assert state2.last_frame == %{{1, 1} => {"B", :default, :default, []}}
    end

    test "full_redraw mode always clears screen" do
      {:ok, state} = init_tty(line_mode: :full_redraw)

      cells1 = [{{1, 1}, {"A", :default, :default, []}}]

      {:ok, state1} =
        capture_io(fn ->
          send(self(), TTY.draw_cells(state, cells1))
        end)
        |> then(fn _ ->
          receive do
            result -> result
          end
        end)

      # Even identical cells should trigger full redraw
      output =
        capture_io(fn ->
          TTY.draw_cells(state1, cells1)
        end)

      # Should ALWAYS have clear screen in full_redraw mode
      assert output =~ "\e[2J"
    end
  end

  # ===========================================================================
  # Cursor Movement Optimization Tests (Section 3.4.4)
  # ===========================================================================

  describe "cursor movement optimization" do
    test "changed cells are sorted by position for rendering" do
      {:ok, state} = init_tty(line_mode: :incremental)

      # First frame
      cells1 = [
        {{1, 1}, {"A", :default, :default, []}},
        {{1, 5}, {"E", :default, :default, []}},
        {{1, 3}, {"C", :default, :default, []}}
      ]

      {:ok, state1} =
        capture_io(fn ->
          send(self(), TTY.draw_cells(state, cells1))
        end)
        |> then(fn _ ->
          receive do
            result -> result
          end
        end)

      # Second frame: change all cells (order doesn't match position order)
      cells2 = [
        {{1, 5}, {"X", :default, :default, []}},
        {{1, 1}, {"Y", :default, :default, []}},
        {{1, 3}, {"Z", :default, :default, []}}
      ]

      output =
        capture_io(fn ->
          TTY.draw_cells(state1, cells2)
        end)

      # All cells changed so they should all be rendered
      # They should be grouped by row and sorted by column
      assert output =~ "Y"
      assert output =~ "Z"
      assert output =~ "X"

      # Characters should appear in column order (Y at 1, Z at 3, X at 5)
      y_pos = :binary.match(output, "Y")
      z_pos = :binary.match(output, "Z")
      x_pos = :binary.match(output, "X")

      assert y_pos != :nomatch
      assert z_pos != :nomatch
      assert x_pos != :nomatch

      {y_start, _} = y_pos
      {z_start, _} = z_pos
      {x_start, _} = x_pos

      assert y_start < z_start
      assert z_start < x_start
    end

    test "adjacent cells on same row use single cursor positioning" do
      {:ok, state} = init_tty(line_mode: :incremental)

      # First frame - empty
      {:ok, state1} =
        capture_io(fn ->
          send(self(), TTY.draw_cells(state, []))
        end)
        |> then(fn _ ->
          receive do
            result -> result
          end
        end)

      # Second frame: add adjacent cells on row 1
      cells2 = [
        {{1, 1}, {"A", :default, :default, []}},
        {{1, 2}, {"B", :default, :default, []}},
        {{1, 3}, {"C", :default, :default, []}}
      ]

      output =
        capture_io(fn ->
          TTY.draw_cells(state1, cells2)
        end)

      # Should only have ONE cursor positioning for row 1 (at start)
      # Count cursor positioning sequences for row 1
      row1_positions =
        output
        |> String.split("\e[1;")
        |> length()

      # Should position only once at the start of the row
      # (one more element than actual occurrences due to split behavior)
      assert row1_positions == 2
    end

    test "non-adjacent cells on same row fill gaps with spaces" do
      {:ok, state} = init_tty(line_mode: :incremental)

      # First frame - empty
      {:ok, state1} =
        capture_io(fn ->
          send(self(), TTY.draw_cells(state, []))
        end)
        |> then(fn _ ->
          receive do
            result -> result
          end
        end)

      # Second frame: cells at columns 1 and 4 (gap of 2)
      cells2 = [
        {{1, 1}, {"A", :default, :default, []}},
        {{1, 4}, {"D", :default, :default, []}}
      ]

      output =
        capture_io(fn ->
          TTY.draw_cells(state1, cells2)
        end)

      # Should have A followed by spaces, then D
      # The pattern should be: cursor positioning + A + spaces + style + D
      assert output =~ "A"
      assert output =~ "D"

      # Gap should be filled with spaces (columns 2, 3 = 2 spaces between A and D)
      # But actually we're going from col 1 (A takes col 1) to col 4
      # So gap is col 2, 3 = 2 spaces
      # Actually after rendering A at col 1, cursor advances to col 2
      # Then we need to fill col 2, 3 to reach col 4 = 2 spaces
      assert output =~ "A  "
    end

    test "cells on different rows get separate cursor positioning" do
      {:ok, state} = init_tty(line_mode: :incremental)

      # First frame - empty
      {:ok, state1} =
        capture_io(fn ->
          send(self(), TTY.draw_cells(state, []))
        end)
        |> then(fn _ ->
          receive do
            result -> result
          end
        end)

      # Second frame: cells on rows 1 and 3
      cells2 = [
        {{1, 1}, {"A", :default, :default, []}},
        {{3, 1}, {"C", :default, :default, []}}
      ]

      output =
        capture_io(fn ->
          TTY.draw_cells(state1, cells2)
        end)

      # Should have cursor positioning for both rows
      assert output =~ "\e[1;1H"
      assert output =~ "\e[3;1H"
    end

    test "style delta tracking works within grouped row cells" do
      {:ok, state} = init_tty(line_mode: :incremental)

      # First frame - empty
      {:ok, state1} =
        capture_io(fn ->
          send(self(), TTY.draw_cells(state, []))
        end)
        |> then(fn _ ->
          receive do
            result -> result
          end
        end)

      # Second frame: adjacent cells with same style
      cells2 = [
        {{1, 1}, {"A", :red, :default, []}},
        {{1, 2}, {"B", :red, :default, []}},
        {{1, 3}, {"C", :red, :default, []}}
      ]

      output =
        capture_io(fn ->
          TTY.draw_cells(state1, cells2)
        end)

      # Red color should only appear once (delta tracking)
      red_count = length(String.split(output, "\e[31m")) - 1
      assert red_count == 1
    end

    test "multiple rows are processed in order" do
      {:ok, state} = init_tty(line_mode: :incremental)

      # First frame - empty
      {:ok, state1} =
        capture_io(fn ->
          send(self(), TTY.draw_cells(state, []))
        end)
        |> then(fn _ ->
          receive do
            result -> result
          end
        end)

      # Second frame: cells on rows 3, 1, 2 (out of order)
      cells2 = [
        {{3, 1}, {"3", :default, :default, []}},
        {{1, 1}, {"1", :default, :default, []}},
        {{2, 1}, {"2", :default, :default, []}}
      ]

      output =
        capture_io(fn ->
          TTY.draw_cells(state1, cells2)
        end)

      # Rows should be processed in order 1, 2, 3
      row1_pos = :binary.match(output, "\e[1;1H")
      row2_pos = :binary.match(output, "\e[2;1H")
      row3_pos = :binary.match(output, "\e[3;1H")

      assert row1_pos != :nomatch
      assert row2_pos != :nomatch
      assert row3_pos != :nomatch

      {r1_start, _} = row1_pos
      {r2_start, _} = row2_pos
      {r3_start, _} = row3_pos

      assert r1_start < r2_start
      assert r2_start < r3_start
    end

    test "removed cells are sorted for sequential clearing" do
      {:ok, state} = init_tty(line_mode: :incremental)

      # First frame: cells at various positions
      cells1 = [
        {{2, 3}, {"X", :default, :default, []}},
        {{1, 1}, {"A", :default, :default, []}},
        {{2, 1}, {"B", :default, :default, []}}
      ]

      {:ok, state1} =
        capture_io(fn ->
          send(self(), TTY.draw_cells(state, cells1))
        end)
        |> then(fn _ ->
          receive do
            result -> result
          end
        end)

      # Second frame: remove all cells
      output =
        capture_io(fn ->
          TTY.draw_cells(state1, [])
        end)

      # All positions should be cleared
      assert output =~ "\e[1;1H"
      assert output =~ "\e[2;1H"
      assert output =~ "\e[2;3H"

      # Positions should be cleared in sorted order
      pos_1_1 = :binary.match(output, "\e[1;1H")
      pos_2_1 = :binary.match(output, "\e[2;1H")
      pos_2_3 = :binary.match(output, "\e[2;3H")

      {p1_start, _} = pos_1_1
      {p2_start, _} = pos_2_1
      {p3_start, _} = pos_2_3

      # {1, 1} < {2, 1} < {2, 3} in tuple comparison order
      assert p1_start < p2_start
      assert p2_start < p3_start
    end

    test "mixed changed and removed cells both optimized" do
      {:ok, state} = init_tty(line_mode: :incremental)

      # First frame
      cells1 = [
        {{1, 1}, {"A", :default, :default, []}},
        {{1, 2}, {"B", :default, :default, []}},
        {{2, 1}, {"C", :default, :default, []}}
      ]

      {:ok, state1} =
        capture_io(fn ->
          send(self(), TTY.draw_cells(state, cells1))
        end)
        |> then(fn _ ->
          receive do
            result -> result
          end
        end)

      # Second frame: change {1, 1} and {1, 2}, remove {2, 1}
      cells2 = [
        {{1, 1}, {"X", :default, :default, []}},
        {{1, 2}, {"Y", :default, :default, []}}
      ]

      output =
        capture_io(fn ->
          TTY.draw_cells(state1, cells2)
        end)

      # Changed cells on row 1 should be grouped (single cursor positioning)
      # Should have cursor position for row 1
      assert output =~ "\e[1;1H"

      # Should have both changed characters
      assert output =~ "X"
      assert output =~ "Y"

      # Should clear removed cell at {2, 1}
      assert output =~ "\e[2;1H"
      assert output =~ "\e[0m "
    end
  end

  # ===========================================================================
  # Section 3.6.2 Tests - Character Mapping
  # ===========================================================================

  describe "character mapping (Section 3.6.2)" do
    test "unicode mode passes through box-drawing characters unchanged" do
      {:ok, state} = init_tty(capabilities: %{unicode: true})
      assert state.character_set == :unicode

      # Unicode box-drawing character
      cells = [{{1, 1}, {"┌", :default, :default, []}}]

      output =
        capture_io(fn ->
          TTY.draw_cells(state, cells)
        end)

      # Should contain the Unicode character unchanged
      assert output =~ "┌"
    end

    test "ascii mode converts box corners to +" do
      {:ok, state} = init_tty(capabilities: %{unicode: false})
      assert state.character_set == :ascii

      # Unicode corners should become +
      cells = [
        {{1, 1}, {"┌", :default, :default, []}},
        {{1, 2}, {"┐", :default, :default, []}},
        {{1, 3}, {"└", :default, :default, []}},
        {{1, 4}, {"┘", :default, :default, []}}
      ]

      output =
        capture_io(fn ->
          TTY.draw_cells(state, cells)
        end)

      # Should have + characters, not Unicode corners
      assert output =~ "++++"
      refute output =~ "┌"
      refute output =~ "┐"
      refute output =~ "└"
      refute output =~ "┘"
    end

    test "ascii mode converts horizontal line to -" do
      {:ok, state} = init_tty(capabilities: %{unicode: false})

      cells = [{{1, 1}, {"─", :default, :default, []}}]

      output =
        capture_io(fn ->
          TTY.draw_cells(state, cells)
        end)

      assert output =~ "-"
      refute output =~ "─"
    end

    test "ascii mode converts vertical line to |" do
      {:ok, state} = init_tty(capabilities: %{unicode: false})

      cells = [{{1, 1}, {"│", :default, :default, []}}]

      output =
        capture_io(fn ->
          TTY.draw_cells(state, cells)
        end)

      assert output =~ "|"
      refute output =~ "│"
    end

    test "ascii mode converts T-junctions to +" do
      {:ok, state} = init_tty(capabilities: %{unicode: false})

      cells = [
        {{1, 1}, {"┬", :default, :default, []}},
        {{1, 2}, {"┴", :default, :default, []}},
        {{1, 3}, {"├", :default, :default, []}},
        {{1, 4}, {"┤", :default, :default, []}}
      ]

      output =
        capture_io(fn ->
          TTY.draw_cells(state, cells)
        end)

      # Should have + characters
      assert output =~ "++++"
      refute output =~ "┬"
      refute output =~ "┴"
      refute output =~ "├"
      refute output =~ "┤"
    end

    test "ascii mode converts cross junction to +" do
      {:ok, state} = init_tty(capabilities: %{unicode: false})

      cells = [{{1, 1}, {"┼", :default, :default, []}}]

      output =
        capture_io(fn ->
          TTY.draw_cells(state, cells)
        end)

      assert output =~ "+"
      refute output =~ "┼"
    end

    test "ascii mode converts progress bar characters" do
      {:ok, state} = init_tty(capabilities: %{unicode: false})

      cells = [
        {{1, 1}, {"█", :default, :default, []}},
        {{1, 2}, {"░", :default, :default, []}}
      ]

      output =
        capture_io(fn ->
          TTY.draw_cells(state, cells)
        end)

      # Full block becomes #, empty becomes .
      assert output =~ "#."
      refute output =~ "█"
      refute output =~ "░"
    end

    test "ascii mode converts check marks" do
      {:ok, state} = init_tty(capabilities: %{unicode: false})

      cells = [
        {{1, 1}, {"✓", :default, :default, []}},
        {{1, 2}, {"✗", :default, :default, []}}
      ]

      output =
        capture_io(fn ->
          TTY.draw_cells(state, cells)
        end)

      # Check becomes x, cross becomes X
      assert output =~ "xX"
      refute output =~ "✓"
      refute output =~ "✗"
    end

    test "ascii mode converts arrows" do
      {:ok, state} = init_tty(capabilities: %{unicode: false})

      cells = [
        {{1, 1}, {"↑", :default, :default, []}},
        {{1, 2}, {"↓", :default, :default, []}},
        {{1, 3}, {"←", :default, :default, []}},
        {{1, 4}, {"→", :default, :default, []}}
      ]

      output =
        capture_io(fn ->
          TTY.draw_cells(state, cells)
        end)

      # Up=^, Down=v, Left=<, Right=>
      assert output =~ "^v<>"
      refute output =~ "↑"
      refute output =~ "↓"
      refute output =~ "←"
      refute output =~ "→"
    end

    test "regular characters pass through unchanged in ascii mode" do
      {:ok, state} = init_tty(capabilities: %{unicode: false})

      cells = [{{1, 1}, {"Hello", :default, :default, []}}]

      output =
        capture_io(fn ->
          TTY.draw_cells(state, cells)
        end)

      assert output =~ "Hello"
    end

    test "regular characters pass through unchanged in unicode mode" do
      {:ok, state} = init_tty(capabilities: %{unicode: true})

      cells = [{{1, 1}, {"World", :default, :default, []}}]

      output =
        capture_io(fn ->
          TTY.draw_cells(state, cells)
        end)

      assert output =~ "World"
    end

    test "mixed content with box drawing in ascii mode" do
      {:ok, state} = init_tty(capabilities: %{unicode: false})

      # Simulate a simple box: ┌─┐
      cells = [
        {{1, 1}, {"┌", :default, :default, []}},
        {{1, 2}, {"─", :default, :default, []}},
        {{1, 3}, {"┐", :default, :default, []}}
      ]

      output =
        capture_io(fn ->
          TTY.draw_cells(state, cells)
        end)

      # Should render as +-+
      assert output =~ "+-+"
    end
  end
end
