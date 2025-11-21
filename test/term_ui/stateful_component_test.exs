defmodule TermUI.StatefulComponentTest do
  use ExUnit.Case, async: true

  alias TermUI.Component.RenderNode
  alias TermUI.Renderer.Style

  # Test counter component
  defmodule Counter do
    use TermUI.StatefulComponent

    @impl true
    def init(props) do
      {:ok, %{count: props[:initial] || 0}}
    end

    @impl true
    def handle_event({:increment, n}, state) do
      {:ok, %{state | count: state.count + n}}
    end

    def handle_event(:decrement, state) do
      {:ok, %{state | count: state.count - 1}}
    end

    def handle_event(:reset, state) do
      {:ok, %{state | count: 0}}
    end

    def handle_event(_event, state) do
      {:ok, state}
    end

    @impl true
    def render(state, _area) do
      text("Count: #{state.count}")
    end
  end

  # Component with commands
  defmodule CommandComponent do
    use TermUI.StatefulComponent

    @impl true
    def init(props) do
      if props[:send_init] do
        {:ok, %{value: 0}, [{:send, props[:parent], :initialized}]}
      else
        {:ok, %{value: 0}}
      end
    end

    @impl true
    def handle_event(:submit, state) do
      commands = [{:send, self(), {:submitted, state.value}}]
      {:ok, state, commands}
    end

    def handle_event({:set, value}, state) do
      {:ok, %{state | value: value}}
    end

    def handle_event(_event, state) do
      {:ok, state}
    end

    @impl true
    def render(state, _area) do
      text("Value: #{state.value}")
    end
  end

  # Component with all optional callbacks
  defmodule FullComponent do
    use TermUI.StatefulComponent

    @impl true
    def init(_props) do
      {:ok, %{value: 0}}
    end

    @impl true
    def handle_event(_event, state) do
      {:ok, state}
    end

    @impl true
    def render(state, _area) do
      text("#{state.value}")
    end

    @impl true
    def terminate(reason, state) do
      send(self(), {:terminated, reason, state})
      :ok
    end

    @impl true
    def handle_info({:update, value}, state) do
      {:ok, %{state | value: value}}
    end

    def handle_info(_msg, state) do
      {:ok, state}
    end

    @impl true
    def handle_call(:get_value, _from, state) do
      {:reply, state.value, state}
    end

    def handle_call({:set_value, value}, _from, state) do
      {:reply, :ok, %{state | value: value}}
    end
  end

  # Component that stops
  defmodule StoppingComponent do
    use TermUI.StatefulComponent

    @impl true
    def init(props) do
      if props[:fail_init] do
        {:stop, :init_failed}
      else
        {:ok, %{}}
      end
    end

    @impl true
    def handle_event(:stop, state) do
      {:stop, :normal, state}
    end

    def handle_event(_event, state) do
      {:ok, state}
    end

    @impl true
    def render(_state, _area) do
      text("")
    end
  end

  describe "init/1" do
    test "receives props and returns initial state" do
      {:ok, state} = Counter.init(%{initial: 10})
      assert state.count == 10
    end

    test "uses default when prop not provided" do
      {:ok, state} = Counter.init(%{})
      assert state.count == 0
    end

    test "can return commands" do
      {:ok, state, commands} = CommandComponent.init(%{send_init: true, parent: self()})
      assert state.value == 0
      assert commands == [{:send, self(), :initialized}]
    end

    test "can return stop" do
      {:stop, reason} = StoppingComponent.init(%{fail_init: true})
      assert reason == :init_failed
    end
  end

  describe "handle_event/2" do
    test "receives events and updates state" do
      {:ok, state} = Counter.init(%{initial: 5})
      {:ok, new_state} = Counter.handle_event({:increment, 3}, state)
      assert new_state.count == 8
    end

    test "handles multiple event types" do
      {:ok, state} = Counter.init(%{initial: 10})
      {:ok, state} = Counter.handle_event(:decrement, state)
      assert state.count == 9
      {:ok, state} = Counter.handle_event(:reset, state)
      assert state.count == 0
    end

    test "unknown events return unchanged state" do
      {:ok, state} = Counter.init(%{initial: 5})
      {:ok, new_state} = Counter.handle_event(:unknown, state)
      assert new_state.count == 5
    end

    test "can return commands" do
      {:ok, state} = CommandComponent.init(%{})
      {:ok, state} = CommandComponent.handle_event({:set, 42}, state)
      {:ok, _state, commands} = CommandComponent.handle_event(:submit, state)
      assert [{:send, _pid, {:submitted, 42}}] = commands
    end

    test "can return stop" do
      {:ok, state} = StoppingComponent.init(%{})
      {:stop, reason, _state} = StoppingComponent.handle_event(:stop, state)
      assert reason == :normal
    end
  end

  describe "render/2" do
    test "receives state and area" do
      {:ok, state} = Counter.init(%{initial: 42})
      area = %{x: 0, y: 0, width: 80, height: 24}
      result = Counter.render(state, area)
      assert result.type == :text
      assert result.content == "Count: 42"
    end

    test "updates with new state" do
      {:ok, state} = Counter.init(%{initial: 0})
      {:ok, state} = Counter.handle_event({:increment, 5}, state)
      area = %{x: 0, y: 0, width: 80, height: 24}
      result = Counter.render(state, area)
      assert result.content == "Count: 5"
    end
  end

  describe "optional callbacks" do
    test "terminate is called with reason and state" do
      FullComponent.terminate(:shutdown, %{value: 100})
      assert_receive {:terminated, :shutdown, %{value: 100}}
    end

    test "handle_info processes messages" do
      {:ok, state} = FullComponent.init(%{})
      {:ok, new_state} = FullComponent.handle_info({:update, 42}, state)
      assert new_state.value == 42
    end

    test "handle_info ignores unknown messages" do
      {:ok, state} = FullComponent.init(%{})
      {:ok, new_state} = FullComponent.handle_info(:unknown, state)
      assert new_state.value == 0
    end

    test "handle_call returns reply" do
      {:ok, state} = FullComponent.init(%{})
      {:ok, state} = FullComponent.handle_info({:update, 42}, state)
      {:reply, value, _state} = FullComponent.handle_call(:get_value, self(), state)
      assert value == 42
    end

    test "handle_call can update state" do
      {:ok, state} = FullComponent.init(%{})
      {:reply, :ok, new_state} = FullComponent.handle_call({:set_value, 100}, self(), state)
      assert new_state.value == 100
    end
  end

  describe "__using__ macro" do
    test "provides default terminate" do
      {:ok, state} = Counter.init(%{})
      result = Counter.terminate(:normal, state)
      assert result == :ok
    end

    test "provides default handle_info" do
      {:ok, state} = Counter.init(%{})
      {:ok, new_state} = Counter.handle_info(:message, state)
      assert new_state == state
    end

    test "provides default handle_call" do
      {:ok, state} = Counter.init(%{})
      {:reply, :ok, new_state} = Counter.handle_call(:request, self(), state)
      assert new_state == state
    end

    test "imports helpers" do
      # Verify text() is available
      {:ok, state} = Counter.init(%{initial: 0})
      area = %{x: 0, y: 0, width: 80, height: 24}
      result = Counter.render(state, area)
      assert %RenderNode{} = result
    end
  end

  describe "command types" do
    test "send command" do
      {:ok, state} = CommandComponent.init(%{})
      {:ok, state} = CommandComponent.handle_event({:set, 10}, state)
      {:ok, _state, commands} = CommandComponent.handle_event(:submit, state)
      assert [{:send, _pid, {:submitted, 10}}] = commands
    end
  end

  describe "state management patterns" do
    test "accumulating changes" do
      {:ok, state} = Counter.init(%{initial: 0})

      state =
        Enum.reduce(1..5, state, fn n, acc ->
          {:ok, new_state} = Counter.handle_event({:increment, n}, acc)
          new_state
        end)

      assert state.count == 15
    end

    test "state isolation between instances" do
      {:ok, state1} = Counter.init(%{initial: 0})
      {:ok, state2} = Counter.init(%{initial: 100})

      {:ok, state1} = Counter.handle_event({:increment, 1}, state1)

      assert state1.count == 1
      assert state2.count == 100
    end
  end
end
