defmodule TermUI.MessageQueue do
  @moduledoc """
  Message queue for batching multiple messages before rendering.

  Multiple messages may arrive between renders. We batch messages, applying
  all updates before rendering once. This prevents redundant renders when
  multiple events arrive quickly. The batch preserves message order for
  deterministic updates.

  ## Usage

      # Create a queue
      queue = MessageQueue.new()

      # Enqueue messages
      queue = MessageQueue.enqueue(queue, :increment)
      queue = MessageQueue.enqueue(queue, {:set_value, 42})

      # Process all messages
      {messages, queue} = MessageQueue.flush(queue)

      # Apply messages to state
      state = Enum.reduce(messages, state, fn msg, state ->
        {new_state, _commands} = Component.update(msg, state)
        new_state
      end)
  """

  @default_max_size 1000

  @type message :: term()
  @type t :: %__MODULE__{
          messages: :queue.queue(message()),
          size: non_neg_integer(),
          max_size: pos_integer(),
          overflow_count: non_neg_integer()
        }

  defstruct messages: nil,
            size: 0,
            max_size: @default_max_size,
            overflow_count: 0

  @doc """
  Creates a new message queue.

  ## Options

  - `:max_size` - Maximum number of messages before dropping (default: #{@default_max_size})
  """
  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    %__MODULE__{
      messages: :queue.new(),
      size: 0,
      max_size: Keyword.get(opts, :max_size, @default_max_size),
      overflow_count: 0
    }
  end

  @doc """
  Enqueues a message for processing.

  Messages are added to the back of the queue, preserving order.
  If the queue is at max capacity, the message is dropped and
  overflow count is incremented.
  """
  @spec enqueue(t(), message()) :: t()
  def enqueue(%__MODULE__{size: size, max_size: max_size} = queue, _message)
      when size >= max_size do
    %{queue | overflow_count: queue.overflow_count + 1}
  end

  def enqueue(%__MODULE__{} = queue, message) do
    %{
      queue
      | messages: :queue.in(message, queue.messages),
        size: queue.size + 1
    }
  end

  @doc """
  Enqueues multiple messages at once.
  """
  @spec enqueue_all(t(), [message()]) :: t()
  def enqueue_all(queue, messages) do
    Enum.reduce(messages, queue, &enqueue(&2, &1))
  end

  @doc """
  Removes and returns all messages from the queue.

  Returns `{messages, empty_queue}` where messages is a list
  in the order they were enqueued.
  """
  @spec flush(t()) :: {[message()], t()}
  def flush(%__MODULE__{} = queue) do
    messages = :queue.to_list(queue.messages)

    new_queue = %{
      queue
      | messages: :queue.new(),
        size: 0
    }

    {messages, new_queue}
  end

  @doc """
  Returns true if the queue is empty.
  """
  @spec empty?(t()) :: boolean()
  def empty?(%__MODULE__{size: 0}), do: true
  def empty?(_), do: false

  @doc """
  Returns the number of messages in the queue.
  """
  @spec size(t()) :: non_neg_integer()
  def size(%__MODULE__{size: size}), do: size

  @doc """
  Returns the number of dropped messages due to overflow.
  """
  @spec overflow_count(t()) :: non_neg_integer()
  def overflow_count(%__MODULE__{overflow_count: count}), do: count

  @doc """
  Peeks at the front message without removing it.
  """
  @spec peek(t()) :: {:value, message()} | :empty
  def peek(%__MODULE__{messages: messages}) do
    :queue.peek(messages)
  end

  @doc """
  Removes and returns the front message.
  """
  @spec dequeue(t()) :: {{:value, message()}, t()} | {:empty, t()}
  def dequeue(%__MODULE__{size: 0} = queue), do: {:empty, queue}

  def dequeue(%__MODULE__{} = queue) do
    {{:value, message}, new_messages} = :queue.out(queue.messages)

    new_queue = %{
      queue
      | messages: new_messages,
        size: queue.size - 1
    }

    {{:value, message}, new_queue}
  end

  @doc """
  Clears the queue and resets overflow count.
  """
  @spec clear(t()) :: t()
  def clear(%__MODULE__{} = queue) do
    %{
      queue
      | messages: :queue.new(),
        size: 0,
        overflow_count: 0
    }
  end

  @doc """
  Processes all queued messages with a function.

  Applies `fun` to each message and the accumulator, returning
  the final accumulator and empty queue.

  ## Example

      {final_state, commands, queue} = MessageQueue.process(queue, {state, []}, fn msg, {state, cmds} ->
        {new_state, new_cmds} = Component.update(msg, state)
        {new_state, cmds ++ new_cmds}
      end)
  """
  @spec process(t(), acc, (message(), acc -> acc)) :: {acc, t()} when acc: term()
  def process(%__MODULE__{} = queue, initial_acc, fun) do
    {messages, new_queue} = flush(queue)
    final_acc = Enum.reduce(messages, initial_acc, fun)
    {final_acc, new_queue}
  end
end
