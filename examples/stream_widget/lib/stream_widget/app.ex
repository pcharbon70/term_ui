defmodule StreamWidget.App do
  @moduledoc """
  Example application demonstrating the StreamWidget.

  This example shows:
  - GenStage producer integration
  - Real-time data streaming
  - Pause/resume controls
  - Buffer management
  - Statistics display
  - Overflow strategy switching

  ## Controls

  - Space: Pause/resume stream
  - c: Clear buffer
  - s: Toggle stats display
  - 1-4: Change overflow strategy
  - +/-: Increase/decrease event rate
  - Up/Down: Scroll through buffer
  - PageUp/PageDown: Scroll by page
  - q/Escape: Quit
  """

  use TermUI.Elm

  alias TermUI.Widgets.StreamWidget
  alias TermUI.Widgets.StreamWidget.Consumer
  alias TermUI.Event
  alias TermUI.Renderer.Style
  alias StreamWidgetExample.Producer

  # TermUI.Elm Callbacks

  def init(_args) do
    # Create stream widget props
    props =
      StreamWidget.new(
        buffer_size: 500,
        overflow_strategy: :drop_oldest,
        show_stats: true,
        item_renderer: &render_item/1
      )

    {:ok, widget_state} = StreamWidget.init(props)

    %{
      widget_state: widget_state,
      producer_pid: nil,
      consumer_pid: nil,
      interval_ms: 100,
      message: "Press Space to start streaming, q to quit"
    }
  end

  def event_to_msg(%Event.Key{key: " "}, _state), do: {:msg, :toggle_stream}
  def event_to_msg(%Event.Key{key: "c"}, _state), do: {:msg, :clear}
  def event_to_msg(%Event.Key{key: "s"}, _state), do: {:msg, :toggle_stats}
  def event_to_msg(%Event.Key{key: "1"}, _state), do: {:msg, {:strategy, :drop_oldest}}
  def event_to_msg(%Event.Key{key: "2"}, _state), do: {:msg, {:strategy, :drop_newest}}
  def event_to_msg(%Event.Key{key: "3"}, _state), do: {:msg, {:strategy, :block}}
  def event_to_msg(%Event.Key{key: "4"}, _state), do: {:msg, {:strategy, :sliding}}
  def event_to_msg(%Event.Key{key: "+"}, _state), do: {:msg, :faster}
  def event_to_msg(%Event.Key{key: "-"}, _state), do: {:msg, :slower}
  def event_to_msg(%Event.Key{key: key}, _state) when key in ["q", "Q"], do: {:msg, :quit}
  def event_to_msg(%Event.Key{key: :escape}, _state), do: {:msg, :quit}

  def event_to_msg(%Event.Key{key: key}, _state)
      when key in [:up, :down, :page_up, :page_down, :home, :end] do
    {:msg, {:widget_event, %Event.Key{key: key}}}
  end

  def event_to_msg(_event, _state), do: :ignore

  def update(:quit, state) do
    # Stop producer and consumer
    if state.producer_pid, do: GenStage.stop(state.producer_pid)
    if state.consumer_pid, do: GenStage.stop(state.consumer_pid)
    {state, [:quit]}
  end

  def update(:toggle_stream, state) when state.producer_pid == nil do
    # Start streaming
    {:ok, producer} = Producer.start_link(interval_ms: state.interval_ms)
    {:ok, consumer} = Consumer.start_link(self())
    Consumer.subscribe(consumer, producer)

    # Update widget state to reflect running
    {:ok, widget_state} =
      StreamWidget.handle_info({:consumer_started, consumer}, state.widget_state)

    {%{state |
      producer_pid: producer,
      consumer_pid: consumer,
      widget_state: widget_state,
      message: "Streaming... Space to pause, q to quit"
    }, []}
  end

  def update(:toggle_stream, state) do
    # Pause/resume when streaming
    if StreamWidget.paused?(state.widget_state) do
      Producer.resume(state.producer_pid)
      {:ok, widget_state} = StreamWidget.resume(state.widget_state)
      {%{state | widget_state: widget_state, message: "Resumed streaming"}, []}
    else
      Producer.pause(state.producer_pid)
      {:ok, widget_state} = StreamWidget.pause(state.widget_state)
      {%{state | widget_state: widget_state, message: "Paused streaming"}, []}
    end
  end

  def update(:clear, state) do
    {:ok, widget_state} = StreamWidget.clear(state.widget_state)
    {%{state | widget_state: widget_state, message: "Buffer cleared"}, []}
  end

  def update(:toggle_stats, state) do
    {:ok, widget_state} = StreamWidget.handle_event(%Event.Key{key: "s"}, state.widget_state)
    {%{state | widget_state: widget_state}, []}
  end

  def update({:strategy, strategy}, state) do
    {:ok, widget_state} = StreamWidget.set_overflow_strategy(state.widget_state, strategy)
    {%{state | widget_state: widget_state, message: "Strategy: #{strategy}"}, []}
  end

  def update(:faster, state) do
    new_interval = max(10, state.interval_ms - 10)
    if state.producer_pid, do: Producer.set_interval(state.producer_pid, new_interval)
    {%{state | interval_ms: new_interval, message: "Interval: #{new_interval}ms"}, []}
  end

  def update(:slower, state) do
    new_interval = min(1000, state.interval_ms + 10)
    if state.producer_pid, do: Producer.set_interval(state.producer_pid, new_interval)
    {%{state | interval_ms: new_interval, message: "Interval: #{new_interval}ms"}, []}
  end

  def update({:widget_event, event}, state) do
    {:ok, widget_state} = StreamWidget.handle_event(event, state.widget_state)
    {%{state | widget_state: widget_state}, []}
  end

  def update(_msg, state) do
    {state, []}
  end

  # Handle info messages from the consumer
  def handle_info({:stream_items, items}, state) do
    {:ok, widget_state} = StreamWidget.handle_info({:stream_items, items}, state.widget_state)
    {%{state | widget_state: widget_state}, []}
  end

  def handle_info({:consumer_started, pid}, state) do
    {:ok, widget_state} = StreamWidget.handle_info({:consumer_started, pid}, state.widget_state)
    {%{state | widget_state: widget_state}, []}
  end

  def handle_info(_msg, state) do
    {state, []}
  end

  def view(state) do
    # Use fixed dimensions for the widget
    area = %{x: 0, y: 0, width: 78, height: 15}

    widget_view = StreamWidget.render(state.widget_state, area)

    help_text = "[Space] Start/Pause | [c] Clear | [s] Stats | [1-4] Strategy | [+/-] Rate | [q] Quit"

    stack(:vertical, [
      text("StreamWidget Example", Style.new(fg: :cyan, attrs: [:bold])),
      text(state.message, Style.new(fg: :yellow)),
      text("", nil),
      render_widget_container(widget_view, state),
      text("", nil),
      text(help_text, Style.new(fg: :white, attrs: [:dim]))
    ])
  end

  defp render_widget_container(widget_view, state) do
    box_width = 80
    inner_width = box_width - 2

    stats = StreamWidget.get_stats(state.widget_state)
    buffer_info = "Buffer: #{stats.buffer_size}/#{stats.buffer_capacity}"

    top_border = "+" <> String.duplicate("-", 3) <> " Stream " <> String.duplicate("-", inner_width - 14 - String.length(buffer_info)) <> " #{buffer_info} +"
    bottom_border = "+" <> String.duplicate("-", inner_width) <> "+"

    stack(:vertical, [
      text(top_border, Style.new(fg: :blue)),
      stack(:horizontal, [
        text("| ", nil),
        widget_view,
        text(" |", nil)
      ]),
      text(bottom_border, Style.new(fg: :blue))
    ])
  end

  # Custom item renderer for display
  defp render_item(item) do
    data = item.data

    cond do
      is_binary(data) -> data
      true -> inspect(data)
    end
  end

  # Public API

  def run do
    TermUI.Runtime.run(root: __MODULE__)
  end
end
