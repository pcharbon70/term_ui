defmodule TermUI.Backend.SSHTest do
  use ExUnit.Case, async: true

  alias TermUI.Backend.SSH

  # Helper: init SSH backend with a StringIO device to capture output
  defp init_ssh(opts \\ []) do
    {:ok, device} = StringIO.open("")
    opts = Keyword.put_new(opts, :device, device)
    {:ok, state} = SSH.init(opts)
    {state, device}
  end

  # Helper: read all output written to the StringIO device
  defp device_output(device) do
    {_input, output} = StringIO.contents(device)
    output
  end

  # ===========================================================================
  # Module Structure
  # ===========================================================================

  describe "behaviour declaration" do
    test "module declares @behaviour TermUI.Backend" do
      behaviours = SSH.__info__(:attributes)[:behaviour] || []
      assert TermUI.Backend in behaviours
    end

    test "module compiles without warnings" do
      assert Code.ensure_loaded?(SSH)
    end
  end

  # ===========================================================================
  # State Struct
  # ===========================================================================

  describe "state struct defaults" do
    test "has device field with default nil" do
      state = %SSH{}
      assert state.device == nil
    end

    test "has size field with default {24, 80}" do
      state = %SSH{}
      assert state.size == {24, 80}
    end

    test "has cursor_visible field with default false" do
      state = %SSH{}
      assert state.cursor_visible == false
    end

    test "has cursor_position field with default nil" do
      state = %SSH{}
      assert state.cursor_position == nil
    end

    test "has alternate_screen field with default false" do
      state = %SSH{}
      assert state.alternate_screen == false
    end

    test "has mouse_mode field with default :none" do
      state = %SSH{}
      assert state.mouse_mode == :none
    end

    test "has current_style field with default nil" do
      state = %SSH{}
      assert state.current_style == nil
    end
  end

  # ===========================================================================
  # init/1
  # ===========================================================================

  describe "init/1" do
    test "returns {:ok, state} with device" do
      {state, _device} = init_ssh()
      assert %SSH{} = state
    end

    test "stores device in state" do
      {:ok, device} = StringIO.open("")
      {:ok, state} = SSH.init(device: device)
      assert state.device == device
    end

    test "stores custom size" do
      {state, _device} = init_ssh(size: {50, 120})
      assert state.size == {50, 120}
    end

    test "defaults size to {24, 80}" do
      {state, _device} = init_ssh()
      assert state.size == {24, 80}
    end

    test "raises on missing device" do
      assert_raise KeyError, fn ->
        SSH.init([])
      end
    end

    test "enters alternate screen by default" do
      {state, device} = init_ssh()
      assert state.alternate_screen == true
      assert device_output(device) =~ "\e[?1049h"
    end

    test "skips alternate screen when disabled" do
      {state, device} = init_ssh(alternate_screen: false)
      assert state.alternate_screen == false
      refute device_output(device) =~ "\e[?1049h"
    end

    test "hides cursor by default" do
      {_state, device} = init_ssh()
      assert device_output(device) =~ "\e[?25l"
    end

    test "skips hiding cursor when disabled" do
      {state, device} = init_ssh(hide_cursor: false)
      assert state.cursor_visible == true
      refute device_output(device) =~ "\e[?25l"
    end

    test "clears screen on init" do
      {_state, device} = init_ssh()
      output = device_output(device)
      assert output =~ "\e[2J"
      assert output =~ "\e[H"
    end

    test "disables autowrap on init" do
      {_state, device} = init_ssh()
      assert device_output(device) =~ "\e[?7l"
    end

    test "enables mouse tracking when requested" do
      {state, device} = init_ssh(mouse_tracking: :click)
      assert state.mouse_mode == :click
      assert device_output(device) =~ "\e[?1000h"
    end

    test "no mouse tracking by default" do
      {state, _device} = init_ssh()
      assert state.mouse_mode == :none
    end
  end

  # ===========================================================================
  # shutdown/1
  # ===========================================================================

  describe "shutdown/1" do
    test "returns :ok" do
      {state, _device} = init_ssh()
      assert :ok = SSH.shutdown(state)
    end

    test "shows cursor on shutdown" do
      {state, device} = init_ssh()
      # Clear init output
      StringIO.contents(device)
      SSH.shutdown(state)
      {_input, output} = StringIO.contents(device)
      assert output =~ "\e[?25h"
    end

    test "leaves alternate screen on shutdown" do
      {state, device} = init_ssh()
      SSH.shutdown(state)
      {_input, output} = StringIO.contents(device)
      assert output =~ "\e[?1049l"
    end

    test "resets attributes on shutdown" do
      {state, device} = init_ssh()
      SSH.shutdown(state)
      {_input, output} = StringIO.contents(device)
      assert output =~ "\e[0m"
    end

    test "disables mouse tracking on shutdown" do
      {state, device} = init_ssh(mouse_tracking: :all)
      SSH.shutdown(state)
      {_input, output} = StringIO.contents(device)
      assert output =~ "\e[?1000l"
    end

    test "restores autowrap on shutdown" do
      {state, device} = init_ssh()
      SSH.shutdown(state)
      assert device_output(device) =~ "\e[?7h"
    end

    test "handles closed device gracefully" do
      {state, device} = init_ssh()
      StringIO.close(device)
      # Should not raise
      assert :ok = SSH.shutdown(state)
    end
  end

  # ===========================================================================
  # size/1
  # ===========================================================================

  describe "size/1" do
    test "returns cached size" do
      {state, _device} = init_ssh(size: {40, 160})
      assert {:ok, {40, 160}} = SSH.size(state)
    end

    test "returns default size" do
      {state, _device} = init_ssh()
      assert {:ok, {24, 80}} = SSH.size(state)
    end
  end

  # ===========================================================================
  # update_size/3
  # ===========================================================================

  describe "update_size/3" do
    test "updates size in state" do
      {state, _device} = init_ssh()
      {:ok, new_state} = SSH.update_size(state, 50, 120)
      assert {:ok, {50, 120}} = SSH.size(new_state)
    end

    test "rejects zero rows" do
      {state, _device} = init_ssh()

      assert_raise FunctionClauseError, fn ->
        SSH.update_size(state, 0, 80)
      end
    end

    test "rejects zero cols" do
      {state, _device} = init_ssh()

      assert_raise FunctionClauseError, fn ->
        SSH.update_size(state, 24, 0)
      end
    end

    test "rejects negative dimensions" do
      {state, _device} = init_ssh()

      assert_raise FunctionClauseError, fn ->
        SSH.update_size(state, -1, 80)
      end
    end
  end

  # ===========================================================================
  # Cursor operations
  # ===========================================================================

  describe "move_cursor/2" do
    test "writes cursor position sequence" do
      {state, device} = init_ssh()
      {:ok, _state} = SSH.move_cursor(state, {5, 10})
      assert device_output(device) =~ "\e[5;10H"
    end

    test "updates cursor_position in state" do
      {state, _device} = init_ssh()
      {:ok, state} = SSH.move_cursor(state, {5, 10})
      assert state.cursor_position == {5, 10}
    end

    test "clamps row to terminal bounds" do
      {state, _device} = init_ssh(size: {24, 80})
      {:ok, state} = SSH.move_cursor(state, {100, 10})
      assert state.cursor_position == {24, 10}
    end

    test "clamps col to terminal bounds" do
      {state, _device} = init_ssh(size: {24, 80})
      {:ok, state} = SSH.move_cursor(state, {5, 200})
      assert state.cursor_position == {5, 80}
    end

    test "clamps minimum to 1" do
      {state, _device} = init_ssh()
      {:ok, state} = SSH.move_cursor(state, {0, 0})
      assert state.cursor_position == {1, 1}
    end
  end

  describe "hide_cursor/1" do
    test "writes hide sequence" do
      {state, _device} = init_ssh(hide_cursor: false)
      {:ok, device} = StringIO.open("")
      state = %{state | device: device}
      {:ok, state} = SSH.hide_cursor(state)
      assert device_output(device) =~ "\e[?25l"
      assert state.cursor_visible == false
    end

    test "no-op when already hidden" do
      {state, _device} = init_ssh()
      {:ok, device} = StringIO.open("")
      state = %{state | device: device, cursor_visible: false}
      {:ok, _state} = SSH.hide_cursor(state)
      assert device_output(device) == ""
    end
  end

  describe "show_cursor/1" do
    test "writes show sequence" do
      {state, _device} = init_ssh()
      {:ok, device} = StringIO.open("")
      state = %{state | device: device, cursor_visible: false}
      {:ok, state} = SSH.show_cursor(state)
      assert device_output(device) =~ "\e[?25h"
      assert state.cursor_visible == true
    end

    test "no-op when already visible" do
      {state, _device} = init_ssh(hide_cursor: false)
      {:ok, device} = StringIO.open("")
      state = %{state | device: device, cursor_visible: true}
      {:ok, _state} = SSH.show_cursor(state)
      assert device_output(device) == ""
    end
  end

  # ===========================================================================
  # Rendering
  # ===========================================================================

  describe "clear/1" do
    test "writes clear and home sequences" do
      {state, device} = init_ssh()
      {:ok, _state} = SSH.clear(state)
      output = device_output(device)
      # clear appears at init and again on clear call
      assert String.contains?(output, "\e[2J\e[H")
    end

    test "resets cursor position" do
      {state, _device} = init_ssh()
      {:ok, state} = SSH.move_cursor(state, {10, 20})
      {:ok, state} = SSH.clear(state)
      assert state.cursor_position == {1, 1}
    end

    test "resets style state" do
      {state, _device} = init_ssh()
      state = %{state | current_style: %{fg: :red, bg: :default, attrs: []}}
      {:ok, state} = SSH.clear(state)
      assert state.current_style == nil
    end
  end

  describe "draw_cells/2" do
    test "returns {:ok, state} for empty cells" do
      {state, _device} = init_ssh()
      assert {:ok, %SSH{}} = SSH.draw_cells(state, [])
    end

    test "writes character to device" do
      {state, _device} = init_ssh()
      {:ok, device} = StringIO.open("")
      state = %{state | device: device}

      cells = [{{1, 1}, {"A", :default, :default, []}}]
      {:ok, _state} = SSH.draw_cells(state, cells)

      output = device_output(device)
      assert output =~ "A"
    end

    test "writes cursor position for first cell" do
      {state, _device} = init_ssh()
      {:ok, device} = StringIO.open("")
      state = %{state | device: device}

      cells = [{{3, 5}, {"X", :default, :default, []}}]
      {:ok, _state} = SSH.draw_cells(state, cells)

      output = device_output(device)
      assert output =~ "\e[3;5H"
    end

    test "draws multiple cells" do
      {state, _device} = init_ssh()
      {:ok, device} = StringIO.open("")
      state = %{state | device: device}

      cells = [
        {{1, 1}, {"H", :default, :default, []}},
        {{1, 2}, {"i", :default, :default, []}}
      ]

      {:ok, _state} = SSH.draw_cells(state, cells)

      output = device_output(device)
      assert output =~ "H"
      assert output =~ "i"
    end

    test "moves the cursor across a gap between cells" do
      {state, _device} = init_ssh()
      {:ok, device} = StringIO.open("")
      state = %{state | device: device}

      cells = [
        {{1, 1}, {"A", :default, :default, []}},
        {{1, 3}, {"B", :default, :default, []}}
      ]

      {:ok, _state} = SSH.draw_cells(state, cells)

      assert device_output(device) =~ "\e[1;3H"
    end

    test "tracks display width for wide graphemes" do
      {state, _device} = init_ssh()
      {:ok, device} = StringIO.open("")
      state = %{state | device: device}

      {:ok, state} =
        SSH.draw_cells(state, [{{1, 1}, {"界", :default, :default, []}}])

      assert state.cursor_position == {1, 3}
    end

    test "emits SGR for colored text" do
      {state, _device} = init_ssh()
      {:ok, device} = StringIO.open("")
      state = %{state | device: device}

      cells = [{{1, 1}, {"R", {255, 0, 0}, :default, []}}]
      {:ok, _state} = SSH.draw_cells(state, cells)

      output = device_output(device)
      # Should contain RGB foreground sequence
      assert output =~ "\e[38;2;255;0;0m"
    end

    test "emits bold attribute" do
      {state, _device} = init_ssh()
      {:ok, device} = StringIO.open("")
      state = %{state | device: device}

      cells = [{{1, 1}, {"B", :default, :default, [:bold]}}]
      {:ok, _state} = SSH.draw_cells(state, cells)

      output = device_output(device)
      assert output =~ "\e[1m"
    end

    test "tracks cursor position after draw" do
      {state, _device} = init_ssh()
      {:ok, device} = StringIO.open("")
      state = %{state | device: device}

      cells = [{{5, 10}, {"Z", :default, :default, []}}]
      {:ok, state} = SSH.draw_cells(state, cells)

      # After drawing "Z" at {5, 10}, cursor should be at {5, 11}
      assert state.cursor_position == {5, 11}
    end

    test "style delta skips unchanged style" do
      {state, _device} = init_ssh()
      {:ok, device} = StringIO.open("")
      state = %{state | device: device}

      # First draw sets the style
      cells = [{{1, 1}, {"A", :default, :default, []}}]
      {:ok, state} = SSH.draw_cells(state, cells)

      # Clear the device and draw again with same style
      {:ok, device2} = StringIO.open("")
      state = %{state | device: device2}
      cells = [{{1, 2}, {"B", :default, :default, []}}]
      {:ok, _state} = SSH.draw_cells(state, cells)

      output = device_output(device2)
      # Should NOT contain a reset since style is unchanged
      refute output =~ "\e[0m"
    end

    test "sanitizes empty string to space" do
      {state, _device} = init_ssh()
      {:ok, device} = StringIO.open("")
      state = %{state | device: device}

      cells = [{{1, 1}, {"", :default, :default, []}}]
      {:ok, _state} = SSH.draw_cells(state, cells)

      output = device_output(device)
      assert output =~ " "
    end

    test "sanitizes control characters" do
      {state, _device} = init_ssh()
      {:ok, device} = StringIO.open("")
      state = %{state | device: device}

      {:ok, _state} = SSH.draw_cells(state, [{{1, 1}, {"\n", :default, :default, []}}])

      output = device_output(device)
      refute output =~ "\n"
      assert output =~ " "
    end
  end

  describe "flush/1" do
    test "returns {:ok, state}" do
      {state, _device} = init_ssh()
      assert {:ok, %SSH{}} = SSH.flush(state)
    end

    test "does not modify state" do
      {state, _device} = init_ssh()
      {:ok, new_state} = SSH.flush(state)
      assert state == new_state
    end
  end

  # ===========================================================================
  # Input
  # ===========================================================================

  describe "poll_event/2" do
    test "returns {:timeout, state}" do
      {state, _device} = init_ssh()
      assert {:timeout, %SSH{}} = SSH.poll_event(state, 100)
    end

    test "does not modify state" do
      {state, _device} = init_ssh()
      {:timeout, new_state} = SSH.poll_event(state, 100)
      assert state == new_state
    end
  end

  # ===========================================================================
  # Mouse Tracking
  # ===========================================================================

  describe "mouse tracking modes" do
    test "click mode enables normal + SGR tracking" do
      {state, device} = init_ssh(mouse_tracking: :click)
      assert state.mouse_mode == :click
      output = device_output(device)
      assert output =~ "\e[?1000h"
      assert output =~ "\e[?1006h"
    end

    test "drag mode enables button + SGR tracking" do
      {state, device} = init_ssh(mouse_tracking: :drag)
      assert state.mouse_mode == :drag
      output = device_output(device)
      assert output =~ "\e[?1002h"
      assert output =~ "\e[?1006h"
    end

    test "all mode enables any-event + SGR tracking" do
      {state, device} = init_ssh(mouse_tracking: :all)
      assert state.mouse_mode == :all
      output = device_output(device)
      assert output =~ "\e[?1003h"
      assert output =~ "\e[?1006h"
    end
  end
end
