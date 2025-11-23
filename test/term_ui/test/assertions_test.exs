defmodule TermUI.Test.AssertionsTest do
  use ExUnit.Case, async: true
  use TermUI.Test.Assertions

  alias TermUI.Test.TestRenderer
  alias TermUI.Renderer.Cell

  describe "assert_text/4" do
    test "passes when text matches" do
      {:ok, renderer} = TestRenderer.new(10, 80)
      TestRenderer.write_string(renderer, 1, 1, "Hello")
      assert_text(renderer, 1, 1, "Hello")
      TestRenderer.destroy(renderer)
    end

    test "fails when text differs" do
      {:ok, renderer} = TestRenderer.new(10, 80)
      TestRenderer.write_string(renderer, 1, 1, "Hello")

      assert_raise ExUnit.AssertionError, ~r/Text assertion failed/, fn ->
        assert_text(renderer, 1, 1, "World")
      end

      TestRenderer.destroy(renderer)
    end
  end

  describe "refute_text/4" do
    test "passes when text differs" do
      {:ok, renderer} = TestRenderer.new(10, 80)
      TestRenderer.write_string(renderer, 1, 1, "Hello")
      refute_text(renderer, 1, 1, "World")
      TestRenderer.destroy(renderer)
    end

    test "fails when text matches" do
      {:ok, renderer} = TestRenderer.new(10, 80)
      TestRenderer.write_string(renderer, 1, 1, "Hello")

      assert_raise ExUnit.AssertionError, ~r/Text refutation failed/, fn ->
        refute_text(renderer, 1, 1, "Hello")
      end

      TestRenderer.destroy(renderer)
    end
  end

  describe "assert_text_contains/5" do
    test "passes when region contains text" do
      {:ok, renderer} = TestRenderer.new(10, 80)
      TestRenderer.write_string(renderer, 1, 1, "Hello, World!")
      assert_text_contains(renderer, 1, 1, 13, "World")
      TestRenderer.destroy(renderer)
    end

    test "fails when region does not contain text" do
      {:ok, renderer} = TestRenderer.new(10, 80)
      TestRenderer.write_string(renderer, 1, 1, "Hello")

      assert_raise ExUnit.AssertionError, ~r/Text contains assertion failed/, fn ->
        assert_text_contains(renderer, 1, 1, 5, "World")
      end

      TestRenderer.destroy(renderer)
    end
  end

  describe "refute_text_contains/5" do
    test "passes when region does not contain text" do
      {:ok, renderer} = TestRenderer.new(10, 80)
      TestRenderer.write_string(renderer, 1, 1, "Hello")
      refute_text_contains(renderer, 1, 1, 5, "World")
      TestRenderer.destroy(renderer)
    end

    test "fails when region contains text" do
      {:ok, renderer} = TestRenderer.new(10, 80)
      TestRenderer.write_string(renderer, 1, 1, "Hello, World!")

      assert_raise ExUnit.AssertionError, ~r/Text contains refutation failed/, fn ->
        refute_text_contains(renderer, 1, 1, 13, "World")
      end

      TestRenderer.destroy(renderer)
    end
  end

  describe "assert_text_exists/2" do
    test "passes when text found anywhere" do
      {:ok, renderer} = TestRenderer.new(10, 80)
      TestRenderer.write_string(renderer, 5, 10, "Error")
      assert_text_exists(renderer, "Error")
      TestRenderer.destroy(renderer)
    end

    test "fails when text not found" do
      {:ok, renderer} = TestRenderer.new(10, 80)

      assert_raise ExUnit.AssertionError, ~r/Text existence assertion failed/, fn ->
        assert_text_exists(renderer, "NotFound")
      end

      TestRenderer.destroy(renderer)
    end
  end

  describe "refute_text_exists/2" do
    test "passes when text not found" do
      {:ok, renderer} = TestRenderer.new(10, 80)
      TestRenderer.write_string(renderer, 1, 1, "Hello")
      refute_text_exists(renderer, "NotFound")
      TestRenderer.destroy(renderer)
    end

    test "fails when text found" do
      {:ok, renderer} = TestRenderer.new(10, 80)
      TestRenderer.write_string(renderer, 1, 1, "Error")

      assert_raise ExUnit.AssertionError, ~r/Text existence refutation failed/, fn ->
        refute_text_exists(renderer, "Error")
      end

      TestRenderer.destroy(renderer)
    end
  end

  describe "assert_style/4" do
    test "passes when fg matches" do
      {:ok, renderer} = TestRenderer.new(10, 80)
      cell = Cell.new("X", fg: :red)
      TestRenderer.set_cell(renderer, 1, 1, cell)
      assert_style(renderer, 1, 1, fg: :red)
      TestRenderer.destroy(renderer)
    end

    test "passes when bg matches" do
      {:ok, renderer} = TestRenderer.new(10, 80)
      cell = Cell.new("X", bg: :blue)
      TestRenderer.set_cell(renderer, 1, 1, cell)
      assert_style(renderer, 1, 1, bg: :blue)
      TestRenderer.destroy(renderer)
    end

    test "passes when attrs match" do
      {:ok, renderer} = TestRenderer.new(10, 80)
      cell = Cell.new("X", attrs: [:bold])
      TestRenderer.set_cell(renderer, 1, 1, cell)
      assert_style(renderer, 1, 1, attrs: [:bold])
      TestRenderer.destroy(renderer)
    end

    test "fails when fg differs" do
      {:ok, renderer} = TestRenderer.new(10, 80)
      cell = Cell.new("X", fg: :red)
      TestRenderer.set_cell(renderer, 1, 1, cell)

      assert_raise ExUnit.AssertionError, ~r/Style assertion failed/, fn ->
        assert_style(renderer, 1, 1, fg: :blue)
      end

      TestRenderer.destroy(renderer)
    end
  end

  describe "assert_attr/4" do
    test "passes when cell has attribute" do
      {:ok, renderer} = TestRenderer.new(10, 80)
      cell = Cell.new("X", attrs: [:bold, :underline])
      TestRenderer.set_cell(renderer, 1, 1, cell)
      assert_attr(renderer, 1, 1, :bold)
      TestRenderer.destroy(renderer)
    end

    test "fails when cell lacks attribute" do
      {:ok, renderer} = TestRenderer.new(10, 80)
      cell = Cell.new("X")
      TestRenderer.set_cell(renderer, 1, 1, cell)

      assert_raise ExUnit.AssertionError, ~r/Attribute assertion failed/, fn ->
        assert_attr(renderer, 1, 1, :bold)
      end

      TestRenderer.destroy(renderer)
    end
  end

  describe "refute_attr/4" do
    test "passes when cell lacks attribute" do
      {:ok, renderer} = TestRenderer.new(10, 80)
      cell = Cell.new("X")
      TestRenderer.set_cell(renderer, 1, 1, cell)
      refute_attr(renderer, 1, 1, :bold)
      TestRenderer.destroy(renderer)
    end

    test "fails when cell has attribute" do
      {:ok, renderer} = TestRenderer.new(10, 80)
      cell = Cell.new("X", attrs: [:bold])
      TestRenderer.set_cell(renderer, 1, 1, cell)

      assert_raise ExUnit.AssertionError, ~r/Attribute refutation failed/, fn ->
        refute_attr(renderer, 1, 1, :bold)
      end

      TestRenderer.destroy(renderer)
    end
  end

  describe "assert_state/3" do
    test "passes when state at path matches" do
      state = %{counter: %{value: 42}}
      assert_state(state, [:counter, :value], 42)
    end

    test "fails when state at path differs" do
      state = %{counter: %{value: 42}}

      assert_raise ExUnit.AssertionError, ~r/State assertion failed/, fn ->
        assert_state(state, [:counter, :value], 100)
      end
    end
  end

  describe "refute_state/3" do
    test "passes when state at path differs" do
      state = %{counter: %{value: 42}}
      refute_state(state, [:counter, :value], 100)
    end

    test "fails when state at path matches" do
      state = %{counter: %{value: 42}}

      assert_raise ExUnit.AssertionError, ~r/State refutation failed/, fn ->
        refute_state(state, [:counter, :value], 42)
      end
    end
  end

  describe "assert_state_exists/2" do
    test "passes when state at path exists" do
      state = %{counter: %{value: 42}}
      assert_state_exists(state, [:counter, :value])
    end

    test "fails when state at path is nil" do
      state = %{counter: %{value: nil}}

      assert_raise ExUnit.AssertionError, ~r/State existence assertion failed/, fn ->
        assert_state_exists(state, [:counter, :value])
      end
    end
  end

  describe "assert_snapshot/2" do
    test "passes when buffer matches snapshot" do
      {:ok, renderer} = TestRenderer.new(10, 80)
      TestRenderer.write_string(renderer, 1, 1, "Test")
      snapshot = TestRenderer.snapshot(renderer)
      assert_snapshot(renderer, snapshot)
      TestRenderer.destroy(renderer)
    end

    test "fails when buffer differs from snapshot" do
      {:ok, renderer} = TestRenderer.new(10, 80)
      TestRenderer.write_string(renderer, 1, 1, "Test")
      snapshot = TestRenderer.snapshot(renderer)
      TestRenderer.write_string(renderer, 1, 1, "Changed")

      assert_raise ExUnit.AssertionError, ~r/Snapshot assertion failed/, fn ->
        assert_snapshot(renderer, snapshot)
      end

      TestRenderer.destroy(renderer)
    end
  end

  describe "assert_empty/1" do
    test "passes for empty buffer" do
      {:ok, renderer} = TestRenderer.new(10, 80)
      assert_empty(renderer)
      TestRenderer.destroy(renderer)
    end

    test "fails for non-empty buffer" do
      {:ok, renderer} = TestRenderer.new(10, 80)
      TestRenderer.write_string(renderer, 1, 1, "Text")

      assert_raise ExUnit.AssertionError, ~r/Empty buffer assertion failed/, fn ->
        assert_empty(renderer)
      end

      TestRenderer.destroy(renderer)
    end
  end

  describe "assert_row/3" do
    test "passes when row matches" do
      {:ok, renderer} = TestRenderer.new(10, 80)
      TestRenderer.write_string(renderer, 1, 1, "Hello")
      assert_row(renderer, 1, "Hello")
      TestRenderer.destroy(renderer)
    end

    test "fails when row differs" do
      {:ok, renderer} = TestRenderer.new(10, 80)
      TestRenderer.write_string(renderer, 1, 1, "Hello")

      assert_raise ExUnit.AssertionError, ~r/Row assertion failed/, fn ->
        assert_row(renderer, 1, "World")
      end

      TestRenderer.destroy(renderer)
    end
  end
end
