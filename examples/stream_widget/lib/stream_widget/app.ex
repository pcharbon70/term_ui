defmodule StreamWidgetExample.App do
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
  alias TermUI.Renderer.Style
  alias StreamWidgetExample.Producer

  # TermUI.Elm Callbacks

  @impl true
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

    model = %{
      widget_state: widget_state,
      producer_pid: nil,
      consumer_pid: nil,
      interval_ms: 100,
      message: "Press Space to start streaming, q to quit"
    }

    {:ok, model}
  end

  @impl true
  def update(msg, model) do
    case msg do
      # Start streaming
      {:key, %{char: " "}} when model.producer_pid == nil ->
        {:ok, producer} = Producer.start_link(interval_ms: model.interval_ms)
        {:ok, consumer} = Consumer.start_link(self())
        Consumer.subscribe(consumer, producer)

        # Update widget state to reflect running
        {:ok, widget_state} =
          StreamWidget.handle_info({:consumer_started, consumer}, model.widget_state)

        new_model = %{
          model
          | producer_pid: producer,
            consumer_pid: consumer,
            widget_state: widget_state,
            message: "Streaming... Space to pause, q to quit"
        }

        {:ok, new_model}

      # Pause/resume when streaming
      {:key, %{char: " "}} when model.producer_pid != nil ->
        if StreamWidget.paused?(model.widget_state) do
          Producer.resume(model.producer_pid)
          {:ok, widget_state} = StreamWidget.resume(model.widget_state)
          {:ok, %{model | widget_state: widget_state, message: "Resumed streaming"}}
        else
          Producer.pause(model.producer_pid)
          {:ok, widget_state} = StreamWidget.pause(model.widget_state)
          {:ok, %{model | widget_state: widget_state, message: "Paused streaming"}}
        end

      # Clear buffer
      {:key, %{char: "c"}} ->
        {:ok, widget_state} = StreamWidget.clear(model.widget_state)
        {:ok, %{model | widget_state: widget_state, message: "Buffer cleared"}}

      # Toggle stats
      {:key, %{char: "s"}} ->
        {:ok, widget_state} = StreamWidget.handle_event(%TermUI.Event.Key{char: "s"}, model.widget_state)
        {:ok, %{model | widget_state: widget_state}}

      # Overflow strategies
      {:key, %{char: "1"}} ->
        {:ok, widget_state} = StreamWidget.set_overflow_strategy(model.widget_state, :drop_oldest)
        {:ok, %{model | widget_state: widget_state, message: "Strategy: drop_oldest"}}

      {:key, %{char: "2"}} ->
        {:ok, widget_state} = StreamWidget.set_overflow_strategy(model.widget_state, :drop_newest)
        {:ok, %{model | widget_state: widget_state, message: "Strategy: drop_newest"}}

      {:key, %{char: "3"}} ->
        {:ok, widget_state} = StreamWidget.set_overflow_strategy(model.widget_state, :block)
        {:ok, %{model | widget_state: widget_state, message: "Strategy: block"}}

      {:key, %{char: "4"}} ->
        {:ok, widget_state} = StreamWidget.set_overflow_strategy(model.widget_state, :sliding)
        {:ok, %{model | widget_state: widget_state, message: "Strategy: sliding"}}

      # Rate adjustment
      {:key, %{char: "+"}} ->
        new_interval = max(10, model.interval_ms - 10)
        if model.producer_pid, do: Producer.set_interval(model.producer_pid, new_interval)
        {:ok, %{model | interval_ms: new_interval, message: "Interval: #{new_interval}ms"}}

      {:key, %{char: "-"}} ->
        new_interval = min(1000, model.interval_ms + 10)
        if model.producer_pid, do: Producer.set_interval(model.producer_pid, new_interval)
        {:ok, %{model | interval_ms: new_interval, message: "Interval: #{new_interval}ms"}}

      # Navigation
      {:key, %{key: key}} when key in [:up, :down, :page_up, :page_down, :home, :end] ->
        event = %TermUI.Event.Key{key: key}
        {:ok, widget_state} = StreamWidget.handle_event(event, model.widget_state)
        {:ok, %{model | widget_state: widget_state}}

      # Quit
      {:key, %{char: "q"}} ->
        {:stop, :normal}

      {:key, %{key: :escape}} ->
        {:stop, :normal}

      # Stream items from consumer
      {:stream_items, items} ->
        {:ok, widget_state} = StreamWidget.handle_info({:stream_items, items}, model.widget_state)
        {:ok, %{model | widget_state: widget_state}}

      {:consumer_started, pid} ->
        {:ok, widget_state} = StreamWidget.handle_info({:consumer_started, pid}, model.widget_state)
        {:ok, %{model | widget_state: widget_state}}

      _ ->
        {:ok, model}
    end
  end

  @impl true
  def view(model) do
    # Use fixed dimensions for the widget
    area = %{x: 0, y: 0, width: 78, height: 15}

    widget_view = StreamWidget.render(model.widget_state, area)

    help_text = "[Space] Start/Pause | [c] Clear | [s] Stats | [1-4] Strategy | [+/-] Rate | [q] Quit"

    stack(:vertical, [
      text("StreamWidget Example", Style.new(fg: :cyan, attrs: [:bold])),
      text(model.message, Style.new(fg: :yellow)),
      text("", nil),
      render_widget_container(widget_view, model),
      text("", nil),
      text(help_text, Style.new(fg: :white, attrs: [:dim]))
    ])
  end

  defp render_widget_container(widget_view, model) do
    box_width = 80
    inner_width = box_width - 2

    stats = StreamWidget.get_stats(model.widget_state)
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
end
