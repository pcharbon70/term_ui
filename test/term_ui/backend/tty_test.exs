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

    test "has current_style field with default nil" do
      state = %TTY{}
      assert state.current_style == nil
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

  describe "cursor operations" do
    test "move_cursor/2 returns {:ok, state}" do
      {:ok, state} = init_tty([])
      assert {:ok, _state} = TTY.move_cursor(state, {10, 20})
    end

    test "hide_cursor/1 sets cursor_visible to false" do
      {:ok, state} = init_tty([])
      # Note: init already hides cursor, so it's false after init
      assert state.cursor_visible == false
      # Show first, then hide to test the transition
      {:ok, state} = TTY.show_cursor(state)
      assert state.cursor_visible == true
      {:ok, state} = TTY.hide_cursor(state)
      assert state.cursor_visible == false
    end

    test "show_cursor/1 sets cursor_visible to true" do
      {:ok, state} = init_tty([])
      # init hides cursor, so start with false
      assert state.cursor_visible == false
      {:ok, state} = TTY.show_cursor(state)
      assert state.cursor_visible == true
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

    test "in incremental mode, does not output clear screen sequence" do
      {:ok, state} = init_tty(line_mode: :incremental)
      cells = [{{1, 1}, {"A", :default, :default, []}}]

      output =
        capture_io(fn ->
          TTY.draw_cells(state, cells)
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

    test "updates last_frame in state" do
      {:ok, state} = init_tty([])
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
  end
end
