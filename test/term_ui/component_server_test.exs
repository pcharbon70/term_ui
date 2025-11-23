defmodule TermUI.ComponentServerTest do
  use ExUnit.Case, async: false

  alias TermUI.ComponentRegistry
  alias TermUI.ComponentServer
  alias TermUI.ComponentSupervisor

  # Test component with full lifecycle
  defmodule TestComponent do
    use TermUI.StatefulComponent

    @impl true
    def init(props) do
      if props[:fail_init] do
        {:stop, :init_failed}
      else
        {:ok, %{value: props[:initial] || 0, mounted: false}}
      end
    end

    @impl true
    def mount(state) do
      {:ok, %{state | mounted: true}}
    end

    @impl true
    def update(new_props, state) do
      {:ok, %{state | value: new_props[:value] || state.value}}
    end

    @impl true
    def unmount(_state) do
      :ok
    end

    @impl true
    def handle_event({:set, value}, state) do
      {:ok, %{state | value: value}}
    end

    def handle_event({:get_value, caller}, state) do
      {:ok, state, [{:send, caller, {:value, state.value}}]}
    end

    def handle_event(_event, state) do
      {:ok, state}
    end

    @impl true
    def render(state, _area) do
      text("Value: #{state.value}")
    end
  end

  # Component with commands
  defmodule CommandComponent do
    use TermUI.StatefulComponent

    @impl true
    def init(props) do
      if props[:init_command] do
        {:ok, %{parent: props[:parent]}, [{:send, props[:parent], :initialized}]}
      else
        {:ok, %{parent: props[:parent]}}
      end
    end

    @impl true
    def mount(state) do
      if state.parent do
        {:ok, state, [{:send, state.parent, :mounted}]}
      else
        {:ok, state}
      end
    end

    @impl true
    def handle_event(_event, state) do
      {:ok, state}
    end

    @impl true
    def render(_state, _area) do
      text("")
    end
  end

  # Component that fails on mount
  defmodule FailingMountComponent do
    use TermUI.StatefulComponent

    @impl true
    def init(_props) do
      {:ok, %{}}
    end

    @impl true
    def mount(_state) do
      {:stop, :mount_failed}
    end

    @impl true
    def handle_event(_event, state) do
      {:ok, state}
    end

    @impl true
    def render(_state, _area) do
      text("")
    end
  end

  # Slow init component
  defmodule SlowInitComponent do
    use TermUI.StatefulComponent

    @impl true
    def init(_props) do
      Process.sleep(200)
      {:ok, %{}}
    end

    @impl true
    def handle_event(_event, state) do
      {:ok, state}
    end

    @impl true
    def render(_state, _area) do
      text("")
    end
  end

  setup do
    # Start required processes
    start_supervised!(TermUI.Component.StatePersistence)
    start_supervised!(ComponentRegistry)
    start_supervised!(ComponentSupervisor)
    :ok
  end

  describe "initialization" do
    test "creates process with correct initial state" do
      {:ok, pid} = ComponentServer.start_link(TestComponent, %{initial: 42}, [])

      state = ComponentServer.get_state(pid)
      assert state.value == 42
      assert state.mounted == false
    end

    test "lifecycle starts as :initialized" do
      {:ok, pid} = ComponentServer.start_link(TestComponent, %{}, [])

      assert ComponentServer.get_lifecycle(pid) == :initialized
    end

    test "init can return commands" do
      {:ok, _pid} =
        ComponentServer.start_link(CommandComponent, %{init_command: true, parent: self()}, [])

      assert_receive :initialized
    end

    test "invalid props fail initialization" do
      Process.flag(:trap_exit, true)
      result = ComponentServer.start_link(TestComponent, %{fail_init: true}, [])

      # Should fail to start
      assert match?({:error, :init_failed}, result)
    end

    test "init timeout stops slow initialization" do
      Process.flag(:trap_exit, true)
      result = ComponentServer.start_link(SlowInitComponent, %{}, timeout: 50)

      case result do
        {:ok, pid} ->
          assert_receive {:EXIT, ^pid, {:init_timeout, 50}}

        {:error, {:init_timeout, 50}} ->
          :ok
      end
    end
  end

  describe "mounting" do
    test "mount callback called after mount" do
      {:ok, pid} = ComponentServer.start_link(TestComponent, %{}, [])

      assert :ok = ComponentServer.mount(pid)

      state = ComponentServer.get_state(pid)
      assert state.mounted == true
    end

    test "lifecycle changes to :mounted" do
      {:ok, pid} = ComponentServer.start_link(TestComponent, %{}, [])
      ComponentServer.mount(pid)

      assert ComponentServer.get_lifecycle(pid) == :mounted
    end

    test "mount commands are executed" do
      {:ok, pid} = ComponentServer.start_link(CommandComponent, %{parent: self()}, [])
      ComponentServer.mount(pid)

      assert_receive :mounted
    end

    test "component registered on mount" do
      {:ok, pid} = ComponentServer.start_link(TestComponent, %{}, id: :test_comp)
      ComponentServer.mount(pid)

      assert {:ok, ^pid} = ComponentRegistry.lookup(:test_comp)
    end

    test "mount error stops process" do
      Process.flag(:trap_exit, true)
      {:ok, pid} = ComponentServer.start_link(FailingMountComponent, %{}, [])

      # Mount will stop the process
      try do
        ComponentServer.mount(pid)
      catch
        :exit, _ -> :ok
      end

      # Wait for EXIT message
      assert_receive {:EXIT, ^pid, :mount_failed}
    end

    test "mount not allowed when already mounted" do
      {:ok, pid} = ComponentServer.start_link(TestComponent, %{}, [])
      ComponentServer.mount(pid)

      result = ComponentServer.mount(pid)
      assert match?({:error, {:invalid_lifecycle, :mounted, :expected_initialized}}, result)
    end
  end

  describe "updates" do
    test "update callback receives new props" do
      {:ok, pid} = ComponentServer.start_link(TestComponent, %{initial: 1}, [])
      ComponentServer.mount(pid)

      ComponentServer.update_props(pid, %{value: 100})

      state = ComponentServer.get_state(pid)
      assert state.value == 100
    end

    test "update not called when props unchanged" do
      {:ok, pid} = ComponentServer.start_link(TestComponent, %{initial: 1}, [])
      ComponentServer.mount(pid)

      # Update with same props
      props = ComponentServer.get_props(pid)
      ComponentServer.update_props(pid, props)

      # State should be unchanged
      state = ComponentServer.get_state(pid)
      assert state.value == 1
    end

    test "props are stored and retrievable" do
      {:ok, pid} = ComponentServer.start_link(TestComponent, %{initial: 5, extra: "data"}, [])

      props = ComponentServer.get_props(pid)
      assert props.initial == 5
      assert props.extra == "data"
    end

    test "update requires mounted lifecycle" do
      {:ok, pid} = ComponentServer.start_link(TestComponent, %{}, [])

      result = ComponentServer.update_props(pid, %{value: 1})
      assert match?({:error, {:invalid_lifecycle, :initialized, :expected_mounted}}, result)
    end
  end

  describe "unmounting" do
    test "unmount callback called" do
      {:ok, pid} = ComponentServer.start_link(TestComponent, %{}, id: :unmount_test)
      ComponentServer.mount(pid)

      assert :ok = ComponentServer.unmount(pid)
      assert ComponentServer.get_lifecycle(pid) == :unmounted
    end

    test "registry entry removed on unmount" do
      {:ok, pid} = ComponentServer.start_link(TestComponent, %{}, id: :registry_test)
      ComponentServer.mount(pid)
      assert ComponentRegistry.registered?(:registry_test)

      ComponentServer.unmount(pid)
      refute ComponentRegistry.registered?(:registry_test)
    end

    test "cleanup on terminate even when mounted" do
      Process.flag(:trap_exit, true)
      {:ok, pid} = ComponentServer.start_link(TestComponent, %{}, id: :terminate_test)
      ComponentServer.mount(pid)

      # Kill the process abruptly
      Process.exit(pid, :kill)

      # Wait for DOWN message
      assert_receive {:EXIT, ^pid, :killed}

      # Give time for registry cleanup via monitor
      Process.sleep(50)

      # Registry should be cleaned up
      refute ComponentRegistry.registered?(:terminate_test)
    end

    test "unmount requires mounted lifecycle" do
      {:ok, pid} = ComponentServer.start_link(TestComponent, %{}, [])

      result = ComponentServer.unmount(pid)
      assert match?({:error, {:invalid_lifecycle, :initialized, :expected_mounted}}, result)
    end
  end

  describe "events" do
    test "send_event updates state" do
      {:ok, pid} = ComponentServer.start_link(TestComponent, %{initial: 0}, [])
      ComponentServer.mount(pid)

      ComponentServer.send_event(pid, {:set, 42})

      state = ComponentServer.get_state(pid)
      assert state.value == 42
    end

    test "events can return commands" do
      {:ok, pid} = ComponentServer.start_link(TestComponent, %{initial: 99}, [])
      ComponentServer.mount(pid)

      ComponentServer.send_event(pid, {:get_value, self()})

      assert_receive {:value, 99}
    end

    test "events require mounted lifecycle" do
      {:ok, pid} = ComponentServer.start_link(TestComponent, %{}, [])

      result = ComponentServer.send_event(pid, {:set, 1})
      assert match?({:error, {:invalid_lifecycle, :initialized, :expected_mounted}}, result)
    end
  end

  describe "hooks" do
    test "after_mount hook fires after mount" do
      {:ok, pid} = ComponentServer.start_link(TestComponent, %{}, [])

      test_pid = self()

      ComponentServer.register_hook(pid, :after_mount, fn _state ->
        send(test_pid, :after_mount_called)
      end)

      ComponentServer.mount(pid)

      assert_receive :after_mount_called
    end

    test "before_unmount hook fires before unmount" do
      {:ok, pid} = ComponentServer.start_link(TestComponent, %{}, [])
      ComponentServer.mount(pid)

      test_pid = self()

      ComponentServer.register_hook(pid, :before_unmount, fn _state ->
        send(test_pid, :before_unmount_called)
      end)

      ComponentServer.unmount(pid)

      assert_receive :before_unmount_called
    end

    test "on_prop_change hook fires on update" do
      {:ok, pid} = ComponentServer.start_link(TestComponent, %{initial: 1}, [])
      ComponentServer.mount(pid)

      test_pid = self()

      ComponentServer.register_hook(pid, :on_prop_change, fn state ->
        send(test_pid, {:prop_changed, state.value})
      end)

      ComponentServer.update_props(pid, %{value: 100})

      assert_receive {:prop_changed, 100}
    end

    test "multiple hooks execute in order" do
      {:ok, pid} = ComponentServer.start_link(TestComponent, %{}, [])

      test_pid = self()

      ComponentServer.register_hook(pid, :after_mount, fn _state ->
        send(test_pid, :first)
      end)

      ComponentServer.register_hook(pid, :after_mount, fn _state ->
        send(test_pid, :second)
      end)

      ComponentServer.mount(pid)

      assert_receive :first
      assert_receive :second
    end
  end
end
