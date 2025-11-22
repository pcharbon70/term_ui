defmodule TermUI.Integration.EventSystemTest do
  @moduledoc """
  Integration tests for the Phase 5 Event System.

  Tests realistic workflows that involve multiple subsystems working together,
  such as shortcuts triggering clipboard operations, mouse events with
  coordinate transformation, and focus changes affecting application state.
  """

  use ExUnit.Case, async: false

  alias TermUI.Event
  alias TermUI.Shortcut
  alias TermUI.Mouse.Tracker, as: MouseTracker
  alias TermUI.Mouse.Router, as: MouseRouter
  alias TermUI.Clipboard
  alias TermUI.Clipboard.Selection
  alias TermUI.Focus
  alias TermUI.Command
  alias TermUI.Command.Executor

  describe "command execution workflows" do
    test "timer command executes and delivers result to component" do
      {:ok, executor} = Executor.start_link()
      test_pid = self()

      cmd = Command.timer(10, {:timer_done, :test})
      Executor.execute(executor, cmd, test_pid, :test_component)

      assert_receive {:command_result, :test_component, _ref, {:timer_done, :test}}, 100

      GenServer.stop(executor)
    end

    test "multiple commands execute concurrently and deliver results" do
      {:ok, executor} = Executor.start_link()
      test_pid = self()

      cmd1 = Command.timer(10, :first)
      cmd2 = Command.timer(10, :second)

      Executor.execute(executor, cmd1, test_pid, :comp1)
      Executor.execute(executor, cmd2, test_pid, :comp2)

      results = receive_results_with_ref(2, 200)
      assert length(results) == 2

      GenServer.stop(executor)
    end

    test "command cancellation prevents result delivery" do
      {:ok, executor} = Executor.start_link()
      test_pid = self()

      cmd = Command.timer(100, :should_not_receive)
      {:ok, ref} = Executor.execute(executor, cmd, test_pid, :test)

      Executor.cancel(executor, ref)

      refute_receive {:command_result, _, _, _}, 150

      GenServer.stop(executor)
    end
  end

  describe "mouse drag with routing and tracking" do
    test "complete drag sequence with coordinate transformation" do
      components = %{
        panel: %{bounds: %{x: 100, y: 50, width: 200, height: 100}, z_index: 0}
      }

      tracker = MouseTracker.new(drag_threshold: 1)

      # Press at global coordinates - route to component
      press = Event.mouse(:press, :left, 120, 70)
      {component_id, local_event} = MouseRouter.route(components, press)

      assert component_id == :panel
      assert local_event.x == 20
      assert local_event.y == 20

      # Track drag state
      {tracker, _events} = MouseTracker.process(tracker, press)
      assert MouseTracker.button_down(tracker) == :left

      # Move beyond threshold - drag starts
      move = Event.mouse(:move, nil, 150, 90)
      {tracker, events} = MouseTracker.process(tracker, move)

      assert MouseTracker.dragging?(tracker)
      assert [{:drag_start, :left, 120, 70}, {:drag_move, :left, 150, 90, 30, 20}] = events

      # Release - drag ends
      release = Event.mouse(:release, :left, 180, 100)
      {tracker, events} = MouseTracker.process(tracker, release)

      refute MouseTracker.dragging?(tracker)
      assert [{:drag_end, :left, 180, 100}] = events
    end

    test "hover tracking with component routing" do
      components = %{
        button1: %{bounds: %{x: 0, y: 0, width: 50, height: 30}, z_index: 0},
        button2: %{bounds: %{x: 60, y: 0, width: 50, height: 30}, z_index: 0}
      }

      tracker = MouseTracker.new()

      # Move over button1
      move1 = Event.mouse(:move, nil, 25, 15)
      {id1, _} = MouseRouter.route(components, move1)
      {tracker, events} = MouseTracker.update_hover(tracker, id1)

      assert id1 == :button1
      assert events == [{:hover_enter, :button1}]

      # Move to button2 - leave button1, enter button2
      move2 = Event.mouse(:move, nil, 85, 15)
      {id2, _} = MouseRouter.route(components, move2)
      {_tracker, events} = MouseTracker.update_hover(tracker, id2)

      assert id2 == :button2
      assert events == [{:hover_leave, :button1}, {:hover_enter, :button2}]
    end

    test "z-order routing with overlapping components" do
      components = %{
        background: %{bounds: %{x: 0, y: 0, width: 100, height: 100}, z_index: 0},
        dialog: %{bounds: %{x: 20, y: 20, width: 60, height: 60}, z_index: 10}
      }

      # Click in overlap area routes to higher z-index
      event = Event.mouse(:click, :left, 50, 50)
      {id, local_event} = MouseRouter.route(components, event)

      assert id == :dialog
      assert local_event.x == 30
      assert local_event.y == 30
    end
  end

  describe "shortcut system workflows" do
    test "global shortcut triggers from any context" do
      {:ok, registry} = Shortcut.start_link()

      Shortcut.register(registry, %Shortcut{
        key: :q,
        modifiers: [:ctrl],
        action: {:function, fn -> :quit end},
        scope: :global
      })

      event = Event.key(:q, modifiers: [:ctrl])

      # Matches in any mode or focused component
      assert {:ok, _} = Shortcut.match(registry, event, %{mode: :normal})
      assert {:ok, _} = Shortcut.match(registry, event, %{mode: :edit})
      assert {:ok, _} = Shortcut.match(registry, event, %{focused_component: :editor})

      GenServer.stop(registry)
    end

    test "mode-scoped shortcut respects application mode" do
      {:ok, registry} = Shortcut.start_link()

      Shortcut.register(registry, %Shortcut{
        key: :i,
        modifiers: [],
        action: {:function, fn -> :insert end},
        scope: {:mode, :normal}
      })

      event = Event.key(:i)

      # Only matches in normal mode
      assert :no_match = Shortcut.match(registry, event, %{mode: :edit})
      assert {:ok, _} = Shortcut.match(registry, event, %{mode: :normal})

      GenServer.stop(registry)
    end

    test "component-scoped shortcut respects focus" do
      {:ok, registry} = Shortcut.start_link()

      Shortcut.register(registry, %Shortcut{
        key: :enter,
        modifiers: [],
        action: {:function, fn -> :submit end},
        scope: {:component, :form}
      })

      event = Event.key(:enter)

      # Only matches when form is focused
      assert :no_match = Shortcut.match(registry, event, %{focused_component: :list})
      assert {:ok, _} = Shortcut.match(registry, event, %{focused_component: :form})

      GenServer.stop(registry)
    end

    test "key sequence completes across multiple key events" do
      {:ok, registry} = Shortcut.start_link()

      Shortcut.register(registry, %Shortcut{
        key: :g,
        modifiers: [],
        action: {:function, fn -> :go_top end},
        sequence: [:g, :g]
      })

      event = Event.key(:g)

      # First key starts sequence
      assert :no_match = Shortcut.match(registry, event)

      # Second key completes sequence
      assert {:ok, shortcut} = Shortcut.match(registry, event)
      assert shortcut.sequence == [:g, :g]
      assert Shortcut.execute(shortcut) == :go_top

      GenServer.stop(registry)
    end

    test "priority resolves conflicting shortcuts" do
      {:ok, registry} = Shortcut.start_link()

      Shortcut.register(registry, %Shortcut{
        key: :s,
        modifiers: [:ctrl],
        action: {:function, fn -> :low_priority end},
        priority: 0
      })

      Shortcut.register(registry, %Shortcut{
        key: :s,
        modifiers: [:ctrl],
        action: {:function, fn -> :high_priority end},
        priority: 10
      })

      event = Event.key(:s, modifiers: [:ctrl])
      {:ok, shortcut} = Shortcut.match(registry, event)

      assert Shortcut.execute(shortcut) == :high_priority

      GenServer.stop(registry)
    end

    test "shortcut triggers clipboard copy operation" do
      {:ok, registry} = Shortcut.start_link()

      # Register Ctrl+C shortcut that performs copy
      Shortcut.register(registry, %Shortcut{
        key: :c,
        modifiers: [:ctrl],
        action: {:function, fn ->
          text = "Document content here"
          selection = Selection.new() |> Selection.start(9) |> Selection.extend(16)
          content = Selection.extract(selection, text)
          sequence = Clipboard.write_sequence(content)
          {:copied, content, sequence}
        end},
        description: "Copy selection to clipboard"
      })

      event = Event.key(:c, modifiers: [:ctrl])
      {:ok, shortcut} = Shortcut.match(registry, event)
      {:copied, content, sequence} = Shortcut.execute(shortcut)

      assert content == "content"
      assert String.contains?(sequence, Base.encode64("content"))

      GenServer.stop(registry)
    end
  end

  describe "clipboard workflow integration" do
    test "complete copy workflow: select, extract, write to clipboard" do
      text = "The quick brown fox jumps over the lazy dog"

      # Select "quick brown"
      selection =
        Selection.new()
        |> Selection.start(4)
        |> Selection.extend(15)

      # Extract selected content
      content = Selection.extract(selection, text)
      assert content == "quick brown"

      # Generate clipboard write sequence
      sequence = Clipboard.write_sequence(content)
      assert String.contains?(sequence, Base.encode64("quick brown"))
    end

    test "complete cut workflow: select, copy, delete" do
      text = "Hello World"

      # Select "World"
      selection =
        Selection.new()
        |> Selection.start(6)
        |> Selection.extend(11)

      # Extract for clipboard
      content = Selection.extract(selection, text)
      assert content == "World"

      # Generate clipboard sequence
      _sequence = Clipboard.write_sequence(content)

      # Delete selected content
      {start_pos, end_pos} = Selection.range(selection)
      remaining = String.slice(text, 0, start_pos) <> String.slice(text, end_pos..-1//1)

      assert remaining == "Hello "
    end

    test "selection expansion simulates shift+arrow navigation" do
      text = "Hello World Example"

      # Start with cursor at position 6 (beginning of "World")
      # Simulate Shift+Right five times to select "World"
      selection =
        Selection.new()
        |> Selection.start(6)
        |> Selection.extend(7)
        |> Selection.extend(8)
        |> Selection.extend(9)
        |> Selection.extend(10)
        |> Selection.extend(11)

      assert Selection.extract(selection, text) == "World"
    end
  end

  describe "focus event workflows" do
    test "focus lost triggers registered actions" do
      {:ok, tracker} = Focus.Tracker.start_link(initial_focus: true)
      test_pid = self()

      # Register multiple focus lost actions
      Focus.Tracker.on_focus_lost(tracker, fn ->
        send(test_pid, :autosave_triggered)
      end)

      Focus.Tracker.on_focus_lost(tracker, fn ->
        send(test_pid, :cleanup_triggered)
      end)

      # Lose focus
      Focus.Tracker.set_focus(tracker, false)

      # Both actions should execute
      assert_receive :autosave_triggered, 100
      assert_receive :cleanup_triggered, 100

      GenServer.stop(tracker)
    end

    test "focus gained triggers refresh actions" do
      {:ok, tracker} = Focus.Tracker.start_link(initial_focus: false)
      test_pid = self()

      Focus.Tracker.on_focus_gained(tracker, fn ->
        send(test_pid, :refresh_triggered)
      end)

      # Gain focus
      Focus.Tracker.set_focus(tracker, true)

      assert_receive :refresh_triggered, 100

      GenServer.stop(tracker)
    end

    test "auto-pause pauses on focus lost and resumes on focus gained" do
      {:ok, tracker} = Focus.Tracker.start_link(initial_focus: true)

      Focus.Tracker.enable_auto_pause(tracker)

      # Initially not paused
      refute Focus.Tracker.paused?(tracker)

      # Lose focus - should pause
      Focus.Tracker.set_focus(tracker, false)
      assert Focus.Tracker.paused?(tracker)

      # Gain focus - should resume
      Focus.Tracker.set_focus(tracker, true)
      refute Focus.Tracker.paused?(tracker)

      GenServer.stop(tracker)
    end

    test "focus lost triggers autosave then pauses animations" do
      {:ok, tracker} = Focus.Tracker.start_link(initial_focus: true)
      test_pid = self()

      # Register autosave action
      Focus.Tracker.on_focus_lost(tracker, fn ->
        send(test_pid, :autosave)
      end)

      # Enable auto-pause
      Focus.Tracker.enable_auto_pause(tracker)

      # Lose focus
      Focus.Tracker.set_focus(tracker, false)

      # Both should happen
      assert_receive :autosave, 100
      assert Focus.Tracker.paused?(tracker)

      GenServer.stop(tracker)
    end
  end

  describe "cross-system integration" do
    test "shortcut with command execution workflow" do
      {:ok, registry} = Shortcut.start_link()
      {:ok, executor} = Executor.start_link()
      test_pid = self()

      # Register shortcut that returns a command
      Shortcut.register(registry, %Shortcut{
        key: :r,
        modifiers: [:ctrl],
        action: {:command, Command.timer(10, :refreshed)},
        description: "Refresh"
      })

      # Match shortcut
      event = Event.key(:r, modifiers: [:ctrl])
      {:ok, shortcut} = Shortcut.match(registry, event)

      # Execute shortcut returns command
      {:execute_command, cmd} = Shortcut.execute(shortcut)

      # Execute command
      Executor.execute(executor, cmd, test_pid, :app)

      # Receive command result
      assert_receive {:command_result, :app, _ref, :refreshed}, 100

      GenServer.stop(registry)
      GenServer.stop(executor)
    end

    test "mouse click triggers shortcut-like action via routing" do
      components = %{
        save_button: %{bounds: %{x: 10, y: 10, width: 80, height: 30}, z_index: 0}
      }

      # Click on button
      event = Event.mouse(:click, :left, 50, 25)
      {component_id, local_event} = MouseRouter.route(components, event)

      assert component_id == :save_button
      assert local_event.action == :click

      # Component could register a shortcut or handle the click directly
      # This demonstrates routing working with events
    end

    test "focus change affects shortcut scope matching" do
      {:ok, registry} = Shortcut.start_link()
      {:ok, tracker} = Focus.Tracker.start_link(initial_focus: true)

      # Register component-scoped shortcut
      Shortcut.register(registry, %Shortcut{
        key: :enter,
        modifiers: [],
        action: {:function, fn -> :submit end},
        scope: {:component, :form}
      })

      event = Event.key(:enter)

      # When form is focused, shortcut matches
      context = %{focused_component: :form}
      assert {:ok, _} = Shortcut.match(registry, event, context)

      # When something else is focused, shortcut doesn't match
      context = %{focused_component: :list}
      assert :no_match = Shortcut.match(registry, event, context)

      GenServer.stop(registry)
      GenServer.stop(tracker)
    end
  end

  # Helper Functions

  defp receive_results_with_ref(count, timeout) do
    receive_results_with_ref(count, timeout, [])
  end

  defp receive_results_with_ref(0, _timeout, acc), do: Enum.reverse(acc)

  defp receive_results_with_ref(count, timeout, acc) do
    receive do
      {:command_result, component, _ref, result} ->
        receive_results_with_ref(count - 1, timeout, [{component, result} | acc])
    after
      timeout -> Enum.reverse(acc)
    end
  end
end
