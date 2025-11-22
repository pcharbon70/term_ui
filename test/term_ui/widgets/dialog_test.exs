defmodule TermUI.Widgets.DialogTest do
  use ExUnit.Case, async: true

  alias TermUI.Widgets.Dialog
  alias TermUI.Event

  describe "new/1" do
    test "creates dialog props with required fields" do
      props = Dialog.new(title: "Test Dialog")

      assert props.title == "Test Dialog"
      assert props.width == 40
      assert props.closeable == true
      assert length(props.buttons) == 1
    end

    test "creates dialog with custom buttons" do
      buttons = [
        %{id: :cancel, label: "Cancel"},
        %{id: :ok, label: "OK"}
      ]

      props = Dialog.new(title: "Test", buttons: buttons)

      assert props.buttons == buttons
    end

    test "creates dialog with callbacks" do
      on_close = fn -> :ok end
      on_confirm = fn _ -> :ok end

      props = Dialog.new(
        title: "Test",
        on_close: on_close,
        on_confirm: on_confirm
      )

      assert props.on_close == on_close
      assert props.on_confirm == on_confirm
    end
  end

  describe "init/1" do
    test "initializes dialog state" do
      props = Dialog.new(title: "Test Dialog")
      {:ok, state} = Dialog.init(props)

      assert state.title == "Test Dialog"
      assert state.visible == true
      assert state.focused_button == :ok
    end

    test "focuses default button" do
      buttons = [
        %{id: :cancel, label: "Cancel"},
        %{id: :ok, label: "OK", default: true}
      ]

      props = Dialog.new(title: "Test", buttons: buttons)
      {:ok, state} = Dialog.init(props)

      assert state.focused_button == :ok
    end
  end

  describe "keyboard navigation" do
    setup do
      buttons = [
        %{id: :cancel, label: "Cancel"},
        %{id: :ok, label: "OK"}
      ]

      props = Dialog.new(title: "Test", buttons: buttons)
      {:ok, state} = Dialog.init(props)
      %{state: state}
    end

    test "tab moves focus forward", %{state: state} do
      event = %Event.Key{key: :tab, modifiers: []}
      {:ok, new_state} = Dialog.handle_event(event, state)

      assert new_state.focused_button == :ok
    end

    test "shift+tab moves focus backward", %{state: state} do
      state = %{state | focused_button: :ok}
      event = %Event.Key{key: :tab, modifiers: [:shift]}
      {:ok, new_state} = Dialog.handle_event(event, state)

      assert new_state.focused_button == :cancel
    end

    test "left arrow moves focus backward", %{state: state} do
      state = %{state | focused_button: :ok}
      event = %Event.Key{key: :left}
      {:ok, new_state} = Dialog.handle_event(event, state)

      assert new_state.focused_button == :cancel
    end

    test "right arrow moves focus forward", %{state: state} do
      event = %Event.Key{key: :right}
      {:ok, new_state} = Dialog.handle_event(event, state)

      assert new_state.focused_button == :ok
    end

    test "focus wraps around", %{state: state} do
      state = %{state | focused_button: :ok}
      event = %Event.Key{key: :right}
      {:ok, new_state} = Dialog.handle_event(event, state)

      assert new_state.focused_button == :cancel
    end

    test "enter activates focused button", %{state: state} do
      on_confirm = fn id -> send(self(), {:confirmed, id}) end
      state = %{state | on_confirm: on_confirm}

      event = %Event.Key{key: :enter}
      {:ok, _state} = Dialog.handle_event(event, state)

      assert_receive {:confirmed, :cancel}
    end

    test "space activates focused button", %{state: state} do
      on_confirm = fn id -> send(self(), {:confirmed, id}) end
      state = %{state | on_confirm: on_confirm}

      event = %Event.Key{key: " "}
      {:ok, _state} = Dialog.handle_event(event, state)

      assert_receive {:confirmed, :cancel}
    end
  end

  describe "escape handling" do
    setup do
      props = Dialog.new(title: "Test")
      {:ok, state} = Dialog.init(props)
      %{state: state}
    end

    test "escape closes dialog when closeable", %{state: state} do
      on_close = fn -> send(self(), :closed) end
      state = %{state | on_close: on_close}

      event = %Event.Key{key: :escape}
      {:ok, new_state} = Dialog.handle_event(event, state)

      assert_receive :closed
      assert not Dialog.visible?(new_state)
    end

    test "escape does nothing when not closeable", %{state: state} do
      state = %{state | closeable: false}

      event = %Event.Key{key: :escape}
      {:ok, new_state} = Dialog.handle_event(event, state)

      assert Dialog.visible?(new_state)
    end
  end

  describe "public API" do
    setup do
      props = Dialog.new(title: "Test")
      {:ok, state} = Dialog.init(props)
      %{state: state}
    end

    test "visible? returns visibility state", %{state: state} do
      assert Dialog.visible?(state)
    end

    test "show makes dialog visible", %{state: state} do
      state = %{state | visible: false}
      state = Dialog.show(state)

      assert Dialog.visible?(state)
    end

    test "hide makes dialog invisible", %{state: state} do
      state = Dialog.hide(state)

      assert not Dialog.visible?(state)
    end

    test "get_focused_button returns focused button", %{state: state} do
      assert Dialog.get_focused_button(state) == :ok
    end

    test "focus_button changes focus", %{state: state} do
      buttons = [
        %{id: :cancel, label: "Cancel"},
        %{id: :ok, label: "OK"}
      ]
      state = %{state | buttons: buttons}

      state = Dialog.focus_button(state, :cancel)

      assert state.focused_button == :cancel
    end

    test "focus_button ignores invalid button", %{state: state} do
      state = Dialog.focus_button(state, :invalid)

      assert state.focused_button == :ok
    end

    test "set_content updates content", %{state: state} do
      new_content = %{type: :text, content: "New content"}
      state = Dialog.set_content(state, new_content)

      assert state.content == new_content
    end

    test "set_title updates title", %{state: state} do
      state = Dialog.set_title(state, "New Title")

      assert state.title == "New Title"
    end
  end

  describe "render" do
    test "renders dialog as overlay" do
      props = Dialog.new(title: "Test Dialog")
      {:ok, state} = Dialog.init(props)
      area = %{x: 0, y: 0, width: 80, height: 24}

      result = Dialog.render(state, area)

      assert result.type == :overlay
      assert result.z == 100
    end

    test "renders empty when not visible" do
      props = Dialog.new(title: "Test")
      {:ok, state} = Dialog.init(props)
      state = Dialog.hide(state)
      area = %{x: 0, y: 0, width: 80, height: 24}

      result = Dialog.render(state, area)

      assert result.type == :empty
    end

    test "calculates centered position" do
      props = Dialog.new(title: "Test", width: 40)
      {:ok, state} = Dialog.init(props)
      area = %{x: 0, y: 0, width: 80, height: 24}

      result = Dialog.render(state, area)

      # Centered: (80 - 40) / 2 = 20
      assert result.dialog_x == 20
    end
  end
end
