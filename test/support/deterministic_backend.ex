defmodule TermUI.Test.DeterministicBackend do
  @moduledoc false

  @behaviour TermUI.Backend

  @impl true
  def init(opts) do
    owner = Keyword.fetch!(opts, :owner)
    send(owner, {:backend, :init, self()})

    {:ok,
     %{
       owner: owner,
       size: Keyword.get(opts, :size, {6, 20}),
       events: Keyword.get(opts, :events, []),
       fail: Keyword.get(opts, :fail),
       draws: 0
     }}
  end

  @impl true
  def size(%{fail: :size}), do: {:error, :size_failed}
  def size(state), do: {:ok, state.size}

  @impl true
  def capabilities(%{fail: :capabilities}), do: raise("capabilities failed")
  def capabilities(_state), do: %{colors: :true_color, unicode: true}

  @impl true
  def draw(%{fail: :draw}, _frame), do: {:error, :draw_failed}

  def draw(state, frame) do
    send(state.owner, {:backend, :draw, frame})
    {:ok, %{state | draws: state.draws + 1}}
  end

  @impl true
  def flush(%{fail: :flush}), do: {:error, :flush_failed}

  def flush(state) do
    send(state.owner, {:backend, :flush, state.draws})
    {:ok, state}
  end

  @impl true
  def clipboard(%{fail: :clipboard}, _operation), do: {:error, :clipboard_failed}

  def clipboard(state, operation) do
    send(state.owner, {:backend, :clipboard, operation})
    {:ok, state}
  end

  @impl true
  def poll_event(%{fail: :input} = state, _timeout), do: {:error, :input_failed, state}

  def poll_event(%{events: [event | rest]} = state, _timeout),
    do: {:ok, event, %{state | events: rest}}

  def poll_event(state, timeout) do
    receive do
    after
      timeout -> {:timeout, state}
    end
  end

  @impl true
  def resize(%{fail: :resize}, _size), do: {:error, :resize_failed}

  def resize(state, size) do
    send(state.owner, {:backend, :resize, size})
    {:ok, %{state | size: size}}
  end

  @impl true
  def shutdown(state, reason) do
    send(state.owner, {:backend, :shutdown, reason})
    send(state.owner, {:backend, :shutdown_state, length(state.events), state.draws})
    :ok
  end
end
