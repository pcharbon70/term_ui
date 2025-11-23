defmodule TermUI.Widgets.ToastTest do
  use ExUnit.Case, async: true

  alias TermUI.Widgets.Toast
  alias TermUI.Widgets.ToastManager
  alias TermUI.Event

  describe "Toast.new/1" do
    test "creates toast with required fields" do
      props = Toast.new(message: "Test message")

      assert props.message == "Test message"
      assert props.type == :info
      assert props.duration == 3000
      assert props.position == :bottom_right
    end

    test "creates toast with custom type" do
      props = Toast.new(message: "Success!", type: :success)

      assert props.type == :success
      assert props.icon == "✓"
    end

    test "creates toast with custom duration" do
      props = Toast.new(message: "Test", duration: 5000)

      assert props.duration == 5000
    end

    test "creates toast with nil duration for no auto-dismiss" do
      props = Toast.new(message: "Test", duration: nil)

      assert props.duration == nil
    end

    test "creates toast with custom position" do
      props = Toast.new(message: "Test", position: :top_center)

      assert props.position == :top_center
    end

    test "uses correct icons for each type" do
      types_and_icons = [
        {:info, "ℹ"},
        {:success, "✓"},
        {:warning, "⚠"},
        {:error, "✗"}
      ]

      for {type, expected_icon} <- types_and_icons do
        props = Toast.new(message: "Test", type: type)
        assert props.icon == expected_icon
      end
    end
  end

  describe "Toast.init/1" do
    test "initializes toast state" do
      props = Toast.new(message: "Test message")
      {:ok, state} = Toast.init(props)

      assert state.message == "Test message"
      assert state.visible == true
      assert is_integer(state.created_at)
    end
  end

  describe "Toast keyboard handling" do
    setup do
      props = Toast.new(message: "Test")
      {:ok, state} = Toast.init(props)
      %{state: state}
    end

    test "escape dismisses toast", %{state: state} do
      on_dismiss = fn -> send(self(), :dismissed) end
      state = %{state | on_dismiss: on_dismiss}

      event = %Event.Key{key: :escape}
      {:ok, new_state} = Toast.handle_event(event, state)

      assert_receive :dismissed
      assert not Toast.visible?(new_state)
    end
  end

  describe "Toast mouse handling" do
    setup do
      props = Toast.new(message: "Test")
      {:ok, state} = Toast.init(props)
      %{state: state}
    end

    test "click dismisses toast", %{state: state} do
      on_dismiss = fn -> send(self(), :dismissed) end
      state = %{state | on_dismiss: on_dismiss}

      event = %Event.Mouse{action: :click, x: 10, y: 5}
      {:ok, new_state} = Toast.handle_event(event, state)

      assert_receive :dismissed
      assert not Toast.visible?(new_state)
    end
  end

  describe "Toast public API" do
    setup do
      props = Toast.new(message: "Test", type: :success, position: :top_right)
      {:ok, state} = Toast.init(props)
      %{state: state}
    end

    test "visible? returns visibility state", %{state: state} do
      assert Toast.visible?(state)
    end

    test "dismiss_toast hides toast", %{state: state} do
      state = Toast.dismiss_toast(state)

      assert not Toast.visible?(state)
    end

    test "get_type returns toast type", %{state: state} do
      assert Toast.get_type(state) == :success
    end

    test "get_position returns toast position", %{state: state} do
      assert Toast.get_position(state) == :top_right
    end

    test "elapsed_time returns time since creation", %{state: state} do
      :timer.sleep(10)
      elapsed = Toast.elapsed_time(state)

      assert elapsed >= 10
    end

    test "should_dismiss? returns false before duration", %{state: state} do
      state = %{state | duration: 10000}

      assert not Toast.should_dismiss?(state)
    end

    test "should_dismiss? returns true after duration" do
      props = Toast.new(message: "Test", duration: 1)
      {:ok, state} = Toast.init(props)

      :timer.sleep(5)

      assert Toast.should_dismiss?(state)
    end

    test "should_dismiss? returns false with nil duration", %{state: state} do
      state = %{state | duration: nil}

      assert not Toast.should_dismiss?(state)
    end
  end

  describe "Toast render" do
    test "renders toast as overlay" do
      props = Toast.new(message: "Test")
      {:ok, state} = Toast.init(props)
      area = %{x: 0, y: 0, width: 80, height: 24}

      result = Toast.render(state, area)

      assert result.type == :overlay
      assert result.z == 150
    end

    test "renders empty when not visible" do
      props = Toast.new(message: "Test")
      {:ok, state} = Toast.init(props)
      state = Toast.dismiss_toast(state)
      area = %{x: 0, y: 0, width: 80, height: 24}

      result = Toast.render(state, area)

      assert result.type == :empty
    end

    test "positions toast at bottom_right" do
      props = Toast.new(message: "Test", position: :bottom_right, width: 40)
      {:ok, state} = Toast.init(props)
      area = %{x: 0, y: 0, width: 80, height: 24}

      result = Toast.render(state, area)

      # Bottom right: x = 80 - 40 - 1 = 39, y = 24 - 3 - 1 = 20
      assert result.x == 39
      assert result.y == 20
    end

    test "positions toast at top_center" do
      props = Toast.new(message: "Test", position: :top_center, width: 40)
      {:ok, state} = Toast.init(props)
      area = %{x: 0, y: 0, width: 80, height: 24}

      result = Toast.render(state, area)

      # Top center: x = (80 - 40) / 2 = 20, y = 1
      assert result.x == 20
      assert result.y == 1
    end
  end

  describe "ToastManager" do
    test "new creates manager with defaults" do
      manager = ToastManager.new()

      assert manager.position == :bottom_right
      assert manager.max_toasts == 5
      assert manager.default_duration == 3000
      assert manager.toasts == []
    end

    test "new with custom options" do
      manager =
        ToastManager.new(
          position: :top_right,
          max_toasts: 3,
          default_duration: 5000
        )

      assert manager.position == :top_right
      assert manager.max_toasts == 3
      assert manager.default_duration == 5000
    end

    test "add_toast adds toast to manager" do
      manager = ToastManager.new()
      manager = ToastManager.add_toast(manager, "Test message", :info)

      assert ToastManager.toast_count(manager) == 1
    end

    test "add_toast respects max_toasts" do
      manager = ToastManager.new(max_toasts: 2)

      manager = ToastManager.add_toast(manager, "Message 1")
      manager = ToastManager.add_toast(manager, "Message 2")
      manager = ToastManager.add_toast(manager, "Message 3")

      assert ToastManager.toast_count(manager) == 2
    end

    test "tick removes dismissed toasts" do
      manager = ToastManager.new()
      manager = ToastManager.add_toast(manager, "Test", :info, duration: 1)

      :timer.sleep(5)

      manager = ToastManager.tick(manager)

      assert ToastManager.toast_count(manager) == 0
    end

    test "get_toasts returns visible toasts" do
      manager = ToastManager.new()
      manager = ToastManager.add_toast(manager, "Message 1")
      manager = ToastManager.add_toast(manager, "Message 2")

      toasts = ToastManager.get_toasts(manager)

      assert length(toasts) == 2
    end

    test "clear_all removes all toasts" do
      manager = ToastManager.new()
      manager = ToastManager.add_toast(manager, "Message 1")
      manager = ToastManager.add_toast(manager, "Message 2")

      manager = ToastManager.clear_all(manager)

      assert ToastManager.toast_count(manager) == 0
    end

    test "render returns empty when no toasts" do
      manager = ToastManager.new()
      area = %{x: 0, y: 0, width: 80, height: 24}

      result = ToastManager.render(manager, area)

      assert result.type == :empty
    end

    test "render returns stack for multiple toasts" do
      manager = ToastManager.new()
      manager = ToastManager.add_toast(manager, "Message 1")
      manager = ToastManager.add_toast(manager, "Message 2")
      area = %{x: 0, y: 0, width: 80, height: 24}

      result = ToastManager.render(manager, area)

      assert result.type == :stack
      assert length(result.children) == 2
    end
  end
end
