defmodule TermUI.Dev.UIInspectorTest do
  use ExUnit.Case, async: true

  alias TermUI.Dev.UIInspector

  describe "render/3" do
    test "renders overlay for components" do
      components = %{
        :comp1 => %{
          module: MyModule,
          state: %{},
          render_time: 1000,
          bounds: %{x: 0, y: 0, width: 20, height: 10}
        }
      }

      result = UIInspector.render(components, nil, %{width: 80, height: 24})

      assert result.type == :overlay
      assert result.z == 200
    end

    test "renders empty overlay for no components" do
      result = UIInspector.render(%{}, nil, %{width: 80, height: 24})

      assert result.type == :overlay
    end
  end

  describe "render_component_boundary/3" do
    test "renders boundary with label" do
      info = %{
        module: MyApp.TestComponent,
        state: %{},
        render_time: 1500,
        bounds: %{x: 5, y: 5, width: 30, height: 10}
      }

      result = UIInspector.render_component_boundary(:test, info, false)

      assert result.type == :positioned
      assert result.x == 5
      assert result.y == 5
    end

    test "uses different style when selected" do
      info = %{
        module: TestComponent,
        state: %{},
        render_time: 100,
        bounds: %{x: 0, y: 0, width: 20, height: 5}
      }

      result = UIInspector.render_component_boundary(:test, info, true)
      assert result.style == :selected

      result = UIInspector.render_component_boundary(:test, info, false)
      assert result.style == :normal
    end
  end

  describe "create_labeled_border/3" do
    test "creates border with centered label" do
      result = UIInspector.create_labeled_border("Test", 20, "─")

      assert String.length(result) == 20
      assert String.contains?(result, "[ Test ]")
    end

    test "truncates long labels" do
      result = UIInspector.create_labeled_border("VeryLongLabelThatDoesNotFit", 15, "─")

      assert String.length(result) == 15
    end
  end

  describe "get_module_name/1" do
    test "extracts short name from module atom" do
      assert UIInspector.get_module_name(MyApp.Widgets.Button) == "Button"
      assert UIInspector.get_module_name(SimpleModule) == "SimpleModule"
    end

    test "returns Unknown for non-atom" do
      assert UIInspector.get_module_name("not an atom") == "Unknown"
    end
  end

  describe "format_render_time/1" do
    test "formats microseconds" do
      assert UIInspector.format_render_time(500) == "500μs"
    end

    test "formats milliseconds" do
      assert UIInspector.format_render_time(1500) == "1.5ms"
      assert UIInspector.format_render_time(500_000) == "500.0ms"
    end

    test "formats seconds" do
      assert UIInspector.format_render_time(1_500_000) == "1.5s"
    end
  end

  describe "find_component_at/3" do
    test "finds component at position" do
      components = %{
        :comp1 => %{
          bounds: %{x: 0, y: 0, width: 20, height: 10}
        },
        :comp2 => %{
          bounds: %{x: 30, y: 30, width: 10, height: 10}
        }
      }

      assert UIInspector.find_component_at(components, 10, 5) == :comp1
      assert UIInspector.find_component_at(components, 35, 35) == :comp2
      assert UIInspector.find_component_at(components, 50, 50) == nil
    end

    test "prefers smaller component when overlapping" do
      components = %{
        :parent => %{
          bounds: %{x: 0, y: 0, width: 50, height: 50}
        },
        :child => %{
          bounds: %{x: 10, y: 10, width: 10, height: 10}
        }
      }

      # Click inside child should find child (smaller)
      assert UIInspector.find_component_at(components, 15, 15) == :child
    end
  end

  describe "get_state_summary/1" do
    test "summarizes map state" do
      assert UIInspector.get_state_summary(%{a: 1, b: 2}) =~ "a"
      assert UIInspector.get_state_summary(%{a: 1, b: 2}) =~ "b"
    end

    test "truncates large maps" do
      state = %{a: 1, b: 2, c: 3, d: 4, e: 5}
      summary = UIInspector.get_state_summary(state)
      assert summary =~ "..."
      assert summary =~ "+2"
    end

    test "summarizes list state" do
      assert UIInspector.get_state_summary([1, 2, 3]) == "List[3]"
    end
  end
end
