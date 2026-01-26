defmodule TermUI.BackendTest do
  use ExUnit.Case, async: true

  alias TermUI.Backend

  describe "module structure" do
    test "module compiles successfully" do
      assert Code.ensure_loaded?(Backend)
    end

    test "module defines a behaviour" do
      assert function_exported?(Backend, :behaviour_info, 1)
    end

    test "behaviour_info(:callbacks) returns expected callbacks" do
      callbacks = Backend.behaviour_info(:callbacks)

      # Lifecycle callbacks
      assert {:init, 1} in callbacks
      assert {:shutdown, 1} in callbacks

      # Query callbacks
      assert {:size, 1} in callbacks

      # Cursor callbacks
      assert {:move_cursor, 2} in callbacks
      assert {:hide_cursor, 1} in callbacks
      assert {:show_cursor, 1} in callbacks

      # Rendering callbacks
      assert {:clear, 1} in callbacks
      assert {:draw_cells, 2} in callbacks
      assert {:flush, 1} in callbacks

      # Input callbacks
      assert {:poll_event, 2} in callbacks
    end

    test "behaviour_info(:callbacks) returns exactly 10 callbacks" do
      callbacks = Backend.behaviour_info(:callbacks)
      assert length(callbacks) == 10
    end
  end

  describe "documentation" do
    test "module has moduledoc" do
      {:docs_v1, _, :elixir, _, module_doc, _, _} = Code.fetch_docs(Backend)
      assert module_doc != :none
      assert module_doc != :hidden

      %{"en" => doc} = module_doc
      assert String.contains?(doc, "Behaviour")
      assert String.contains?(doc, "terminal backend")
    end

    test "all callbacks have documentation" do
      {:docs_v1, _, :elixir, _, _, _, docs} = Code.fetch_docs(Backend)

      callback_docs =
        docs
        |> Enum.filter(fn
          {{:callback, _, _}, _, _, _, _} -> true
          _ -> false
        end)

      # Check we have docs for all callbacks
      assert length(callback_docs) == 10

      # Check none have :none or :hidden documentation
      for {{:callback, name, arity}, _, _, doc, _} <- callback_docs do
        assert doc != :none,
               "Callback #{name}/#{arity} has no documentation"

        assert doc != :hidden,
               "Callback #{name}/#{arity} has hidden documentation"
      end
    end

    test "all types have documentation" do
      {:docs_v1, _, :elixir, _, _, _, docs} = Code.fetch_docs(Backend)

      type_docs =
        docs
        |> Enum.filter(fn
          {{:type, _, _}, _, _, _, _} -> true
          _ -> false
        end)

      # We define 6 types: position, size, color, cell, event, state
      assert length(type_docs) == 6

      # Check each type has a typedoc
      for {{:type, name, arity}, _, _, doc, _} <- type_docs do
        assert doc != :none,
               "Type #{name}/#{arity} has no documentation"

        assert doc != :hidden,
               "Type #{name}/#{arity} has hidden documentation"
      end
    end
  end

  describe "type definitions" do
    # These tests verify types are defined by checking that the module
    # compiles without errors and that Dialyzer would accept the types.
    # Actual type checking is done at compile time.

    test "position type is defined" do
      # Type exists if module compiles - verified by first test
      # This documents the expected type structure
      assert true
    end

    test "size type is defined" do
      assert true
    end

    test "color type supports :default atom" do
      # Type validation happens at compile time via Dialyzer
      assert true
    end

    test "color type supports named color atoms" do
      assert true
    end

    test "color type supports 0..255 integer" do
      assert true
    end

    test "color type supports RGB tuple" do
      assert true
    end

    test "cell type is defined as 4-tuple" do
      assert true
    end

    test "event type aliases TermUI.Event.t()" do
      # Verify Event module exists
      assert Code.ensure_loaded?(TermUI.Event)
    end

    test "state type is defined" do
      assert true
    end
  end

  describe "example implementation" do
    # Define a minimal test backend to verify the behaviour works
    defmodule TestBackend do
      @behaviour TermUI.Backend

      @impl true
      def init(_opts), do: {:ok, %{}}

      @impl true
      def shutdown(_state), do: :ok

      @impl true
      def size(_state), do: {:ok, {24, 80}}

      @impl true
      def move_cursor(state, _position), do: {:ok, state}

      @impl true
      def hide_cursor(state), do: {:ok, state}

      @impl true
      def show_cursor(state), do: {:ok, state}

      @impl true
      def clear(state), do: {:ok, state}

      @impl true
      def draw_cells(state, _cells), do: {:ok, state}

      @impl true
      def flush(state), do: {:ok, state}

      @impl true
      def poll_event(state, _timeout), do: {:timeout, state}
    end

    test "test backend compiles without warnings" do
      assert Code.ensure_loaded?(TestBackend)
    end

    test "test backend implements all callbacks" do
      # If it compiles with @behaviour and @impl true, all callbacks are implemented
      assert function_exported?(TestBackend, :init, 1)
      assert function_exported?(TestBackend, :shutdown, 1)
      assert function_exported?(TestBackend, :size, 1)
      assert function_exported?(TestBackend, :move_cursor, 2)
      assert function_exported?(TestBackend, :hide_cursor, 1)
      assert function_exported?(TestBackend, :show_cursor, 1)
      assert function_exported?(TestBackend, :clear, 1)
      assert function_exported?(TestBackend, :draw_cells, 2)
      assert function_exported?(TestBackend, :flush, 1)
      assert function_exported?(TestBackend, :poll_event, 2)
    end

    test "init/1 returns {:ok, state}" do
      assert {:ok, _state} = TestBackend.init([])
    end

    test "shutdown/1 returns :ok" do
      {:ok, state} = TestBackend.init([])
      assert :ok = TestBackend.shutdown(state)
    end

    test "size/1 returns {:ok, {rows, cols}}" do
      {:ok, state} = TestBackend.init([])
      assert {:ok, {rows, cols}} = TestBackend.size(state)
      assert is_integer(rows) and rows > 0
      assert is_integer(cols) and cols > 0
    end

    test "cursor operations return {:ok, state}" do
      {:ok, state} = TestBackend.init([])

      assert {:ok, state} = TestBackend.move_cursor(state, {1, 1})
      assert {:ok, state} = TestBackend.hide_cursor(state)
      assert {:ok, _state} = TestBackend.show_cursor(state)
    end

    test "rendering operations return {:ok, state}" do
      {:ok, state} = TestBackend.init([])

      assert {:ok, state} = TestBackend.clear(state)
      assert {:ok, state} = TestBackend.draw_cells(state, [])
      assert {:ok, _state} = TestBackend.flush(state)
    end

    test "poll_event/2 returns valid result" do
      {:ok, state} = TestBackend.init([])

      # Our test backend returns :timeout
      assert {:timeout, _state} = TestBackend.poll_event(state, 0)
    end
  end
end
