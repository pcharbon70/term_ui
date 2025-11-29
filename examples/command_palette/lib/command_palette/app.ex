defmodule CommandPalette.App do
  @moduledoc """
  CommandPalette Widget Example

  This example demonstrates how to use the TermUI.Widgets.CommandPalette widget
  for VS Code-style command discovery and execution.

  Features demonstrated:
  - Fuzzy search through commands
  - Category filtering with prefixes (>, @, #, :)
  - Recent commands tracking
  - Keyboard shortcut hints
  - Nested command menus (submenus)
  - Async command loading

  Controls:
  - Ctrl+P: Open command palette
  - Up/Down: Navigate results
  - Enter: Execute selected command
  - Escape: Close palette
  - Backspace: Go back in submenu / delete character
  - Q: Quit the application (when palette is closed)
  """

  @behaviour TermUI.Elm

  import TermUI.Component.Helpers

  alias TermUI.Event
  alias TermUI.Renderer.Style
  alias TermUI.Widgets.CommandPalette, as: Palette

  # ----------------------------------------------------------------------------
  # Component Callbacks
  # ----------------------------------------------------------------------------

  @doc """
  Initialize the component state.
  """
  def init(_opts) do
    commands = build_commands()

    props =
      Palette.new(
        commands: commands,
        on_select: fn cmd -> send(self(), {:command_executed, cmd}) end,
        on_close: fn -> send(self(), :palette_closed) end,
        max_visible: 8,
        max_recent: 5,
        placeholder: "Type to search commands...",
        width: 60
      )

    {:ok, palette_state} = Palette.init(props)

    %{
      palette: Palette.hide(palette_state),
      last_action: nil,
      counter: 0,
      theme: :dark,
      notifications: true,
      messages: []
    }
  end

  defp build_commands do
    [
      # File commands
      %{id: :new_file, label: "New File", shortcut: "Ctrl+N", category: :command,
        icon: "+", action: fn -> :new_file end},
      %{id: :open_file, label: "Open File", shortcut: "Ctrl+O", category: :command,
        icon: "O", action: fn -> :open_file end},
      %{id: :save_file, label: "Save File", shortcut: "Ctrl+S", category: :command,
        icon: "S", action: fn -> :save_file end},
      %{id: :save_as, label: "Save As...", shortcut: "Ctrl+Shift+S", category: :command,
        icon: "S", action: fn -> :save_as end},
      %{id: :close_file, label: "Close File", shortcut: "Ctrl+W", category: :command,
        icon: "X", action: fn -> :close_file end},

      # Edit commands
      %{id: :undo, label: "Undo", shortcut: "Ctrl+Z", category: :command,
        icon: "U", action: fn -> :undo end},
      %{id: :redo, label: "Redo", shortcut: "Ctrl+Shift+Z", category: :command,
        icon: "R", action: fn -> :redo end},
      %{id: :cut, label: "Cut", shortcut: "Ctrl+X", category: :command,
        action: fn -> :cut end},
      %{id: :copy, label: "Copy", shortcut: "Ctrl+C", category: :command,
        action: fn -> :copy end},
      %{id: :paste, label: "Paste", shortcut: "Ctrl+V", category: :command,
        action: fn -> :paste end},

      # View commands
      %{id: :toggle_sidebar, label: "Toggle Sidebar", shortcut: "Ctrl+B", category: :command,
        action: fn -> :toggle_sidebar end},
      %{id: :zoom_in, label: "Zoom In", shortcut: "Ctrl++", category: :command,
        action: fn -> :zoom_in end},
      %{id: :zoom_out, label: "Zoom Out", shortcut: "Ctrl+-", category: :command,
        action: fn -> :zoom_out end},

      # Go to commands (with @ prefix)
      %{id: :goto_line, label: "Go to Line...", shortcut: "Ctrl+G", category: :symbol,
        icon: "#", action: fn -> :goto_line end},
      %{id: :goto_symbol, label: "Go to Symbol", shortcut: "Ctrl+Shift+O", category: :symbol,
        icon: "@", action: fn -> :goto_symbol end},
      %{id: :goto_definition, label: "Go to Definition", shortcut: "F12", category: :symbol,
        icon: ">", action: fn -> :goto_definition end},

      # Settings with submenu
      %{id: :settings, label: "Settings", category: :command, icon: "*",
        action: {:submenu, [
          %{id: :theme_settings, label: "Theme", action: {:submenu, [
            %{id: :theme_dark, label: "Dark Theme", action: fn -> {:set_theme, :dark} end},
            %{id: :theme_light, label: "Light Theme", action: fn -> {:set_theme, :light} end},
            %{id: :theme_high_contrast, label: "High Contrast", action: fn -> {:set_theme, :high_contrast} end}
          ]}},
          %{id: :notifications_settings, label: "Notifications", action: {:submenu, [
            %{id: :notif_on, label: "Enable Notifications", action: fn -> {:set_notifications, true} end},
            %{id: :notif_off, label: "Disable Notifications", action: fn -> {:set_notifications, false} end}
          ]}},
          %{id: :reset_settings, label: "Reset All Settings", action: fn -> :reset_settings end}
        ]}},

      # Help commands
      %{id: :help, label: "Show Help", shortcut: "F1", category: :command,
        icon: "?", action: fn -> :help end},
      %{id: :about, label: "About", category: :command,
        icon: "i", action: fn -> :about end},

      # Demo async loading
      %{id: :search_files, label: "Search Files...", category: :command,
        icon: "/", action: {:async, fn query ->
          # Simulate file search results
          Process.sleep(100)
          [
            %{id: :file1, label: "src/main.ex", description: "matches: #{query}",
              action: fn -> {:open, "src/main.ex"} end},
            %{id: :file2, label: "lib/app.ex", description: "matches: #{query}",
              action: fn -> {:open, "lib/app.ex"} end},
            %{id: :file3, label: "test/test_helper.exs", description: "matches: #{query}",
              action: fn -> {:open, "test/test_helper.exs"} end}
          ]
        end}},

      # Tag-based commands (with # prefix)
      %{id: :tag_todo, label: "TODO items", category: :tag,
        icon: "#", action: fn -> :show_todos end},
      %{id: :tag_fixme, label: "FIXME items", category: :tag,
        icon: "#", action: fn -> :show_fixmes end},
      %{id: :tag_note, label: "NOTE items", category: :tag,
        icon: "#", action: fn -> :show_notes end}
    ]
  end

  @doc """
  Convert keyboard events to messages.
  """
  def event_to_msg(%Event.Key{key: "p", modifiers: [:ctrl]}, _state) do
    {:msg, :toggle_palette}
  end

  def event_to_msg(%Event.Key{key: key}, state) when key in ["q", "Q"] do
    if not Palette.visible?(state.palette) do
      {:msg, :quit}
    else
      {:msg, {:palette_event, Event.key(nil, char: key)}}
    end
  end

  def event_to_msg(event, state) do
    if Palette.visible?(state.palette) do
      {:msg, {:palette_event, event}}
    else
      {:msg, :noop}
    end
  end

  @doc """
  Update state based on messages.
  """
  def update(:quit, state) do
    {state, [:quit]}
  end

  def update(:toggle_palette, state) do
    palette = Palette.toggle(state.palette)
    {%{state | palette: palette}, []}
  end

  def update({:palette_event, event}, state) do
    {:ok, new_palette} = Palette.handle_event(event, state.palette)
    {%{state | palette: new_palette}, []}
  end

  def update(:noop, state) do
    {state, []}
  end

  def update(_msg, state) do
    {state, []}
  end

  @doc """
  Handle info messages.
  """
  def handle_info({:command_executed, cmd}, state) do
    result = execute_action(cmd.action)
    state = apply_result(state, cmd.id, result)
    {state, []}
  end

  def handle_info(:palette_closed, state) do
    {state, []}
  end

  def handle_info(_msg, state) do
    {state, []}
  end

  defp execute_action(action) when is_function(action, 0), do: action.()
  defp execute_action({:submenu, _}), do: :submenu
  defp execute_action({:async, _}), do: :async
  defp execute_action(_), do: :unknown

  defp apply_result(state, cmd_id, result) do
    state = %{state | last_action: {cmd_id, result}}

    case result do
      {:set_theme, theme} ->
        add_message(state, "Theme changed to #{theme}")
        |> Map.put(:theme, theme)

      {:set_notifications, enabled} ->
        add_message(state, "Notifications #{if enabled, do: "enabled", else: "disabled"}")
        |> Map.put(:notifications, enabled)

      :reset_settings ->
        add_message(state, "Settings reset to defaults")
        |> Map.put(:theme, :dark)
        |> Map.put(:notifications, true)

      {:open, path} ->
        add_message(state, "Opening #{path}")

      action when is_atom(action) ->
        add_message(state, "Executed: #{action}")

      _ ->
        state
    end
  end

  defp add_message(state, message) do
    messages = [{DateTime.utc_now(), message} | state.messages] |> Enum.take(5)
    %{state | messages: messages}
  end

  @doc """
  Render the current state to a render tree.
  """
  def view(state) do
    stack(:vertical, [
      # Title
      text("CommandPalette Widget Example", Style.new(fg: :cyan, attrs: [:bold])),
      text(""),

      # Instructions
      render_instructions(),
      text(""),

      # Current state
      render_state(state),
      text(""),

      # Recent messages
      render_messages(state),
      text(""),

      # Command palette (overlay)
      if Palette.visible?(state.palette) do
        stack(:vertical, [
          text(""),
          Palette.render(state.palette, %{width: 60, height: 12})
        ])
      else
        empty()
      end
    ])
  end

  # ----------------------------------------------------------------------------
  # Private Helpers
  # ----------------------------------------------------------------------------

  defp render_instructions do
    stack(:vertical, [
      text("Controls:", Style.new(fg: :yellow)),
      text("  Ctrl+P         Open command palette"),
      text("  Up/Down        Navigate results"),
      text("  Enter          Execute selected command"),
      text("  Escape         Close palette"),
      text("  Q              Quit (when palette is closed)"),
      text(""),
      text("Category Prefixes:", Style.new(fg: :yellow)),
      text("  >              Commands (default)"),
      text("  @              Symbols / Go to"),
      text("  #              Tags / Topics"),
      text("  :              Line numbers / Locations")
    ])
  end

  defp render_state(state) do
    stack(:vertical, [
      text("--- Current State ---", Style.new(fg: :magenta)),
      text("  Theme: #{state.theme}"),
      text("  Notifications: #{if state.notifications, do: "enabled", else: "disabled"}"),
      text("  Palette visible: #{Palette.visible?(state.palette)}"),
      case state.last_action do
        {cmd_id, result} ->
          text("  Last action: #{cmd_id} -> #{inspect(result)}")
        nil ->
          text("  Last action: (none)")
      end
    ])
  end

  defp render_messages(state) do
    if state.messages == [] do
      stack(:vertical, [
        text("--- Messages ---", Style.new(fg: :green)),
        text("  (no messages yet)")
      ])
    else
      messages =
        Enum.map(state.messages, fn {_time, msg} ->
          text("  > #{msg}", Style.new(fg: :white))
        end)

      stack(:vertical, [
        text("--- Messages ---", Style.new(fg: :green))
        | messages
      ])
    end
  end

  # ----------------------------------------------------------------------------
  # Public API
  # ----------------------------------------------------------------------------

  @doc """
  Run the command palette example application.
  """
  def run do
    TermUI.Runtime.run(root: __MODULE__)
  end
end
