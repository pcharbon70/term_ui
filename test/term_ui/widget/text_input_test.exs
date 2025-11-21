defmodule TermUI.Widget.TextInputTest do
  use ExUnit.Case, async: true

  alias TermUI.Widget.TextInput
  alias TermUI.Component.RenderNode
  alias TermUI.Event

  @area %{x: 0, y: 0, width: 20, height: 1}

  describe "init/1" do
    test "initializes with empty value" do
      {:ok, state} = TextInput.init(%{})

      assert state.value == ""
      assert state.cursor == 0
      assert state.scroll_offset == 0
    end

    test "initializes with provided value" do
      {:ok, state} = TextInput.init(%{value: "Hello"})

      assert state.value == "Hello"
      assert state.cursor == 5  # at end
    end

    test "stores props in state" do
      props = %{placeholder: "Enter..."}
      {:ok, state} = TextInput.init(props)
      assert state.props == props
    end
  end

  describe "handle_event/2 cursor movement" do
    test "left arrow moves cursor left" do
      {:ok, state} = TextInput.init(%{value: "Hello"})
      {:ok, new_state} = TextInput.handle_event(%Event.Key{key: :left}, state)

      assert new_state.cursor == 4
    end

    test "left arrow stops at beginning" do
      {:ok, state} = TextInput.init(%{value: "Hello"})
      state = %{state | cursor: 0}
      {:ok, new_state} = TextInput.handle_event(%Event.Key{key: :left}, state)

      assert new_state.cursor == 0
    end

    test "right arrow moves cursor right" do
      {:ok, state} = TextInput.init(%{value: "Hello"})
      state = %{state | cursor: 2}
      {:ok, new_state} = TextInput.handle_event(%Event.Key{key: :right}, state)

      assert new_state.cursor == 3
    end

    test "right arrow stops at end" do
      {:ok, state} = TextInput.init(%{value: "Hello"})
      {:ok, new_state} = TextInput.handle_event(%Event.Key{key: :right}, state)

      assert new_state.cursor == 5
    end

    test "home moves cursor to beginning" do
      {:ok, state} = TextInput.init(%{value: "Hello"})
      {:ok, new_state} = TextInput.handle_event(%Event.Key{key: :home}, state)

      assert new_state.cursor == 0
    end

    test "end moves cursor to end" do
      {:ok, state} = TextInput.init(%{value: "Hello"})
      state = %{state | cursor: 2}
      {:ok, new_state} = TextInput.handle_event(%Event.Key{key: :end}, state)

      assert new_state.cursor == 5
    end
  end

  describe "handle_event/2 editing" do
    test "backspace deletes character before cursor" do
      {:ok, state} = TextInput.init(%{value: "Hello"})
      {:ok, new_state, commands} = TextInput.handle_event(%Event.Key{key: :backspace}, state)

      assert new_state.value == "Hell"
      assert new_state.cursor == 4
      assert [{:send, _pid, {:changed, "Hell"}}] = commands
    end

    test "backspace at beginning does nothing" do
      {:ok, state} = TextInput.init(%{value: "Hello"})
      state = %{state | cursor: 0}
      {:ok, new_state} = TextInput.handle_event(%Event.Key{key: :backspace}, state)

      assert new_state.value == "Hello"
    end

    test "delete removes character after cursor" do
      {:ok, state} = TextInput.init(%{value: "Hello"})
      state = %{state | cursor: 0}
      {:ok, new_state, commands} = TextInput.handle_event(%Event.Key{key: :delete}, state)

      assert new_state.value == "ello"
      assert new_state.cursor == 0
      assert [{:send, _pid, {:changed, "ello"}}] = commands
    end

    test "delete at end does nothing" do
      {:ok, state} = TextInput.init(%{value: "Hello"})
      {:ok, new_state} = TextInput.handle_event(%Event.Key{key: :delete}, state)

      assert new_state.value == "Hello"
    end

    test "character input inserts at cursor" do
      {:ok, state} = TextInput.init(%{value: "Hllo"})
      state = %{state | cursor: 1}
      {:ok, new_state, commands} = TextInput.handle_event(%Event.Key{char: "e"}, state)

      assert new_state.value == "Hello"
      assert new_state.cursor == 2
      assert [{:send, _pid, {:changed, "Hello"}}] = commands
    end

    test "enter triggers submit command" do
      {:ok, state} = TextInput.init(%{value: "Hello"})
      {:ok, _state, commands} = TextInput.handle_event(%Event.Key{key: :enter}, state)

      assert [{:send, _pid, {:submit, "Hello"}}] = commands
    end
  end

  describe "handle_info/2" do
    test "changed message invokes on_change callback" do
      test_pid = self()
      callback = fn value -> send(test_pid, {:changed, value}) end
      props = %{on_change: callback}
      {:ok, state} = TextInput.init(props)

      {:ok, _state} = TextInput.handle_info({:changed, "New"}, state)
      assert_receive {:changed, "New"}
    end

    test "changed message enforces max_length" do
      props = %{max_length: 5}
      {:ok, state} = TextInput.init(props)
      state = %{state | cursor: 10}

      {:ok, new_state} = TextInput.handle_info({:changed, "TooLongValue"}, state)
      assert new_state.value == "TooLo"
      assert new_state.cursor == 5  # adjusted to end
    end

    test "submit message invokes on_submit callback" do
      test_pid = self()
      callback = fn value -> send(test_pid, {:submitted, value}) end
      props = %{on_submit: callback}
      {:ok, state} = TextInput.init(props)

      {:ok, _state} = TextInput.handle_info({:submit, "Hello"}, state)
      assert_receive {:submitted, "Hello"}
    end

    test "set_value updates value and cursor" do
      {:ok, state} = TextInput.init(%{})
      {:ok, new_state} = TextInput.handle_info({:set_value, "New value"}, state)

      assert new_state.value == "New value"
      assert new_state.cursor == 9
    end
  end

  describe "render/2" do
    test "renders value" do
      props = %{value: "Hello"}
      {:ok, state} = TextInput.init(props)
      result = TextInput.render(state, @area)

      assert %RenderNode{type: :cells, cells: cells} = result
      chars = Enum.map(Enum.take(cells, 5), fn c -> c.cell.char end)
      assert chars == ["H", "e", "l", "l", "o"]
    end

    test "renders placeholder when empty" do
      props = %{placeholder: "Enter name..."}
      {:ok, state} = TextInput.init(props)
      result = TextInput.render(state, @area)

      assert %RenderNode{type: :cells, cells: cells} = result
      chars = Enum.map(cells, fn c -> c.cell.char end) |> Enum.join() |> String.trim()
      assert String.starts_with?(chars, "Enter name...")

      # Placeholder should be gray
      first_cell = hd(cells)
      assert first_cell.cell.fg == :bright_black
    end

    test "shows cursor with inverted style" do
      props = %{value: "Hello", cursor_style: %{bg: :white, fg: :black}}
      {:ok, state} = TextInput.init(props)
      state = %{state | cursor: 2}  # cursor at 'l'
      result = TextInput.render(state, @area)

      assert %RenderNode{type: :cells, cells: cells} = result
      cursor_cell = Enum.at(cells, 2)
      assert cursor_cell.cell.fg == :black
      assert cursor_cell.cell.bg == :white
    end

    test "applies custom style" do
      props = %{value: "Hello", style: %{fg: :blue}}
      {:ok, state} = TextInput.init(props)
      result = TextInput.render(state, @area)

      assert %RenderNode{type: :cells, cells: cells} = result
      # Non-cursor cells should have custom style
      first_cell = hd(cells)
      assert first_cell.cell.fg == :blue
    end

    test "pads to area width" do
      props = %{value: "Hi"}
      {:ok, state} = TextInput.init(props)
      result = TextInput.render(state, @area)

      assert %RenderNode{type: :cells, cells: cells} = result
      assert length(cells) == 20
    end

    test "scrolls when cursor exceeds visible area" do
      props = %{value: "This is a very long text input value"}
      {:ok, state} = TextInput.init(props)
      # cursor at end (36), area width is 20
      result = TextInput.render(state, @area)

      assert %RenderNode{type: :cells, cells: cells} = result
      # Should show end of string
      chars = Enum.map(cells, fn c -> c.cell.char end) |> Enum.join() |> String.trim()
      assert String.ends_with?(chars, "value")
    end

    test "scrolls left when cursor moves before visible area" do
      props = %{value: "Long text that was scrolled"}
      {:ok, state} = TextInput.init(props)
      state = %{state | cursor: 0, scroll_offset: 10}
      result = TextInput.render(state, @area)

      assert %RenderNode{type: :cells, cells: cells} = result
      # Should show beginning
      chars = Enum.map(cells, fn c -> c.cell.char end) |> Enum.join() |> String.trim()
      assert String.starts_with?(chars, "Long")
    end

    test "no cursor shown on placeholder" do
      props = %{placeholder: "Type here..."}
      {:ok, state} = TextInput.init(props)
      result = TextInput.render(state, @area)

      assert %RenderNode{type: :cells, cells: cells} = result
      # All cells should have placeholder style (gray), no inverted cursor
      assert Enum.all?(cells, fn c -> c.cell.fg == :bright_black end)
    end
  end
end
