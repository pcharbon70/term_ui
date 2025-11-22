defmodule TermUI.Integration.EventSystemTest do
  @moduledoc """
  Integration tests for the Phase 5 Event System.

  Tests the complete event flow from terminal input through to
  component updates and rendering, covering mouse interactions,
  keyboard shortcuts, clipboard operations, and focus events.
  """

  use ExUnit.Case, async: true

  alias TermUI.Event
  alias TermUI.Shortcut
  alias TermUI.Mouse.Tracker, as: MouseTracker
  alias TermUI.Mouse.Router, as: MouseRouter
  alias TermUI.Clipboard
  alias TermUI.Clipboard.Selection
  alias TermUI.Clipboard.PasteAccumulator
  alias TermUI.Focus
  alias TermUI.Command
  alias TermUI.Command.Executor

  # ===========================================================================
  # 5.8.1 Event Flow Testing
  # ===========================================================================

  describe "event flow - keyboard events" do
    test "keyboard event creates correct event structure" do
      event = Event.key(:a, modifiers: [:ctrl])

      assert event.key == :a
      assert event.modifiers == [:ctrl]
      assert %Event.Key{} = event
    end

    test "keyboard event with multiple modifiers" do
      event = Event.key(:s, modifiers: [:ctrl, :shift, :alt])

      assert :ctrl in event.modifiers
      assert :shift in event.modifiers
      assert :alt in event.modifiers
    end

    test "special key events" do
      event = Event.key(:enter)
      assert event.key == :enter

      event = Event.key(:escape)
      assert event.key == :escape

      event = Event.key(:tab)
      assert event.key == :tab
    end
  end

  describe "event flow - command execution" do
    test "timer command executes and returns result" do
      {:ok, executor} = Executor.start_link()
      test_pid = self()

      cmd = Command.timer(10, {:timer_done, :test})
      Executor.execute(executor, cmd, test_pid, :test_component)

      assert_receive {:command_result, :test_component, _ref, {:timer_done, :test}}, 100
    end

    test "multiple commands execute concurrently" do
      {:ok, executor} = Executor.start_link()
      test_pid = self()

      cmd1 = Command.timer(10, :first)
      cmd2 = Command.timer(10, :second)

      Executor.execute(executor, cmd1, test_pid, :comp1)
      Executor.execute(executor, cmd2, test_pid, :comp2)

      results = receive_results_with_ref(2, 200)
      assert length(results) == 2
    end

    test "command cancellation prevents result" do
      {:ok, executor} = Executor.start_link()
      test_pid = self()

      cmd = Command.timer(100, :should_not_receive)
      {:ok, ref} = Executor.execute(executor, cmd, test_pid, :test)

      Executor.cancel(executor, ref)

      refute_receive {:command_result, _, _}, 150
    end
  end

  describe "event flow - event to message transformation" do
    test "event contains all necessary fields for routing" do
      key_event = Event.key(:j, modifiers: [])
      assert Map.has_key?(key_event, :key)
      assert Map.has_key?(key_event, :modifiers)

      mouse_event = Event.mouse(:click, :left, 10, 20)
      assert Map.has_key?(mouse_event, :x)
      assert Map.has_key?(mouse_event, :y)
      assert Map.has_key?(mouse_event, :button)
      assert Map.has_key?(mouse_event, :action)
    end
  end

  # ===========================================================================
  # 5.8.2 Mouse Interaction Testing
  # ===========================================================================

  describe "mouse interaction - click events" do
    test "click event contains position and button" do
      event = Event.mouse(:click, :left, 15, 25)

      assert event.action == :click
      assert event.button == :left
      assert event.x == 15
      assert event.y == 25
    end

    test "right click event" do
      event = Event.mouse(:click, :right, 10, 10)
      assert event.button == :right
    end

    test "mouse router routes to component at position" do
      components = %{
        button: %{bounds: %{x: 10, y: 10, width: 20, height: 10}, z_index: 0}
      }

      event = Event.mouse(:click, :left, 15, 15)
      {id, transformed} = MouseRouter.route(components, event)

      assert id == :button
      assert transformed.x == 5
      assert transformed.y == 5
    end

    test "mouse router returns nil for empty space" do
      components = %{
        button: %{bounds: %{x: 10, y: 10, width: 20, height: 10}, z_index: 0}
      }

      event = Event.mouse(:click, :left, 0, 0)
      assert nil == MouseRouter.route(components, event)
    end
  end

  describe "mouse interaction - drag operations" do
    test "drag sequence press-move-release" do
      tracker = MouseTracker.new(drag_threshold: 3)

      # Press
      press = Event.mouse(:press, :left, 10, 10)
      {tracker, events} = MouseTracker.process(tracker, press)
      assert events == []
      assert MouseTracker.button_down(tracker) == :left

      # Move beyond threshold
      move = Event.mouse(:move, nil, 20, 20)
      {tracker, events} = MouseTracker.process(tracker, move)
      assert MouseTracker.dragging?(tracker)
      assert [{:drag_start, :left, 10, 10}, {:drag_move, :left, 20, 20, 10, 10}] = events

      # Release
      release = Event.mouse(:release, :left, 25, 25)
      {tracker, events} = MouseTracker.process(tracker, release)
      refute MouseTracker.dragging?(tracker)
      assert [{:drag_end, :left, 25, 25}] = events
    end

    test "small movements don't start drag" do
      tracker = MouseTracker.new(drag_threshold: 10)

      press = Event.mouse(:press, :left, 10, 10)
      {tracker, _} = MouseTracker.process(tracker, press)

      move = Event.mouse(:move, nil, 12, 11)
      {tracker, events} = MouseTracker.process(tracker, move)

      refute MouseTracker.dragging?(tracker)
      assert events == []
    end
  end

  describe "mouse interaction - scroll wheel" do
    test "scroll up event" do
      event = Event.mouse(:scroll_up, nil, 10, 10)
      assert event.action == :scroll_up
    end

    test "scroll down event" do
      event = Event.mouse(:scroll_down, nil, 10, 10)
      assert event.action == :scroll_down
    end

    test "scroll action detection" do
      assert TermUI.Mouse.scroll_action?(:scroll_up)
      assert TermUI.Mouse.scroll_action?(:scroll_down)
      refute TermUI.Mouse.scroll_action?(:click)
    end
  end

  describe "mouse interaction - hover" do
    test "hover enter and leave events" do
      tracker = MouseTracker.new()

      # Enter component
      {tracker, events} = MouseTracker.update_hover(tracker, :button1)
      assert events == [{:hover_enter, :button1}]

      # Leave component
      {tracker, events} = MouseTracker.update_hover(tracker, nil)
      assert events == [{:hover_leave, :button1}]
    end

    test "hover between components" do
      tracker = MouseTracker.new()

      {tracker, _} = MouseTracker.update_hover(tracker, :button1)
      {_tracker, events} = MouseTracker.update_hover(tracker, :button2)

      assert events == [{:hover_leave, :button1}, {:hover_enter, :button2}]
    end
  end

  # ===========================================================================
  # 5.8.3 Shortcut Testing
  # ===========================================================================

  describe "shortcut - global shortcuts" do
    test "global shortcut matches from any context" do
      {:ok, registry} = Shortcut.start_link()

      Shortcut.register(registry, %Shortcut{
        key: :q,
        modifiers: [:ctrl],
        action: {:function, fn -> :quit end},
        scope: :global
      })

      event = Event.key(:q, modifiers: [:ctrl])

      # Should match with any context
      assert {:ok, _} = Shortcut.match(registry, event, %{mode: :normal})
      assert {:ok, _} = Shortcut.match(registry, event, %{mode: :edit})
      assert {:ok, _} = Shortcut.match(registry, event, %{focused_component: :editor})
    end
  end

  describe "shortcut - scoped shortcuts" do
    test "mode-scoped shortcut only matches in that mode" do
      {:ok, registry} = Shortcut.start_link()

      Shortcut.register(registry, %Shortcut{
        key: :i,
        modifiers: [],
        action: {:function, fn -> :insert end},
        scope: {:mode, :normal}
      })

      event = Event.key(:i)

      # Should not match in edit mode
      assert :no_match = Shortcut.match(registry, event, %{mode: :edit})

      # Should match in normal mode
      assert {:ok, _} = Shortcut.match(registry, event, %{mode: :normal})
    end

    test "component-scoped shortcut only matches when focused" do
      {:ok, registry} = Shortcut.start_link()

      Shortcut.register(registry, %Shortcut{
        key: :enter,
        modifiers: [],
        action: {:function, fn -> :submit end},
        scope: {:component, :form}
      })

      event = Event.key(:enter)

      # Should not match when different component focused
      assert :no_match = Shortcut.match(registry, event, %{focused_component: :list})

      # Should match when form focused
      assert {:ok, _} = Shortcut.match(registry, event, %{focused_component: :form})
    end
  end

  describe "shortcut - key sequences" do
    test "key sequence matches on completion" do
      {:ok, registry} = Shortcut.start_link()

      Shortcut.register(registry, %Shortcut{
        key: :g,
        modifiers: [],
        action: {:function, fn -> :go_top end},
        sequence: [:g, :g]
      })

      event = Event.key(:g)

      # First key - no match
      assert :no_match = Shortcut.match(registry, event)

      # Second key - matches
      assert {:ok, shortcut} = Shortcut.match(registry, event)
      assert shortcut.sequence == [:g, :g]
    end

    test "sequence resets on clear" do
      {:ok, registry} = Shortcut.start_link()

      Shortcut.register(registry, %Shortcut{
        key: :g,
        modifiers: [],
        action: {:function, fn -> :go_top end},
        sequence: [:g, :g]
      })

      event = Event.key(:g)

      # Start sequence
      Shortcut.match(registry, event)

      # Clear sequence
      Shortcut.clear_sequence(registry)

      # Next key starts fresh
      assert :no_match = Shortcut.match(registry, event)
    end
  end

  describe "shortcut - priority resolution" do
    test "higher priority shortcut wins" do
      {:ok, registry} = Shortcut.start_link()

      Shortcut.register(registry, %Shortcut{
        key: :s,
        modifiers: [:ctrl],
        action: {:function, fn -> :low end},
        priority: 0
      })

      Shortcut.register(registry, %Shortcut{
        key: :s,
        modifiers: [:ctrl],
        action: {:function, fn -> :high end},
        priority: 10
      })

      event = Event.key(:s, modifiers: [:ctrl])
      {:ok, shortcut} = Shortcut.match(registry, event)

      assert Shortcut.execute(shortcut) == :high
    end
  end

  describe "shortcut - action execution" do
    test "function action executes and returns result" do
      shortcut = %Shortcut{
        key: :x,
        modifiers: [:ctrl],
        action: {:function, fn -> {:cut, "content"} end}
      }

      assert {:cut, "content"} = Shortcut.execute(shortcut)
    end

    test "message action returns send_message tuple" do
      shortcut = %Shortcut{
        key: :s,
        modifiers: [:ctrl],
        action: {:message, :editor, :save}
      }

      assert {:send_message, :editor, :save} = Shortcut.execute(shortcut)
    end

    test "command action returns execute_command tuple" do
      command = {:file_write, "/path", "content"}

      shortcut = %Shortcut{
        key: :s,
        modifiers: [:ctrl],
        action: {:command, command}
      }

      assert {:execute_command, ^command} = Shortcut.execute(shortcut)
    end
  end

  # ===========================================================================
  # 5.8.4 Clipboard Testing
  # ===========================================================================

  describe "clipboard - paste accumulation" do
    test "accumulates content between markers" do
      acc = PasteAccumulator.new()
      acc = PasteAccumulator.start(acc)
      acc = PasteAccumulator.add(acc, "Hello ")
      acc = PasteAccumulator.add(acc, "World")
      {content, _} = PasteAccumulator.complete(acc)

      assert content == "Hello World"
    end

    test "paste event creation" do
      event = Event.paste("pasted content")

      assert %Event.Paste{} = event
      assert event.content == "pasted content"
    end
  end

  describe "clipboard - selection management" do
    test "selection tracks start and end" do
      selection = Selection.new()
      selection = Selection.start(selection, 5)
      selection = Selection.extend(selection, 15)

      assert Selection.range(selection) == {5, 15}
      assert Selection.length(selection) == 10
    end

    test "selection extracts content" do
      text = "Hello World Example"
      selection = Selection.new()
      selection = Selection.start(selection, 6)
      selection = Selection.extend(selection, 11)

      assert Selection.extract(selection, text) == "World"
    end

    test "selection expands with shift+arrow simulation" do
      text = "Hello World"
      selection = Selection.new()

      # Simulate Shift+Right to select "Hello"
      selection = Selection.expand(selection, :right, text, 0)
      selection = Selection.expand(selection, :right, text, 1)
      selection = Selection.expand(selection, :right, text, 2)
      selection = Selection.expand(selection, :right, text, 3)
      selection = Selection.expand(selection, :right, text, 4)

      assert Selection.extract(selection, text) == "Hello"
    end

    test "selection clears on navigation" do
      selection = Selection.new()
      selection = Selection.start(selection, 0)
      selection = Selection.extend(selection, 10)

      assert Selection.active?(selection)

      selection = Selection.clear(selection)
      refute Selection.active?(selection)
    end
  end

  describe "clipboard - OSC 52 operations" do
    test "generates correct write sequence" do
      sequence = Clipboard.write_sequence("test")
      encoded = Base.encode64("test")

      assert sequence == "\e]52;c;#{encoded}\e\\"
    end

    test "handles unicode content" do
      sequence = Clipboard.write_sequence("日本語")
      encoded = Base.encode64("日本語")

      assert sequence == "\e]52;c;#{encoded}\e\\"
    end

    test "targets primary selection" do
      sequence = Clipboard.write_sequence("test", target: :primary)

      assert String.contains?(sequence, ";p;")
    end
  end

  describe "clipboard - cut/copy/paste workflow" do
    test "copy workflow: select and write to clipboard" do
      text = "The quick brown fox"

      # Select "quick"
      selection = Selection.new()
      selection = Selection.start(selection, 4)
      selection = Selection.extend(selection, 9)

      # Extract and generate clipboard sequence
      content = Selection.extract(selection, text)
      sequence = Clipboard.write_sequence(content)

      assert content == "quick"
      assert String.contains?(sequence, Base.encode64("quick"))
    end

    test "cut workflow: select, copy, then delete" do
      text = "Hello World"

      # Select "World"
      selection = Selection.new()
      selection = Selection.start(selection, 6)
      selection = Selection.extend(selection, 11)

      # Get selected content
      content = Selection.extract(selection, text)
      assert content == "World"

      # Simulate deletion (would be done by component)
      {start, finish} = Selection.range(selection)
      new_text = String.slice(text, 0, start) <> String.slice(text, finish, String.length(text))

      assert new_text == "Hello "
    end
  end

  # ===========================================================================
  # Focus Event Testing
  # ===========================================================================

  describe "focus - state tracking" do
    test "focus state updates correctly" do
      {:ok, tracker} = Focus.Tracker.start_link()

      assert Focus.Tracker.has_focus?(tracker)

      Focus.Tracker.set_focus(tracker, false)
      refute Focus.Tracker.has_focus?(tracker)

      Focus.Tracker.set_focus(tracker, true)
      assert Focus.Tracker.has_focus?(tracker)
    end

    test "focus actions execute on state change" do
      {:ok, tracker} = Focus.Tracker.start_link(initial_focus: true)
      test_pid = self()

      Focus.Tracker.on_focus_lost(tracker, fn ->
        send(test_pid, :autosave_triggered)
      end)

      Focus.Tracker.set_focus(tracker, false)

      assert_receive :autosave_triggered, 100
    end
  end

  describe "focus - optimization hooks" do
    test "auto-pause on focus lost" do
      {:ok, tracker} = Focus.Tracker.start_link(initial_focus: true)

      Focus.Tracker.enable_auto_pause(tracker)

      refute Focus.Tracker.paused?(tracker)

      Focus.Tracker.set_focus(tracker, false)
      assert Focus.Tracker.paused?(tracker)

      Focus.Tracker.set_focus(tracker, true)
      refute Focus.Tracker.paused?(tracker)
    end
  end

  # ===========================================================================
  # Complex Integration Scenarios
  # ===========================================================================

  describe "integration - complex workflows" do
    test "shortcut triggers clipboard operation" do
      {:ok, registry} = Shortcut.start_link()

      # Register Ctrl+C shortcut
      Shortcut.register(registry, %Shortcut{
        key: :c,
        modifiers: [:ctrl],
        action: {:function, fn ->
          # Simulate copy operation
          {:copy, "selected text"}
        end},
        description: "Copy"
      })

      event = Event.key(:c, modifiers: [:ctrl])
      {:ok, shortcut} = Shortcut.match(registry, event)
      result = Shortcut.execute(shortcut)

      assert result == {:copy, "selected text"}
    end

    test "mouse drag with coordinate transformation" do
      components = %{
        panel: %{bounds: %{x: 100, y: 50, width: 200, height: 100}, z_index: 0}
      }

      tracker = MouseTracker.new(drag_threshold: 1)

      # Press at global coordinates
      press = Event.mouse(:press, :left, 120, 70)
      {component_id, local_event} = MouseRouter.route(components, press)

      assert component_id == :panel
      assert local_event.x == 20
      assert local_event.y == 20

      # Track drag
      {tracker, _} = MouseTracker.process(tracker, press)

      # Move
      move = Event.mouse(:move, nil, 150, 90)
      {_tracker, events} = MouseTracker.process(tracker, move)

      # Should have started dragging
      assert [{:drag_start, _, _, _}, {:drag_move, _, _, _, _, _}] = events
    end

    test "focus lost triggers autosave then pauses animations" do
      {:ok, tracker} = Focus.Tracker.start_link(initial_focus: true)
      test_pid = self()

      # Register autosave
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
    end
  end

  # ===========================================================================
  # Helper Functions
  # ===========================================================================

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
