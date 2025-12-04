defmodule TermUI.Backend.SelectorTest do
  use ExUnit.Case, async: true

  alias TermUI.Backend.Selector

  describe "module structure" do
    test "module compiles successfully" do
      assert Code.ensure_loaded?(Selector)
    end

    test "module exports select/0" do
      assert function_exported?(Selector, :select, 0)
    end

    test "module exports select/1" do
      assert function_exported?(Selector, :select, 1)
    end
  end

  describe "documentation" do
    test "module has comprehensive moduledoc" do
      {:docs_v1, _, :elixir, _, module_doc, _, _} = Code.fetch_docs(Selector)
      assert module_doc != :none
      assert module_doc != :hidden

      %{"en" => doc} = module_doc

      # Check key documentation topics are covered
      assert String.contains?(doc, "try raw mode first"),
             "Should document the selection strategy"

      assert String.contains?(doc, "heuristics") or String.contains?(doc, "Heuristics"),
             "Should explain why heuristics are insufficient"

      assert String.contains?(doc, "Nerves"),
             "Should mention Nerves as an example"

      assert String.contains?(doc, "SSH"),
             "Should mention SSH sessions as an example"

      assert String.contains?(doc, "IEx") or String.contains?(doc, "remsh"),
             "Should mention remote IEx as an example"

      assert String.contains?(doc, "{:raw, state}"),
             "Should document raw return value"

      assert String.contains?(doc, "{:tty, capabilities}"),
             "Should document tty return value"
    end

    test "select/0 has documentation" do
      {:docs_v1, _, :elixir, _, _, _, docs} = Code.fetch_docs(Selector)

      select_0_doc =
        Enum.find(docs, fn
          {{:function, :select, 0}, _, _, _, _} -> true
          _ -> false
        end)

      assert select_0_doc != nil, "select/0 should have documentation"
      {{:function, :select, 0}, _, _, doc, _} = select_0_doc
      assert doc != :none
      assert doc != :hidden
    end

    test "select/1 has documentation" do
      {:docs_v1, _, :elixir, _, _, _, docs} = Code.fetch_docs(Selector)

      select_1_doc =
        Enum.find(docs, fn
          {{:function, :select, 1}, _, _, _, _} -> true
          _ -> false
        end)

      assert select_1_doc != nil, "select/1 should have documentation"
      {{:function, :select, 1}, _, _, doc, _} = select_1_doc
      assert doc != :none
      assert doc != :hidden
    end
  end

  describe "type definitions" do
    test "selection_result type is defined" do
      {:docs_v1, _, :elixir, _, _, _, docs} = Code.fetch_docs(Selector)

      type_docs =
        docs
        |> Enum.filter(fn
          {{:type, :selection_result, _}, _, _, _, _} -> true
          _ -> false
        end)

      assert length(type_docs) == 1, "selection_result type should be defined"
    end

    test "raw_state type is defined" do
      {:docs_v1, _, :elixir, _, _, _, docs} = Code.fetch_docs(Selector)

      type_docs =
        docs
        |> Enum.filter(fn
          {{:type, :raw_state, _}, _, _, _, _} -> true
          _ -> false
        end)

      assert length(type_docs) == 1, "raw_state type should be defined"
    end

    test "capabilities type is defined" do
      {:docs_v1, _, :elixir, _, _, _, docs} = Code.fetch_docs(Selector)

      type_docs =
        docs
        |> Enum.filter(fn
          {{:type, :capabilities, _}, _, _, _, _} -> true
          _ -> false
        end)

      assert length(type_docs) == 1, "capabilities type should be defined"
    end

    test "color_depth type is defined" do
      {:docs_v1, _, :elixir, _, _, _, docs} = Code.fetch_docs(Selector)

      type_docs =
        docs
        |> Enum.filter(fn
          {{:type, :color_depth, _}, _, _, _, _} -> true
          _ -> false
        end)

      assert length(type_docs) == 1, "color_depth type should be defined"
    end
  end

  describe "select/0 return format" do
    test "returns a two-element tuple" do
      result = Selector.select()
      assert is_tuple(result)
      assert tuple_size(result) == 2
    end

    test "returns either {:raw, _} or {:tty, _}" do
      result = Selector.select()

      case result do
        {:raw, state} ->
          assert is_map(state)

        {:tty, capabilities} ->
          assert is_map(capabilities)

        other ->
          flunk("Unexpected return value: #{inspect(other)}")
      end
    end

    test "tty capabilities has expected keys" do
      # Current placeholder always returns TTY
      {:tty, capabilities} = Selector.select()

      assert Map.has_key?(capabilities, :colors)
      assert Map.has_key?(capabilities, :unicode)
      assert Map.has_key?(capabilities, :dimensions)
      assert Map.has_key?(capabilities, :terminal)
    end
  end

  describe "select/1 with :auto" do
    test "delegates to select/0" do
      # Both should return the same format
      result_0 = Selector.select()
      result_1 = Selector.select(:auto)

      assert elem(result_0, 0) == elem(result_1, 0)
    end
  end

  describe "select/1 with explicit module" do
    test "returns {:explicit, module, []} for module atom" do
      result = Selector.select(SomeModule)
      assert result == {:explicit, SomeModule, []}
    end

    test "returns {:explicit, module, opts} for {module, opts} tuple" do
      result = Selector.select({SomeModule, [option: :value]})
      assert result == {:explicit, SomeModule, [option: :value]}
    end

    test "works with actual backend module atoms" do
      result = Selector.select(TermUI.Backend.TTY)
      assert result == {:explicit, TermUI.Backend.TTY, []}
    end

    test "passes through options correctly" do
      opts = [line_mode: :full_redraw, alternate_screen: false]
      result = Selector.select({TermUI.Backend.TTY, opts})
      assert result == {:explicit, TermUI.Backend.TTY, opts}
    end
  end

  describe "try_raw_mode/0 core selection logic" do
    test "returns a two-element tuple" do
      result = Selector.try_raw_mode()
      assert is_tuple(result)
      assert tuple_size(result) == 2
    end

    test "first element is :raw or :tty" do
      {mode, _} = Selector.try_raw_mode()
      assert mode in [:raw, :tty]
    end

    test "raw mode returns map with raw_mode_started key" do
      case Selector.try_raw_mode() do
        {:raw, state} ->
          assert is_map(state)
          assert Map.has_key?(state, :raw_mode_started)
          assert state.raw_mode_started == true

        {:tty, _} ->
          # TTY mode is also valid - depends on environment
          :ok
      end
    end

    test "tty mode returns capabilities map" do
      case Selector.try_raw_mode() do
        {:tty, capabilities} ->
          assert is_map(capabilities)
          assert Map.has_key?(capabilities, :colors)
          assert Map.has_key?(capabilities, :unicode)
          assert Map.has_key?(capabilities, :dimensions)
          assert Map.has_key?(capabilities, :terminal)

        {:raw, _} ->
          # Raw mode is also valid - depends on environment
          :ok
      end
    end
  end

  describe "attempt_raw_mode/0" do
    # These tests verify the attempt_raw_mode function behavior
    # The actual result depends on OTP version and terminal state

    test "returns a valid selection result" do
      result = Selector.attempt_raw_mode()
      assert is_tuple(result)
      assert tuple_size(result) == 2

      case result do
        {:raw, state} ->
          assert is_map(state)
          assert state.raw_mode_started == true

        {:tty, capabilities} ->
          assert is_map(capabilities)

        other ->
          flunk("Unexpected result: #{inspect(other)}")
      end
    end

    test "handles :already_started error by returning tty mode" do
      # In a test environment with IEx/shell already running,
      # we expect {:error, :already_started} which should return TTY mode
      # This test documents expected behavior - actual result depends on environment
      result = Selector.attempt_raw_mode()

      case result do
        {:tty, capabilities} ->
          assert is_map(capabilities)
          assert Map.has_key?(capabilities, :colors)

        {:raw, _state} ->
          # Raw mode succeeded - also valid
          :ok
      end
    end
  end

  describe "pre-OTP 28 fallback" do
    # Test that the try/rescue in try_raw_mode handles UndefinedFunctionError
    # We can't easily simulate this without mocking, so we test the structure

    test "try_raw_mode wraps attempt_raw_mode in try/rescue" do
      # The function should not raise even if shell.start_interactive doesn't exist
      # This is verified by the function returning a valid result
      result = Selector.try_raw_mode()
      assert match?({:raw, _}, result) or match?({:tty, _}, result)
    end

    test "function exports attempt_raw_mode for testability" do
      # attempt_raw_mode is exported (doc false) to allow testing the core logic
      assert function_exported?(Selector, :attempt_raw_mode, 0)
    end
  end

  describe "raw mode state format" do
    test "raw state contains raw_mode_started boolean" do
      # When raw mode succeeds, state should have this key
      # Test the expected structure
      expected_keys = [:raw_mode_started]

      case Selector.try_raw_mode() do
        {:raw, state} ->
          for key <- expected_keys do
            assert Map.has_key?(state, key), "Raw state should have #{key} key"
          end

          assert is_boolean(state.raw_mode_started)

        {:tty, _} ->
          # TTY mode - raw state format not applicable
          :ok
      end
    end
  end

  describe "integration with select/0" do
    test "select/0 delegates to try_raw_mode/0" do
      # Both should return compatible formats
      select_result = Selector.select()
      try_result = Selector.try_raw_mode()

      # Both should be same mode (raw or tty)
      assert elem(select_result, 0) == elem(try_result, 0)
    end
  end
end
