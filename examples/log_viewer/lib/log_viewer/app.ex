defmodule LogViewer.App do
  @moduledoc """
  LogViewer Widget Example

  This example demonstrates how to use the TermUI.Widgets.LogViewer widget
  for displaying and analyzing log data with virtual scrolling.

  Features demonstrated:
  - Virtual scrolling for large log datasets
  - Tail mode for live log monitoring
  - Search with regex support
  - Syntax highlighting for log levels
  - Filtering by pattern
  - Line bookmarking
  - Selection for copy operations
  - Wrap/truncate toggle

  Controls:
  - Up/Down: Navigate between lines
  - PageUp/PageDown: Scroll by page
  - Home/End: Jump to first/last line
  - /: Start search
  - n/N: Next/previous search match
  - f: Toggle filter mode
  - b: Toggle bookmark on current line
  - B: Jump to next bookmark
  - t: Toggle tail mode
  - w: Toggle wrap mode
  - Space: Start/extend selection
  - Escape: Clear search/filter/selection
  - A: Add simulated log entries
  - C: Clear all logs
  - Q: Quit the application
  """

  use TermUI.Elm

  alias TermUI.Event
  alias TermUI.Renderer.Style
  alias TermUI.Widgets.LogViewer, as: LV

  @modules ["MyApp.Server", "MyApp.Handler", "MyApp.Database", "MyApp.Cache", "MyApp.Auth"]
  @levels [:debug, :info, :warning, :error]
  @messages [
    "Request processed successfully",
    "Connection established",
    "Cache hit for key: user_123",
    "Slow query detected: 250ms",
    "Authentication failed for user",
    "Database connection pool at 80%",
    "Memory usage: 512MB",
    "Rate limit exceeded",
    "Session expired",
    "Config reloaded"
  ]

  # ----------------------------------------------------------------------------
  # Component Callbacks
  # ----------------------------------------------------------------------------

  @doc """
  Initialize the component state.
  """
  def init(_opts) do
    initial_logs = generate_initial_logs(50)

    %{
      log_state: nil,
      initial_logs: initial_logs,
      log_counter: 50,
      status_message: "Use / to search, f to filter, t for tail mode"
    }
  end

  defp build_log_state(logs) do
    props =
      LV.new(
        lines: logs,
        tail_mode: true,
        highlight_levels: true,
        show_line_numbers: true,
        show_levels: true,
        max_lines: 10_000
      )

    {:ok, state} = LV.init(props)
    state
  end

  defp generate_initial_logs(count) do
    base_time = DateTime.utc_now()

    for i <- 0..(count - 1) do
      generate_log_line(base_time, i)
    end
  end

  defp generate_log_line(base_time, offset) do
    timestamp = DateTime.add(base_time, offset, :second)
    module = Enum.random(@modules)
    level = Enum.random(@levels)
    message = Enum.random(@messages)

    level_str = level |> Atom.to_string() |> String.upcase()
    ts_str = DateTime.to_iso8601(timestamp)

    "#{ts_str} [#{module}] #{level_str}: #{message}"
  end

  @doc """
  Convert keyboard events to messages.
  """
  def event_to_msg(%Event.Key{key: key}, _state) when key in ["q", "Q"], do: {:msg, :quit}
  def event_to_msg(%Event.Key{key: key}, _state) when key in ["a", "A"], do: {:msg, :add_logs}
  def event_to_msg(%Event.Key{key: key}, _state) when key in ["c", "C"], do: {:msg, :clear_logs}

  def event_to_msg(event, _state) do
    {:msg, {:log_event, event}}
  end

  @doc """
  Update state based on messages.
  """
  def update(:quit, state) do
    {state, [:quit]}
  end

  def update(:add_logs, state) do
    log_state = ensure_log_state(state)
    base_time = DateTime.utc_now()

    new_logs =
      for i <- 0..4 do
        generate_log_line(base_time, state.log_counter + i)
      end

    log_state = LV.add_lines(log_state, new_logs)
    message = "Added 5 log entries (total: #{LV.line_count(log_state)})"

    {%{state | log_state: log_state, log_counter: state.log_counter + 5, status_message: message}, []}
  end

  def update(:clear_logs, state) do
    log_state = ensure_log_state(state)
    log_state = LV.clear(log_state)
    {%{state | log_state: log_state, log_counter: 0, status_message: "Logs cleared"}, []}
  end

  def update({:log_event, event}, state) do
    log_state = ensure_log_state(state)
    {:ok, log_state} = LV.handle_event(event, log_state)

    message = get_status_message(log_state)
    {%{state | log_state: log_state, status_message: message}, []}
  end

  defp ensure_log_state(state) do
    state.log_state || build_log_state(state.initial_logs)
  end

  defp get_status_message(log_state) do
    parts = []

    parts =
      if log_state.search do
        match_count = length(log_state.search.matches)
        current = log_state.search.current_match + 1
        parts ++ ["Search: #{current}/#{match_count}"]
      else
        parts
      end

    parts =
      if log_state.filter do
        visible = LV.visible_line_count(log_state)
        total = LV.line_count(log_state)
        parts ++ ["Filtered: #{visible}/#{total}"]
      else
        parts
      end

    parts =
      if MapSet.size(log_state.bookmarks) > 0 do
        parts ++ ["Bookmarks: #{MapSet.size(log_state.bookmarks)}"]
      else
        parts
      end

    parts =
      if log_state.tail_mode do
        parts ++ ["TAIL"]
      else
        parts
      end

    if length(parts) > 0 do
      Enum.join(parts, " | ")
    else
      "Use / to search, f to filter, t for tail mode"
    end
  end

  @doc """
  Render the current state to a render tree.
  """
  def view(state) do
    log_state = ensure_log_state(state)

    stack(:vertical, [
      # Title
      text("LogViewer Widget Example", Style.new(fg: :cyan, attrs: [:bold])),
      text("", nil),

      # Log viewer
      render_log_container(log_state),

      # Status
      text("", nil),
      text(state.status_message, Style.new(fg: :yellow)),

      # Controls
      render_controls(log_state)
    ])
  end

  defp render_log_container(log_state) do
    log_render = LV.render(log_state, %{x: 0, y: 0, width: 75, height: 15})

    box_width = 77
    inner_width = box_width - 2

    line_info = "Lines: #{LV.line_count(log_state)}"
    top_border = "+" <> String.duplicate("-", 3) <> " Log Output " <> String.duplicate("-", inner_width - 16) <> " #{line_info} " <> "+"
    bottom_border = "+" <> String.duplicate("-", inner_width) <> "+"

    stack(:vertical, [
      text(top_border, Style.new(fg: :blue)),
      stack(:horizontal, [
        text("| ", nil),
        log_render,
        text(" |", nil)
      ]),
      text(bottom_border, Style.new(fg: :blue))
    ])
  end

  defp render_controls(log_state) do
    box_width = 60
    inner_width = box_width - 2

    tail_str = if log_state.tail_mode, do: "ON", else: "OFF"
    wrap_str = if log_state.wrap_lines, do: "ON", else: "OFF"

    top_border = "+" <> String.duplicate("-", inner_width - 10) <> " Controls " <> "+"
    bottom_border = "+" <> String.duplicate("-", inner_width) <> "+"

    stack(:vertical, [
      text("", nil),
      text(top_border, Style.new(fg: :yellow)),
      text("|" <> String.pad_trailing("  Up/Down      Navigate lines", inner_width) <> "|", nil),
      text("|" <> String.pad_trailing("  PgUp/PgDn    Scroll by page", inner_width) <> "|", nil),
      text("|" <> String.pad_trailing("  Home/End     First/last line", inner_width) <> "|", nil),
      text("|" <> String.pad_trailing("  /            Start search", inner_width) <> "|", nil),
      text("|" <> String.pad_trailing("  n/N          Next/prev match", inner_width) <> "|", nil),
      text("|" <> String.pad_trailing("  f            Toggle filter", inner_width) <> "|", nil),
      text("|" <> String.pad_trailing("  b/B          Bookmark / Jump to next", inner_width) <> "|", nil),
      text("|" <> String.pad_trailing("  t            Toggle tail mode (#{tail_str})", inner_width) <> "|", nil),
      text("|" <> String.pad_trailing("  w            Toggle wrap (#{wrap_str})", inner_width) <> "|", nil),
      text("|" <> String.pad_trailing("  Space        Start/extend selection", inner_width) <> "|", nil),
      text("|" <> String.pad_trailing("  A/C          Add logs / Clear logs", inner_width) <> "|", nil),
      text("|" <> String.pad_trailing("  Escape       Clear search/filter/selection", inner_width) <> "|", nil),
      text("|" <> String.pad_trailing("  Q            Quit", inner_width) <> "|", nil),
      text(bottom_border, Style.new(fg: :yellow))
    ])
  end

  # ----------------------------------------------------------------------------
  # Public API
  # ----------------------------------------------------------------------------

  @doc """
  Run the log viewer example application.
  """
  def run do
    TermUI.Runtime.run(root: __MODULE__)
  end
end
