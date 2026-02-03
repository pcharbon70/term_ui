defmodule TermUI.Widgets.AlertDialogTest do
  use ExUnit.Case, async: true

  alias TermUI.Event
  alias TermUI.PersistentTerms
  alias TermUI.Widgets.AlertDialog

  describe "new/1" do
    test "creates alert with required fields" do
      props =
        AlertDialog.new(
          type: :info,
          title: "Information",
          message: "This is an info message"
        )

      assert props.type == :info
      assert props.title == "Information"
      assert props.message == "This is an info message"
      assert props.icon_key == :info
    end

    test "creates alert with correct buttons for info type" do
      props =
        AlertDialog.new(
          type: :info,
          title: "Info",
          message: "Message"
        )

      assert length(props.buttons) == 1
      assert hd(props.buttons).id == :ok
    end

    test "creates alert with correct buttons for confirm type" do
      props =
        AlertDialog.new(
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
      props =
        AlertDialog.new(
          type: :ok_cancel,
          title: "Save",
          message: "Save changes?"
        )

      assert length(props.buttons) == 2
      button_ids = Enum.map(props.buttons, & &1.id)
      assert :ok in button_ids
      assert :cancel in button_ids
    end

    test "uses correct icon_keys for each type" do
      types_and_icon_keys = [
        {:info, :info},
        {:success, :check},
        {:warning, :warning},
        {:error, :cross_mark},
        {:confirm, :literal_question}
      ]

      for {type, expected_icon_key} <- types_and_icon_keys do
        props = AlertDialog.new(type: type, title: "T", message: "M")
        assert props.icon_key == expected_icon_key, "Expected #{expected_icon_key} for #{type}"
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

  describe "mouse support" do
    setup do
      # Store and restore backend mode
      original_mode = PersistentTerms.backend_mode()
      :persistent_term.put(:term_ui_backend_mode, :raw)

      on_exit(fn ->
        if original_mode do
          :persistent_term.put(:term_ui_backend_mode, original_mode)
        else
          :persistent_term.erase(:term_ui_backend_mode)
        end
      end)

      :ok
    end

    test "mouse click activates button in raw mode" do
      props = AlertDialog.new(type: :ok_cancel, title: "Test", message: "Message")
      {:ok, state} = AlertDialog.init(props)

      # Set terminal area for accurate button click detection
      state = AlertDialog.update_area(state, %{width: 80, height: 24})

      on_result = fn result -> send(self(), {:result, result}) end
      state = %{state | on_result: on_result}

      # Calculate expected button positions
      # Dialog: default width=50, height=7 (6+1 message line)
      # Dialog x = (80-50)/2 = 15, dialog y = (24-7)/2 = 8
      # Button row in dialog = 4+1 = 5, so button_y = 8+5 = 13
      # Button order: Cancel, OK (OK is default/focused)
      # Cancel (non-focused): "  Cancel  " (10 chars)
      # OK (focused): "[ OK ]" (6 chars)
      # Buttons joined: "  Cancel    [ OK ]" (17 chars with space between)
      # inner_width = 46, left_pad = div(46-17, 2) = 14
      # buttons_start_x = 15 + 2 + 14 = 31
      # Cancel button at x=31, width=10 (positions 31-40)
      # OK button at x=42, width=6 (positions 42-47)

      # Click on OK button (x=43, y=13)
      event = %Event.Mouse{action: :press, button: :left, x: 43, y: 13}
      {:ok, _state} = AlertDialog.handle_event(event, state)

      assert_receive {:result, :ok}
    end

    test "mouse click is ignored in TTY mode" do
      props = AlertDialog.new(type: :ok_cancel, title: "Test", message: "Message")
      {:ok, state} = AlertDialog.init(props)

      # Set terminal area for accurate button click detection
      state = AlertDialog.update_area(state, %{width: 80, height: 24})

      # Set to TTY mode
      :persistent_term.put(:term_ui_backend_mode, :tty)

      on_result = fn result -> send(self(), {:result, result}) end
      state = %{state | on_result: on_result}

      # Click on button position (OK button at x=43, y=13)
      event = %Event.Mouse{action: :press, button: :left, x: 43, y: 13}
      {:ok, _state} = AlertDialog.handle_event(event, state)

      # Should not receive result
      refute_receive {:result, _}, 100
    end

    test "click outside button bounds does nothing" do
      props = AlertDialog.new(type: :ok_cancel, title: "Test", message: "Message")
      {:ok, state} = AlertDialog.init(props)

      # Set terminal area for accurate button click detection
      state = AlertDialog.update_area(state, %{width: 80, height: 24})

      on_result = fn result -> send(self(), {:result, result}) end
      state = %{state | on_result: on_result}

      # Click far outside the dialog
      event = %Event.Mouse{action: :press, button: :left, x: 0, y: 0}
      {:ok, _state} = AlertDialog.handle_event(event, state)

      # Should not receive result
      refute_receive {:result, _}, 100
    end

    test "click on wrong row does nothing" do
      props = AlertDialog.new(type: :ok_cancel, title: "Test", message: "Message")
      {:ok, state} = AlertDialog.init(props)

      # Set terminal area for accurate button click detection
      state = AlertDialog.update_area(state, %{width: 80, height: 24})

      on_result = fn result -> send(self(), {:result, result}) end
      state = %{state | on_result: on_result}

      # Click on button x but wrong y
      event = %Event.Mouse{action: :press, button: :left, x: 33, y: 10}
      {:ok, _state} = AlertDialog.handle_event(event, state)

      # Should not receive result
      refute_receive {:result, _}, 100
    end
  end
end
