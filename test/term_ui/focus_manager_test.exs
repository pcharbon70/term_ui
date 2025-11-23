defmodule TermUI.FocusManagerTest do
  use ExUnit.Case

  alias TermUI.ComponentRegistry
  alias TermUI.Event
  alias TermUI.EventRouter
  alias TermUI.FocusManager
  alias TermUI.SpatialIndex

  # Test component that tracks received events
  defmodule TestComponent do
    use GenServer

    def start_link(opts) do
      test_pid = Keyword.get(opts, :test_pid, self())
      GenServer.start_link(__MODULE__, %{test_pid: test_pid})
    end

    @impl true
    def init(state), do: {:ok, state}

    @impl true
    def handle_call({:event, event}, _from, state) do
      send(state.test_pid, {:event_received, event})
      {:reply, :handled, state}
    end
  end

  setup do
    start_supervised!(ComponentRegistry)
    start_supervised!(SpatialIndex)
    start_supervised!(EventRouter)
    start_supervised!(FocusManager)
    :ok
  end

  describe "get_focused/0 and set_focused/1" do
    test "returns nil when no focus" do
      assert {:ok, nil} = FocusManager.get_focused()
    end

    test "sets and gets focused component" do
      {:ok, pid} = TestComponent.start_link(test_pid: self())
      :ok = ComponentRegistry.register(:input, pid, TestComponent)

      :ok = FocusManager.set_focused(:input)

      assert {:ok, :input} = FocusManager.get_focused()
    end

    test "sends focus event to new component" do
      {:ok, pid} = TestComponent.start_link(test_pid: self())
      :ok = ComponentRegistry.register(:input, pid, TestComponent)

      :ok = FocusManager.set_focused(:input)

      assert_receive {:event_received, %Event.Focus{action: :gained}}
    end

    test "sends blur event to old component" do
      {:ok, pid1} = TestComponent.start_link(test_pid: self())
      {:ok, pid2} = TestComponent.start_link(test_pid: self())

      :ok = ComponentRegistry.register(:input1, pid1, TestComponent)
      :ok = ComponentRegistry.register(:input2, pid2, TestComponent)

      :ok = FocusManager.set_focused(:input1)
      assert_receive {:event_received, %Event.Focus{action: :gained}}

      :ok = FocusManager.set_focused(:input2)
      assert_receive {:event_received, %Event.Focus{action: :lost}}
      assert_receive {:event_received, %Event.Focus{action: :gained}}
    end

    test "returns error for non-existent component" do
      assert {:error, :not_found} = FocusManager.set_focused(:nonexistent)
    end

    test "clear_focus clears the focus" do
      {:ok, pid} = TestComponent.start_link(test_pid: self())
      :ok = ComponentRegistry.register(:input, pid, TestComponent)

      :ok = FocusManager.set_focused(:input)
      :ok = FocusManager.clear_focus()

      assert {:ok, nil} = FocusManager.get_focused()
    end

    test "setting same focus doesn't send duplicate events" do
      {:ok, pid} = TestComponent.start_link(test_pid: self())
      :ok = ComponentRegistry.register(:input, pid, TestComponent)

      :ok = FocusManager.set_focused(:input)
      # Receive focus gained from EventRouter
      assert_receive {:event_received, %Event.Focus{action: :gained}}

      :ok = FocusManager.set_focused(:input)
      # No more events should be sent
      refute_receive {:event_received, _}, 50
    end
  end

  describe "focus_next/0 and focus_prev/0" do
    test "focus_next moves to first when no focus" do
      {:ok, pid} = TestComponent.start_link(test_pid: self())
      :ok = ComponentRegistry.register(:input, pid, TestComponent)
      :ok = SpatialIndex.update(:input, pid, %{x: 0, y: 0, width: 10, height: 1})

      :ok = FocusManager.focus_next()

      assert {:ok, :input} = FocusManager.get_focused()
    end

    test "focus_next moves to next component" do
      {:ok, pid1} = TestComponent.start_link(test_pid: self())
      {:ok, pid2} = TestComponent.start_link(test_pid: self())

      :ok = ComponentRegistry.register(:input1, pid1, TestComponent)
      :ok = ComponentRegistry.register(:input2, pid2, TestComponent)
      :ok = SpatialIndex.update(:input1, pid1, %{x: 0, y: 0, width: 10, height: 1})
      :ok = SpatialIndex.update(:input2, pid2, %{x: 0, y: 1, width: 10, height: 1})

      :ok = FocusManager.set_focused(:input1)
      # Clear events
      assert_receive {:event_received, _}

      :ok = FocusManager.focus_next()
      assert {:ok, :input2} = FocusManager.get_focused()
    end

    test "focus_next wraps around" do
      {:ok, pid1} = TestComponent.start_link(test_pid: self())
      {:ok, pid2} = TestComponent.start_link(test_pid: self())

      :ok = ComponentRegistry.register(:input1, pid1, TestComponent)
      :ok = ComponentRegistry.register(:input2, pid2, TestComponent)
      :ok = SpatialIndex.update(:input1, pid1, %{x: 0, y: 0, width: 10, height: 1})
      :ok = SpatialIndex.update(:input2, pid2, %{x: 0, y: 1, width: 10, height: 1})

      :ok = FocusManager.set_focused(:input2)

      :ok = FocusManager.focus_next()
      assert {:ok, :input1} = FocusManager.get_focused()
    end

    test "focus_prev moves to last when no focus" do
      {:ok, pid1} = TestComponent.start_link(test_pid: self())
      {:ok, pid2} = TestComponent.start_link(test_pid: self())

      :ok = ComponentRegistry.register(:input1, pid1, TestComponent)
      :ok = ComponentRegistry.register(:input2, pid2, TestComponent)
      :ok = SpatialIndex.update(:input1, pid1, %{x: 0, y: 0, width: 10, height: 1})
      :ok = SpatialIndex.update(:input2, pid2, %{x: 0, y: 1, width: 10, height: 1})

      :ok = FocusManager.focus_prev()
      assert {:ok, :input2} = FocusManager.get_focused()
    end

    test "focus_prev wraps around" do
      {:ok, pid1} = TestComponent.start_link(test_pid: self())
      {:ok, pid2} = TestComponent.start_link(test_pid: self())

      :ok = ComponentRegistry.register(:input1, pid1, TestComponent)
      :ok = ComponentRegistry.register(:input2, pid2, TestComponent)
      :ok = SpatialIndex.update(:input1, pid1, %{x: 0, y: 0, width: 10, height: 1})
      :ok = SpatialIndex.update(:input2, pid2, %{x: 0, y: 1, width: 10, height: 1})

      :ok = FocusManager.set_focused(:input1)

      :ok = FocusManager.focus_prev()
      assert {:ok, :input2} = FocusManager.get_focused()
    end

    test "returns error when no focusable components" do
      assert {:error, :no_focusable} = FocusManager.focus_next()
      assert {:error, :no_focusable} = FocusManager.focus_prev()
    end
  end

  describe "focus stack" do
    test "push_focus pushes current to stack" do
      {:ok, pid1} = TestComponent.start_link(test_pid: self())
      {:ok, pid2} = TestComponent.start_link(test_pid: self())

      :ok = ComponentRegistry.register(:input1, pid1, TestComponent)
      :ok = ComponentRegistry.register(:input2, pid2, TestComponent)

      :ok = FocusManager.set_focused(:input1)
      :ok = FocusManager.push_focus(:input2)

      assert {:ok, :input2} = FocusManager.get_focused()
      assert [:input1] = FocusManager.get_stack()
    end

    test "pop_focus restores previous focus" do
      {:ok, pid1} = TestComponent.start_link(test_pid: self())
      {:ok, pid2} = TestComponent.start_link(test_pid: self())

      :ok = ComponentRegistry.register(:input1, pid1, TestComponent)
      :ok = ComponentRegistry.register(:input2, pid2, TestComponent)

      :ok = FocusManager.set_focused(:input1)
      :ok = FocusManager.push_focus(:input2)
      :ok = FocusManager.pop_focus()

      assert {:ok, :input1} = FocusManager.get_focused()
      assert [] = FocusManager.get_stack()
    end

    test "pop_focus returns error on empty stack" do
      assert {:error, :empty_stack} = FocusManager.pop_focus()
    end

    test "nested push/pop works correctly" do
      {:ok, pid1} = TestComponent.start_link(test_pid: self())
      {:ok, pid2} = TestComponent.start_link(test_pid: self())
      {:ok, pid3} = TestComponent.start_link(test_pid: self())

      :ok = ComponentRegistry.register(:input1, pid1, TestComponent)
      :ok = ComponentRegistry.register(:input2, pid2, TestComponent)
      :ok = ComponentRegistry.register(:input3, pid3, TestComponent)

      :ok = FocusManager.set_focused(:input1)
      :ok = FocusManager.push_focus(:input2)
      :ok = FocusManager.push_focus(:input3)

      assert {:ok, :input3} = FocusManager.get_focused()
      assert [:input2, :input1] = FocusManager.get_stack()

      :ok = FocusManager.pop_focus()
      assert {:ok, :input2} = FocusManager.get_focused()

      :ok = FocusManager.pop_focus()
      assert {:ok, :input1} = FocusManager.get_focused()
    end
  end

  describe "focus groups and trapping" do
    test "register_group creates a focus group" do
      :ok = FocusManager.register_group(:modal, [:btn1, :btn2, :btn3])

      groups = FocusManager.get_groups()
      assert Map.has_key?(groups, :modal)
      assert groups[:modal] == [:btn1, :btn2, :btn3]
    end

    test "unregister_group removes a focus group" do
      :ok = FocusManager.register_group(:modal, [:btn1, :btn2])
      :ok = FocusManager.unregister_group(:modal)

      groups = FocusManager.get_groups()
      refute Map.has_key?(groups, :modal)
    end

    test "trap_focus restricts navigation to group" do
      {:ok, pid1} = TestComponent.start_link(test_pid: self())
      {:ok, pid2} = TestComponent.start_link(test_pid: self())
      {:ok, pid3} = TestComponent.start_link(test_pid: self())

      :ok = ComponentRegistry.register(:outside, pid1, TestComponent)
      :ok = ComponentRegistry.register(:modal_btn1, pid2, TestComponent)
      :ok = ComponentRegistry.register(:modal_btn2, pid3, TestComponent)

      :ok = SpatialIndex.update(:outside, pid1, %{x: 0, y: 0, width: 10, height: 1})
      :ok = SpatialIndex.update(:modal_btn1, pid2, %{x: 0, y: 1, width: 10, height: 1})
      :ok = SpatialIndex.update(:modal_btn2, pid3, %{x: 0, y: 2, width: 10, height: 1})

      :ok = FocusManager.register_group(:modal, [:modal_btn1, :modal_btn2])
      :ok = FocusManager.trap_focus(:modal)
      :ok = FocusManager.set_focused(:modal_btn1)

      # Focus should cycle within group
      :ok = FocusManager.focus_next()
      assert {:ok, :modal_btn2} = FocusManager.get_focused()

      :ok = FocusManager.focus_next()
      assert {:ok, :modal_btn1} = FocusManager.get_focused()
    end

    test "release_focus exits the trap" do
      {:ok, pid1} = TestComponent.start_link(test_pid: self())
      {:ok, pid2} = TestComponent.start_link(test_pid: self())

      :ok = ComponentRegistry.register(:outside, pid1, TestComponent)
      :ok = ComponentRegistry.register(:modal_btn, pid2, TestComponent)

      :ok = SpatialIndex.update(:outside, pid1, %{x: 0, y: 0, width: 10, height: 1})
      :ok = SpatialIndex.update(:modal_btn, pid2, %{x: 0, y: 1, width: 10, height: 1})

      :ok = FocusManager.register_group(:modal, [:modal_btn])
      :ok = FocusManager.trap_focus(:modal)
      :ok = FocusManager.release_focus()

      :ok = FocusManager.set_focused(:modal_btn)
      :ok = FocusManager.focus_next()

      # Should navigate to outside component now
      assert {:ok, :outside} = FocusManager.get_focused()
    end

    test "trap_focus returns error for unknown group" do
      assert {:error, :group_not_found} = FocusManager.trap_focus(:unknown)
    end
  end

  describe "focused?/1" do
    test "returns true when component is focused" do
      {:ok, pid} = TestComponent.start_link(test_pid: self())
      :ok = ComponentRegistry.register(:input, pid, TestComponent)

      :ok = FocusManager.set_focused(:input)

      assert FocusManager.focused?(:input)
    end

    test "returns false when component is not focused" do
      {:ok, pid} = TestComponent.start_link(test_pid: self())
      :ok = ComponentRegistry.register(:input, pid, TestComponent)

      refute FocusManager.focused?(:input)
    end

    test "returns false when different component is focused" do
      {:ok, pid1} = TestComponent.start_link(test_pid: self())
      {:ok, pid2} = TestComponent.start_link(test_pid: self())

      :ok = ComponentRegistry.register(:input1, pid1, TestComponent)
      :ok = ComponentRegistry.register(:input2, pid2, TestComponent)

      :ok = FocusManager.set_focused(:input1)

      refute FocusManager.focused?(:input2)
    end
  end

  describe "request_auto_focus/1" do
    test "sets focus when nothing is focused" do
      {:ok, pid} = TestComponent.start_link(test_pid: self())
      :ok = ComponentRegistry.register(:input, pid, TestComponent)

      FocusManager.request_auto_focus(:input)

      # Give cast time to process
      Process.sleep(10)

      assert {:ok, :input} = FocusManager.get_focused()
    end

    test "does not change focus when something is already focused" do
      {:ok, pid1} = TestComponent.start_link(test_pid: self())
      {:ok, pid2} = TestComponent.start_link(test_pid: self())

      :ok = ComponentRegistry.register(:input1, pid1, TestComponent)
      :ok = ComponentRegistry.register(:input2, pid2, TestComponent)

      :ok = FocusManager.set_focused(:input1)
      FocusManager.request_auto_focus(:input2)

      # Give cast time to process
      Process.sleep(10)

      assert {:ok, :input1} = FocusManager.get_focused()
    end
  end
end
