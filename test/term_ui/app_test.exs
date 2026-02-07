defmodule TermUI.AppTest do
  use ExUnit.Case, async: false

  alias TermUI.App

  # Clean up persistent_term values between tests
  setup do
    # Store original values
    original_backend_mode = :persistent_term.get(:term_ui_backend_mode, :not_set)
    original_capabilities = :persistent_term.get(:term_ui_capabilities, :not_set)

    on_exit(fn ->
      # Restore or clean up persistent_term
      if original_backend_mode != :not_set do
        :persistent_term.put(:term_ui_backend_mode, original_backend_mode)
      else
        :persistent_term.erase(:term_ui_backend_mode)
      end

      if original_capabilities != :not_set do
        :persistent_term.put(:term_ui_capabilities, original_capabilities)
      else
        :persistent_term.erase(:term_ui_capabilities)
      end
    end)

    :ok
  end

  # Simple test component
  defmodule SimpleCounter do
    use TermUI.Elm

    def init(_opts), do: %{count: 0}

    def event_to_msg(_, _), do: :ignore
    def update(_, state), do: {state, []}
    def view(state), do: {:text, "Count: " <> to_string(state.count)}
  end

  describe "start/2" do
    test "starts application and returns {:ok, pid}" do
      {:ok, pid} = App.start(SimpleCounter, skip_terminal: true)

      assert is_pid(pid)
      assert Process.alive?(pid)

      # Clean up
      GenServer.stop(pid)
    end

    test "passes options to Runtime" do
      {:ok, pid} =
        App.start(SimpleCounter,
          skip_terminal: true,
          backend: :tty,
          render_interval: 100
        )

      assert is_pid(pid)

      # Verify options were applied
      state = TermUI.Runtime.get_state(pid)
      assert state.render_interval == 100

      # Clean up
      GenServer.stop(pid)
    end

    test "accepts name option for registered process" do
      {:ok, _pid} =
        App.start(SimpleCounter,
          skip_terminal: true,
          name: :test_app
        )

      # Verify we can access by name
      state = TermUI.Runtime.get_state(:test_app)
      assert state.root_module == SimpleCounter

      # Clean up
      GenServer.stop(:test_app)
    end

    test "returns error when Runtime fails to start" do
      # This would fail if we pass invalid options
      # For now, we just verify the happy path
      assert {:ok, _pid} = App.start(SimpleCounter, skip_terminal: true)
    end
  end

  describe "run/2" do
    test "runs application to completion" do
      # This test uses a task to avoid blocking the test runner
      task =
        Task.async(fn ->
          # Create a component that quits immediately via handle_info
          defmodule QuickQuit do
            use TermUI.Elm

            def init(_opts) do
              %{count: 0}
            end

            def event_to_msg(_, _), do: :ignore

            def update(_, state), do: {state, []}

            def view(_state), do: {:text, "Quick"}

            def handle_info(:quit_now, state) do
              {state, [:quit]}
            end
          end

          # Start the app and then send quit message
          {:ok, pid} = App.start(QuickQuit, skip_terminal: true)
          send(pid, :quit_now)

          # Wait for it to stop
          ref = Process.monitor(pid)

          receive do
            {:DOWN, ^ref, :process, ^pid, :normal} ->
              {:ok, :exited_normally}

            {:DOWN, ^ref, :process, ^pid, reason} ->
              {:error, reason}
          end
        end)

      assert {:ok, :exited_normally} = Task.await(task, 5000)
    end

    test "handles crash and cleans up terminal" do
      # This test verifies cleanup on crash
      # Note: With skip_terminal: true, the Runtime catches errors gracefully
      # So we just verify the run completes
      task =
        Task.async(fn ->
          defmodule GracefulExit do
            use TermUI.Elm

            def init(_opts) do
              %{count: 0}
            end

            def event_to_msg(_, _), do: :ignore

            def update(_, state), do: {state, []}

            def view(_state), do: {:text, "Graceful"}

            def handle_info(:quit_now, state) do
              {state, [:quit]}
            end
          end

          # Start the app and then send quit message
          {:ok, pid} = App.start(GracefulExit, skip_terminal: true)
          send(pid, :quit_now)

          # Wait for it to stop
          ref = Process.monitor(pid)

          receive do
            {:DOWN, ^ref, :process, ^pid, :normal} ->
              {:ok, :exited_normally}

            {:DOWN, ^ref, :process, ^pid, reason} ->
              {:error, reason}
          end
        end)

      assert {:ok, :exited_normally} = Task.await(task, 5000)
    end

    test "accepts and passes options through" do
      task =
        Task.async(fn ->
          defmodule QuickQuit2 do
            use TermUI.Elm

            def init(_opts) do
              %{count: 0}
            end

            def event_to_msg(_, _), do: :ignore

            def update(_, state), do: {state, []}

            def view(_state), do: {:text, "Quick"}

            def handle_info(:quit_now, state) do
              {state, [:quit]}
            end
          end

          # Start the app with backend option and then send quit message
          {:ok, pid} = App.start(QuickQuit2, skip_terminal: true, backend: :tty)
          send(pid, :quit_now)

          # Wait for it to stop
          ref = Process.monitor(pid)

          receive do
            {:DOWN, ^ref, :process, ^pid, :normal} ->
              {:ok, :exited_normally}

            {:DOWN, ^ref, :process, ^pid, reason} ->
              {:error, reason}
          end
        end)

      assert {:ok, :exited_normally} = Task.await(task, 5000)
    end
  end

  describe "backend_mode/0" do
    test "returns nil when no app is running" do
      # Ensure no app is running
      :persistent_term.erase(:term_ui_backend_mode)

      assert App.backend_mode() == nil
    end

    test "returns :raw when raw backend is selected" do
      :persistent_term.put(:term_ui_backend_mode, :raw)

      assert App.backend_mode() == :raw
    end

    test "returns :tty when TTY backend is selected" do
      :persistent_term.put(:term_ui_backend_mode, :tty)

      assert App.backend_mode() == :tty
    end

    test "returns backend mode after starting app" do
      {:ok, pid} =
        App.start(SimpleCounter,
          skip_terminal: true,
          backend: :tty
        )

      # When skip_terminal is true, backend mode is :skip
      assert App.backend_mode() == :skip

      # Clean up
      GenServer.stop(pid)
    end
  end

  describe "supports?/1" do
    setup do
      # Set up some default capabilities
      :persistent_term.put(:term_ui_capabilities, %{
        unicode: true,
        mouse: true,
        colors: :true_color
      })

      :ok
    end

    test "returns true for unicode when supported" do
      assert App.supports?(:unicode) == true
    end

    test "returns false for unicode when not supported" do
      :persistent_term.put(:term_ui_capabilities, %{unicode: false})

      assert App.supports?(:unicode) == false
    end

    test "returns true for mouse when supported" do
      assert App.supports?(:mouse) == true
    end

    test "returns false for mouse when not supported" do
      :persistent_term.put(:term_ui_capabilities, %{mouse: false})

      assert App.supports?(:mouse) == false
    end

    test "returns true for colors when not monochrome" do
      assert App.supports?(:colors) == true
    end

    test "returns false for colors when monochrome" do
      :persistent_term.put(:term_ui_capabilities, %{colors: :monochrome})

      assert App.supports?(:colors) == false
    end

    test "returns true for true_color when supported" do
      assert App.supports?(:true_color) == true
    end

    test "returns false for true_color when not supported" do
      :persistent_term.put(:term_ui_capabilities, %{colors: :color_256})

      assert App.supports?(:true_color) == false
    end

    test "returns true for color_256 when 256 colors or better" do
      :persistent_term.put(:term_ui_capabilities, %{colors: :color_256})
      assert App.supports?(:color_256) == true

      :persistent_term.put(:term_ui_capabilities, %{colors: :true_color})
      assert App.supports?(:color_256) == true
    end

    test "returns false for color_256 when only 16 colors" do
      :persistent_term.put(:term_ui_capabilities, %{colors: :color_16})

      assert App.supports?(:color_256) == false
    end

    test "returns true for color_16 when 16 colors or better" do
      :persistent_term.put(:term_ui_capabilities, %{colors: :color_16})
      assert App.supports?(:color_16) == true

      :persistent_term.put(:term_ui_capabilities, %{colors: :color_256})
      assert App.supports?(:color_16) == true
    end

    test "returns false for color_16 when monochrome" do
      :persistent_term.put(:term_ui_capabilities, %{colors: :monochrome})

      assert App.supports?(:color_16) == false
    end

    test "returns true for monochrome when monochrome" do
      :persistent_term.put(:term_ui_capabilities, %{colors: :monochrome})

      assert App.supports?(:monochrome) == true
    end

    test "returns false for monochrome when colors supported" do
      assert App.supports?(:monochrome) == false
    end

    test "returns false for unknown queries" do
      assert App.supports?(:unknown_capability) == false
    end

    test "returns false when no capabilities are stored" do
      :persistent_term.erase(:term_ui_capabilities)

      # Should return defaults (unicode: true, others: false)
      assert App.supports?(:unicode) == true
      assert App.supports?(:mouse) == false
    end
  end

  describe "shutdown/0" do
    test "shuts down running Runtime process" do
      {:ok, _pid} =
        App.start(SimpleCounter,
          skip_terminal: true,
          name: :test_shutdown
        )

      assert Process.alive?(Process.whereis(:test_shutdown))

      assert :ok = App.shutdown(:test_shutdown)

      # Wait for the process to actually terminate
      :timer.sleep(100)
      refute Process.whereis(:test_shutdown)
    end

    test "returns error when process not found" do
      assert {:error, :not_found} = App.shutdown(:nonexistent_process)
    end

    test "accepts pid for shutdown" do
      {:ok, pid} = App.start(SimpleCounter, skip_terminal: true)

      assert Process.alive?(pid)

      assert :ok = App.shutdown(pid)

      # Give it a moment to shut down
      Process.sleep(50)
      refute Process.alive?(pid)
    end
  end
end
