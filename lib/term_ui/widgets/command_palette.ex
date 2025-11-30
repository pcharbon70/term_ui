defmodule TermUI.Widgets.CommandPalette do
  @moduledoc """
  CommandPalette widget for VS Code-style command discovery and execution.

  Provides a modal overlay with fuzzy search for commands, supporting
  categories, recent commands, keyboard shortcuts, nested menus,
  and async command loading.

  ## Usage

      CommandPalette.new(
        commands: [
          %{id: :save, label: "Save File", shortcut: "Ctrl+S", action: fn -> save_file() end},
          %{id: :open, label: "Open File", shortcut: "Ctrl+O", action: fn -> open_file() end},
          %{id: :goto_line, label: "Go to Line", category: :goto, action: fn -> goto_line() end}
        ],
        on_select: fn command -> execute_command(command) end,
        on_close: fn -> close_palette() end
      )

  ## Command Categories

  Use query prefixes to filter by category:
  - `>` - Commands (default)
  - `@` - Symbols/Go to
  - `#` - Topics/Tags
  - `:` - Line numbers/Locations

  ## Keyboard Navigation

  - Up/Down: Navigate through results
  - Enter: Execute selected command
  - Escape: Close palette
  - Backspace (empty query with submenu): Go back
  - PageUp/PageDown: Jump through results
  """

  use TermUI.StatefulComponent

  alias TermUI.Event
  alias TermUI.Widgets.WidgetHelpers, as: Helpers

  @type command :: %{
          id: atom(),
          label: String.t(),
          description: String.t() | nil,
          shortcut: String.t() | nil,
          category: atom() | nil,
          action: (-> term()) | {:submenu, [command()]} | {:async, (String.t() -> [command()])},
          icon: String.t() | nil,
          enabled: boolean() | (-> boolean())
        }

  @category_prefixes %{
    ">" => :command,
    "@" => :symbol,
    "#" => :tag,
    ":" => :location
  }

  @doc """
  Creates new CommandPalette widget props.

  ## Options

  - `:commands` - List of command definitions (required)
  - `:on_select` - Callback when command is selected
  - `:on_close` - Callback when palette is closed
  - `:max_visible` - Maximum visible results (default: 10)
  - `:max_recent` - Maximum recent commands to track (default: 5)
  - `:placeholder` - Search input placeholder (default: "Type a command...")
  - `:width` - Palette width (default: 60)
  """
  @spec new(keyword()) :: map()
  def new(opts) do
    commands = Keyword.fetch!(opts, :commands)

    %{
      commands: normalize_commands(commands),
      on_select: Keyword.get(opts, :on_select),
      on_close: Keyword.get(opts, :on_close),
      max_visible: Keyword.get(opts, :max_visible, 10),
      max_recent: Keyword.get(opts, :max_recent, 5),
      placeholder: Keyword.get(opts, :placeholder, "Type a command..."),
      width: Keyword.get(opts, :width, 60)
    }
  end

  defp normalize_commands(commands) do
    Enum.map(commands, fn cmd ->
      Map.merge(
        %{
          description: nil,
          shortcut: nil,
          category: :command,
          icon: nil,
          enabled: true
        },
        cmd
      )
    end)
  end

  @impl true
  def init(props) do
    state = %{
      commands: props.commands,
      filtered_commands: props.commands,
      query: "",
      selected_index: 0,
      recent_commands: [],
      max_recent: props.max_recent,
      max_visible: props.max_visible,
      visible: true,
      loading: false,
      async_error: nil,
      category_filter: nil,
      on_select: props.on_select,
      on_close: props.on_close,
      placeholder: props.placeholder,
      width: props.width,
      submenu_stack: [],
      scroll_offset: 0
    }

    {:ok, state}
  end

  @impl true
  def update(new_props, state) do
    # Update commands and configuration from new props
    state =
      state
      |> Map.put(:commands, normalize_commands(new_props.commands))
      |> Map.put(:max_recent, new_props.max_recent)
      |> Map.put(:max_visible, new_props.max_visible)
      |> Map.put(:placeholder, new_props.placeholder)
      |> Map.put(:width, new_props.width)

    # Re-filter commands with current query
    state = update_query(state, state.query)

    {:ok, state}
  end

  @impl true
  def handle_event(%Event.Key{key: :escape}, state) do
    if state.submenu_stack != [] do
      # Go back from submenu
      state = pop_submenu(state)
      {:ok, state}
    else
      # Close palette
      if state.on_close, do: state.on_close.()
      state = %{state | visible: false}
      {:ok, state}
    end
  end

  def handle_event(%Event.Key{key: :enter}, state) do
    if state.filtered_commands != [] do
      command = Enum.at(state.filtered_commands, state.selected_index)
      execute_command(state, command)
    else
      {:ok, state}
    end
  end

  def handle_event(%Event.Key{key: :up}, state) do
    new_index = max(0, state.selected_index - 1)
    state = update_selection(state, new_index)
    {:ok, state}
  end

  def handle_event(%Event.Key{key: :down}, state) do
    max_index = max(0, length(state.filtered_commands) - 1)
    new_index = min(max_index, state.selected_index + 1)
    state = update_selection(state, new_index)
    {:ok, state}
  end

  def handle_event(%Event.Key{key: :page_up}, state) do
    new_index = max(0, state.selected_index - state.max_visible)
    state = update_selection(state, new_index)
    {:ok, state}
  end

  def handle_event(%Event.Key{key: :page_down}, state) do
    max_index = max(0, length(state.filtered_commands) - 1)
    new_index = min(max_index, state.selected_index + state.max_visible)
    state = update_selection(state, new_index)
    {:ok, state}
  end

  def handle_event(%Event.Key{key: :backspace}, state) do
    cond do
      state.query == "" && state.submenu_stack != [] ->
        # Go back from submenu
        state = pop_submenu(state)
        {:ok, state}

      state.query != "" ->
        # Delete character
        new_query = String.slice(state.query, 0..-2//1)
        state = update_query(state, new_query)
        {:ok, state}

      true ->
        {:ok, state}
    end
  end

  def handle_event(%Event.Key{key: :tab}, state) do
    # Tab to autocomplete first result or cycle through
    {:ok, state}
  end

  def handle_event(%Event.Key{char: char}, state) when is_binary(char) and char != "" do
    new_query = state.query <> char
    state = update_query(state, new_query)
    {:ok, state}
  end

  def handle_event(_event, state) do
    {:ok, state}
  end

  @impl true
  def render(state, _area) do
    unless state.visible do
      empty()
    else
      render_palette(state)
    end
  end

  # Query handling

  defp update_query(state, new_query) do
    {category, search_query} = parse_query(new_query)

    # Get commands to search
    commands = get_current_commands(state)

    # Filter by category if specified
    commands =
      if category do
        Enum.filter(commands, &(&1.category == category))
      else
        commands
      end

    # Filter and score by search query
    filtered =
      if search_query == "" do
        # Show recent commands first, then all
        recent_cmds = get_recent_commands(state, commands)
        recent_ids = MapSet.new(Enum.map(recent_cmds, & &1.id))
        other_cmds = Enum.reject(commands, fn cmd -> MapSet.member?(recent_ids, cmd.id) end)
        recent_cmds ++ other_cmds
      else
        commands
        |> Enum.map(fn cmd ->
          score = fuzzy_score(search_query, cmd.label)
          {cmd, score}
        end)
        |> Enum.filter(fn {_cmd, score} -> score > 0 end)
        |> Enum.sort_by(fn {_cmd, score} -> -score end)
        |> Enum.map(fn {cmd, _score} -> cmd end)
      end

    %{
      state
      | query: new_query,
        category_filter: category,
        filtered_commands: filtered,
        selected_index: 0,
        scroll_offset: 0
    }
  end

  defp parse_query(query) do
    case query do
      ">" <> rest -> {:command, rest}
      "@" <> rest -> {:symbol, rest}
      "#" <> rest -> {:tag, rest}
      ":" <> rest -> {:location, rest}
      _ -> {nil, query}
    end
  end

  defp get_current_commands(state) do
    case state.submenu_stack do
      [] -> state.commands
      [%{commands: commands} | _] -> commands
    end
  end

  defp get_recent_commands(state, available_commands) do
    available_ids = MapSet.new(Enum.map(available_commands, & &1.id))

    state.recent_commands
    |> Enum.filter(&MapSet.member?(available_ids, &1))
    |> Enum.take(state.max_recent)
    |> Enum.map(fn id -> Enum.find(available_commands, &(&1.id == id)) end)
    |> Enum.reject(&is_nil/1)
  end

  # Fuzzy search - optimized with early termination

  # Minimum score threshold for fuzzy matches
  @min_fuzzy_score 5

  defp fuzzy_score(query, target) do
    query_lower = String.downcase(query)
    target_lower = String.downcase(target)
    query_len = String.length(query_lower)
    target_len = String.length(target_lower)

    cond do
      # Early termination: query longer than target can't match
      query_len > target_len ->
        0

      # Exact match
      target_lower == query_lower ->
        100

      # Prefix match
      String.starts_with?(target_lower, query_lower) ->
        50 + 10 * query_len

      # Contains
      String.contains?(target_lower, query_lower) ->
        30 + 5 * query_len

      # Fuzzy match with early termination
      true ->
        # Convert to charlists for O(1) indexing
        query_chars = String.to_charlist(query_lower)
        target_chars = String.to_charlist(target_lower)
        fuzzy_match_score(query_chars, target_chars, 0, 0, target_len)
    end
  end

  defp fuzzy_match_score([], _target, score, _last_match_idx, _target_len) do
    if score >= @min_fuzzy_score, do: score, else: 0
  end

  defp fuzzy_match_score([q | rest_q], target, score, last_match_idx, target_len) do
    # Early termination: not enough characters left to match remaining query
    remaining_query = length(rest_q) + 1
    remaining_target = target_len - last_match_idx

    if remaining_query > remaining_target do
      0
    else
      case find_char_index_fast(target, q, last_match_idx, target_len) do
        nil ->
          0

        idx ->
          # Bonus for consecutive matches (adjacent to previous match)
          consecutive_bonus = if idx == last_match_idx, do: 20, else: 0

          # Bonus for word boundary
          boundary_bonus =
            cond do
              idx == 0 -> 15
              Enum.at(target, idx - 1) in ~c" _-/\\" -> 10
              true -> 0
            end

          # Penalty for gaps
          gap_penalty = min(10, max(0, (idx - last_match_idx - 1) * 2))

          new_score = score + 10 + consecutive_bonus + boundary_bonus - gap_penalty
          fuzzy_match_score(rest_q, target, new_score, idx + 1, target_len)
      end
    end
  end

  # Optimized char finding using charlists for O(1) access
  defp find_char_index_fast(chars, target_char, start_idx, len) do
    find_char_index_fast(chars, target_char, start_idx, len, start_idx)
  end

  defp find_char_index_fast(_chars, _target_char, idx, len, _start) when idx >= len, do: nil

  defp find_char_index_fast(chars, target_char, idx, len, start) do
    if Enum.at(chars, idx) == target_char do
      idx
    else
      find_char_index_fast(chars, target_char, idx + 1, len, start)
    end
  end

  # Selection

  defp update_selection(state, new_index) do
    # Update scroll offset to keep selection visible
    scroll_offset =
      cond do
        new_index < state.scroll_offset ->
          new_index

        new_index >= state.scroll_offset + state.max_visible ->
          new_index - state.max_visible + 1

        true ->
          state.scroll_offset
      end

    %{state | selected_index: new_index, scroll_offset: scroll_offset}
  end

  # Command execution

  defp execute_command(state, nil), do: {:ok, state}

  defp execute_command(state, command) do
    # Check if enabled
    enabled =
      case command.enabled do
        true -> true
        false -> false
        fun when is_function(fun, 0) -> fun.()
      end

    unless enabled do
      {:ok, state}
    else
      case command.action do
        {:submenu, subcommands} ->
          state = push_submenu(state, command.id, subcommands)
          {:ok, state}

        {:async, loader} ->
          state = %{state | loading: true}
          # Execute loader with proper error handling
          # Note: For truly non-blocking async, the caller should spawn a Task
          # and send a message back. This implementation is synchronous but safe.
          try do
            commands = loader.(state.query)
            state = push_submenu(state, command.id, commands)
            state = %{state | loading: false}
            {:ok, state}
          rescue
            e ->
              require Logger
              Logger.error("CommandPalette async loader error for #{command.id}: #{inspect(e)}")
              state = %{state | loading: false, async_error: inspect(e)}
              {:ok, state}
          end

        action when is_function(action, 0) ->
          # Track in recent commands
          state = track_recent(state, command.id)

          # Execute action
          action.()

          # Call on_select callback
          if state.on_select, do: state.on_select.(command)

          # Close palette
          if state.on_close, do: state.on_close.()
          state = %{state | visible: false}
          {:ok, state}

        _ ->
          {:ok, state}
      end
    end
  end

  defp track_recent(state, command_id) do
    recent =
      [command_id | Enum.reject(state.recent_commands, &(&1 == command_id))]
      |> Enum.take(state.max_recent)

    %{state | recent_commands: recent}
  end

  # Submenu handling

  defp push_submenu(state, parent_id, commands) do
    entry = %{parent_id: parent_id, commands: normalize_commands(commands)}

    state = %{
      state
      | submenu_stack: [entry | state.submenu_stack],
        query: "",
        selected_index: 0,
        scroll_offset: 0
    }

    update_query(state, "")
  end

  defp pop_submenu(state) do
    case state.submenu_stack do
      [] ->
        state

      [_ | rest] ->
        state = %{state | submenu_stack: rest, query: "", selected_index: 0, scroll_offset: 0}

        update_query(state, "")
    end
  end

  # Rendering

  defp render_palette(state) do
    width = state.width

    # Build parts
    header = render_header(state, width)
    search = render_search_input(state, width)
    results = render_results(state, width)
    footer = render_footer(state, width)

    # Build palette
    content =
      stack(:vertical, [
        header,
        search,
        text(String.duplicate("─", width)),
        results,
        footer
      ])

    # Wrap in box
    styled(content, Style.new(attrs: [:bold]))
  end

  defp render_header(state, width) do
    # Breadcrumb for submenus
    breadcrumb =
      if state.submenu_stack != [] do
        path =
          state.submenu_stack
          |> Enum.reverse()
          |> Enum.map_join(" > ", fn %{parent_id: id} ->
            cmd = Enum.find(state.commands, &(&1.id == id))
            if cmd, do: cmd.label, else: to_string(id)
          end)

        " > #{path}"
      else
        ""
      end

    title = Helpers.pad_and_truncate("Command Palette#{breadcrumb}", width)

    styled(text("┌#{String.duplicate("─", width - 2)}┐\n│#{title}│"), Style.new(fg: :cyan))
  end

  defp render_search_input(state, width) do
    # Category prefix indicator
    prefix_indicator =
      case state.category_filter do
        :command -> ">"
        :symbol -> "@"
        :tag -> "#"
        :location -> ":"
        nil -> " "
      end

    # Query or placeholder
    display_text =
      if state.query == "" do
        state.placeholder
      else
        state.query
      end

    # Loading indicator
    loading_indicator = if state.loading, do: " ⟳", else: ""

    input_width = width - 6 - String.length(loading_indicator)
    truncated = Helpers.pad_and_truncate(display_text, input_width)

    input_content = "│ #{prefix_indicator} #{truncated}#{loading_indicator} │"

    if state.query == "" do
      styled(text(input_content), Style.new(fg: :white, attrs: [:dim]))
    else
      text(input_content)
    end
  end

  defp render_results(state, width) do
    if state.filtered_commands == [] do
      no_results = "  No commands found"
      padded = String.pad_trailing(no_results, width - 2)
      styled(text("│#{padded}│"), Style.new(fg: :white, attrs: [:dim]))
    else
      # Get visible slice
      visible_commands =
        state.filtered_commands
        |> Enum.drop(state.scroll_offset)
        |> Enum.take(state.max_visible)
        |> Enum.with_index(state.scroll_offset)

      rows =
        Enum.map(visible_commands, fn {cmd, idx} ->
          render_command_row(cmd, idx, state, width)
        end)

      stack(:vertical, rows)
    end
  end

  defp render_command_row(command, index, state, width) do
    is_selected = index == state.selected_index

    # Icon
    icon = command.icon || " "

    # Label with match highlighting
    label = command.label

    # Shortcut (right-aligned)
    shortcut =
      if command.shortcut do
        " [#{command.shortcut}]"
      else
        ""
      end

    # Calculate available space
    # For borders and padding
    content_width = width - 4
    # For icon and space
    label_width = content_width - String.length(shortcut) - 2

    # Truncate label if needed
    truncated_label = Helpers.truncate(label, label_width)
    padding_needed = content_width - String.length(truncated_label) - String.length(shortcut) - 2

    row_content =
      " #{icon} #{truncated_label}#{String.duplicate(" ", max(0, padding_needed))}#{shortcut} "

    row = "│#{row_content}│"

    Helpers.text_focused(row, is_selected)
  end

  defp render_footer(state, width) do
    # Show scroll indicator if there are more results
    total = length(state.filtered_commands)
    showing = min(state.max_visible, total)

    footer_text =
      if total > state.max_visible do
        "#{state.scroll_offset + 1}-#{state.scroll_offset + showing} of #{total}"
      else
        "#{total} commands"
      end

    # Navigation hints
    hints = "↑↓ navigate  ⏎ select  ⎋ close"

    padding = width - String.length(footer_text) - String.length(hints) - 4

    footer_content =
      if padding > 0 do
        " #{footer_text}#{String.duplicate(" ", padding)}#{hints} "
      else
        " #{footer_text} "
      end

    footer_content = Helpers.pad_and_truncate(footer_content, width - 2)

    styled(
      text("│#{footer_content}│\n└#{String.duplicate("─", width - 2)}┘"),
      Style.new(fg: :white, attrs: [:dim])
    )
  end

  # Public API

  @doc """
  Shows the command palette.
  """
  @spec show(map()) :: map()
  def show(state) do
    %{state | visible: true, query: "", selected_index: 0, scroll_offset: 0}
    |> update_query("")
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
    if state.visible do
      hide(state)
    else
      show(state)
    end
  end

  @doc """
  Checks if the palette is visible.
  """
  @spec visible?(map()) :: boolean()
  def visible?(state) do
    state.visible
  end

  @doc """
  Gets the current search query.
  """
  @spec get_query(map()) :: String.t()
  def get_query(state) do
    state.query
  end

  @doc """
  Sets the search query programmatically.
  """
  @spec set_query(map(), String.t()) :: map()
  def set_query(state, query) do
    update_query(state, query)
  end

  @doc """
  Gets the filtered commands.
  """
  @spec get_filtered_commands(map()) :: [command()]
  def get_filtered_commands(state) do
    state.filtered_commands
  end

  @doc """
  Gets the selected command.
  """
  @spec get_selected_command(map()) :: command() | nil
  def get_selected_command(state) do
    Enum.at(state.filtered_commands, state.selected_index)
  end

  @doc """
  Gets the recent commands.
  """
  @spec get_recent_commands(map()) :: [atom()]
  def get_recent_commands(state) do
    state.recent_commands
  end

  @doc """
  Clears the recent commands.
  """
  @spec clear_recent_commands(map()) :: map()
  def clear_recent_commands(state) do
    %{state | recent_commands: []}
  end

  @doc """
  Adds commands dynamically.
  """
  @spec add_commands(map(), [command()]) :: map()
  def add_commands(state, new_commands) do
    commands = state.commands ++ normalize_commands(new_commands)
    state = %{state | commands: commands}
    update_query(state, state.query)
  end

  @doc """
  Removes commands by ID.
  """
  @spec remove_commands(map(), [atom()]) :: map()
  def remove_commands(state, command_ids) do
    ids_set = MapSet.new(command_ids)
    commands = Enum.reject(state.commands, &MapSet.member?(ids_set, &1.id))
    state = %{state | commands: commands}
    update_query(state, state.query)
  end

  @doc """
  Gets the category prefix map.
  """
  @spec category_prefixes() :: map()
  def category_prefixes, do: @category_prefixes
end
