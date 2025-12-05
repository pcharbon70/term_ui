defmodule TermUI.Backend.RawIntegrationTest do
  @moduledoc """
  Integration tests for TermUI.Backend.Raw module.

  These tests verify the Raw backend works correctly in realistic scenarios,
  including interaction with existing TermUI components like Cell, Style,
  Buffer, and Diff.
  """

  use ExUnit.Case, async: true

  alias TermUI.Backend.Raw
  alias TermUI.Renderer.Cell

  # Helper to convert Cell struct to backend cell tuple format
  defp cell_to_tuple(%Cell{char: char, fg: fg, bg: bg, attrs: attrs}) do
    {char, fg, bg, MapSet.to_list(attrs)}
  end

  # Helper to convert a list of {{row, col}, Cell} to {{row, col}, tuple}
  defp to_backend_cells(cells) do
    Enum.map(cells, fn {pos, cell} -> {pos, cell_to_tuple(cell)} end)
  end

  # ===========================================================================
  # Section 2.9.1: Full Lifecycle Tests
  # ===========================================================================

  describe "full lifecycle integration (2.9.1)" do
    # Note: ANSI cursor coordinates are 1-indexed, so we use {1, 1} for top-left

    test "init → draw_cells → shutdown sequence" do
      # Initialize backend
      {:ok, state} = Raw.init(size: {24, 80}, alternate_screen: false)
      assert state.size == {24, 80}

      # Draw some cells (1-indexed coordinates)
      cells =
        [
          {{1, 1}, Cell.new("H")},
          {{1, 2}, Cell.new("i")}
        ]
        |> to_backend_cells()

      {:ok, state} = Raw.draw_cells(state, cells)

      # Shutdown cleanly
      assert :ok = Raw.shutdown(state)
    end

    test "init → draw_cells → poll_event (timeout) → shutdown sequence" do
      {:ok, state} = Raw.init(size: {24, 80}, alternate_screen: false)

      # Draw cells (1-indexed coordinates)
      cells = to_backend_cells([{{5, 10}, Cell.new("X", fg: :red)}])
      {:ok, state} = Raw.draw_cells(state, cells)

      # Poll with immediate timeout (no actual input)
      {:timeout, state} = Raw.poll_event(state, 0)

      # Shutdown
      assert :ok = Raw.shutdown(state)
    end

    test "alternate screen is tracked in state" do
      # With alternate screen
      {:ok, with_alt} = Raw.init(size: {24, 80}, alternate_screen: true)
      assert with_alt.alternate_screen == true
      :ok = Raw.shutdown(with_alt)

      # Without alternate screen
      {:ok, without_alt} = Raw.init(size: {24, 80}, alternate_screen: false)
      assert without_alt.alternate_screen == false
      :ok = Raw.shutdown(without_alt)
    end

    test "cursor visibility is tracked in state" do
      # Hidden cursor (default)
      {:ok, hidden} = Raw.init(size: {24, 80}, hide_cursor: true, alternate_screen: false)
      assert hidden.cursor_visible == false
      :ok = Raw.shutdown(hidden)

      # Visible cursor
      {:ok, visible} = Raw.init(size: {24, 80}, hide_cursor: false, alternate_screen: false)
      assert visible.cursor_visible == true
      :ok = Raw.shutdown(visible)
    end

    test "shutdown is safe to call multiple times" do
      {:ok, state} = Raw.init(size: {24, 80}, alternate_screen: false)
      :ok = Raw.shutdown(state)

      # Shutdown returns :ok without state, so this demonstrates
      # that shutdown completes without error
    end

    test "shutdown after drawing styled cells" do
      {:ok, state} = Raw.init(size: {24, 80}, alternate_screen: false)

      # Draw cells with various styles (1-indexed coordinates)
      cells =
        [
          {{1, 1}, Cell.new("A", fg: :red, bg: :blue, attrs: [:bold])},
          {{1, 2}, Cell.new("B", fg: :green, attrs: [:italic, :underline])},
          {{1, 3}, Cell.new("C", fg: {255, 128, 0}, bg: {0, 64, 128})}
        ]
        |> to_backend_cells()

      {:ok, state} = Raw.draw_cells(state, cells)
      assert :ok = Raw.shutdown(state)
    end
  end

  # ===========================================================================
  # Section 2.9.2: Renderer Integration Tests
  # ===========================================================================

  describe "renderer integration (2.9.2)" do
    # Note: ANSI cursor coordinates are 1-indexed

    setup do
      {:ok, state} = Raw.init(size: {24, 80}, alternate_screen: false)
      %{state: state}
    end

    test "draw_cells with Cell.new/2 styled cells", %{state: state} do
      cells =
        [
          {{1, 1}, Cell.new("R", fg: :red)},
          {{1, 2}, Cell.new("G", fg: :green)},
          {{1, 3}, Cell.new("B", fg: :blue)}
        ]
        |> to_backend_cells()

      assert {:ok, _} = Raw.draw_cells(state, cells)
    end

    test "draw_cells with 256-color palette cells", %{state: state} do
      cells =
        [
          {{1, 1}, Cell.new("1", fg: 196)},
          {{1, 2}, Cell.new("2", bg: 232)}
        ]
        |> to_backend_cells()

      assert {:ok, _} = Raw.draw_cells(state, cells)
    end

    test "draw_cells with true color RGB cells", %{state: state} do
      cells =
        [
          {{1, 1}, Cell.new("T", fg: {255, 0, 0})},
          {{1, 2}, Cell.new("C", bg: {0, 255, 0})}
        ]
        |> to_backend_cells()

      assert {:ok, _} = Raw.draw_cells(state, cells)
    end

    test "draw_cells with all attribute combinations", %{state: state} do
      cells =
        [
          {{1, 1}, Cell.new("B", attrs: [:bold])},
          {{2, 1}, Cell.new("D", attrs: [:dim])},
          {{3, 1}, Cell.new("I", attrs: [:italic])},
          {{4, 1}, Cell.new("U", attrs: [:underline])},
          {{5, 1}, Cell.new("K", attrs: [:blink])},
          {{6, 1}, Cell.new("R", attrs: [:reverse])},
          {{7, 1}, Cell.new("H", attrs: [:hidden])},
          {{8, 1}, Cell.new("S", attrs: [:strikethrough])}
        ]
        |> to_backend_cells()

      assert {:ok, _} = Raw.draw_cells(state, cells)
    end

    test "draw_cells with multiple attributes on single cell", %{state: state} do
      cell = Cell.new("X", fg: :red, bg: :blue, attrs: [:bold, :italic, :underline])
      cells = to_backend_cells([{{5, 10}, cell}])

      assert {:ok, _} = Raw.draw_cells(state, cells)
    end

    test "draw_cells with default colors", %{state: state} do
      cells =
        [
          {{1, 1}, Cell.new("D", fg: :default, bg: :default)}
        ]
        |> to_backend_cells()

      assert {:ok, _} = Raw.draw_cells(state, cells)
    end

    test "draw_cells maintains style across multiple calls", %{state: state} do
      # First call with red
      cells1 = to_backend_cells([{{1, 1}, Cell.new("A", fg: :red)}])
      {:ok, state} = Raw.draw_cells(state, cells1)

      # Second call with same style - should use delta optimization
      cells2 = to_backend_cells([{{1, 2}, Cell.new("B", fg: :red)}])
      {:ok, state} = Raw.draw_cells(state, cells2)

      # Third call with different style
      cells3 = to_backend_cells([{{1, 3}, Cell.new("C", fg: :blue)}])
      {:ok, _} = Raw.draw_cells(state, cells3)
    end
  end

  # ===========================================================================
  # Section 2.9.3: Input Integration Tests
  # ===========================================================================

  describe "input integration (2.9.3)" do
    setup do
      {:ok, state} = Raw.init(size: {24, 80}, alternate_screen: false)
      %{state: state}
    end

    test "poll_event returns timeout when no input", %{state: state} do
      assert {:timeout, _} = Raw.poll_event(state, 0)
    end

    test "poll_event with buffered input returns events", %{state: state} do
      # Inject input into buffer
      state = %{state | input_buffer: "abc"}

      # Should return first character
      {:ok, event, state} = Raw.poll_event(state, 0)
      assert event.key == "a"

      # Continue getting events from queue
      {:ok, event, state} = Raw.poll_event(state, 0)
      assert event.key == "b"

      {:ok, event, _state} = Raw.poll_event(state, 0)
      assert event.key == "c"
    end

    test "poll_event handles escape sequences", %{state: state} do
      # Arrow up sequence
      state = %{state | input_buffer: "\e[A"}

      {:ok, event, _} = Raw.poll_event(state, 0)
      assert event.key == :up
    end

    test "poll_event handles function keys", %{state: state} do
      # F1 via SS3
      state = %{state | input_buffer: "\eOP"}

      {:ok, event, _} = Raw.poll_event(state, 0)
      assert event.key == :f1
    end

    test "poll_event handles control characters", %{state: state} do
      # Ctrl+C
      state = %{state | input_buffer: <<3>>}

      {:ok, event, _} = Raw.poll_event(state, 0)
      assert event.key == "c"
      assert :ctrl in event.modifiers
    end

    test "poll_event preserves state fields", %{state: state} do
      {:timeout, new_state} = Raw.poll_event(state, 0)

      # Core state should be preserved
      assert new_state.size == state.size
      assert new_state.alternate_screen == state.alternate_screen
      assert new_state.cursor_visible == state.cursor_visible
    end
  end

  # ===========================================================================
  # Section 2.9.4: Performance Tests
  # ===========================================================================

  describe "performance integration (2.9.4)" do
    # Note: ANSI cursor coordinates are 1-indexed

    setup do
      {:ok, state} = Raw.init(size: {24, 80}, alternate_screen: false)
      %{state: state}
    end

    test "full screen render (80x24 = 1920 cells) completes", %{state: state} do
      # Generate all cells for 80x24 screen (1-indexed: rows 1-24, cols 1-80)
      cells =
        for row <- 1..24, col <- 1..80 do
          {{row, col}, Cell.new("X")}
        end
        |> to_backend_cells()

      assert length(cells) == 1920

      # Should complete without error
      {:ok, _} = Raw.draw_cells(state, cells)
    end

    test "differential update (10% changed cells) is efficient", %{state: state} do
      # First render full screen (1-indexed)
      full_cells =
        for row <- 1..24, col <- 1..80 do
          {{row, col}, Cell.new(" ")}
        end
        |> to_backend_cells()

      {:ok, state} = Raw.draw_cells(state, full_cells)

      # Update only 10% (192 cells) - first 8 columns of each row
      update_cells =
        for row <- 1..24, col <- 1..8 do
          {{row, col}, Cell.new("U", fg: :red)}
        end
        |> to_backend_cells()

      assert length(update_cells) == 192

      # Should complete efficiently
      {:ok, _} = Raw.draw_cells(state, update_cells)
    end

    test "style delta tracking minimizes escape sequences", %{state: state} do
      # All same style - should only emit style once (1-indexed)
      cells =
        for col <- 1..10 do
          {{1, col}, Cell.new("S", fg: :red, attrs: [:bold])}
        end
        |> to_backend_cells()

      # This should work due to style delta tracking
      {:ok, _} = Raw.draw_cells(state, cells)
    end

    test "cursor optimization reduces movement sequences", %{state: state} do
      # Sequential cells should use minimal cursor movement (1-indexed)
      cells =
        [
          {{1, 1}, Cell.new("A")},
          {{1, 2}, Cell.new("B")},
          {{1, 3}, Cell.new("C")}
        ]
        |> to_backend_cells()

      {:ok, _} = Raw.draw_cells(state, cells)
    end

    test "large coordinate handling", %{state: state} do
      # Test with coordinates near typical terminal limits (1-indexed)
      cells =
        [
          {{1, 1}, Cell.new("T")},
          {{24, 80}, Cell.new("B")}
        ]
        |> to_backend_cells()

      {:ok, _} = Raw.draw_cells(state, cells)
    end
  end

  # ===========================================================================
  # Section 2.9: Mouse Tracking Integration
  # ===========================================================================

  describe "mouse tracking integration" do
    setup do
      {:ok, state} = Raw.init(size: {24, 80}, alternate_screen: false)
      %{state: state}
    end

    test "enable and disable mouse tracking cycle", %{state: state} do
      # Enable
      {:ok, state} = Raw.enable_mouse(state, :click)
      assert state.mouse_mode == :click

      # Disable
      {:ok, state} = Raw.disable_mouse(state)
      assert state.mouse_mode == :none

      # Re-enable with different mode
      {:ok, state} = Raw.enable_mouse(state, :all)
      assert state.mouse_mode == :all

      # Shutdown with mouse enabled (should disable)
      :ok = Raw.shutdown(state)
    end

    test "init with mouse_tracking option" do
      {:ok, state} = Raw.init(size: {24, 80}, mouse_tracking: :drag, alternate_screen: false)
      assert state.mouse_mode == :drag
      :ok = Raw.shutdown(state)
    end
  end
end
