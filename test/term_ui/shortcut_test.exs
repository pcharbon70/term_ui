defmodule TermUI.ShortcutTest do
  use ExUnit.Case, async: true

  alias TermUI.Shortcut
  alias TermUI.Event

  describe "start_link/1" do
    test "starts registry" do
      {:ok, registry} = Shortcut.start_link()
      assert is_pid(registry)
    end

    test "starts with registered name" do
      {:ok, _} = Shortcut.start_link(name: :test_shortcuts)
      assert is_pid(Process.whereis(:test_shortcuts))
      GenServer.stop(:test_shortcuts)
    end
  end

  describe "register/2" do
    test "registers a shortcut" do
      {:ok, registry} = Shortcut.start_link()

      shortcut = %Shortcut{
        key: :q,
        modifiers: [:ctrl],
        action: {:function, fn -> :quit end}
      }

      assert :ok = Shortcut.register(registry, shortcut)
      assert length(Shortcut.list(registry)) == 1
    end

    test "registers multiple shortcuts" do
      {:ok, registry} = Shortcut.start_link()

      Shortcut.register(registry, %Shortcut{key: :q, modifiers: [:ctrl], action: {:function, fn -> :quit end}})
      Shortcut.register(registry, %Shortcut{key: :s, modifiers: [:ctrl], action: {:function, fn -> :save end}})

      assert length(Shortcut.list(registry)) == 2
    end
  end

  describe "unregister/3" do
    test "removes a shortcut" do
      {:ok, registry} = Shortcut.start_link()

      Shortcut.register(registry, %Shortcut{key: :q, modifiers: [:ctrl], action: {:function, fn -> :quit end}})
      assert length(Shortcut.list(registry)) == 1

      Shortcut.unregister(registry, :q, [:ctrl])
      assert length(Shortcut.list(registry)) == 0
    end
  end

  describe "match/3" do
    test "matches shortcut by key" do
      {:ok, registry} = Shortcut.start_link()

      shortcut = %Shortcut{key: :q, modifiers: [], action: {:function, fn -> :quit end}}
      Shortcut.register(registry, shortcut)

      event = Event.key(:q)
      assert {:ok, matched} = Shortcut.match(registry, event)
      assert matched.key == :q
    end

    test "matches shortcut with modifiers" do
      {:ok, registry} = Shortcut.start_link()

      shortcut = %Shortcut{key: :s, modifiers: [:ctrl], action: {:function, fn -> :save end}}
      Shortcut.register(registry, shortcut)

      event = Event.key(:s, modifiers: [:ctrl])
      assert {:ok, matched} = Shortcut.match(registry, event)
      assert matched.key == :s
    end

    test "requires all modifiers to match" do
      {:ok, registry} = Shortcut.start_link()

      shortcut = %Shortcut{key: :s, modifiers: [:ctrl, :shift], action: {:function, fn -> :save_as end}}
      Shortcut.register(registry, shortcut)

      # Missing shift
      event = Event.key(:s, modifiers: [:ctrl])
      assert :no_match = Shortcut.match(registry, event)

      # Has all modifiers
      event = Event.key(:s, modifiers: [:ctrl, :shift])
      assert {:ok, _} = Shortcut.match(registry, event)
    end

    test "returns no_match when no shortcut matches" do
      {:ok, registry} = Shortcut.start_link()

      event = Event.key(:x)
      assert :no_match = Shortcut.match(registry, event)
    end

    test "returns highest priority shortcut on conflict" do
      {:ok, registry} = Shortcut.start_link()

      low = %Shortcut{key: :s, modifiers: [:ctrl], action: {:function, fn -> :low end}, priority: 0}
      high = %Shortcut{key: :s, modifiers: [:ctrl], action: {:function, fn -> :high end}, priority: 10}

      Shortcut.register(registry, low)
      Shortcut.register(registry, high)

      event = Event.key(:s, modifiers: [:ctrl])
      {:ok, matched} = Shortcut.match(registry, event)

      # Execute to check which one matched
      result = Shortcut.execute(matched)
      assert result == :high
    end
  end

  describe "match/3 with scopes" do
    test "global shortcuts always match" do
      {:ok, registry} = Shortcut.start_link()

      shortcut = %Shortcut{key: :q, modifiers: [:ctrl], action: {:function, fn -> :quit end}, scope: :global}
      Shortcut.register(registry, shortcut)

      event = Event.key(:q, modifiers: [:ctrl])
      assert {:ok, _} = Shortcut.match(registry, event, %{mode: :edit})
    end

    test "mode shortcuts only match in that mode" do
      {:ok, registry} = Shortcut.start_link()

      shortcut = %Shortcut{
        key: :i,
        modifiers: [],
        action: {:function, fn -> :insert end},
        scope: {:mode, :normal}
      }
      Shortcut.register(registry, shortcut)

      event = Event.key(:i)

      # Not in normal mode
      assert :no_match = Shortcut.match(registry, event, %{mode: :edit})

      # In normal mode
      assert {:ok, _} = Shortcut.match(registry, event, %{mode: :normal})
    end

    test "component shortcuts only match when component focused" do
      {:ok, registry} = Shortcut.start_link()

      shortcut = %Shortcut{
        key: :enter,
        modifiers: [],
        action: {:function, fn -> :submit end},
        scope: {:component, :text_input}
      }
      Shortcut.register(registry, shortcut)

      event = Event.key(:enter)

      # Different component focused
      assert :no_match = Shortcut.match(registry, event, %{focused_component: :button})

      # Correct component focused
      assert {:ok, _} = Shortcut.match(registry, event, %{focused_component: :text_input})
    end
  end

  describe "match/3 with sequences" do
    test "matches key sequence" do
      {:ok, registry} = Shortcut.start_link()

      shortcut = %Shortcut{
        key: :g,
        modifiers: [],
        action: {:function, fn -> :go_top end},
        sequence: [:g, :g]
      }
      Shortcut.register(registry, shortcut)

      event1 = Event.key(:g)
      event2 = Event.key(:g)

      # First key - no match yet
      assert :no_match = Shortcut.match(registry, event1)

      # Second key - sequence complete
      assert {:ok, matched} = Shortcut.match(registry, event2)
      assert matched.sequence == [:g, :g]
    end

    test "clears sequence on timeout" do
      {:ok, registry} = Shortcut.start_link()

      shortcut = %Shortcut{
        key: :g,
        modifiers: [],
        action: {:function, fn -> :go_top end},
        sequence: [:g, :g]
      }
      Shortcut.register(registry, shortcut)

      event = Event.key(:g)

      # First key starts sequence
      Shortcut.match(registry, event)

      # Clear sequence
      Shortcut.clear_sequence(registry)

      # Next key starts fresh, doesn't match
      assert :no_match = Shortcut.match(registry, event)
    end
  end

  describe "execute/1" do
    test "executes function action" do
      shortcut = %Shortcut{
        key: :q,
        modifiers: [:ctrl],
        action: {:function, fn -> :quit_result end}
      }

      assert :quit_result = Shortcut.execute(shortcut)
    end

    test "returns message tuple for message action" do
      shortcut = %Shortcut{
        key: :s,
        modifiers: [:ctrl],
        action: {:message, :root, :save}
      }

      assert {:send_message, :root, :save} = Shortcut.execute(shortcut)
    end

    test "returns command tuple for command action" do
      command = {:file_write, "/path", "content"}
      shortcut = %Shortcut{
        key: :s,
        modifiers: [:ctrl],
        action: {:command, command}
      }

      assert {:execute_command, ^command} = Shortcut.execute(shortcut)
    end
  end

  describe "list/1" do
    test "returns all registered shortcuts" do
      {:ok, registry} = Shortcut.start_link()

      Shortcut.register(registry, %Shortcut{key: :a, action: {:function, fn -> :a end}})
      Shortcut.register(registry, %Shortcut{key: :b, action: {:function, fn -> :b end}})
      Shortcut.register(registry, %Shortcut{key: :c, action: {:function, fn -> :c end}})

      shortcuts = Shortcut.list(registry)
      assert length(shortcuts) == 3
    end
  end

  describe "list_for_scope/2" do
    test "filters shortcuts by scope" do
      {:ok, registry} = Shortcut.start_link()

      Shortcut.register(registry, %Shortcut{key: :q, action: {:function, fn -> :quit end}, scope: :global})
      Shortcut.register(registry, %Shortcut{key: :i, action: {:function, fn -> :insert end}, scope: {:mode, :normal}})
      Shortcut.register(registry, %Shortcut{key: :d, action: {:function, fn -> :delete end}, scope: {:mode, :normal}})

      global = Shortcut.list_for_scope(registry, :global)
      assert length(global) == 1

      normal = Shortcut.list_for_scope(registry, {:mode, :normal})
      assert length(normal) == 2
    end
  end

  describe "format/1" do
    test "formats simple key" do
      shortcut = %Shortcut{key: :q, modifiers: []}
      assert Shortcut.format(shortcut) == "Q"
    end

    test "formats key with modifier" do
      shortcut = %Shortcut{key: :s, modifiers: [:ctrl]}
      assert Shortcut.format(shortcut) == "Ctrl+S"
    end

    test "formats key with multiple modifiers" do
      shortcut = %Shortcut{key: :s, modifiers: [:ctrl, :shift]}
      assert Shortcut.format(shortcut) == "Ctrl+Shift+S"
    end

    test "orders modifiers consistently" do
      shortcut = %Shortcut{key: :s, modifiers: [:shift, :ctrl, :alt]}
      assert Shortcut.format(shortcut) == "Ctrl+Alt+Shift+S"
    end

    test "formats special keys" do
      assert Shortcut.format(%Shortcut{key: :enter, modifiers: []}) == "ENTER"
      assert Shortcut.format(%Shortcut{key: :escape, modifiers: []}) == "ESCAPE"
      assert Shortcut.format(%Shortcut{key: :tab, modifiers: []}) == "TAB"
    end
  end

  describe "wildcard matching" do
    test "matches any key with :any" do
      {:ok, registry} = Shortcut.start_link()

      shortcut = %Shortcut{
        key: :any,
        modifiers: [:ctrl],
        action: {:function, fn -> :any_ctrl end}
      }
      Shortcut.register(registry, shortcut)

      event = Event.key(:x, modifiers: [:ctrl])
      assert {:ok, _} = Shortcut.match(registry, event)

      event = Event.key(:y, modifiers: [:ctrl])
      assert {:ok, _} = Shortcut.match(registry, event)
    end
  end

  describe "integration" do
    test "full workflow: register, match, execute" do
      {:ok, registry} = Shortcut.start_link()

      # Register shortcuts
      Shortcut.register(registry, %Shortcut{
        key: :q,
        modifiers: [:ctrl],
        action: {:function, fn -> :quit end},
        description: "Quit application"
      })

      Shortcut.register(registry, %Shortcut{
        key: :s,
        modifiers: [:ctrl],
        action: {:message, :editor, :save},
        description: "Save file"
      })

      # Match and execute quit
      event = Event.key(:q, modifiers: [:ctrl])
      {:ok, shortcut} = Shortcut.match(registry, event)
      assert Shortcut.execute(shortcut) == :quit

      # Match and execute save
      event = Event.key(:s, modifiers: [:ctrl])
      {:ok, shortcut} = Shortcut.match(registry, event)
      assert Shortcut.execute(shortcut) == {:send_message, :editor, :save}

      # List shortcuts
      shortcuts = Shortcut.list(registry)
      assert length(shortcuts) == 2
      assert Enum.all?(shortcuts, fn s -> s.description != nil end)
    end
  end
end
