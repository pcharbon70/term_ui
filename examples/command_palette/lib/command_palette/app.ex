defmodule CommandPalette.App do
  @moduledoc """
  Command Palette Widget Example

  Demonstrates a simple command dropdown triggered by typing `/`.
  Similar to how Claude Code shows available slash commands.

  Controls:
  - `/` opens the command dropdown
  - Type to filter commands
  - Up/Down to navigate
  - Enter to execute selected command
  - Escape to close
  - Q (when dropdown closed) to quit
  """

  use TermUI.Elm

  alias TermUI.Event
  alias TermUI.Renderer.Style
  alias TermUI.Widgets.CommandPalette

  # ----------------------------------------------------------------------------
  # Component Callbacks
  # ----------------------------------------------------------------------------

  def init(_opts) do
    # Create command palette (initially hidden)
    palette_props = CommandPalette.new(commands: available_commands())
    {:ok, palette} = CommandPalette.init(palette_props)
    palette = CommandPalette.hide(palette)

    %{
      palette: palette,
      message: nil
    }
  end

  defp available_commands do
    [
      %{id: :help, label: "/help", action: fn -> :ok end},
      %{id: :clear, label: "/clear", action: fn -> :ok end},
      %{id: :save, label: "/save", action: fn -> :ok end},
      %{id: :open, label: "/open", action: fn -> :ok end},
      %{id: :new, label: "/new", action: fn -> :ok end},
      %{id: :quit, label: "/quit", action: fn -> :ok end},
      %{id: :settings, label: "/settings", action: fn -> :ok end},
      %{id: :theme, label: "/theme", action: fn -> :ok end},
      %{id: :format, label: "/format", action: fn -> :ok end},
      %{id: :search, label: "/search", action: fn -> :ok end}
    ]
  end

  def event_to_msg(%Event.Key{key: key}, %{palette: palette}) do
    if CommandPalette.visible?(palette) do
      {:msg, {:palette_event, %Event.Key{key: key}}}
    else
      query = CommandPalette.get_query(palette)

      case key do
        "/" -> {:msg, :open_palette}
        :enter when query != "" -> {:msg, :execute_command}
        "q" -> {:msg, :quit}
        "Q" -> {:msg, :quit}
        _ -> :ignore
      end
    end
  end

  def event_to_msg(_event, _state), do: :ignore

  def update(:open_palette, state) do
    palette = CommandPalette.show(state.palette)
    {%{state | palette: palette, message: nil}, []}
  end

  def update({:palette_event, event}, state) do
    {:ok, palette} = CommandPalette.handle_event(event, state.palette)
    {%{state | palette: palette}, []}
  end

  def update(:execute_command, state) do
    query = CommandPalette.get_query(state.palette)
    # Find matching command
    cmd = Enum.find(available_commands(), fn c -> c.label == query end)

    message =
      if cmd do
        if is_function(cmd.action, 0), do: cmd.action.()
        "Executed: #{cmd.label}"
      else
        "Unknown command: #{query}"
      end

    # Reset palette
    palette = CommandPalette.show(state.palette)
    palette = CommandPalette.hide(palette)

    {%{state | palette: palette, message: message}, []}
  end

  def update(:quit, state) do
    {state, [:quit]}
  end

  def view(state) do
    stack(:vertical, [
      text("Command Palette Example", Style.new(fg: :cyan, attrs: [:bold])),
      text("", nil),
      text("Press / to open the command dropdown", nil),
      text("", nil),
      render_message(state.message),
      render_palette(state),
      text("", nil),
      render_controls()
    ])
  end

  defp render_message(nil), do: text("", nil)
  defp render_message(msg), do: text(msg, Style.new(fg: :green))

  defp render_palette(state) do
    query = CommandPalette.get_query(state.palette)

    if CommandPalette.visible?(state.palette) do
      stack(:vertical, [
        text("/" <> query, Style.new(fg: :yellow)),
        CommandPalette.render(state.palette, %{})
      ])
    else
      if query != "" do
        text(query <> "  (press Enter to execute)", Style.new(fg: :yellow))
      else
        text("", nil)
      end
    end
  end

  defp render_controls do
    stack(:vertical, [
      text("Controls:", Style.new(fg: :yellow)),
      text("  /         Open command dropdown", nil),
      text("  Type      Filter commands", nil),
      text("  Up/Down   Navigate", nil),
      text("  Enter     Execute command", nil),
      text("  Escape    Close dropdown", nil),
      text("  Q         Quit", nil)
    ])
  end

  # ----------------------------------------------------------------------------
  # Public API
  # ----------------------------------------------------------------------------

  def run do
    TermUI.Runtime.run(root: __MODULE__)
  end
end
