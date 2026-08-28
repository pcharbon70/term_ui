defmodule TermUI.Widgets.CommandPalette do
  @moduledoc """
  Simple command dropdown for filtering and selecting commands.

  Shows a list of commands filtered by case-insensitive substring as the user
  types.
  Similar to typing `/` in Claude Code to see available slash commands.

  ## Usage

      # Define commands
      commands = [
        %{id: :help, label: "/help"},
        %{id: :save, label: "/save"},
        %{id: :quit, label: "/quit"}
      ]

      # Create and show palette
      props = CommandPalette.new(commands: commands)
      {:ok, palette} = CommandPalette.init(props)

      # Render dropdown when visible
      if CommandPalette.visible?(palette) do
        CommandPalette.render(palette, area)
      end

  ## Keyboard Navigation

  - Type to filter by case-insensitive substring
  - Up/Down: Navigate through results
  - Enter: Select the highlighted command and close the palette
  - Escape: Close dropdown
  - Backspace: Delete character

  ## Monochrome Compatibility

  This widget is fully functional in monochrome terminals:
  - Selected items use reverse video for visibility
  - Filter input uses bold text for focus indication
  - All visual states remain distinguishable without color

  The widget automatically uses theme component styles which include
  monochrome-visible attributes (reverse, bold).
  """

  use TermUI.StatefulComponent

  alias TermUI.Event
  alias TermUI.Renderer.Style
  alias TermUI.Theme

  # Dialyzer: Functions return specific map types
  @dialyzer {:nowarn_function, new: 1, show: 1, hide: 1, toggle: 1}

  @doc """
  Creates new CommandPalette widget props.

  ## Options

  - `:commands` - List of command maps (required). Each command has:
    - `:id` - Unique identifier (atom)
    - `:label` - Display text (string)
    - Any other fields are application-owned metadata. The widget never invokes
      an `:action` function; the root application interprets the selection.
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
    if state.visible do
      render_dropdown(state)
    else
      empty()
    end
  end

  # Filter commands by case-insensitive substring match
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
          render_command_row(cmd, idx, state.selected, min_width)
        end)

      stack(:vertical, rows)
    end
  end

  defp render_command_row(cmd, idx, selected_idx, min_width) do
    padded_label = String.pad_trailing(cmd.label, min_width)
    text_line = "  " <> padded_label

    if idx == selected_idx do
      text(text_line, Theme.get_component_style(:item, :selected))
    else
      text(text_line, nil)
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
