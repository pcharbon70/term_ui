defmodule TermUI.Widget.ButtonTest do
  use ExUnit.Case, async: true

  alias TermUI.Component.RenderNode
  alias TermUI.Event
  alias TermUI.Widget.Button

  @area %{x: 0, y: 0, width: 20, height: 1}

  describe "init/1" do
    test "initializes with default values" do
      {:ok, state} = Button.init(%{})

      assert state.pressed == false
      assert state.hovered == false
      assert state.disabled == false
    end

    test "initializes disabled from props" do
      {:ok, state} = Button.init(%{disabled: true})
      assert state.disabled == true
    end

    test "stores props in state" do
      props = %{label: "Submit", on_click: fn -> :ok end}
      {:ok, state} = Button.init(props)
      assert state.props == props
    end
  end

  describe "handle_event/2 keyboard" do
    test "enter key triggers click when not disabled" do
      {:ok, state} = Button.init(%{})
      {:ok, new_state, commands} = Button.handle_event(%Event.Key{key: :enter}, state)

      assert new_state.pressed == true
      assert [{:send, _pid, :click}] = commands
    end

    test "space key triggers click when not disabled" do
      {:ok, state} = Button.init(%{})
      {:ok, new_state, commands} = Button.handle_event(%Event.Key{key: :space}, state)

      assert new_state.pressed == true
      assert [{:send, _pid, :click}] = commands
    end

    test "enter key does nothing when disabled" do
      {:ok, state} = Button.init(%{disabled: true})
      {:ok, new_state} = Button.handle_event(%Event.Key{key: :enter}, state)

      assert new_state.pressed == false
      assert new_state == state
    end

    test "ignores other keys" do
      {:ok, state} = Button.init(%{})
      {:ok, new_state} = Button.handle_event(%Event.Key{key: :up}, state)

      assert new_state == state
    end
  end

  describe "handle_event/2 mouse" do
    test "click triggers when not disabled" do
      {:ok, state} = Button.init(%{})
      {:ok, new_state, commands} = Button.handle_event(%Event.Mouse{action: :click}, state)

      assert new_state.pressed == true
      assert [{:send, _pid, :click}] = commands
    end

    test "click does nothing when disabled" do
      {:ok, state} = Button.init(%{disabled: true})
      {:ok, new_state} = Button.handle_event(%Event.Mouse{action: :click}, state)

      assert new_state == state
    end

    test "press sets pressed state" do
      {:ok, state} = Button.init(%{})
      {:ok, new_state} = Button.handle_event(%Event.Mouse{action: :press}, state)

      assert new_state.pressed == true
    end

    test "release clears pressed state" do
      {:ok, state} = Button.init(%{})
      state = %{state | pressed: true}
      {:ok, new_state} = Button.handle_event(%Event.Mouse{action: :release}, state)

      assert new_state.pressed == false
    end
  end

  describe "handle_event/2 focus" do
    test "focus gained does not change state" do
      {:ok, state} = Button.init(%{})
      {:ok, new_state} = Button.handle_event(%Event.Focus{action: :gained}, state)

      assert new_state == state
    end

    test "focus lost clears pressed state" do
      {:ok, state} = Button.init(%{})
      state = %{state | pressed: true}
      {:ok, new_state} = Button.handle_event(%Event.Focus{action: :lost}, state)

      assert new_state.pressed == false
    end
  end

  describe "handle_info/2" do
    test "click message invokes on_click callback" do
      test_pid = self()
      callback = fn -> send(test_pid, :clicked) end
      props = %{on_click: callback}
      {:ok, state} = Button.init(props)

      {:ok, new_state} = Button.handle_info(:click, state)

      assert_receive :clicked
      assert new_state.pressed == false
    end

    test "click message handles missing callback" do
      {:ok, state} = Button.init(%{})
      {:ok, new_state} = Button.handle_info(:click, state)

      assert new_state.pressed == false
    end

    test "ignores unknown messages" do
      {:ok, state} = Button.init(%{})
      {:ok, new_state} = Button.handle_info(:unknown, state)

      assert new_state == state
    end
  end

  describe "render/2" do
    test "renders centered label" do
      props = %{label: "OK"}
      {:ok, state} = Button.init(props)
      result = Button.render(state, @area)

      assert %RenderNode{type: :cells, cells: cells} = result
      assert length(cells) == 20

      # Find O and K positions - should be centered
      chars_with_pos = Enum.map(cells, fn c -> {c.x, c.cell.char} end)
      o_pos = Enum.find_value(chars_with_pos, fn {x, c} -> if c == "O", do: x end)
      k_pos = Enum.find_value(chars_with_pos, fn {x, c} -> if c == "K", do: x end)

      # "OK" centered in 20 chars: padding = 9
      assert o_pos == 9
      assert k_pos == 10
    end

    test "renders disabled button with gray text" do
      props = %{label: "Disabled", disabled: true}
      {:ok, state} = Button.init(props)
      result = Button.render(state, @area)

      assert %RenderNode{type: :cells, cells: cells} = result
      first_char = Enum.find(cells, fn c -> c.cell.char != " " end)
      assert first_char.cell.fg == :bright_black
    end

    test "applies pressed style when pressed" do
      props = %{label: "Press", pressed_style: %{fg: :black, bg: :white}}
      {:ok, state} = Button.init(props)
      state = %{state | pressed: true}
      result = Button.render(state, @area)

      assert %RenderNode{type: :cells, cells: cells} = result
      first_char = Enum.find(cells, fn c -> c.cell.char != " " end)
      assert first_char.cell.fg == :black
      assert first_char.cell.bg == :white
    end

    test "truncates long label to fit width" do
      props = %{label: "This is a very long button label"}
      {:ok, state} = Button.init(props)
      result = Button.render(state, @area)

      assert %RenderNode{type: :cells, cells: cells} = result
      assert length(cells) == 20
    end

    test "uses default label when not provided" do
      props = %{}
      {:ok, state} = Button.init(props)
      result = Button.render(state, @area)

      assert %RenderNode{type: :cells, cells: cells} = result
      chars = Enum.map(cells, & &1.cell.char)
      text = chars |> Enum.join() |> String.trim()
      assert text == "Button"
    end
  end
end
