defmodule TermUI.ElmTest do
  use ExUnit.Case, async: true

  alias TermUI.Elm
  alias TermUI.Event

  describe "normalize_update_result/2" do
    test "passes through standard form" do
      state = %{count: 5}
      commands = [:cmd1, :cmd2]

      result = Elm.normalize_update_result({state, commands}, %{count: 0})

      assert result == {state, commands}
    end

    test "converts single-tuple to standard form" do
      state = %{count: 5}

      result = Elm.normalize_update_result({state}, %{count: 0})

      assert result == {state, []}
    end

    test "converts :noreply to keep old state" do
      old_state = %{count: 0}

      result = Elm.normalize_update_result(:noreply, old_state)

      assert result == {old_state, []}
    end
  end

  describe "component using Elm behaviour" do
    defmodule Counter do
      use TermUI.Elm

      def init(opts), do: %{count: Keyword.get(opts, :initial, 0)}

      def event_to_msg(%Event.Key{key: :up}, _state), do: {:msg, :increment}
      def event_to_msg(%Event.Key{key: :down}, _state), do: {:msg, :decrement}
      def event_to_msg(%Event.Key{key: :r}, _state), do: {:msg, :reset}
      def event_to_msg(_, _), do: :ignore

      def update(:increment, state), do: {%{state | count: state.count + 1}, []}
      def update(:decrement, state), do: {%{state | count: state.count - 1}, []}
      def update(:reset, state), do: {%{state | count: 0}, []}
      def update(:noop, _state), do: :noreply

      def view(state), do: {:text, "Count: #{state.count}"}
    end

    test "init creates initial state" do
      state = Counter.init([])
      assert state == %{count: 0}
    end

    test "init accepts options" do
      state = Counter.init(initial: 10)
      assert state == %{count: 10}
    end

    test "event_to_msg converts key events" do
      state = %{count: 0}

      assert {:msg, :increment} = Counter.event_to_msg(Event.key(:up), state)
      assert {:msg, :decrement} = Counter.event_to_msg(Event.key(:down), state)
      assert {:msg, :reset} = Counter.event_to_msg(Event.key(:r), state)
    end

    test "event_to_msg returns :ignore for unhandled events" do
      state = %{count: 0}
      assert :ignore = Counter.event_to_msg(Event.key(:x), state)
    end

    test "update produces new state" do
      state = %{count: 5}

      {new_state, commands} = Counter.update(:increment, state)

      assert new_state == %{count: 6}
      assert commands == []
    end

    test "update returns :noreply to keep state" do
      state = %{count: 5}
      result = Counter.update(:noop, state)
      assert result == :noreply
    end

    test "view renders state to tree" do
      state = %{count: 42}
      tree = Counter.view(state)
      assert tree == {:text, "Count: 42"}
    end

    test "full cycle: event -> message -> update -> view" do
      # Initialize
      state = Counter.init([])
      assert state.count == 0

      # Event arrives
      event = Event.key(:up)

      # Convert to message
      {:msg, msg} = Counter.event_to_msg(event, state)
      assert msg == :increment

      # Update state
      {new_state, _} = Counter.update(msg, state)
      assert new_state.count == 1

      # Render
      tree = Counter.view(new_state)
      assert tree == {:text, "Count: 1"}
    end
  end

  describe "component with commands" do
    defmodule Fetcher do
      use TermUI.Elm

      def init(_opts), do: %{data: nil, loading: false, error: nil}

      def event_to_msg(%Event.Key{key: :f}, _state), do: {:msg, :fetch}
      def event_to_msg(_, _), do: :ignore

      def update(:fetch, state) do
        command = {:http_get, "https://api.example.com/data", :data_loaded}
        {%{state | loading: true}, [command]}
      end

      def update({:data_loaded, {:ok, data}}, state) do
        {%{state | data: data, loading: false}, []}
      end

      def update({:data_loaded, {:error, reason}}, state) do
        {%{state | error: reason, loading: false}, []}
      end

      def view(state) do
        cond do
          state.loading -> {:text, "Loading..."}
          state.error -> {:text, "Error: #{state.error}"}
          state.data -> {:text, "Data: #{state.data}"}
          true -> {:text, "Press F to fetch"}
        end
      end
    end

    test "update returns commands" do
      state = %{data: nil, loading: false, error: nil}

      {new_state, commands} = Fetcher.update(:fetch, state)

      assert new_state.loading == true
      assert length(commands) == 1
      assert {:http_get, _, :data_loaded} = hd(commands)
    end

    test "update handles command result" do
      state = %{data: nil, loading: true, error: nil}

      {new_state, _} = Fetcher.update({:data_loaded, {:ok, "result"}}, state)

      assert new_state.data == "result"
      assert new_state.loading == false
    end
  end

  describe "Elm.Helpers" do
    import TermUI.Elm.Helpers

    test "text creates text node" do
      node = text("Hello")
      assert node == {:text, "Hello"}
    end

    test "text converts non-string to string" do
      node = text(42)
      assert node == {:text, "42"}
    end

    test "styled creates styled node" do
      node = styled("Hello", %{fg: :blue})
      assert node == {:styled, "Hello", %{fg: :blue}}
    end

    test "fragment groups nodes" do
      nodes = fragment([{:text, "a"}, {:text, "b"}])
      assert nodes == {:fragment, [{:text, "a"}, {:text, "b"}]}
    end
  end
end
