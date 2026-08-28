defmodule TermUI.Input.SelectorTest do
  use ExUnit.Case, async: false

  alias TermUI.Input.Selector

  doctest TermUI.Input.Selector

  setup do
    # Ensure modules are fully loaded before testing function exports
    Code.ensure_loaded(TermUI.Input.Raw)
    Code.ensure_loaded(TermUI.Input.TTY)
    :ok
  end

  describe "select/1 with :raw mode" do
    test "returns TermUI.Input.Raw" do
      assert Selector.select(:raw) == TermUI.Input.Raw
    end

    test "returned module implements TermUI.Input behaviour" do
      handler = Selector.select(:raw)
      behaviours = handler.__info__(:attributes)[:behaviour] || []
      assert TermUI.Input in behaviours
    end

    test "returned module has new/0 function" do
      handler = Selector.select(:raw)
      assert function_exported?(handler, :new, 0)
    end

    test "returned module has poll/2 function" do
      handler = Selector.select(:raw)
      assert function_exported?(handler, :poll, 2)
    end

    test "returned module has mode/1 function" do
      handler = Selector.select(:raw)
      assert function_exported?(handler, :mode, 1)
    end
  end

  describe "select/1 with :tty mode" do
    test "returns TermUI.Input.TTY" do
      assert Selector.select(:tty) == TermUI.Input.TTY
    end

    test "returned module implements TermUI.Input behaviour" do
      handler = Selector.select(:tty)
      behaviours = handler.__info__(:attributes)[:behaviour] || []
      assert TermUI.Input in behaviours
    end

    test "returned module has new/0 function" do
      handler = Selector.select(:tty)
      assert function_exported?(handler, :new, 0)
    end

    test "returned module has poll/2 function" do
      handler = Selector.select(:tty)
      assert function_exported?(handler, :poll, 2)
    end

    test "returned module has mode/1 function" do
      handler = Selector.select(:tty)
      assert function_exported?(handler, :mode, 1)
    end
  end

  describe "select/1 with invalid mode" do
    test "raises ArgumentError for atom" do
      assert_raise ArgumentError, ~r/invalid input mode: :invalid/, fn ->
        Selector.select(:invalid)
      end
    end

    test "raises ArgumentError for nil" do
      assert_raise ArgumentError, ~r/invalid input mode: nil/, fn ->
        Selector.select(nil)
      end
    end

    test "raises ArgumentError for string" do
      assert_raise ArgumentError, ~r/invalid input mode: "raw"/, fn ->
        Selector.select("raw")
      end
    end

    test "error message mentions expected values" do
      assert_raise ArgumentError, ~r/expected :raw or :tty/, fn ->
        Selector.select(:unknown)
      end
    end
  end

  describe "select/0 auto-detection" do
    # Note: Testing select/0 is challenging because it calls Backend.Selector.select/0
    # which attempts to modify terminal state. We test the structure here.

    test "returns a module" do
      # This test will actually trigger backend selection
      # In test environment, this will typically return TTY mode
      handler = Selector.select()
      assert is_atom(handler)
    end

    test "returns either Input.Raw or Input.TTY" do
      handler = Selector.select()
      assert handler in [TermUI.Input.Raw, TermUI.Input.TTY]
    end

    test "returned handler implements TermUI.Input behaviour" do
      handler = Selector.select()
      behaviours = handler.__info__(:attributes)[:behaviour] || []
      assert TermUI.Input in behaviours
    end

    test "returned handler can create new state" do
      handler = Selector.select()
      state = handler.new()
      assert is_struct(state)
    end

    test "returned handler mode matches selection" do
      handler = Selector.select()
      state = handler.new()
      mode = handler.mode(state)

      cond do
        handler == TermUI.Input.Raw -> assert mode == :raw
        handler == TermUI.Input.TTY -> assert mode == :tty
      end
    end
  end

  describe "handler integration" do
    test "Raw handler mode returns :raw" do
      handler = Selector.select(:raw)
      state = handler.new()
      assert handler.mode(state) == :raw
    end

    test "TTY handler mode returns :tty" do
      handler = Selector.select(:tty)
      state = handler.new()
      assert handler.mode(state) == :tty
    end

    test "handlers can be used interchangeably" do
      # Both handlers should follow the same interface
      for mode <- [:raw, :tty] do
        handler = Selector.select(mode)
        state = handler.new()

        # State should be a struct
        assert is_struct(state)

        # Mode should match
        assert handler.mode(state) == mode

        # Handler should have poll function
        assert function_exported?(handler, :poll, 2)
      end
    end
  end

  describe "documentation" do
    test "module has documentation" do
      {:docs_v1, _, :elixir, _, %{"en" => moduledoc}, _, _} = Code.fetch_docs(Selector)
      assert is_binary(moduledoc)
      assert String.length(moduledoc) > 0
    end

    test "moduledoc explains relationship with Backend.Selector" do
      {:docs_v1, _, :elixir, _, %{"en" => moduledoc}, _, _} = Code.fetch_docs(Selector)
      assert String.contains?(moduledoc, "Backend.Selector")
    end

    test "moduledoc explains available handlers" do
      {:docs_v1, _, :elixir, _, %{"en" => moduledoc}, _, _} = Code.fetch_docs(Selector)
      assert String.contains?(moduledoc, "Input.Raw")
      assert String.contains?(moduledoc, "Input.TTY")
    end

    test "moduledoc explains LineReader is not included" do
      {:docs_v1, _, :elixir, _, %{"en" => moduledoc}, _, _} = Code.fetch_docs(Selector)
      assert String.contains?(moduledoc, "LineReader")
    end

    test "select/1 has documentation" do
      {:docs_v1, _, :elixir, _, _, _, functions} = Code.fetch_docs(Selector)

      select_1_doc =
        Enum.find(functions, fn
          {{:function, :select, 1}, _, _, _, _} -> true
          _ -> false
        end)

      assert select_1_doc != nil
      {_, _, _, %{"en" => doc}, _} = select_1_doc
      assert String.contains?(doc, "mode")
    end

    test "select/0 has documentation" do
      {:docs_v1, _, :elixir, _, _, _, functions} = Code.fetch_docs(Selector)

      select_0_doc =
        Enum.find(functions, fn
          {{:function, :select, 0}, _, _, _, _} -> true
          _ -> false
        end)

      assert select_0_doc != nil
      {_, _, _, %{"en" => doc}, _} = select_0_doc
      assert String.contains?(doc, "auto-detect")
    end
  end

  describe "type specifications" do
    test "module defines mode type" do
      # Verify the module exports the expected types
      # This is a compile-time check, so we just verify the module loads
      assert Code.ensure_loaded?(Selector)
    end

    test "select/1 returns a module" do
      result = Selector.select(:raw)
      assert is_atom(result)
      assert Code.ensure_loaded(result) == {:module, result}
    end
  end
end
