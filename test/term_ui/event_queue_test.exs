defmodule TermUI.EventQueueTest do
  use ExUnit.Case, async: true

  alias TermUI.EventQueue

  describe "new/1" do
    test "creates queue with default max size" do
      queue = EventQueue.new()
      assert EventQueue.max_size(queue) == 1000
      assert EventQueue.size(queue) == 0
      assert EventQueue.empty?(queue)
    end

    test "creates queue with custom max size" do
      queue = EventQueue.new(max_size: 500)
      assert EventQueue.max_size(queue) == 500
    end
  end

  describe "push/2 and pop/1" do
    test "push and pop single event" do
      queue = EventQueue.new()
      assert {:ok, queue} = EventQueue.push(queue, :event1)

      refute EventQueue.empty?(queue)
      assert EventQueue.size(queue) == 1

      {{:value, :event1}, queue} = EventQueue.pop(queue)
      assert EventQueue.empty?(queue)
    end

    test "maintains FIFO order" do
      queue = EventQueue.new()
      {:ok, queue} = EventQueue.push(queue, :first)
      {:ok, queue} = EventQueue.push(queue, :second)
      {:ok, queue} = EventQueue.push(queue, :third)

      assert EventQueue.size(queue) == 3

      {{:value, :first}, queue} = EventQueue.pop(queue)
      {{:value, :second}, queue} = EventQueue.pop(queue)
      {{:value, :third}, queue} = EventQueue.pop(queue)

      assert EventQueue.empty?(queue)
    end

    test "pop from empty queue returns empty" do
      queue = EventQueue.new()
      assert {:empty, queue} = EventQueue.pop(queue)
    end
  end

  describe "peek/1" do
    test "returns event without removing it" do
      queue = EventQueue.new()
      {:ok, queue} = EventQueue.push(queue, :peek_test)

      {{:value, :peek_test}, queue} = EventQueue.peek(queue)
      assert EventQueue.size(queue) == 1
      assert EventQueue.full?(queue) == false
    end

    test "peek on empty queue" do
      queue = EventQueue.new()
      assert {:empty, queue} = EventQueue.peek(queue)
    end
  end

  describe "bounded behavior" do
    test "drops oldest event when full" do
      queue = EventQueue.new(max_size: 3)
      {:ok, queue} = EventQueue.push(queue, :first)
      {:ok, queue} = EventQueue.push(queue, :second)
      {:ok, queue} = EventQueue.push(queue, :third)

      assert EventQueue.full?(queue)
      assert EventQueue.size(queue) == 3

      # This should drop :first
      {{:dropped, :first}, queue} = EventQueue.push(queue, :fourth)

      assert EventQueue.size(queue) == 3

      # Verify :first is gone, :second is now oldest
      {{:value, :second}, queue} = EventQueue.pop(queue)
      {{:value, :third}, queue} = EventQueue.pop(queue)
      {{:value, :fourth}, queue} = EventQueue.pop(queue)

      assert {:empty, _} = EventQueue.pop(queue)
    end

    test "tracks dropped events" do
      queue = EventQueue.new(max_size: 2)
      {:ok, queue} = EventQueue.push(queue, :a)
      {:ok, queue} = EventQueue.push(queue, :b)

      assert EventQueue.dropped_count(queue) == 0

      {{:dropped, :a}, queue} = EventQueue.push(queue, :c)
      assert EventQueue.dropped_count(queue) == 1

      {{:dropped, :b}, queue} = EventQueue.push(queue, :d)
      assert EventQueue.dropped_count(queue) == 2
    end

    test "reset_dropped_count resets counter" do
      queue = EventQueue.new(max_size: 1)
      {:ok, queue} = EventQueue.push(queue, :x)
      {{:dropped, :x}, queue} = EventQueue.push(queue, :y)

      assert EventQueue.dropped_count(queue) > 0

      queue = EventQueue.reset_dropped_count(queue)
      assert EventQueue.dropped_count(queue) == 0
    end
  end

  describe "full? and empty?" do
    test "full? returns true at capacity" do
      queue = EventQueue.new(max_size: 1)
      {:ok, queue} = EventQueue.push(queue, :event)

      assert EventQueue.full?(queue)
    end

    test "empty? returns true for new queue" do
      queue = EventQueue.new()
      assert EventQueue.empty?(queue)
    end
  end

  describe "push!/2" do
    test "always returns queue even when dropping" do
      queue = EventQueue.new(max_size: 1)
      {:ok, queue} = EventQueue.push(queue, :first)

      # This drops :first but still returns queue
      queue = EventQueue.push!(queue, :second)
      assert EventQueue.size(queue) == 1
    end
  end

  describe "clear/1" do
    test "clears all events" do
      queue = EventQueue.new()
      {:ok, queue} = EventQueue.push(queue, :a)
      {:ok, queue} = EventQueue.push(queue, :b)
      {:ok, queue} = EventQueue.push(queue, :c)

      assert EventQueue.size(queue) == 3

      queue = EventQueue.clear(queue)
      assert EventQueue.empty?(queue)
      assert EventQueue.size(queue) == 0
    end
  end

  describe "to_list/1" do
    test "converts queue to list" do
      queue = EventQueue.new()
      {:ok, queue} = EventQueue.push(queue, :first)
      {:ok, queue} = EventQueue.push(queue, :second)
      {:ok, queue} = EventQueue.push(queue, :third)

      list = EventQueue.to_list(queue)
      assert list == [:first, :second, :third]
    end

    test "empty queue returns empty list" do
      queue = EventQueue.new()
      assert EventQueue.to_list(queue) == []
    end
  end

  describe "integration - stress test" do
    test "handles rapid push/pop without overflow" do
      queue = EventQueue.new(max_size: 100)

      # Push 1000 events, should only keep 100
      queue =
        Enum.reduce(1..1000, queue, fn i, q ->
          {_, updated} = EventQueue.push(q, i)
          updated
        end)

      assert EventQueue.size(queue) == 100
      assert EventQueue.dropped_count(queue) >= 900
    end

    test "drain queue processes all events" do
      queue = EventQueue.new(max_size: 10)
      {:ok, queue} = EventQueue.push(queue, 1)
      {:ok, queue} = EventQueue.push(queue, 2)
      {:ok, queue} = EventQueue.push(queue, 3)

      # Drain all
      {events, queue} = drain_all(queue, [])
      assert Enum.reverse(events) == [1, 2, 3]
      assert EventQueue.empty?(queue)
    end
  end

  # Helper to drain all events from queue
  defp drain_all(queue, acc) do
    case EventQueue.pop(queue) do
      {{:value, event}, new_queue} -> drain_all(new_queue, [event | acc])
      {:empty, _} -> {acc, queue}
    end
  end
end
