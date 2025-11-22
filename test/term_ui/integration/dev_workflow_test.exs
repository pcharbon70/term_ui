defmodule TermUI.Integration.DevWorkflowTest do
  # async: false because tests share the same named GenServer (DevMode)
  use ExUnit.Case, async: false

  alias TermUI.Dev.DevMode
  alias TermUI.Dev.HotReload
  alias TermUI.Dev.PerfMonitor
  alias TermUI.Dev.StateInspector
  alias TermUI.Dev.UIInspector

  describe "inspector toggle" do
    test "shows/hides component boundaries with shortcut" do
      {:ok, _pid} = DevMode.start_link()

      on_exit(fn ->
        try do
          GenServer.stop(DevMode)
        catch
          :exit, _ -> :ok
        end
      end)

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
      {:ok, _pid} = DevMode.start_link()

      on_exit(fn ->
        try do
          GenServer.stop(DevMode)
        catch
          :exit, _ -> :ok
        end
      end)

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
      area = %{width: 80, height: 24}

      overlay = UIInspector.render(state.components, nil, area)
      assert overlay.type == :overlay
      assert overlay.z == 200
    end

    test "selects component for detailed inspection" do
      {:ok, _pid} = DevMode.start_link()

      on_exit(fn ->
        try do
          GenServer.stop(DevMode)
        catch
          :exit, _ -> :ok
        end
      end)

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

      area = %{width: 80, height: 24}
      panel = StateInspector.render(component_info, area)

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
    test "calculates FPS from frame times" do
      {:ok, _pid} = DevMode.start_link()

      on_exit(fn ->
        try do
          GenServer.stop(DevMode)
        catch
          :exit, _ -> :ok
        end
      end)

      DevMode.enable()

      # Record several frames at ~60 FPS (16.6ms each)
      for _ <- 1..60 do
        DevMode.record_frame(16_666)
      end

      metrics = DevMode.get_metrics()
      # FPS should be approximately 60
      assert metrics.fps > 50 and metrics.fps < 70
    end

    test "tracks memory usage" do
      {:ok, _pid} = DevMode.start_link()

      on_exit(fn ->
        try do
          GenServer.stop(DevMode)
        catch
          :exit, _ -> :ok
        end
      end)

      DevMode.enable()
      DevMode.record_frame(16_000)

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

      area = %{width: 80, height: 24}
      panel = PerfMonitor.render(metrics, area)

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
      {:ok, _pid} = DevMode.start_link()

      on_exit(fn ->
        try do
          GenServer.stop(DevMode)
        catch
          :exit, _ -> :ok
        end
      end)

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
        DevMode.record_frame(16_000)
      end

      # Get state for rendering
      state = DevMode.get_state()
      area = %{width: 80, height: 24}

      # Render all overlays
      overlays = DevMode.render_overlays(state, area)
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
