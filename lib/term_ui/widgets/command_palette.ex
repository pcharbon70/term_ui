defmodule TermUI.Widgets.CommandPalette do
  @moduledoc """
  Simple command dropdown for filtering and selecting commands.

  Shows a list of commands filtered by prefix as the user types.
  Similar to typing `/` in Claude Code to see available slash commands.

  ## Usage

      # Define commands
      commands = [
        %{id: :help, label: "/help", action: fn -> :ok end},
        %{id: :save, label: "/save", action: fn -> :ok end},
        %{id: :quit, label: "/quit", action: fn -> :ok end}
      ]

      # Create and show palette
      props = CommandPalette.new(commands: commands)
      {:ok, palette} = CommandPalette.init(props)

      # Render dropdown when visible
      if CommandPalette.visible?(palette) do
        CommandPalette.render(palette, area)
      end

  ## Keyboard Navigation

  - Type to filter by prefix
  - Up/Down: Navigate through results
  - Enter: Execute selected command
  - Escape: Close dropdown
  - Backspace: Delete character
  """

  use TermUI.StatefulComponent

  alias TermUI.Event

  @doc """
  Creates new CommandPalette widget props.

  ## Options

  - `:commands` - List of command maps (required). Each command has:
    - `:id` - Unique identifier (atom)
    - `:label` - Display text (string)
    - `:action` - Function to execute (fn -> ... end)
  - `:max_visible` - Maximum visible results (default: 8)
  """
  @spec new(keyword()) :: map()
  def new(opts) do
    %{
      commands: Keyword.fetch!(opts, :commands),
      max_visible: Keyword.get(opts, :max_visible, 8)
    }
  end

  @impl true
  def init(props) do
    state = %{
      commands: props.commands,
      filtered: props.commands,
      query: "",
      selected: 0,
      scroll: 0,
      visible: true,
      max_visible: props.max_visible
    }

    {:ok, state}
  end

  @impl true
  def handle_event(%Event.Key{key: :escape}, state) do
    {:ok, %{state | visible: false}}
  end

  def handle_event(%Event.Key{key: :enter}, state) do
    case Enum.at(state.filtered, state.selected) do
      nil ->
        {:ok, %{state | visible: false}}

      command ->
        # Insert command label as the query, close dropdown (don't execute)
        {:ok, %{state | query: command.label, visible: false}}
    end
  end

  def handle_event(%Event.Key{key: :up}, state) do
    new_selected = max(0, state.selected - 1)
    {:ok, update_scroll(%{state | selected: new_selected})}
  end

  def handle_event(%Event.Key{key: :down}, state) do
    max_idx = max(0, length(state.filtered) - 1)
    new_selected = min(max_idx, state.selected + 1)
    {:ok, update_scroll(%{state | selected: new_selected})}
  end

  def handle_event(%Event.Key{key: :backspace}, state) do
    new_query = String.slice(state.query, 0..-2//1)
    {:ok, filter_commands(%{state | query: new_query})}
  end

  def handle_event(%Event.Key{key: key}, state) when is_binary(key) and byte_size(key) == 1 do
    new_query = state.query <> key
    {:ok, filter_commands(%{state | query: new_query})}
  end

  def handle_event(_event, state) do
    {:ok, state}
  end

  @impl true
  def render(state, _area) do
    unless state.visible do
      empty()
    else
      render_dropdown(state)
    end
  end

  # Filter commands by prefix match
  defp filter_commands(state) do
    filtered =
      if state.query == "" do
        state.commands
      else
        query = String.downcase(state.query)

        Enum.filter(state.commands, fn cmd ->
          String.downcase(cmd.label) |> String.contains?(query)
        end)
      end

    %{state | filtered: filtered, selected: 0, scroll: 0}
  end

  # Keep selection visible in scroll window
  defp update_scroll(state) do
    scroll =
      cond do
        state.selected < state.scroll ->
          state.selected

        state.selected >= state.scroll + state.max_visible ->
          state.selected - state.max_visible + 1

        true ->
          state.scroll
      end

    %{state | scroll: scroll}
  end

  # Render the dropdown list
  defp render_dropdown(state) do
    visible_commands =
      state.filtered
      |> Enum.drop(state.scroll)
      |> Enum.take(state.max_visible)
      |> Enum.with_index(state.scroll)

    if visible_commands == [] do
      text("  (no matches)                    ", Style.new(fg: :bright_black))
    else
      # Calculate max label width for consistent padding
      # Add extra padding to ensure we overwrite any previous content
      max_label_width =
        state.filtered
        |> Enum.map(fn cmd -> String.length(cmd.label) end)
        |> Enum.max(fn -> 0 end)

      # Pad to at least 30 chars to clear any previous content on the line
      min_width = max(max_label_width, 30)

      rows =
        Enum.map(visible_commands, fn {cmd, idx} ->
          is_selected = idx == state.selected
          # Pad label to consistent width
          padded_label = String.pad_trailing(cmd.label, min_width)

          if is_selected do
            text("  " <> padded_label, Style.new(fg: :black, bg: :cyan))
          else
            text("  " <> padded_label, nil)
          end
        end)

      stack(:vertical, rows)
    end
  end

  # Public API

  @doc """
  Shows the command palette.
  """
  @spec show(map()) :: map()
  def show(state) do
    %{state | visible: true, query: "", selected: 0, scroll: 0}
    |> filter_commands()
  end

  @doc """
  Hides the command palette.
  """
  @spec hide(map()) :: map()
  def hide(state) do
    %{state | visible: false}
  end

  @doc """
  Toggles the command palette visibility.
  """
  @spec toggle(map()) :: map()
  def toggle(state) do
    if state.visible, do: hide(state), else: show(state)
  end

  @doc """
  Checks if the palette is visible.
  """
  @spec visible?(map()) :: boolean()
  def visible?(state) do
    state.visible
  end

  @doc """
  Gets the currently selected command.
  """
  @spec get_selected(map()) :: map() | nil
  def get_selected(state) do
    Enum.at(state.filtered, state.selected)
  end

  @doc """
  Gets the current query.
  """
  @spec get_query(map()) :: String.t()
  def get_query(state) do
    state.query
  end
end
