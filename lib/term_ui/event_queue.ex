defmodule TermUI.EventQueue do
  @moduledoc """
  Bounded event queue for preventing DoS via event flooding.

  This module implements a fixed-size queue with a drop-oldest strategy
  to prevent unbounded memory growth from rapid event input.

  ## Design

  The queue uses Erlang's `:queue` module for efficient operations:
  - O(1) amortized for enqueue/dequeue
  - O(1) for length checks

  When the queue is full and a new event arrives, the oldest event is
  dropped and a warning is logged (rate-limited).

  ## Example

      # Create a new queue with max size
      queue = EventQueue.new(max_size: 1000)

      # Add an event
      {:ok, queue} = EventQueue.push(queue, :some_event)

      # Drop oldest when full
      {{:dropped, oldest_event}, queue} = EventQueue.push(queue, :new_event)

      # Take next event
      {{:value, event}, queue} = EventQueue.pop(queue)
      {:empty, queue} = EventQueue.pop(queue)
  """

  require Logger

  @typedoc "Event queue structure"
  @type t :: %__MODULE__{
          queue: :queue.queue(),
          size: non_neg_integer(),
          max_size: pos_integer(),
          dropped_count: non_neg_integer(),
          last_warning: integer() | nil
        }

  @typedoc "Push result - either success or dropped event"
  @type push_result :: {:ok, t()} | {{:dropped, term()}, t()}

  @typedoc "Pop result - value, empty, or timeout"
  @type pop_result :: {{:value, term()}, t()} | {:empty, t()}

  defstruct [:queue, :size, :max_size, :dropped_count, :last_warning]

  @doc """
  Default maximum queue size.

  This value balances memory usage with responsiveness:
  - At 60 FPS, 1000 events = ~16 seconds of input buffer
  - Typical key presses are <100 events/sec
  """
  def max_size, do: 1000

  @doc """
  Warning rate limit in milliseconds (log once per 5 seconds max).
  """
  def warning_interval, do: 5000

  @doc """
  Creates a new event queue with the given options.

  ## Options

  - `:max_size` - Maximum number of events in queue (default: 1000)

  ## Example

      queue = EventQueue.new()
      queue = EventQueue.new(max_size: 500)
  """
  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    max_size = Keyword.get(opts, :max_size, max_size())

    %__MODULE__{
      queue: :queue.new(),
      size: 0,
      max_size: max_size,
      dropped_count: 0,
      last_warning: nil
    }
  end

  @doc """
  Returns the current size of the queue.
  """
  @spec size(t()) :: non_neg_integer()
  def size(%__MODULE__{size: size}), do: size

  @doc """
  Returns the maximum size of the queue.
  """
  @spec max_size(t()) :: pos_integer()
  def max_size(%__MODULE__{max_size: max_size}), do: max_size

  @doc """
  Returns whether the queue is empty.
  """
  @spec empty?(t()) :: boolean()
  def empty?(%__MODULE__{size: 0}), do: true
  def empty?(%__MODULE__{}), do: false

  @doc """
  Returns whether the queue is full.
  """
  @spec full?(t()) :: boolean()
  def full?(%__MODULE__{size: size, max_size: max_size}), do: size >= max_size

  @doc """
  Pushes an event onto the queue.

  If the queue is full, the oldest event is dropped and returned.

  ## Returns

  - `{:ok, queue}` - Event was added
  - `{{:dropped, oldest_event}, queue}` - Queue was full, oldest event dropped

  ## Example

      {:ok, queue} = EventQueue.push(queue, :event)
      {{:dropped, oldest}, queue} = EventQueue.push(queue, :new_event)
  """
  @spec push(t(), term()) :: push_result()
  def push(%__MODULE__{} = q, event) do
    if full?(q) do
      drop_oldest_and_push(q, event)
    else
      new_queue = :queue.in(event, q.queue)
      {:ok, %{q | queue: new_queue, size: q.size + 1}}
    end
  end

  @doc """
  Pushes an event onto the queue, dropping oldest if full.

  Similar to `push/2` but always returns the updated queue without
  indicating whether a drop occurred. Use `dropped_count/1` to check
  for drops.
  """
  @spec push!(t(), term()) :: t()
  def push!(%__MODULE__{} = q, event) do
    case push(q, event) do
      {:ok, new_q} -> new_q
      {{:dropped, _}, new_q} -> new_q
    end
  end

  @doc """
  Pops the next event from the queue.

  ## Returns

  - `{{:value, event}, queue}` - Next event
  - `{:empty, queue}` - Queue is empty

  ## Example

      {{:value, event}, queue} = EventQueue.pop(queue)
      {:empty, queue} = EventQueue.pop(queue)
  """
  @spec pop(t()) :: pop_result()
  def pop(%__MODULE__{size: 0} = q) do
    {:empty, q}
  end

  def pop(%__MODULE__{} = q) do
    case :queue.out(q.queue) do
      {{:value, event}, new_queue} ->
        {{:value, event}, %{q | queue: new_queue, size: q.size - 1}}

      {:empty, _} ->
        {:empty, q}
    end
  end

  @doc """
  Peeks at the next event without removing it.

  ## Returns

  - `{{:value, event}, queue}` - Next event
  - `{:empty, queue}` - Queue is empty
  """
  @spec peek(t()) :: pop_result()
  def peek(%__MODULE__{size: 0} = q) do
    {:empty, q}
  end

  def peek(%__MODULE__{} = q) do
    case :queue.peek(q.queue) do
      {:value, event} -> {{:value, event}, q}
      :empty -> {:empty, q}
    end
  end

  @doc """
  Returns the number of events that have been dropped due to overflow.

  This counter is cumulative for the lifetime of the queue.
  """
  @spec dropped_count(t()) :: non_neg_integer()
  def dropped_count(%__MODULE__{dropped_count: count}), do: count

  @doc """
  Resets the dropped event counter to zero.
  """
  @spec reset_dropped_count(t()) :: t()
  def reset_dropped_count(%__MODULE__{} = q), do: %{q | dropped_count: 0}

  @doc """
  Clears all events from the queue.
  """
  @spec clear(t()) :: t()
  def clear(%__MODULE__{} = q) do
    %{q | queue: :queue.new(), size: 0}
  end

  @doc """
  Converts the queue to a list for inspection/testing.

  Events are ordered from oldest to newest (front to back).
  """
  @spec to_list(t()) :: [term()]
  def to_list(%__MODULE__{} = q) do
    :queue.to_list(q.queue)
  end

  # Private functions

  # Drops the oldest event and pushes a new one.
  # Logs a warning if rate limit allows.
  defp drop_oldest_and_push(%__MODULE__{} = q, new_event) do
    # Drop oldest from front
    {{:value, oldest}, queue_after_drop} = :queue.out(q.queue)

    # Add new event at back
    new_queue = :queue.in(new_event, queue_after_drop)

    new_q = %{q | queue: new_queue, dropped_count: q.dropped_count + 1}

    # Log warning with rate limiting
    maybe_log_overflow(new_q)

    # Return dropped event and new queue
    {{:dropped, oldest}, new_q}
  end

  # Logs overflow warning if rate limit allows.
  defp maybe_log_overflow(%__MODULE__{dropped_count: count} = q) do
    now = System.monotonic_time(:millisecond)
    should_log = should_log_warning?(q, now)

    if should_log do
      Logger.warning(
        "TermUI.EventQueue: Overflow! Dropped events (total: #{count}). " <>
          "Input arriving faster than processing. Events are being dropped."
      )

      %{q | last_warning: now}
    else
      q
    end
  end

  # Determines if we should log a warning based on rate limit.
  defp should_log_warning?(%__MODULE__{last_warning: nil}, _now), do: true

  defp should_log_warning?(%__MODULE__{last_warning: last}, now) do
    now - last >= warning_interval()
  end
end
