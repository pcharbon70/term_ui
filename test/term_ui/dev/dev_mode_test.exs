defmodule TermUI.Dev.DevModeTest do
  use ExUnit.Case, async: false

  alias TermUI.Dev.DevMode

  setup do
    # Start DevMode server for each test
    start_supervised!(DevMode)
    :ok
  end

  describe "enable/disable" do
    test "starts disabled" do
      refute DevMode.enabled?()
    end

    test "can enable development mode" do
      :ok = DevMode.enable()
      assert DevMode.enabled?()
    end

    test "can disable development mode" do
      DevMode.enable()
      :ok = DevMode.disable()
      refute DevMode.enabled?()
    end
  end

  describe "UI inspector" do
    test "starts disabled" do
      refute DevMode.ui_inspector_enabled?()
    end

    test "can toggle UI inspector" do
      assert DevMode.toggle_ui_inspector() == true
      assert DevMode.ui_inspector_enabled?()

      assert DevMode.toggle_ui_inspector() == false
      refute DevMode.ui_inspector_enabled?()
    end
  end

  describe "state inspector" do
    test "starts disabled" do
      refute DevMode.state_inspector_enabled?()
    end

    test "can toggle state inspector" do
      assert DevMode.toggle_state_inspector() == true
      assert DevMode.state_inspector_enabled?()

      assert DevMode.toggle_state_inspector() == false
      refute DevMode.state_inspector_enabled?()
    end
  end

  describe "performance monitor" do
    test "starts disabled" do
      refute DevMode.perf_monitor_enabled?()
    end

    test "can toggle performance monitor" do
      assert DevMode.toggle_perf_monitor() == true
      assert DevMode.perf_monitor_enabled?()

      assert DevMode.toggle_perf_monitor() == false
      refute DevMode.perf_monitor_enabled?()
    end
  end

  describe "component registration" do
    test "can register a component" do
      bounds = %{x: 0, y: 0, width: 10, height: 5}
      :ok = DevMode.register_component(:test_component, TestModule, %{foo: "bar"}, bounds)

      components = DevMode.get_components()
      assert Map.has_key?(components, :test_component)
      assert components[:test_component].module == TestModule
      assert components[:test_component].state == %{foo: "bar"}
    end

    test "can unregister a component" do
      bounds = %{x: 0, y: 0, width: 10, height: 5}
      DevMode.register_component(:test_component, TestModule, %{}, bounds)
      :ok = DevMode.unregister_component(:test_component)

      components = DevMode.get_components()
      refute Map.has_key?(components, :test_component)
    end

    test "can update component state" do
      bounds = %{x: 0, y: 0, width: 10, height: 5}
      DevMode.register_component(:test_component, TestModule, %{count: 0}, bounds)
      :ok = DevMode.update_component_state(:test_component, %{count: 42})

      components = DevMode.get_components()
      assert components[:test_component].state == %{count: 42}
    end

    test "can record render time" do
      bounds = %{x: 0, y: 0, width: 10, height: 5}
      DevMode.register_component(:test_component, TestModule, %{}, bounds)
      :ok = DevMode.record_render_time(:test_component, 1500)

      components = DevMode.get_components()
      assert components[:test_component].render_time == 1500
    end
  end

  describe "component selection" do
    test "starts with no selection" do
      assert DevMode.get_selected_component() == nil
    end

    test "can select a component" do
      bounds = %{x: 0, y: 0, width: 10, height: 5}
      DevMode.register_component(:test_component, TestModule, %{}, bounds)
      :ok = DevMode.select_component(:test_component)

      assert DevMode.get_selected_component() == :test_component
    end

    test "unregistering selected component clears selection" do
      bounds = %{x: 0, y: 0, width: 10, height: 5}
      DevMode.register_component(:test_component, TestModule, %{}, bounds)
      DevMode.select_component(:test_component)
      DevMode.unregister_component(:test_component)

      assert DevMode.get_selected_component() == nil
    end
  end

  describe "metrics" do
    test "starts with zero metrics" do
      metrics = DevMode.get_metrics()
      assert metrics.fps == 0.0
      assert metrics.frame_times == []
    end

    test "record_frame updates metrics" do
      DevMode.record_frame(16_000)
      DevMode.record_frame(17_000)
      DevMode.record_frame(15_000)

      metrics = DevMode.get_metrics()
      assert length(metrics.frame_times) == 3
      assert metrics.fps > 0
      assert metrics.memory > 0
      assert metrics.process_count > 0
    end

    test "FPS calculation from frame times" do
      # Record 60 frames at 16.67ms each (60 FPS)
      for _ <- 1..60 do
        DevMode.record_frame(16_667)
      end

      metrics = DevMode.get_metrics()
      # Should be approximately 60 FPS
      assert_in_delta metrics.fps, 60.0, 1.0
    end
  end

  describe "keyboard shortcuts" do
    test "handles shortcuts when enabled" do
      DevMode.enable()

      # Toggle UI inspector with Ctrl+Shift+I
      assert DevMode.handle_shortcut(:i, [:ctrl, :shift]) == :handled
      assert DevMode.ui_inspector_enabled?()

      # Toggle state inspector with Ctrl+Shift+S
      assert DevMode.handle_shortcut(:s, [:ctrl, :shift]) == :handled
      assert DevMode.state_inspector_enabled?()

      # Toggle perf monitor with Ctrl+Shift+P
      assert DevMode.handle_shortcut(:p, [:ctrl, :shift]) == :handled
      assert DevMode.perf_monitor_enabled?()
    end

    test "ignores shortcuts when disabled" do
      # DevMode not enabled
      assert DevMode.handle_shortcut(:i, [:ctrl, :shift]) == :not_handled
      refute DevMode.ui_inspector_enabled?()
    end

    test "ignores non-dev shortcuts" do
      DevMode.enable()
      assert DevMode.handle_shortcut(:x, [:ctrl, :shift]) == :not_handled
    end

    test "requires both ctrl and shift modifiers" do
      DevMode.enable()
      assert DevMode.handle_shortcut(:i, [:ctrl]) == :not_handled
      assert DevMode.handle_shortcut(:i, [:shift]) == :not_handled
    end
  end

  describe "get_state" do
    test "returns full state" do
      DevMode.enable()
      DevMode.toggle_ui_inspector()

      state = DevMode.get_state()
      assert state.enabled == true
      assert state.ui_inspector == true
      assert is_map(state.components)
      assert is_map(state.metrics)
    end
  end
end
