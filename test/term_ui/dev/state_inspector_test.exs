defmodule TermUI.Dev.StateInspectorTest do
  use ExUnit.Case, async: true

  alias TermUI.Dev.StateInspector

  describe "render/2" do
    test "renders empty panel when nil" do
      result = StateInspector.render(nil, %{width: 80, height: 24})
      assert result.type == :empty
    end

    test "renders state panel for component" do
      component_info = %{
        module: TestModule,
        state: %{count: 42}
      }

      result = StateInspector.render(component_info, %{width: 80, height: 24})

      assert result.type == :positioned
      assert result.z == 190
    end
  end

  describe "render_state_tree/2" do
    test "renders empty map" do
      result = StateInspector.render_state_tree(%{}, 0)
      assert result == ["%{}"]
    end

    test "renders simple map" do
      result = StateInspector.render_state_tree(%{name: "test", count: 42}, 0)

      assert Enum.any?(result, &String.contains?(&1, "name"))
      assert Enum.any?(result, &String.contains?(&1, "test"))
      assert Enum.any?(result, &String.contains?(&1, "count"))
      assert Enum.any?(result, &String.contains?(&1, "42"))
    end

    test "renders nested map" do
      state = %{
        user: %{
          name: "Alice",
          age: 30
        }
      }

      result = StateInspector.render_state_tree(state, 0)

      assert Enum.any?(result, &String.contains?(&1, "user"))
      assert Enum.any?(result, &String.contains?(&1, "name"))
      assert Enum.any?(result, &String.contains?(&1, "Alice"))
    end

    test "renders empty list" do
      result = StateInspector.render_state_tree([], 0)
      assert result == ["[]"]
    end

    test "renders list with items" do
      result = StateInspector.render_state_tree([1, 2, 3], 0)

      assert Enum.any?(result, &String.contains?(&1, "[0]"))
      assert Enum.any?(result, &String.contains?(&1, "1"))
    end

    test "truncates long lists" do
      long_list = Enum.to_list(1..20)
      result = StateInspector.render_state_tree(long_list, 0)

      assert Enum.any?(result, &String.contains?(&1, "... (15 more)"))
    end

    test "renders tuple" do
      result = StateInspector.render_state_tree({:ok, "value"}, 0)

      assert Enum.any?(result, &String.contains?(&1, ":ok"))
    end

    test "renders simple values" do
      assert StateInspector.render_state_tree(:atom, 0) == [":atom"]
      assert StateInspector.render_state_tree(42, 0) == ["42"]
      assert StateInspector.render_state_tree("string", 0) == ["\"string\""]
      assert StateInspector.render_state_tree(nil, 0) == ["nil"]
      assert StateInspector.render_state_tree(true, 0) == ["true"]
    end

    test "adds indentation for depth" do
      state = %{nested: %{value: 1}}
      result = StateInspector.render_state_tree(state, 1)

      # Should have extra indentation
      assert Enum.any?(result, fn line -> String.starts_with?(line, "  ") end)
    end
  end

  describe "diff_states/2" do
    test "returns empty for identical states" do
      state = %{a: 1, b: 2}
      assert StateInspector.diff_states(state, state) == []
    end

    test "detects changed values" do
      old = %{a: 1, b: 2}
      new = %{a: 1, b: 3}

      paths = StateInspector.diff_states(old, new)
      assert [:b] in paths
    end

    test "detects nested changes" do
      old = %{user: %{name: "Alice", age: 30}}
      new = %{user: %{name: "Alice", age: 31}}

      paths = StateInspector.diff_states(old, new)
      assert [:user, :age] in paths
    end

    test "detects added keys" do
      old = %{a: 1}
      new = %{a: 1, b: 2}

      paths = StateInspector.diff_states(old, new)
      assert [:b] in paths
    end

    test "detects removed keys" do
      old = %{a: 1, b: 2}
      new = %{a: 1}

      paths = StateInspector.diff_states(old, new)
      assert [:b] in paths
    end
  end
end
