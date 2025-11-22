defmodule TermUI.Integration.DevWorkflowTest do
  # async: false because tests share the same named GenServer (DevMode)
  use ExUnit.Case, async: false

  alias TermUI.Dev.DevMode
  alias TermUI.Dev.HotReload
  alias TermUI.Dev.PerfMonitor
  alias TermUI.Dev.StateInspector
  alias TermUI.Dev.UIInspector

  @default_area %{width: 80, height: 24}

  # Frame timing constants (microseconds)
  # 60 FPS = 16,666 microseconds per frame
  @frame_time_60fps 16_666
  # Slightly faster than 60 FPS for testing
  @frame_time_fast 16_000

  # Helper to start DevMode and ensure cleanup
  defp start_dev_mode do
    {:ok, _pid} = DevMode.start_link()

    on_exit(fn ->
      # Only stop if the process still exists (may have been stopped by test)
      # Use try/catch as a safety net for race conditions
      if Process.whereis(DevMode) do
        try do
          GenServer.stop(DevMode)
        catch
          :exit, _ -> :ok
        end
      end
    end)
  end

  describe "inspector toggle" do
    setup do
      start_dev_mode()
      :ok
    end

    test "shows/hides component boundaries with shortcut" do
      DevMode.enable()

      # Initially disabled
      refute DevMode.ui_inspector_enabled?()

      # Toggle with Ctrl+Shift+I
      result = DevMode.handle_shortcut(:i, [:ctrl, :shift])
      assert result == :handled
      assert DevMode.ui_inspector_enabled?()

      # Toggle off
      DevMode.handle_shortcut(:i, [:ctrl, :shift])
      refute DevMode.ui_inspector_enabled?()
    end

    test "renders component boundaries when enabled" do
      DevMode.enable()
      DevMode.toggle_ui_inspector()

      # Register a component
      DevMode.register_component(
        :test_comp,
        TestModule,
        %{count: 0},
        %{x: 10, y: 5, width: 30, height: 10}
      )

      # Get state and render overlay
      state = DevMode.get_state()
      overlay = UIInspector.render(state.components, nil, @default_area)
      assert overlay.type == :overlay
      assert overlay.z == 200
    end

    test "selects component for detailed inspection" do
      DevMode.enable()
      DevMode.toggle_ui_inspector()
      DevMode.toggle_state_inspector()

      # Register components
      DevMode.register_component(
        :parent,
        ParentModule,
        %{items: [1, 2, 3]},
        %{x: 0, y: 0, width: 80, height: 24}
      )

      DevMode.register_component(
        :child,
        ChildModule,
        %{selected: true},
        %{x: 10, y: 5, width: 20, height: 10}
      )

      # Find component at position
      components = DevMode.get_components()
      found = UIInspector.find_component_at(components, 15, 7)
      assert found == :child

      # Select it
      DevMode.select_component(:child)
      assert DevMode.get_selected_component() == :child
    end
  end

  describe "state inspector" do
    test "renders state tree for selected component" do
      state = %{
        counter: 42,
        items: ["a", "b", "c"],
        nested: %{
          deep: %{value: true}
        }
      }

      component_info = %{
        module: TestModule,
        state: state,
        render_time: 1000,
        bounds: %{x: 0, y: 0, width: 40, height: 20}
      }

      panel = StateInspector.render(component_info, @default_area)

      assert panel.type == :positioned
      # Panel should be positioned on the right side
      assert panel.x > 0
    end

    test "detects state changes" do
      old_state = %{count: 1, name: "test"}
      new_state = %{count: 2, name: "test"}

      diffs = StateInspector.diff_states(old_state, new_state)
      assert length(diffs) == 1
      assert [:count] in diffs
    end

    test "handles nested state structures" do
      state = %{
        user: %{
          profile: %{
            name: "Alice",
            settings: %{theme: :dark}
          }
        }
      }

      tree = StateInspector.render_state_tree(state, 0)
      assert is_list(tree)
      assert length(tree) > 1
    end
  end

  describe "performance monitor" do
    setup do
      start_dev_mode()
      :ok
    end

    test "calculates FPS from frame times" do
      DevMode.enable()

      # Record several frames at ~60 FPS
      for _ <- 1..60 do
        DevMode.record_frame(@frame_time_60fps)
      end

      metrics = DevMode.get_metrics()
      # FPS should be approximately 60
      assert metrics.fps > 50 and metrics.fps < 70
    end

    test "tracks memory usage" do
      DevMode.enable()
      DevMode.record_frame(@frame_time_fast)

      metrics = DevMode.get_metrics()
      assert metrics.memory > 0
      assert metrics.process_count > 0
    end

    test "renders performance panel" do
      metrics = %{
        fps: 60.0,
        frame_times: List.duplicate(16_666, 60),
        memory: 50_000_000,
        process_count: 100
      }

      panel = PerfMonitor.render(metrics, @default_area)

      assert panel.type == :positioned
    end

    test "formats bytes correctly" do
      assert PerfMonitor.format_bytes(500) == "500 B"
      assert PerfMonitor.format_bytes(1024) == "1.0 KB"
      assert PerfMonitor.format_bytes(1_500_000) == "1.4 MB"
      assert PerfMonitor.format_bytes(2_000_000_000) == "1.86 GB"
    end
  end

  describe "hot reload workflow" do
    # Skip in normal test runs due to module reload complexity
    @tag :skip
    test "updates component behavior after reload" do
      # This test would verify that:
      # 1. A module is loaded
      # 2. Code is changed and recompiled
      # 3. The component uses the new behavior
      # Skipped due to complexity of module reloading in test environment
    end

    test "tracks recent reloads" do
      {:ok, _pid} = HotReload.start_link()

      # The reload tracking should work even without actual reloads
      reloads = HotReload.get_recent_reloads()
      assert is_list(reloads)

      HotReload.stop()
    end
  end

  describe "integrated development workflow" do
    setup do
      start_dev_mode()
      :ok
    end

    test "complete dev mode cycle" do
      # Enable dev mode
      DevMode.enable()
      assert DevMode.enabled?()

      # Register components
      DevMode.register_component(
        :app,
        AppModule,
        %{page: :home},
        %{x: 0, y: 0, width: 80, height: 24}
      )

      # Toggle all inspectors
      DevMode.toggle_ui_inspector()
      DevMode.toggle_state_inspector()
      DevMode.toggle_perf_monitor()

      assert DevMode.ui_inspector_enabled?()
      assert DevMode.state_inspector_enabled?()
      assert DevMode.perf_monitor_enabled?()

      # Record some frames
      for _ <- 1..10 do
        DevMode.record_frame(@frame_time_fast)
      end

      # Get state for rendering
      state = DevMode.get_state()

      # Render all overlays
      overlays = DevMode.render_overlays(state, @default_area)
      assert length(overlays) == 3

      # Update component state
      DevMode.update_component_state(:app, %{page: :settings})
      components = DevMode.get_components()
      assert components[:app].state.page == :settings

      # Disable dev mode
      DevMode.disable()
      refute DevMode.enabled?()
    end

    test "keyboard shortcuts only work when dev mode enabled" do
      # Should not handle when disabled
      result = DevMode.handle_shortcut(:i, [:ctrl, :shift])
      assert result == :not_handled

      # Enable and try again
      DevMode.enable()
      result = DevMode.handle_shortcut(:i, [:ctrl, :shift])
      assert result == :handled
    end
  end
end
