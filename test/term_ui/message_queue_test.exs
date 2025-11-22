defmodule TermUI.MessageQueueTest do
  use ExUnit.Case, async: true

  alias TermUI.MessageQueue

  describe "new/1" do
    test "creates empty queue" do
      queue = MessageQueue.new()
      assert MessageQueue.empty?(queue)
      assert MessageQueue.size(queue) == 0
    end

    test "accepts max_size option" do
      queue = MessageQueue.new(max_size: 10)
      assert queue.max_size == 10
    end
  end

  describe "enqueue/2" do
    test "adds message to queue" do
      queue = MessageQueue.new()
      queue = MessageQueue.enqueue(queue, :test)

      assert MessageQueue.size(queue) == 1
      refute MessageQueue.empty?(queue)
    end

    test "preserves message order" do
      queue =
        MessageQueue.new()
        |> MessageQueue.enqueue(:first)
        |> MessageQueue.enqueue(:second)
        |> MessageQueue.enqueue(:third)

      {messages, _} = MessageQueue.flush(queue)
      assert messages == [:first, :second, :third]
    end

    test "drops messages when at max capacity" do
      queue = MessageQueue.new(max_size: 2)

      queue =
        queue
        |> MessageQueue.enqueue(:first)
        |> MessageQueue.enqueue(:second)
        |> MessageQueue.enqueue(:third)

      assert MessageQueue.size(queue) == 2
      assert MessageQueue.overflow_count(queue) == 1
    end
  end

  describe "enqueue_all/2" do
    test "enqueues multiple messages" do
      queue = MessageQueue.new()
      queue = MessageQueue.enqueue_all(queue, [:first, :second, :third])

      assert MessageQueue.size(queue) == 3
      {messages, _} = MessageQueue.flush(queue)
      assert messages == [:first, :second, :third]
    end
  end

  describe "flush/1" do
    test "returns all messages and empties queue" do
      queue =
        MessageQueue.new()
        |> MessageQueue.enqueue(:a)
        |> MessageQueue.enqueue(:b)

      {messages, new_queue} = MessageQueue.flush(queue)

      assert messages == [:a, :b]
      assert MessageQueue.empty?(new_queue)
    end

    test "returns empty list for empty queue" do
      queue = MessageQueue.new()
      {messages, _} = MessageQueue.flush(queue)
      assert messages == []
    end
  end

  describe "peek/1" do
    test "returns front message without removing" do
      queue =
        MessageQueue.new()
        |> MessageQueue.enqueue(:first)
        |> MessageQueue.enqueue(:second)

      assert {:value, :first} = MessageQueue.peek(queue)
      assert MessageQueue.size(queue) == 2
    end

    test "returns :empty for empty queue" do
      queue = MessageQueue.new()
      assert :empty = MessageQueue.peek(queue)
    end
  end

  describe "dequeue/1" do
    test "removes and returns front message" do
      queue =
        MessageQueue.new()
        |> MessageQueue.enqueue(:first)
        |> MessageQueue.enqueue(:second)

      {{:value, msg}, new_queue} = MessageQueue.dequeue(queue)

      assert msg == :first
      assert MessageQueue.size(new_queue) == 1
    end

    test "returns :empty for empty queue" do
      queue = MessageQueue.new()
      {:empty, _} = MessageQueue.dequeue(queue)
    end
  end

  describe "clear/1" do
    test "removes all messages and resets overflow" do
      queue =
        MessageQueue.new(max_size: 2)
        |> MessageQueue.enqueue(:a)
        |> MessageQueue.enqueue(:b)
        |> MessageQueue.enqueue(:c)

      queue = MessageQueue.clear(queue)

      assert MessageQueue.empty?(queue)
      assert MessageQueue.overflow_count(queue) == 0
    end
  end

  describe "process/3" do
    test "applies function to all messages" do
      queue =
        MessageQueue.new()
        |> MessageQueue.enqueue(1)
        |> MessageQueue.enqueue(2)
        |> MessageQueue.enqueue(3)

      {sum, new_queue} = MessageQueue.process(queue, 0, fn msg, acc -> acc + msg end)

      assert sum == 6
      assert MessageQueue.empty?(new_queue)
    end

    test "collects state and commands" do
      queue =
        MessageQueue.new()
        |> MessageQueue.enqueue(:increment)
        |> MessageQueue.enqueue(:increment)
        |> MessageQueue.enqueue({:add, 5})

      update_fn = fn
        :increment, {count, cmds} -> {count + 1, cmds}
        {:add, n}, {count, cmds} -> {count + n, [:added | cmds]}
      end

      {{final_count, commands}, _} = MessageQueue.process(queue, {0, []}, update_fn)

      assert final_count == 7
      assert commands == [:added]
    end
  end

  describe "message batching scenario" do
    test "multiple messages apply before single render" do
      # Simulate rapid input
      queue =
        MessageQueue.new()
        |> MessageQueue.enqueue({:key, :up})
        |> MessageQueue.enqueue({:key, :up})
        |> MessageQueue.enqueue({:key, :up})

      # Process batch
      {messages, _} = MessageQueue.flush(queue)

      # All messages should be processed
      assert length(messages) == 3
    end
  end
end
