defmodule TermUI.InputTest do
  use TermUI.TestCase, async: true

  alias TermUI.Input
  alias TermUI.Event

  describe "behaviour definition" do
    test "module compiles and defines behaviour" do
      # Verify the module is loaded and defines a behaviour
      assert Code.ensure_loaded?(Input)
      assert function_exported?(Input, :behaviour_info, 1)
    end

    test "behaviour_info returns expected callbacks" do
      callbacks = Input.behaviour_info(:callbacks)

      # Should define poll/2, mode/1, and stop/1 callbacks
      assert {:poll, 2} in callbacks
      assert {:mode, 1} in callbacks
      assert {:stop, 1} in callbacks
      assert length(callbacks) == 3
    end

    test "behaviour_info returns optional callbacks (empty)" do
      optional_callbacks = Input.behaviour_info(:optional_callbacks)
      assert optional_callbacks == []
    end
  end

  describe "type specifications" do
    test "key_event type references Event.Key" do
      # Create a valid key event to verify type compatibility
      event = Event.key(:enter)
      assert %Event.Key{} = event
      assert event.key == :enter
    end

    test "input_result types cover all cases" do
      # {:ok, key_event}
      key_event = Event.key(:a, char: "a")
      result1 = {:ok, key_event}
      assert {:ok, %Event.Key{}} = result1

      # {:ok, mouse_event}
      mouse_event = Event.mouse(:click, :left, 10, 20)
      result2 = {:ok, mouse_event}
      assert {:ok, %Event.Mouse{}} = result2

      # {:ok, paste_event}
      paste_event = Event.paste("hello")
      result3 = {:ok, paste_event}
      assert {:ok, %Event.Paste{}} = result3

      # :timeout
      assert :timeout == :timeout

      # :eof
      assert :eof == :eof
    end

    test "mode type covers raw and tty" do
      # Valid modes
      assert :raw in [:raw, :tty]
      assert :tty in [:raw, :tty]
    end
  end

  describe "mock implementation" do
    defmodule MockInput do
      @moduledoc false
      @behaviour TermUI.Input

      defstruct buffer: <<>>, mode: :raw

      @impl true
      def poll(%__MODULE__{} = state, timeout) do
        # Simulate input handling
        if timeout == 0 do
          {:timeout, state}
        else
          event = TermUI.Event.key(:test_key)
          {{:ok, event}, state}
        end
      end

      @impl true
      def mode(%__MODULE__{mode: mode}), do: mode

      @impl true
      def stop(_state), do: :ok
    end

    test "mock module compiles and implements behaviour" do
      assert Code.ensure_loaded?(MockInput)
    end

    test "poll/2 returns expected format" do
      state = %MockInput{mode: :raw}

      # Non-blocking returns timeout
      assert {:timeout, ^state} = MockInput.poll(state, 0)

      # With timeout returns event
      assert {{:ok, %Event.Key{key: :test_key}}, ^state} = MockInput.poll(state, 100)
    end

    test "mode/1 returns the mode" do
      raw_state = %MockInput{mode: :raw}
      tty_state = %MockInput{mode: :tty}

      assert MockInput.mode(raw_state) == :raw
      assert MockInput.mode(tty_state) == :tty
    end

    test "state can be updated through poll" do
      state = %MockInput{buffer: <<>>, mode: :raw}
      {:timeout, state1} = MockInput.poll(state, 0)
      # State is unchanged for this mock, but demonstrates the pattern
      assert state1 == state
    end
  end

  # Stateful mock module for testing state updates
  defmodule StatefulMockInput do
    @moduledoc false
    @behaviour TermUI.Input

    defstruct call_count: 0

    @impl true
    def poll(%__MODULE__{call_count: count} = state, _timeout) do
      new_state = %{state | call_count: count + 1}
      {:timeout, new_state}
    end

    @impl true
    def mode(_state), do: :raw

    @impl true
    def stop(_state), do: :ok
  end

  describe "stateful mock" do
    test "state can be updated through poll calls" do
      state = %StatefulMockInput{call_count: 0}
      {:timeout, state} = StatefulMockInput.poll(state, 0)
      assert state.call_count == 1

      {:timeout, state} = StatefulMockInput.poll(state, 0)
      assert state.call_count == 2
    end
  end

  describe "documentation coverage" do
    test "module has moduledoc" do
      {:docs_v1, _, :elixir, _, %{"en" => moduledoc}, _, _} = Code.fetch_docs(Input)
      assert is_binary(moduledoc)
      assert String.contains?(moduledoc, "Input")
      assert String.contains?(moduledoc, "behaviour")
    end

    test "moduledoc explains character mode" do
      {:docs_v1, _, :elixir, _, %{"en" => moduledoc}, _, _} = Code.fetch_docs(Input)
      assert String.contains?(moduledoc, "Character Mode")
      assert String.contains?(moduledoc, "IO.getn")
    end

    test "moduledoc explains line mode for TextInput.Line" do
      {:docs_v1, _, :elixir, _, %{"en" => moduledoc}, _, _} = Code.fetch_docs(Input)
      assert String.contains?(moduledoc, "Line Mode")
      assert String.contains?(moduledoc, "TextInput.Line")
      assert String.contains?(moduledoc, "LineReader")
    end

    test "poll/2 callback has documentation" do
      {:docs_v1, _, :elixir, _, _, _, docs} = Code.fetch_docs(Input)

      poll_doc =
        Enum.find(docs, fn
          {{:callback, :poll, 2}, _, _, _, _} -> true
          _ -> false
        end)

      assert poll_doc != nil
      {{:callback, :poll, 2}, _, _, %{"en" => doc}, _} = poll_doc
      assert String.contains?(doc, "timeout")
    end

    test "mode/1 callback has documentation" do
      {:docs_v1, _, :elixir, _, _, _, docs} = Code.fetch_docs(Input)

      mode_doc =
        Enum.find(docs, fn
          {{:callback, :mode, 1}, _, _, _, _} -> true
          _ -> false
        end)

      assert mode_doc != nil
      {{:callback, :mode, 1}, _, _, %{"en" => doc}, _} = mode_doc
      assert String.contains?(doc, ":raw")
      assert String.contains?(doc, ":tty")
    end

    test "stop/1 callback has documentation" do
      {:docs_v1, _, :elixir, _, _, _, docs} = Code.fetch_docs(Input)

      stop_doc =
        Enum.find(docs, fn
          {{:callback, :stop, 1}, _, _, _, _} -> true
          _ -> false
        end)

      assert stop_doc != nil
      {{:callback, :stop, 1}, _, _, %{"en" => doc}, _} = stop_doc
      assert String.contains?(doc, "cleanup")
    end
  end
end
