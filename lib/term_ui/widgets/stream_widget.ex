defmodule TermUI.Widgets.StreamWidget do
  @moduledoc """
  StreamWidget for displaying backpressure-aware streaming data.

  StreamWidget can integrate with GenStage for demand-based data streaming,
  providing controls for stream management and real-time statistics.

  ## Usage

      StreamWidget.new(
        buffer_size: 1000,
        overflow_strategy: :drop_oldest
      )

  ## Features

  - Backpressure-aware data streaming via GenStage integration
  - Demand-based flow control
  - Buffer management with configurable overflow strategies
  - Pause/resume stream controls
  - Rate limiting for rendering
  - Real-time stream statistics (items/sec)

  ## Keyboard Controls

  - Space: Toggle pause/resume
  - c: Clear buffer
  - s: Toggle stats display
  - Up/Down: Scroll through buffer
  - PageUp/PageDown: Scroll by page
  - Home/End: Jump to first/last item

  ## GenStage Integration

  The widget provides a companion consumer module that can be started
  separately and sends items to the widget:

      {:ok, consumer} = StreamWidget.Consumer.start_link(widget_pid)
      GenStage.sync_subscribe(consumer, to: producer)
  """

  use TermUI.StatefulComponent

  alias TermUI.Event

  @type overflow_strategy :: :drop_oldest | :drop_newest | :block | :sliding

  @type stream_state :: :idle | :running | :paused | :error

  @type stream_item :: %{
          id: non_neg_integer(),
          timestamp: DateTime.t(),
          data: any(),
          metadata: map()
        }

  @type stats :: %{
          items_received: non_neg_integer(),
          items_dropped: non_neg_integer(),
          items_per_second: float(),
          buffer_size: non_neg_integer(),
          buffer_capacity: non_neg_integer(),
          last_update: DateTime.t() | nil
        }

  @default_buffer_size 1000
  @default_demand 10
  @page_size 20
  @stats_window_ms 5000

  # ----------------------------------------------------------------------------
  # Props
  # ----------------------------------------------------------------------------

  @doc """
  Creates new StreamWidget props.

  ## Options

  - `:buffer_size` - Maximum items in buffer (default: 1000)
  - `:overflow_strategy` - What to do when buffer is full (default: :drop_oldest)
  - `:demand` - How many items to request at a time (default: 10)
  - `:show_stats` - Display statistics bar (default: true)
  - `:render_rate_ms` - Minimum time between renders (default: 100)
  - `:item_renderer` - Function to render each item (fn item -> String.t)
  - `:on_item` - Callback when item is received
  - `:on_error` - Callback when error occurs
  """
  @spec new(keyword()) :: map()
  def new(opts) do
    %{
      buffer_size: Keyword.get(opts, :buffer_size, @default_buffer_size),
      overflow_strategy: Keyword.get(opts, :overflow_strategy, :drop_oldest),
      demand: Keyword.get(opts, :demand, @default_demand),
      show_stats: Keyword.get(opts, :show_stats, true),
      render_rate_ms: Keyword.get(opts, :render_rate_ms, 100),
      item_renderer: Keyword.get(opts, :item_renderer, &default_item_renderer/1),
      on_item: Keyword.get(opts, :on_item),
      on_error: Keyword.get(opts, :on_error)
    }
  end

  defp default_item_renderer(item) do
    case item do
      %{data: data} when is_binary(data) -> data
      %{data: data} -> inspect(data, limit: 50)
      data when is_binary(data) -> data
      data -> inspect(data, limit: 50)
    end
  end

  # ----------------------------------------------------------------------------
  # StatefulComponent Callbacks
  # ----------------------------------------------------------------------------

  @impl true
  def init(props) do
    state = %{
      # Buffer
      buffer: :queue.new(),
      buffer_count: 0,
      buffer_size: props.buffer_size,
      overflow_strategy: props.overflow_strategy,

      # Demand management
      demand: props.demand,
      pending_demand: 0,
      consumer_pid: nil,

      # Stream state
      stream_state: :idle,
      paused: false,

      # Stats
      stats: %{
        items_received: 0,
        items_dropped: 0,
        items_per_second: 0.0,
        buffer_size: 0,
        buffer_capacity: props.buffer_size,
        last_update: nil
      },
      stats_window: [],
      show_stats: props.show_stats,

      # Rendering
      scroll_offset: 0,
      cursor: 0,
      render_rate_ms: props.render_rate_ms,
      last_render_time: nil,
      pending_render: false,
      item_renderer: props.item_renderer,

      # Callbacks
      on_item: props.on_item,
      on_error: props.on_error,

      # Viewport
      viewport_height: 20,
      viewport_width: 80,
      last_area: nil,

      # Item ID counter
      next_id: 0
    }

    {:ok, state}
  end

  # ----------------------------------------------------------------------------
  # Event Handling
  # ----------------------------------------------------------------------------

  @impl true
  def handle_event(%Event.Key{key: :up}, state) do
    move_cursor(state, -1)
  end

  def handle_event(%Event.Key{key: :down}, state) do
    move_cursor(state, 1)
  end

  def handle_event(%Event.Key{key: :page_up}, state) do
    move_cursor(state, -@page_size)
  end

  def handle_event(%Event.Key{key: :page_down}, state) do
    move_cursor(state, @page_size)
  end

  def handle_event(%Event.Key{key: :home}, state) do
    {:ok, %{state | cursor: 0, scroll_offset: 0}}
  end

  def handle_event(%Event.Key{key: :end}, state) do
    last = max(0, state.buffer_count - 1)
    scroll = max(0, state.buffer_count - state.viewport_height)
    {:ok, %{state | cursor: last, scroll_offset: scroll}}
  end

  # Space - toggle pause/resume
  def handle_event(%Event.Key{char: " "}, state) do
    toggle_pause(state)
  end

  # c - clear buffer
  def handle_event(%Event.Key{char: "c"}, state) do
    do_clear(state)
  end

  # s - toggle stats
  def handle_event(%Event.Key{char: "s"}, state) do
    {:ok, %{state | show_stats: not state.show_stats}}
  end

  def handle_event(_event, state) do
    {:ok, state}
  end

  # ----------------------------------------------------------------------------
  # Message Handling
  # ----------------------------------------------------------------------------

  @impl true
  def handle_info({:stream_items, items}, state) when is_list(items) do
    handle_items(state, items)
  end

  def handle_info({:stream_item, item}, state) do
    handle_items(state, [item])
  end

  def handle_info({:consumer_started, pid}, state) do
    {:ok, %{state | consumer_pid: pid, stream_state: :running}}
  end

  def handle_info({:consumer_stopped, _reason}, state) do
    if state.on_error do
      state.on_error.(:consumer_stopped)
    end

    {:ok, %{state | consumer_pid: nil, stream_state: :idle}}
  end

  def handle_info({:request_demand, demand}, state) do
    # Consumer is requesting to know how much demand we want
    if state.consumer_pid do
      send(state.consumer_pid, {:set_demand, calculate_demand(state, demand)})
    end

    {:ok, state}
  end

  def handle_info(_msg, state) do
    {:ok, state}
  end

  # ----------------------------------------------------------------------------
  # Item Processing
  # ----------------------------------------------------------------------------

  defp handle_items(state, items) do
    now = DateTime.utc_now()
    {new_state, items_added, items_dropped} = add_items_to_buffer(state, items, now)

    # Update stats
    stats_window = update_stats_window(new_state.stats_window, items_added, now)
    items_per_second = calculate_items_per_second(stats_window, now)

    new_stats = %{
      new_state.stats
      | items_received: new_state.stats.items_received + items_added,
        items_dropped: new_state.stats.items_dropped + items_dropped,
        items_per_second: items_per_second,
        buffer_size: new_state.buffer_count,
        last_update: now
    }

    # Call on_item callback for each item
    if new_state.on_item do
      Enum.each(items, fn item -> new_state.on_item.(item) end)
    end

    new_state = %{new_state | stats: new_stats, stats_window: stats_window}

    # Notify consumer about available demand if using block strategy
    if new_state.consumer_pid && new_state.overflow_strategy == :block do
      demand = calculate_demand(new_state, new_state.demand)

      if demand > 0 do
        send(new_state.consumer_pid, {:set_demand, demand})
      end
    end

    {:ok, new_state}
  end

  # ----------------------------------------------------------------------------
  # Buffer Management
  # ----------------------------------------------------------------------------

  defp add_items_to_buffer(state, items, now) do
    Enum.reduce(items, {state, 0, 0}, fn event, {acc_state, added, dropped} ->
      item = create_item(event, acc_state.next_id, now)

      case add_to_buffer(acc_state, item) do
        {:ok, new_state} ->
          {%{new_state | next_id: new_state.next_id + 1}, added + 1, dropped}

        {:dropped, new_state} ->
          {%{new_state | next_id: new_state.next_id + 1}, added, dropped + 1}
      end
    end)
  end

  defp create_item(event, id, timestamp) do
    %{
      id: id,
      timestamp: timestamp,
      data: event,
      metadata: %{}
    }
  end

  defp add_to_buffer(state, item) do
    if state.buffer_count >= state.buffer_size do
      handle_overflow(state, item)
    else
      new_buffer = :queue.in(item, state.buffer)
      {:ok, %{state | buffer: new_buffer, buffer_count: state.buffer_count + 1}}
    end
  end

  defp handle_overflow(state, item) do
    case state.overflow_strategy do
      :drop_oldest ->
        {{:value, _dropped}, new_buffer} = :queue.out(state.buffer)
        new_buffer = :queue.in(item, new_buffer)
        {:ok, %{state | buffer: new_buffer}}

      :drop_newest ->
        {:dropped, state}

      :block ->
        # Don't add item, consumer should stop requesting
        {:dropped, state}

      :sliding ->
        # Same as drop_oldest
        {{:value, _dropped}, new_buffer} = :queue.out(state.buffer)
        new_buffer = :queue.in(item, new_buffer)
        {:ok, %{state | buffer: new_buffer}}
    end
  end

  # ----------------------------------------------------------------------------
  # Demand Management
  # ----------------------------------------------------------------------------

  defp calculate_demand(state, requested) do
    case state.overflow_strategy do
      :block ->
        available = state.buffer_size - state.buffer_count
        min(available, requested)

      _ ->
        requested
    end
  end

  # ----------------------------------------------------------------------------
  # Stats Calculation
  # ----------------------------------------------------------------------------

  defp update_stats_window(window, items_added, now) do
    cutoff = DateTime.add(now, -@stats_window_ms, :millisecond)

    # Remove old entries and add new
    window
    |> Enum.filter(fn {ts, _count} -> DateTime.compare(ts, cutoff) == :gt end)
    |> Kernel.++([{now, items_added}])
  end

  defp calculate_items_per_second(window, now) do
    if Enum.empty?(window) do
      0.0
    else
      total_items = Enum.reduce(window, 0, fn {_ts, count}, acc -> acc + count end)
      {oldest_ts, _} = Enum.min_by(window, fn {ts, _} -> DateTime.to_unix(ts, :millisecond) end)
      duration_ms = DateTime.diff(now, oldest_ts, :millisecond)

      if duration_ms > 0 do
        total_items / (duration_ms / 1000.0)
      else
        0.0
      end
    end
  end

  # ----------------------------------------------------------------------------
  # Navigation
  # ----------------------------------------------------------------------------

  defp move_cursor(state, delta) do
    new_cursor = state.cursor + delta
    new_cursor = max(0, min(new_cursor, state.buffer_count - 1))

    # Adjust scroll if cursor is out of view
    new_scroll =
      cond do
        new_cursor < state.scroll_offset ->
          new_cursor

        new_cursor >= state.scroll_offset + state.viewport_height ->
          new_cursor - state.viewport_height + 1

        true ->
          state.scroll_offset
      end

    {:ok, %{state | cursor: new_cursor, scroll_offset: max(0, new_scroll)}}
  end

  # ----------------------------------------------------------------------------
  # Pause/Resume
  # ----------------------------------------------------------------------------

  defp toggle_pause(state) do
    new_paused = not state.paused
    new_state = %{state | paused: new_paused}

    # Notify consumer
    if state.consumer_pid do
      if new_paused do
        send(state.consumer_pid, :pause)
      else
        send(state.consumer_pid, :resume)
      end
    end

    {:ok, new_state}
  end

  # ----------------------------------------------------------------------------
  # Public API
  # ----------------------------------------------------------------------------

  @doc """
  Add items directly (for non-GenStage sources).
  """
  @spec add_items(map(), [any()]) :: {:ok, map()}
  def add_items(state, items) do
    handle_items(state, items)
  end

  @doc """
  Add a single item directly.
  """
  @spec add_item(map(), any()) :: {:ok, map()}
  def add_item(state, item) do
    add_items(state, [item])
  end

  @doc """
  Pause receiving items.
  """
  @spec pause(map()) :: {:ok, map()}
  def pause(state) do
    if state.consumer_pid do
      send(state.consumer_pid, :pause)
    end

    {:ok, %{state | paused: true}}
  end

  @doc """
  Resume receiving items.
  """
  @spec resume(map()) :: {:ok, map()}
  def resume(state) do
    if state.consumer_pid do
      send(state.consumer_pid, :resume)
    end

    {:ok, %{state | paused: false}}
  end

  @doc """
  Clear the buffer.
  """
  @spec clear(map()) :: {:ok, map()}
  def clear(state) do
    do_clear(state)
  end

  defp do_clear(state) do
    {:ok,
     %{
       state
       | buffer: :queue.new(),
         buffer_count: 0,
         cursor: 0,
         scroll_offset: 0,
         stats: %{state.stats | buffer_size: 0}
     }}
  end

  @doc """
  Get current statistics.
  """
  @spec get_stats(map()) :: stats()
  def get_stats(state) do
    state.stats
  end

  @doc """
  Set buffer size. Will drop oldest items if new size is smaller.
  """
  @spec set_buffer_size(map(), non_neg_integer()) :: {:ok, map()}
  def set_buffer_size(state, new_size) when new_size > 0 do
    new_state =
      if new_size < state.buffer_count do
        # Need to drop items
        items_to_drop = state.buffer_count - new_size
        new_buffer = drop_oldest_n(state.buffer, items_to_drop)

        %{
          state
          | buffer: new_buffer,
            buffer_count: new_size,
            buffer_size: new_size,
            stats: %{state.stats | buffer_capacity: new_size, buffer_size: new_size}
        }
      else
        %{state | buffer_size: new_size, stats: %{state.stats | buffer_capacity: new_size}}
      end

    {:ok, new_state}
  end

  defp drop_oldest_n(queue, 0), do: queue

  defp drop_oldest_n(queue, n) do
    case :queue.out(queue) do
      {{:value, _}, new_queue} -> drop_oldest_n(new_queue, n - 1)
      {:empty, queue} -> queue
    end
  end

  @doc """
  Set overflow strategy.
  """
  @spec set_overflow_strategy(map(), overflow_strategy()) :: {:ok, map()}
  def set_overflow_strategy(state, strategy)
      when strategy in [:drop_oldest, :drop_newest, :block, :sliding] do
    {:ok, %{state | overflow_strategy: strategy}}
  end

  @doc """
  Get current buffer count.
  """
  @spec buffer_count(map()) :: non_neg_integer()
  def buffer_count(state), do: state.buffer_count

  @doc """
  Check if stream is paused.
  """
  @spec paused?(map()) :: boolean()
  def paused?(state), do: state.paused

  @doc """
  Get stream state.
  """
  @spec stream_state(map()) :: stream_state()
  def stream_state(state), do: state.stream_state

  @doc """
  Get buffer items as a list.
  """
  @spec get_items(map()) :: [stream_item()]
  def get_items(state), do: :queue.to_list(state.buffer)

  # ----------------------------------------------------------------------------
  # Rendering
  # ----------------------------------------------------------------------------

  @impl true
  def render(state, area) do
    # Update viewport dimensions
    state = %{
      state
      | viewport_height: area.height - (if state.show_stats, do: 2, else: 0),
        viewport_width: area.width,
        last_area: area
    }

    content_height = state.viewport_height
    items = get_visible_items(state, content_height)

    # Render items
    item_lines =
      items
      |> Enum.with_index()
      |> Enum.map(fn {item, idx} ->
        render_item(item, idx + state.scroll_offset, state)
      end)

    # Pad with empty lines if needed
    item_lines =
      if length(item_lines) < content_height do
        padding = List.duplicate(text("", nil), content_height - length(item_lines))
        item_lines ++ padding
      else
        item_lines
      end

    # Build render tree
    if state.show_stats do
      stack(:vertical, item_lines ++ [render_status_bar(state), render_stats_bar(state)])
    else
      stack(:vertical, item_lines)
    end
  end

  defp get_visible_items(state, count) do
    state.buffer
    |> :queue.to_list()
    |> Enum.drop(state.scroll_offset)
    |> Enum.take(count)
  end

  defp render_item(item, index, state) do
    is_selected = index == state.cursor
    content = state.item_renderer.(item)

    # Truncate to viewport width
    content =
      if String.length(content) > state.viewport_width do
        String.slice(content, 0, state.viewport_width - 3) <> "..."
      else
        content
      end

    if is_selected do
      text(content, Style.new(background: :blue, foreground: :white))
    else
      text(content, nil)
    end
  end

  defp render_status_bar(state) do
    status =
      case {state.stream_state, state.paused} do
        {:idle, _} -> "IDLE"
        {:running, true} -> "PAUSED"
        {:running, false} -> "RUNNING"
        {:error, _} -> "ERROR"
      end

    overflow_label =
      case state.overflow_strategy do
        :drop_oldest -> "drop-old"
        :drop_newest -> "drop-new"
        :block -> "block"
        :sliding -> "sliding"
      end

    status_text =
      "[#{status}] Buffer: #{state.buffer_count}/#{state.buffer_size} | Strategy: #{overflow_label}"

    text(status_text, Style.new(foreground: :cyan, bold: true))
  end

  defp render_stats_bar(state) do
    stats = state.stats

    rate =
      if stats.items_per_second >= 1000 do
        "#{Float.round(stats.items_per_second / 1000, 1)}K/s"
      else
        "#{Float.round(stats.items_per_second, 1)}/s"
      end

    stats_text =
      "Received: #{stats.items_received} | Dropped: #{stats.items_dropped} | Rate: #{rate}"

    text(stats_text, Style.new(foreground: :yellow))
  end
end
