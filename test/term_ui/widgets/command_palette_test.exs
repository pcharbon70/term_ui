defmodule TermUI.Widgets.CommandPaletteTest do
  use ExUnit.Case, async: true

  alias TermUI.Event
  alias TermUI.Widgets.CommandPalette

  @default_area %{width: 80, height: 24}

  defp sample_commands do
    [
      %{id: :save, label: "Save File", shortcut: "Ctrl+S", category: :command, action: fn -> :saved end},
      %{id: :open, label: "Open File", shortcut: "Ctrl+O", category: :command, action: fn -> :opened end},
      %{id: :close, label: "Close Tab", shortcut: "Ctrl+W", category: :command, action: fn -> :closed end},
      %{id: :goto_line, label: "Go to Line", category: :goto, action: fn -> :goto end},
      %{id: :goto_symbol, label: "Go to Symbol", category: :symbol, action: fn -> :symbol end},
      %{id: :settings, label: "Open Settings", category: :command, action: fn -> :settings end},
      %{id: :theme, label: "Change Theme", category: :command, action: fn -> :theme end}
    ]
  end

  describe "new/1 and init/1" do
    test "creates palette with commands" do
      props = CommandPalette.new(commands: sample_commands())
      {:ok, state} = CommandPalette.init(props)

      assert length(state.commands) == 7
      assert state.visible == true
      assert state.query == ""
      assert state.selected_index == 0
    end

    test "normalizes commands with defaults" do
      props =
        CommandPalette.new(
          commands: [
            %{id: :test, label: "Test", action: fn -> :test end}
          ]
        )

      {:ok, state} = CommandPalette.init(props)

      [cmd] = state.commands
      assert cmd.description == nil
      assert cmd.shortcut == nil
      assert cmd.category == :command
      assert cmd.icon == nil
      assert cmd.enabled == true
    end

    test "initializes with custom options" do
      props =
        CommandPalette.new(
          commands: sample_commands(),
          max_visible: 5,
          max_recent: 3,
          placeholder: "Search...",
          width: 50
        )

      {:ok, state} = CommandPalette.init(props)

      assert state.max_visible == 5
      assert state.max_recent == 3
      assert state.placeholder == "Search..."
      assert state.width == 50
    end
  end

  describe "fuzzy search" do
    test "exact match scores highest" do
      props = CommandPalette.new(commands: sample_commands())
      {:ok, state} = CommandPalette.init(props)

      state = CommandPalette.set_query(state, "Save File")

      [first | _] = state.filtered_commands
      assert first.id == :save
    end

    test "prefix match ranks high" do
      props = CommandPalette.new(commands: sample_commands())
      {:ok, state} = CommandPalette.init(props)

      state = CommandPalette.set_query(state, "Save")

      [first | _] = state.filtered_commands
      assert first.id == :save
    end

    test "partial match filters correctly" do
      props = CommandPalette.new(commands: sample_commands())
      {:ok, state} = CommandPalette.init(props)

      state = CommandPalette.set_query(state, "File")

      ids = Enum.map(state.filtered_commands, & &1.id)
      assert :save in ids
      assert :open in ids
    end

    test "fuzzy match works for non-consecutive characters" do
      props = CommandPalette.new(commands: sample_commands())
      {:ok, state} = CommandPalette.init(props)

      state = CommandPalette.set_query(state, "sf")

      # Should match "Save File"
      ids = Enum.map(state.filtered_commands, & &1.id)
      assert :save in ids
    end

    test "no matches returns empty list" do
      props = CommandPalette.new(commands: sample_commands())
      {:ok, state} = CommandPalette.init(props)

      state = CommandPalette.set_query(state, "xyz123")

      assert state.filtered_commands == []
    end

    test "case insensitive search" do
      props = CommandPalette.new(commands: sample_commands())
      {:ok, state} = CommandPalette.init(props)

      state = CommandPalette.set_query(state, "save file")

      [first | _] = state.filtered_commands
      assert first.id == :save
    end
  end

  describe "category filtering" do
    test "filters by command category with >" do
      props = CommandPalette.new(commands: sample_commands())
      {:ok, state} = CommandPalette.init(props)

      state = CommandPalette.set_query(state, ">")

      assert state.category_filter == :command
      # All commands with :command category
      assert Enum.all?(state.filtered_commands, &(&1.category == :command))
    end

    test "filters by symbol category with @" do
      props = CommandPalette.new(commands: sample_commands())
      {:ok, state} = CommandPalette.init(props)

      state = CommandPalette.set_query(state, "@")

      assert state.category_filter == :symbol
    end

    test "combines category filter with search" do
      props = CommandPalette.new(commands: sample_commands())
      {:ok, state} = CommandPalette.init(props)

      state = CommandPalette.set_query(state, ">save")

      assert state.category_filter == :command
      assert length(state.filtered_commands) >= 1
      assert Enum.all?(state.filtered_commands, &(&1.category == :command))
    end

    test "returns all category prefixes" do
      prefixes = CommandPalette.category_prefixes()

      assert prefixes[">"] == :command
      assert prefixes["@"] == :symbol
      assert prefixes["#"] == :tag
      assert prefixes[":"] == :location
    end
  end

  describe "navigation" do
    test "down arrow moves selection down" do
      props = CommandPalette.new(commands: sample_commands())
      {:ok, state} = CommandPalette.init(props)

      assert state.selected_index == 0

      {:ok, state} = CommandPalette.handle_event(Event.key(:down), state)
      assert state.selected_index == 1

      {:ok, state} = CommandPalette.handle_event(Event.key(:down), state)
      assert state.selected_index == 2
    end

    test "up arrow moves selection up" do
      props = CommandPalette.new(commands: sample_commands())
      {:ok, state} = CommandPalette.init(props)

      {:ok, state} = CommandPalette.handle_event(Event.key(:down), state)
      {:ok, state} = CommandPalette.handle_event(Event.key(:down), state)
      assert state.selected_index == 2

      {:ok, state} = CommandPalette.handle_event(Event.key(:up), state)
      assert state.selected_index == 1
    end

    test "selection stops at top" do
      props = CommandPalette.new(commands: sample_commands())
      {:ok, state} = CommandPalette.init(props)

      {:ok, state} = CommandPalette.handle_event(Event.key(:up), state)
      assert state.selected_index == 0
    end

    test "selection stops at bottom" do
      props = CommandPalette.new(commands: sample_commands())
      {:ok, state} = CommandPalette.init(props)

      # Move all the way down
      state = Enum.reduce(1..20, state, fn _, acc ->
        {:ok, new_state} = CommandPalette.handle_event(Event.key(:down), acc)
        new_state
      end)

      # Should be at last index
      assert state.selected_index == length(state.filtered_commands) - 1
    end

    test "page down jumps by max_visible" do
      props = CommandPalette.new(commands: sample_commands(), max_visible: 3)
      {:ok, state} = CommandPalette.init(props)

      {:ok, state} = CommandPalette.handle_event(Event.key(:page_down), state)
      assert state.selected_index == 3
    end

    test "page up jumps by max_visible" do
      props = CommandPalette.new(commands: sample_commands(), max_visible: 3)
      {:ok, state} = CommandPalette.init(props)

      # First go down
      state = Enum.reduce(1..5, state, fn _, acc ->
        {:ok, new_state} = CommandPalette.handle_event(Event.key(:down), acc)
        new_state
      end)

      {:ok, state} = CommandPalette.handle_event(Event.key(:page_up), state)
      assert state.selected_index == 2
    end
  end

  describe "text input" do
    test "typing characters updates query" do
      props = CommandPalette.new(commands: sample_commands())
      {:ok, state} = CommandPalette.init(props)

      {:ok, state} = CommandPalette.handle_event(Event.key(nil, char: "s"), state)
      assert state.query == "s"

      {:ok, state} = CommandPalette.handle_event(Event.key(nil, char: "a"), state)
      assert state.query == "sa"

      {:ok, state} = CommandPalette.handle_event(Event.key(nil, char: "v"), state)
      assert state.query == "sav"
    end

    test "backspace removes last character" do
      props = CommandPalette.new(commands: sample_commands())
      {:ok, state} = CommandPalette.init(props)

      state = CommandPalette.set_query(state, "save")

      {:ok, state} = CommandPalette.handle_event(Event.key(:backspace), state)
      assert state.query == "sav"
    end

    test "backspace on empty query does nothing" do
      props = CommandPalette.new(commands: sample_commands())
      {:ok, state} = CommandPalette.init(props)

      {:ok, state} = CommandPalette.handle_event(Event.key(:backspace), state)
      assert state.query == ""
    end

    test "query change resets selection" do
      props = CommandPalette.new(commands: sample_commands())
      {:ok, state} = CommandPalette.init(props)

      {:ok, state} = CommandPalette.handle_event(Event.key(:down), state)
      {:ok, state} = CommandPalette.handle_event(Event.key(:down), state)
      assert state.selected_index == 2

      {:ok, state} = CommandPalette.handle_event(Event.key(nil, char: "o"), state)
      assert state.selected_index == 0
    end
  end

  describe "command execution" do
    test "enter executes selected command" do
      executed = :erlang.make_ref()
      test_pid = self()

      commands = [
        %{id: :test, label: "Test", action: fn -> send(test_pid, {executed, :executed}) end}
      ]

      props = CommandPalette.new(commands: commands)
      {:ok, state} = CommandPalette.init(props)

      {:ok, _state} = CommandPalette.handle_event(Event.key(:enter), state)

      assert_receive {^executed, :executed}
    end

    test "on_select callback is invoked" do
      test_pid = self()

      commands = [
        %{id: :test, label: "Test", action: fn -> :ok end}
      ]

      props =
        CommandPalette.new(
          commands: commands,
          on_select: fn cmd -> send(test_pid, {:selected, cmd.id}) end
        )

      {:ok, state} = CommandPalette.init(props)

      {:ok, _state} = CommandPalette.handle_event(Event.key(:enter), state)

      assert_receive {:selected, :test}
    end

    test "disabled command does not execute" do
      executed = :erlang.make_ref()
      test_pid = self()

      commands = [
        %{id: :test, label: "Test", enabled: false, action: fn -> send(test_pid, {executed, :executed}) end}
      ]

      props = CommandPalette.new(commands: commands)
      {:ok, state} = CommandPalette.init(props)

      {:ok, _state} = CommandPalette.handle_event(Event.key(:enter), state)

      refute_receive {^executed, :executed}
    end

    test "enabled function is evaluated" do
      test_pid = self()

      commands = [
        %{id: :test, label: "Test", enabled: fn -> true end, action: fn -> send(test_pid, :executed) end}
      ]

      props = CommandPalette.new(commands: commands)
      {:ok, state} = CommandPalette.init(props)

      {:ok, _state} = CommandPalette.handle_event(Event.key(:enter), state)

      assert_receive :executed
    end
  end

  describe "recent commands" do
    test "executing command adds to recent" do
      commands = [
        %{id: :cmd1, label: "Command 1", action: fn -> :ok end},
        %{id: :cmd2, label: "Command 2", action: fn -> :ok end}
      ]

      props = CommandPalette.new(commands: commands)
      {:ok, state} = CommandPalette.init(props)

      {:ok, state} = CommandPalette.handle_event(Event.key(:enter), state)

      # Need to re-show palette since it closes on execution
      state = CommandPalette.show(state)
      assert :cmd1 in CommandPalette.get_recent_commands(state)
    end

    test "recent commands limited by max_recent" do
      commands = Enum.map(1..10, fn i ->
        %{id: :"cmd#{i}", label: "Command #{i}", action: fn -> :ok end}
      end)

      props = CommandPalette.new(commands: commands, max_recent: 3)
      {:ok, state} = CommandPalette.init(props)

      # Execute several commands
      state =
        Enum.reduce(1..5, state, fn i, acc ->
          # Select command i
          acc = CommandPalette.set_query(acc, "Command #{i}")
          {:ok, new_state} = CommandPalette.handle_event(Event.key(:enter), acc)
          CommandPalette.show(new_state)
        end)

      recent = CommandPalette.get_recent_commands(state)
      assert length(recent) == 3
    end

    test "clear_recent_commands empties the list" do
      commands = [
        %{id: :cmd1, label: "Command 1", action: fn -> :ok end}
      ]

      props = CommandPalette.new(commands: commands)
      {:ok, state} = CommandPalette.init(props)

      {:ok, state} = CommandPalette.handle_event(Event.key(:enter), state)
      state = CommandPalette.show(state)

      state = CommandPalette.clear_recent_commands(state)
      assert CommandPalette.get_recent_commands(state) == []
    end
  end

  describe "submenu support" do
    test "submenu action pushes submenu" do
      subcommands = [
        %{id: :sub1, label: "Sub 1", action: fn -> :sub1 end},
        %{id: :sub2, label: "Sub 2", action: fn -> :sub2 end}
      ]

      commands = [
        %{id: :parent, label: "Parent", action: {:submenu, subcommands}}
      ]

      props = CommandPalette.new(commands: commands)
      {:ok, state} = CommandPalette.init(props)

      {:ok, state} = CommandPalette.handle_event(Event.key(:enter), state)

      # Should now show subcommands
      assert length(state.submenu_stack) == 1
      assert length(state.filtered_commands) == 2
    end

    test "backspace pops submenu when query is empty" do
      subcommands = [
        %{id: :sub1, label: "Sub 1", action: fn -> :sub1 end}
      ]

      commands = [
        %{id: :parent, label: "Parent", action: {:submenu, subcommands}}
      ]

      props = CommandPalette.new(commands: commands)
      {:ok, state} = CommandPalette.init(props)

      # Enter submenu
      {:ok, state} = CommandPalette.handle_event(Event.key(:enter), state)
      assert length(state.submenu_stack) == 1

      # Go back
      {:ok, state} = CommandPalette.handle_event(Event.key(:backspace), state)
      assert state.submenu_stack == []
    end

    test "escape goes back from submenu" do
      subcommands = [
        %{id: :sub1, label: "Sub 1", action: fn -> :sub1 end}
      ]

      commands = [
        %{id: :parent, label: "Parent", action: {:submenu, subcommands}}
      ]

      props = CommandPalette.new(commands: commands)
      {:ok, state} = CommandPalette.init(props)

      {:ok, state} = CommandPalette.handle_event(Event.key(:enter), state)
      assert length(state.submenu_stack) == 1

      {:ok, state} = CommandPalette.handle_event(Event.key(:escape), state)
      assert state.submenu_stack == []
    end
  end

  describe "visibility" do
    test "escape closes palette" do
      props = CommandPalette.new(commands: sample_commands())
      {:ok, state} = CommandPalette.init(props)

      assert state.visible == true

      {:ok, state} = CommandPalette.handle_event(Event.key(:escape), state)

      assert state.visible == false
    end

    test "on_close callback is invoked" do
      test_pid = self()

      props =
        CommandPalette.new(
          commands: sample_commands(),
          on_close: fn -> send(test_pid, :closed) end
        )

      {:ok, state} = CommandPalette.init(props)

      {:ok, _state} = CommandPalette.handle_event(Event.key(:escape), state)

      assert_receive :closed
    end

    test "show/1 makes palette visible" do
      props = CommandPalette.new(commands: sample_commands())
      {:ok, state} = CommandPalette.init(props)

      state = %{state | visible: false}
      state = CommandPalette.show(state)

      assert state.visible == true
      assert state.query == ""
      assert state.selected_index == 0
    end

    test "hide/1 makes palette hidden" do
      props = CommandPalette.new(commands: sample_commands())
      {:ok, state} = CommandPalette.init(props)

      state = CommandPalette.hide(state)

      assert state.visible == false
    end

    test "toggle/1 toggles visibility" do
      props = CommandPalette.new(commands: sample_commands())
      {:ok, state} = CommandPalette.init(props)

      assert CommandPalette.visible?(state) == true

      state = CommandPalette.toggle(state)
      assert CommandPalette.visible?(state) == false

      state = CommandPalette.toggle(state)
      assert CommandPalette.visible?(state) == true
    end
  end

  describe "public API" do
    test "get_query/1 returns current query" do
      props = CommandPalette.new(commands: sample_commands())
      {:ok, state} = CommandPalette.init(props)

      state = CommandPalette.set_query(state, "test")
      assert CommandPalette.get_query(state) == "test"
    end

    test "get_filtered_commands/1 returns filtered list" do
      props = CommandPalette.new(commands: sample_commands())
      {:ok, state} = CommandPalette.init(props)

      state = CommandPalette.set_query(state, "Save")
      filtered = CommandPalette.get_filtered_commands(state)

      assert length(filtered) >= 1
      assert Enum.any?(filtered, &(&1.id == :save))
    end

    test "get_selected_command/1 returns selected command" do
      props = CommandPalette.new(commands: sample_commands())
      {:ok, state} = CommandPalette.init(props)

      selected = CommandPalette.get_selected_command(state)
      assert selected != nil
    end

    test "add_commands/2 adds new commands" do
      props = CommandPalette.new(commands: sample_commands())
      {:ok, state} = CommandPalette.init(props)

      initial_count = length(state.commands)

      state =
        CommandPalette.add_commands(state, [
          %{id: :new_cmd, label: "New Command", action: fn -> :new end}
        ])

      assert length(state.commands) == initial_count + 1
    end

    test "remove_commands/2 removes commands by id" do
      props = CommandPalette.new(commands: sample_commands())
      {:ok, state} = CommandPalette.init(props)

      state = CommandPalette.remove_commands(state, [:save, :open])

      ids = Enum.map(state.commands, & &1.id)
      refute :save in ids
      refute :open in ids
    end
  end

  describe "rendering" do
    test "renders visible palette" do
      props = CommandPalette.new(commands: sample_commands())
      {:ok, state} = CommandPalette.init(props)

      result = CommandPalette.render(state, @default_area)

      # Should return a non-empty render node
      assert result != nil
    end

    test "renders empty when not visible" do
      props = CommandPalette.new(commands: sample_commands())
      {:ok, state} = CommandPalette.init(props)

      state = CommandPalette.hide(state)
      result = CommandPalette.render(state, @default_area)

      # Should return empty node
      assert result.type == :empty
    end

    test "renders with query" do
      props = CommandPalette.new(commands: sample_commands())
      {:ok, state} = CommandPalette.init(props)

      state = CommandPalette.set_query(state, "save")
      result = CommandPalette.render(state, @default_area)

      assert result != nil
    end

    test "renders no results message" do
      props = CommandPalette.new(commands: sample_commands())
      {:ok, state} = CommandPalette.init(props)

      state = CommandPalette.set_query(state, "xyz123nonexistent")
      result = CommandPalette.render(state, @default_area)

      # Should still render (with "No commands found" message)
      assert result != nil
    end
  end

  describe "async loading" do
    test "async action triggers loading state" do
      commands = [
        %{id: :async_cmd, label: "Async", action: {:async, fn _query -> [] end}}
      ]

      props = CommandPalette.new(commands: commands)
      {:ok, state} = CommandPalette.init(props)

      {:ok, state} = CommandPalette.handle_event(Event.key(:enter), state)

      # After sync execution, loading should be false again
      assert state.loading == false
    end

    test "async action loads subcommands" do
      subcommands = [
        %{id: :loaded1, label: "Loaded 1", action: fn -> :ok end},
        %{id: :loaded2, label: "Loaded 2", action: fn -> :ok end}
      ]

      commands = [
        %{id: :async_cmd, label: "Async", action: {:async, fn _query -> subcommands end}}
      ]

      props = CommandPalette.new(commands: commands)
      {:ok, state} = CommandPalette.init(props)

      {:ok, state} = CommandPalette.handle_event(Event.key(:enter), state)

      # Should have pushed submenu with loaded commands
      assert length(state.submenu_stack) == 1
      assert length(state.filtered_commands) == 2
    end
  end
end
