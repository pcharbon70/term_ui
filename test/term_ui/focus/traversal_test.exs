defmodule TermUI.Focus.TraversalTest do
  use ExUnit.Case

  alias TermUI.Focus.Traversal
  alias TermUI.SpatialIndex

  setup do
    start_supervised!(SpatialIndex)
    :ok
  end

  describe "calculate_order/2" do
    test "orders by position when no tab indices" do
      pid = self()
      :ok = SpatialIndex.update(:c, pid, %{x: 0, y: 2, width: 1, height: 1})
      :ok = SpatialIndex.update(:a, pid, %{x: 0, y: 0, width: 1, height: 1})
      :ok = SpatialIndex.update(:b, pid, %{x: 0, y: 1, width: 1, height: 1})

      result = Traversal.calculate_order([:c, :a, :b])

      assert result == [:a, :b, :c]
    end

    test "tab_index takes precedence over position" do
      pid = self()
      :ok = SpatialIndex.update(:a, pid, %{x: 0, y: 0, width: 1, height: 1})
      :ok = SpatialIndex.update(:b, pid, %{x: 0, y: 1, width: 1, height: 1})
      :ok = SpatialIndex.update(:c, pid, %{x: 0, y: 2, width: 1, height: 1})

      tab_indices = %{a: 3, b: 1, c: 2}
      result = Traversal.calculate_order([:a, :b, :c], tab_indices: tab_indices)

      assert result == [:b, :c, :a]
    end

    test "nil tab_index sorts last" do
      pid = self()
      :ok = SpatialIndex.update(:a, pid, %{x: 0, y: 0, width: 1, height: 1})
      :ok = SpatialIndex.update(:b, pid, %{x: 0, y: 1, width: 1, height: 1})
      :ok = SpatialIndex.update(:c, pid, %{x: 0, y: 2, width: 1, height: 1})

      tab_indices = %{a: 1, c: 2}
      result = Traversal.calculate_order([:a, :b, :c], tab_indices: tab_indices)

      # b has nil tab_index, should be last
      assert List.last(result) == :b
    end
  end

  describe "next/2" do
    test "returns first when current is nil" do
      list = [:a, :b, :c]

      assert Traversal.next(list, nil) == :a
    end

    test "returns next component in list" do
      list = [:a, :b, :c]

      assert Traversal.next(list, :a) == :b
      assert Traversal.next(list, :b) == :c
    end

    test "wraps around to first" do
      list = [:a, :b, :c]

      assert Traversal.next(list, :c) == :a
    end

    test "returns first when current not in list" do
      list = [:a, :b, :c]

      assert Traversal.next(list, :unknown) == :a
    end

    test "returns nil for empty list" do
      assert Traversal.next([], :a) == nil
    end
  end

  describe "prev/2" do
    test "returns last when current is nil" do
      list = [:a, :b, :c]

      assert Traversal.prev(list, nil) == :c
    end

    test "returns previous component in list" do
      list = [:a, :b, :c]

      assert Traversal.prev(list, :c) == :b
      assert Traversal.prev(list, :b) == :a
    end

    test "wraps around to last" do
      list = [:a, :b, :c]

      assert Traversal.prev(list, :a) == :c
    end

    test "returns last when current not in list" do
      list = [:a, :b, :c]

      assert Traversal.prev(list, :unknown) == :c
    end

    test "returns nil for empty list" do
      assert Traversal.prev([], :a) == nil
    end
  end

  describe "should_skip?/2" do
    test "returns false by default" do
      refute Traversal.should_skip?(:component)
    end

    test "returns true when focusable is false" do
      opts = [focusable: %{component: false}]

      assert Traversal.should_skip?(:component, opts)
    end

    test "returns true when disabled is true" do
      opts = [disabled: %{component: true}]

      assert Traversal.should_skip?(:component, opts)
    end

    test "returns true when tab_index is negative" do
      opts = [tab_indices: %{component: -1}]

      assert Traversal.should_skip?(:component, opts)
    end

    test "returns false for positive tab_index" do
      opts = [tab_indices: %{component: 5}]

      refute Traversal.should_skip?(:component, opts)
    end

    test "returns false for zero tab_index" do
      opts = [tab_indices: %{component: 0}]

      refute Traversal.should_skip?(:component, opts)
    end
  end

  describe "filter_focusable/2" do
    test "removes non-focusable components" do
      components = [:a, :b, :c]
      opts = [focusable: %{b: false}]

      result = Traversal.filter_focusable(components, opts)

      assert result == [:a, :c]
    end

    test "removes disabled components" do
      components = [:a, :b, :c]
      opts = [disabled: %{a: true}]

      result = Traversal.filter_focusable(components, opts)

      assert result == [:b, :c]
    end

    test "removes components with negative tab_index" do
      components = [:a, :b, :c]
      opts = [tab_indices: %{c: -1}]

      result = Traversal.filter_focusable(components, opts)

      assert result == [:a, :b]
    end

    test "returns all when no filters" do
      components = [:a, :b, :c]

      result = Traversal.filter_focusable(components)

      assert result == [:a, :b, :c]
    end
  end
end
