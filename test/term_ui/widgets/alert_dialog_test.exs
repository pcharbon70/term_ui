defmodule TermUI.Widgets.AlertDialogTest do
  use ExUnit.Case, async: true

  alias TermUI.Widgets.AlertDialog
  alias TermUI.Event

  describe "new/1" do
    test "creates alert with required fields" do
      props = AlertDialog.new(
        type: :info,
        title: "Information",
        message: "This is an info message"
      )

      assert props.type == :info
      assert props.title == "Information"
      assert props.message == "This is an info message"
      assert props.icon == "ℹ"
    end

    test "creates alert with correct buttons for info type" do
      props = AlertDialog.new(
        type: :info,
        title: "Info",
        message: "Message"
      )

      assert length(props.buttons) == 1
      assert hd(props.buttons).id == :ok
    end

    test "creates alert with correct buttons for confirm type" do
      props = AlertDialog.new(
        type: :confirm,
        title: "Confirm",
        message: "Are you sure?"
      )

      assert length(props.buttons) == 2
      button_ids = Enum.map(props.buttons, & &1.id)
      assert :yes in button_ids
      assert :no in button_ids
    end

    test "creates alert with correct buttons for ok_cancel type" do
      props = AlertDialog.new(
        type: :ok_cancel,
        title: "Save",
        message: "Save changes?"
      )

      assert length(props.buttons) == 2
      button_ids = Enum.map(props.buttons, & &1.id)
      assert :ok in button_ids
      assert :cancel in button_ids
    end

    test "uses correct icons for each type" do
      types_and_icons = [
        {:info, "ℹ"},
        {:success, "✓"},
        {:warning, "⚠"},
        {:error, "✗"},
        {:confirm, "?"}
      ]

      for {type, expected_icon} <- types_and_icons do
        props = AlertDialog.new(type: type, title: "T", message: "M")
        assert props.icon == expected_icon, "Expected #{expected_icon} for #{type}"
      end
    end
  end

  describe "init/1" do
    test "initializes alert state" do
      props = AlertDialog.new(type: :info, title: "Info", message: "Test")
      {:ok, state} = AlertDialog.init(props)

      assert state.alert_type == :info
      assert state.title == "Info"
      assert state.message == "Test"
      assert state.visible == true
    end

    test "focuses default button" do
      props = AlertDialog.new(type: :confirm, title: "Confirm", message: "?")
      {:ok, state} = AlertDialog.init(props)

      # Yes is default for confirm
      assert state.focused_button == :yes
    end
  end

  describe "keyboard navigation" do
    setup do
      props = AlertDialog.new(type: :confirm, title: "Confirm", message: "?")
      {:ok, state} = AlertDialog.init(props)
      %{state: state}
    end

    test "tab moves focus between buttons", %{state: state} do
      event = %Event.Key{key: :tab, modifiers: []}
      {:ok, new_state} = AlertDialog.handle_event(event, state)

      assert new_state.focused_button == :no
    end

    test "enter activates focused button", %{state: state} do
      on_result = fn result -> send(self(), {:result, result}) end
      state = %{state | on_result: on_result}

      event = %Event.Key{key: :enter}
      {:ok, _state} = AlertDialog.handle_event(event, state)

      assert_receive {:result, :yes}
    end

    test "escape returns no for confirm dialogs", %{state: state} do
      on_result = fn result -> send(self(), {:result, result}) end
      state = %{state | on_result: on_result}

      event = %Event.Key{key: :escape}
      {:ok, new_state} = AlertDialog.handle_event(event, state)

      assert_receive {:result, :no}
      assert not AlertDialog.visible?(new_state)
    end

    test "escape returns cancel for ok_cancel dialogs" do
      props = AlertDialog.new(type: :ok_cancel, title: "T", message: "M")
      {:ok, state} = AlertDialog.init(props)

      on_result = fn result -> send(self(), {:result, result}) end
      state = %{state | on_result: on_result}

      event = %Event.Key{key: :escape}
      {:ok, _state} = AlertDialog.handle_event(event, state)

      assert_receive {:result, :cancel}
    end

    test "y key activates yes in confirm dialog", %{state: state} do
      on_result = fn result -> send(self(), {:result, result}) end
      state = %{state | on_result: on_result}

      event = %Event.Key{key: "y"}
      {:ok, _state} = AlertDialog.handle_event(event, state)

      assert_receive {:result, :yes}
    end

    test "n key activates no in confirm dialog", %{state: state} do
      on_result = fn result -> send(self(), {:result, result}) end
      state = %{state | on_result: on_result}

      event = %Event.Key{key: "n"}
      {:ok, _state} = AlertDialog.handle_event(event, state)

      assert_receive {:result, :no}
    end
  end

  describe "public API" do
    setup do
      props = AlertDialog.new(type: :info, title: "Info", message: "Test")
      {:ok, state} = AlertDialog.init(props)
      %{state: state}
    end

    test "visible? returns visibility state", %{state: state} do
      assert AlertDialog.visible?(state)
    end

    test "show makes alert visible", %{state: state} do
      state = %{state | visible: false}
      state = AlertDialog.show(state)

      assert AlertDialog.visible?(state)
    end

    test "hide makes alert invisible", %{state: state} do
      state = AlertDialog.hide(state)

      assert not AlertDialog.visible?(state)
    end

    test "get_type returns alert type", %{state: state} do
      assert AlertDialog.get_type(state) == :info
    end

    test "get_focused_button returns focused button", %{state: state} do
      assert AlertDialog.get_focused_button(state) == :ok
    end

    test "set_message updates message", %{state: state} do
      state = AlertDialog.set_message(state, "New message")

      assert state.message == "New message"
    end
  end

  describe "render" do
    test "renders alert as overlay" do
      props = AlertDialog.new(type: :info, title: "Info", message: "Test")
      {:ok, state} = AlertDialog.init(props)
      area = %{x: 0, y: 0, width: 80, height: 24}

      result = AlertDialog.render(state, area)

      assert result.type == :overlay
      assert result.z == 100
    end

    test "renders empty when not visible" do
      props = AlertDialog.new(type: :info, title: "Info", message: "Test")
      {:ok, state} = AlertDialog.init(props)
      state = AlertDialog.hide(state)
      area = %{x: 0, y: 0, width: 80, height: 24}

      result = AlertDialog.render(state, area)

      assert result.type == :empty
    end

    test "positions alert centered" do
      props = AlertDialog.new(type: :info, title: "Info", message: "Test", width: 50)
      {:ok, state} = AlertDialog.init(props)
      area = %{x: 0, y: 0, width: 80, height: 24}

      result = AlertDialog.render(state, area)

      # Centered: (80 - 50) / 2 = 15
      assert result.x == 15
    end
  end
end
