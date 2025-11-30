defmodule TermUI.Widgets.StreamWidget.ConsumerTest do
  use ExUnit.Case, async: true

  alias TermUI.Widgets.StreamWidget.Consumer

  defmodule TestProducer do
    use GenStage

    def start_link(items) do
      GenStage.start_link(__MODULE__, items)
    end

    def init(items) do
      {:producer, items}
    end

    def handle_demand(demand, items) do
      {to_send, remaining} = Enum.split(items, demand)
      {:noreply, to_send, remaining}
    end
  end

  describe "start_link/2" do
    test "starts consumer and notifies widget" do
      widget_pid = self()
      {:ok, consumer} = Consumer.start_link(widget_pid)

      assert_receive {:consumer_started, ^consumer}
      assert Process.alive?(consumer)
    end
  end

  describe "event forwarding" do
    test "forwards events to widget" do
      widget_pid = self()
      {:ok, consumer} = Consumer.start_link(widget_pid)

      # Discard the consumer_started message
      assert_receive {:consumer_started, _}

      # Start a producer
      {:ok, producer} = TestProducer.start_link(["event1", "event2", "event3"])

      # Subscribe
      GenStage.sync_subscribe(consumer, to: producer)

      # Should receive events
      assert_receive {:stream_items, items}
      assert "event1" in items or "event2" in items or "event3" in items
    end
  end

  describe "pause/resume" do
    test "handles pause message" do
      widget_pid = self()
      {:ok, consumer} = Consumer.start_link(widget_pid)

      assert_receive {:consumer_started, _}

      # Send pause message
      send(consumer, :pause)

      # Process should still be alive
      assert Process.alive?(consumer)
    end

    test "handles resume message" do
      widget_pid = self()
      {:ok, consumer} = Consumer.start_link(widget_pid)

      assert_receive {:consumer_started, _}

      send(consumer, :pause)
      send(consumer, :resume)

      # Process should still be alive
      assert Process.alive?(consumer)
    end
  end

  describe "widget monitoring" do
    test "stops when widget dies" do
      # Trap exits so we don't crash
      Process.flag(:trap_exit, true)

      # Start a widget process that we can kill
      {:ok, widget_pid} = Agent.start(fn -> :running end)

      {:ok, consumer} = Consumer.start_link(widget_pid)

      # Consumer should be running
      assert Process.alive?(consumer)

      # Kill the widget
      Agent.stop(widget_pid)

      # Wait for the consumer to exit
      assert_receive {:EXIT, ^consumer, {:widget_down, :normal}}, 500

      # Consumer should have stopped
      refute Process.alive?(consumer)
    end
  end
end
