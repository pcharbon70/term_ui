defmodule TermUI.ViewCache do
  @moduledoc """
  View memoization cache for skipping renders when state is unchanged.

  The view cache stores the last state hash and render tree for a component.
  When a component's state hasn't changed, we return the cached render tree
  instead of re-calling the view function.

  ## Usage

      cache = ViewCache.new()

      # Check if view needs recalculating
      case ViewCache.get(cache, state) do
        {:hit, render_tree} ->
          # Use cached result
          {render_tree, cache}

        :miss ->
          # Calculate and cache
          render_tree = Component.view(state)
          cache = ViewCache.put(cache, state, render_tree)
          {render_tree, cache}
      end

  ## Performance Considerations

  State hashing uses `:erlang.phash2/1` which is fast but may have collisions.
  For most UI state this is acceptable—the worst case is a redundant render.
  """

  @type state :: term()
  @type render_tree :: term()
  @type state_hash :: integer()

  @type t :: %__MODULE__{
          state_hash: state_hash() | nil,
          render_tree: render_tree() | nil,
          hits: non_neg_integer(),
          misses: non_neg_integer(),
          last_render_time_us: non_neg_integer()
        }

  defstruct state_hash: nil,
            render_tree: nil,
            hits: 0,
            misses: 0,
            last_render_time_us: 0

  # Performance warning threshold in microseconds
  @slow_view_threshold_us 1000

  @doc """
  Creates a new view cache.
  """
  @spec new() :: t()
  def new do
    %__MODULE__{}
  end

  @doc """
  Looks up a cached render tree for the given state.

  Returns `{:hit, render_tree}` if state matches cache,
  or `:miss` if view needs recalculating.
  """
  @spec get(t(), state()) :: {:hit, render_tree()} | :miss
  def get(%__MODULE__{state_hash: nil}, _state), do: :miss

  def get(%__MODULE__{state_hash: cached_hash, render_tree: tree}, state) do
    if hash_state(state) == cached_hash do
      {:hit, tree}
    else
      :miss
    end
  end

  @doc """
  Stores a render tree for the given state.
  """
  @spec put(t(), state(), render_tree()) :: t()
  def put(%__MODULE__{} = cache, state, render_tree) do
    %{
      cache
      | state_hash: hash_state(state),
        render_tree: render_tree
    }
  end

  @doc """
  Records a cache hit and returns updated cache.
  """
  @spec record_hit(t()) :: t()
  def record_hit(%__MODULE__{} = cache) do
    %{cache | hits: cache.hits + 1}
  end

  @doc """
  Records a cache miss and render time.
  """
  @spec record_miss(t(), non_neg_integer()) :: t()
  def record_miss(%__MODULE__{} = cache, render_time_us) do
    %{
      cache
      | misses: cache.misses + 1,
        last_render_time_us: render_time_us
    }
  end

  @doc """
  Invalidates the cache, forcing next view to recalculate.
  """
  @spec invalidate(t()) :: t()
  def invalidate(%__MODULE__{} = cache) do
    %{cache | state_hash: nil, render_tree: nil}
  end

  @doc """
  Returns cache statistics.
  """
  @spec stats(t()) :: %{hits: non_neg_integer(), misses: non_neg_integer(), hit_rate: float()}
  def stats(%__MODULE__{hits: hits, misses: misses}) do
    total = hits + misses
    hit_rate = if total > 0, do: hits / total * 100, else: 0.0

    %{
      hits: hits,
      misses: misses,
      hit_rate: hit_rate
    }
  end

  @doc """
  Checks if the last render was slow and returns a warning if so.
  """
  @spec check_performance(t()) :: :ok | {:slow_view, non_neg_integer()}
  def check_performance(%__MODULE__{last_render_time_us: time})
      when time > @slow_view_threshold_us do
    {:slow_view, time}
  end

  def check_performance(_cache), do: :ok

  @doc """
  Memoizes a view function call.

  Calls the view function only if state has changed, otherwise returns cached result.
  Also records timing and warns about slow views.
  """
  @spec memoize(t(), state(), (state() -> render_tree())) :: {render_tree(), t()}
  def memoize(%__MODULE__{} = cache, state, view_fun) do
    case get(cache, state) do
      {:hit, render_tree} ->
        cache = record_hit(cache)
        {render_tree, cache}

      :miss ->
        {time_us, render_tree} = :timer.tc(fn -> view_fun.(state) end)

        cache =
          cache
          |> put(state, render_tree)
          |> record_miss(time_us)

        case check_performance(cache) do
          {:slow_view, time} ->
            require Logger

            Logger.warning(
              "Slow view function: #{time}µs (threshold: #{@slow_view_threshold_us}µs)"
            )

          :ok ->
            :ok
        end

        {render_tree, cache}
    end
  end

  # Private functions

  defp hash_state(state) do
    :erlang.phash2(state)
  end
end
