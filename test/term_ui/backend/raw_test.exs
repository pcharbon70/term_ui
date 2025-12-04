defmodule TermUI.Backend.RawTest do
  @moduledoc """
  Unit tests for TermUI.Backend.Raw module.

  This test file covers the module structure and behaviour declaration.
  Callback implementation tests will be added in subsequent tasks.
  """

  use ExUnit.Case, async: true

  alias TermUI.Backend.Raw

  describe "module structure (Task 2.1.1)" do
    test "module compiles successfully" do
      assert Code.ensure_loaded?(Raw)
    end

    test "declares @behaviour TermUI.Backend" do
      # Check that the module declares the Backend behaviour
      behaviours = Raw.__info__(:attributes)[:behaviour] || []
      assert TermUI.Backend in behaviours
    end

    test "exports all required callbacks" do
      # Lifecycle callbacks
      assert function_exported?(Raw, :init, 1)
      assert function_exported?(Raw, :shutdown, 1)

      # Query callbacks
      assert function_exported?(Raw, :size, 1)

      # Cursor callbacks
      assert function_exported?(Raw, :move_cursor, 2)
      assert function_exported?(Raw, :hide_cursor, 1)
      assert function_exported?(Raw, :show_cursor, 1)

      # Rendering callbacks
      assert function_exported?(Raw, :clear, 1)
      assert function_exported?(Raw, :draw_cells, 2)
      assert function_exported?(Raw, :flush, 1)

      # Input callbacks
      assert function_exported?(Raw, :poll_event, 2)
    end

    test "has ANSI module aliased" do
      # The module should have access to TermUI.ANSI
      assert Raw.ansi_module() == TermUI.ANSI
    end
  end

  describe "documentation (Task 2.1.1)" do
    test "module has moduledoc" do
      {:docs_v1, _, :elixir, _, module_doc, _, _} = Code.fetch_docs(Raw)
      assert module_doc != :none
      assert module_doc != :hidden
    end

    test "moduledoc describes OTP 28+ requirement" do
      {:docs_v1, _, :elixir, _, %{"en" => doc}, _, _} = Code.fetch_docs(Raw)
      assert doc =~ "OTP 28"
    end

    test "moduledoc describes raw mode activation by Selector" do
      {:docs_v1, _, :elixir, _, %{"en" => doc}, _, _} = Code.fetch_docs(Raw)
      assert doc =~ "Selector"
      assert doc =~ "raw mode"
    end

    test "moduledoc describes initialization flow" do
      {:docs_v1, _, :elixir, _, %{"en" => doc}, _, _} = Code.fetch_docs(Raw)
      assert doc =~ "init/1"
      assert doc =~ "alternate screen"
    end

    test "init/1 has documentation" do
      {:docs_v1, _, :elixir, _, _, _, docs} = Code.fetch_docs(Raw)

      func_docs =
        docs
        |> Enum.filter(fn
          {{:function, :init, 1}, _, _, _, _} -> true
          _ -> false
        end)

      assert length(func_docs) == 1
    end

    test "shutdown/1 has documentation" do
      {:docs_v1, _, :elixir, _, _, _, docs} = Code.fetch_docs(Raw)

      func_docs =
        docs
        |> Enum.filter(fn
          {{:function, :shutdown, 1}, _, _, _, _} -> true
          _ -> false
        end)

      assert length(func_docs) == 1
    end
  end

  describe "stub callbacks (Task 2.1.1)" do
    # These tests verify the stubs work correctly
    # Full implementation tests will be added in subsequent tasks

    test "init/1 returns {:ok, state}" do
      assert {:ok, _state} = Raw.init([])
    end

    test "init/1 accepts options" do
      assert {:ok, _state} = Raw.init(alternate_screen: false, hide_cursor: true)
    end

    test "shutdown/1 returns :ok" do
      {:ok, state} = Raw.init([])
      assert :ok = Raw.shutdown(state)
    end

    test "size/1 returns result tuple" do
      {:ok, state} = Raw.init([])
      result = Raw.size(state)
      # Stub returns {:error, :enotsup}
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "move_cursor/2 returns {:ok, state}" do
      {:ok, state} = Raw.init([])
      assert {:ok, _updated_state} = Raw.move_cursor(state, {1, 1})
    end

    test "hide_cursor/1 returns {:ok, state}" do
      {:ok, state} = Raw.init([])
      assert {:ok, _updated_state} = Raw.hide_cursor(state)
    end

    test "show_cursor/1 returns {:ok, state}" do
      {:ok, state} = Raw.init([])
      assert {:ok, _updated_state} = Raw.show_cursor(state)
    end

    test "clear/1 returns {:ok, state}" do
      {:ok, state} = Raw.init([])
      assert {:ok, _updated_state} = Raw.clear(state)
    end

    test "draw_cells/2 returns {:ok, state}" do
      {:ok, state} = Raw.init([])
      cells = [{{1, 1}, {"A", :default, :default, []}}]
      assert {:ok, _updated_state} = Raw.draw_cells(state, cells)
    end

    test "flush/1 returns {:ok, state}" do
      {:ok, state} = Raw.init([])
      assert {:ok, _updated_state} = Raw.flush(state)
    end

    test "poll_event/2 returns valid result" do
      {:ok, state} = Raw.init([])
      result = Raw.poll_event(state, 0)
      # Stub returns {:timeout, state}
      assert match?({:ok, _, _}, result) or match?({:timeout, _}, result) or
               match?({:error, _, _}, result)
    end
  end
end
