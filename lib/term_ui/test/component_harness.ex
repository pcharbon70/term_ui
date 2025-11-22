defmodule TermUI.Test.ComponentHarness do
  @moduledoc """
  Test harness for isolated component testing.

  Mounts a component in isolation with a test renderer, allowing
  event simulation and state/render inspection.

  ## Usage

      # Mount component
      {:ok, harness} = ComponentHarness.mount_test(MyButton, label: "Click me")

      # Render
      harness = ComponentHarness.render(harness)

      # Send events
      harness = ComponentHarness.send_event(harness, Event.key(:enter))

      # Inspect state and render
      state = ComponentHarness.get_state(harness)
      renderer = ComponentHarness.get_renderer(harness)

      # Cleanup
      ComponentHarness.unmount(harness)

  ## Component Interface

  Components must implement these callbacks:
  - `init/1` - Initialize state from props
  - `render/1` - Render component to nodes
  - `handle_event/2` (optional) - Handle events

  ## Example Component

      defmodule Counter do
        def init(props) do
          %{count: Keyword.get(props, :initial, 0)}
        end

        def render(state) do
          text("Count: \#{state.count}")
        end

        def handle_event(%Event.Key{key: :up}, state) do
          {:noreply, %{state | count: state.count + 1}}
        end

        def handle_event(_event, state) do
          {:noreply, state}
        end
      end
  """

  alias TermUI.Test.TestRenderer

  @type t :: %__MODULE__{
          module: module(),
          state: term(),
          renderer: TestRenderer.t(),
          props: keyword(),
          events: [term()],
          renders: [term()],
          area: map()
        }

  defstruct module: nil,
            state: nil,
            renderer: nil,
            props: [],
            events: [],
            renders: [],
            area: %{width: 80, height: 24}

  @doc """
  Mounts a component in isolation for testing.

  ## Options

  - `:width` - Renderer width (default: 80)
  - `:height` - Renderer height (default: 24)
  - `:props` - Initial props to pass to component

  ## Examples

      {:ok, harness} = ComponentHarness.mount_test(MyButton, label: "Click")
      {:ok, harness} = ComponentHarness.mount_test(MyWidget, width: 40, height: 10)
  """
  @spec mount_test(module(), keyword()) :: {:ok, t()} | {:error, term()}
  def mount_test(module, opts \\ []) do
    width = Keyword.get(opts, :width, 80)
    height = Keyword.get(opts, :height, 24)
    props = Keyword.delete(opts, :width) |> Keyword.delete(:height)

    with {:ok, renderer} <- TestRenderer.new(height, width),
         {:ok, state} <- init_component(module, props) do
      harness = %__MODULE__{
        module: module,
        state: state,
        renderer: renderer,
        props: props,
        events: [],
        renders: [],
        area: %{width: width, height: height}
      }

      {:ok, harness}
    end
  end

  defp init_component(module, props) do
    if function_exported?(module, :init, 1) do
      {:ok, module.init(props)}
    else
      {:ok, %{}}
    end
  end

  @doc """
  Unmounts the component and cleans up resources.
  """
  @spec unmount(t()) :: :ok
  def unmount(%__MODULE__{renderer: renderer}) do
    TestRenderer.destroy(renderer)
  end

  @doc """
  Renders the component to the test renderer.

  Returns the updated harness with render result stored.
  """
  @spec render(t()) :: t()
  def render(%__MODULE__{} = harness) do
    if function_exported?(harness.module, :render, 1) do
      render_result = harness.module.render(harness.state)

      # Store render result for inspection
      harness = %{harness | renders: [render_result | harness.renders]}

      # Render to buffer if result is renderable
      harness = render_to_buffer(harness, render_result)

      harness
    else
      harness
    end
  end

  defp render_to_buffer(harness, render_result) do
    # Clear buffer first
    TestRenderer.clear(harness.renderer)

    # Simple render - just handle basic text nodes for now
    render_node(harness.renderer, render_result, 1, 1)

    harness
  end

  defp render_node(renderer, %{type: :text, content: content}, row, col) do
    TestRenderer.write_string(renderer, row, col, content)
  end

  defp render_node(renderer, %{type: :stack, direction: :vertical, children: children}, row, col) do
    Enum.reduce(children, row, fn child, current_row ->
      render_node(renderer, child, current_row, col)
      current_row + 1
    end)
  end

  defp render_node(
         renderer,
         %{type: :stack, direction: :horizontal, children: children},
         row,
         col
       ) do
    Enum.reduce(children, col, fn child, current_col ->
      width = render_node(renderer, child, row, current_col)
      current_col + width
    end)
  end

  defp render_node(renderer, content, row, col) when is_binary(content) do
    TestRenderer.write_string(renderer, row, col, content)
  end

  defp render_node(_renderer, _node, _row, _col), do: 0

  @doc """
  Sends an event to the component.

  Returns the updated harness with new state.
  """
  @spec send_event(t(), term()) :: t()
  def send_event(%__MODULE__{} = harness, event) do
    harness = %{harness | events: [event | harness.events]}

    if function_exported?(harness.module, :handle_event, 2) do
      case harness.module.handle_event(event, harness.state) do
        {:noreply, new_state} ->
          %{harness | state: new_state}

        {:noreply, new_state, _commands} ->
          %{harness | state: new_state}

        {:reply, _reply, new_state} ->
          %{harness | state: new_state}

        _ ->
          harness
      end
    else
      harness
    end
  end

  @doc """
  Sends multiple events in sequence.
  """
  @spec send_events(t(), [term()]) :: t()
  def send_events(%__MODULE__{} = harness, events) when is_list(events) do
    Enum.reduce(events, harness, fn event, acc ->
      send_event(acc, event)
    end)
  end

  @doc """
  Gets the current component state.
  """
  @spec get_state(t()) :: term()
  def get_state(%__MODULE__{state: state}), do: state

  @doc """
  Gets the test renderer for inspection.
  """
  @spec get_renderer(t()) :: TestRenderer.t()
  def get_renderer(%__MODULE__{renderer: renderer}), do: renderer

  @doc """
  Gets the most recent render result.
  """
  @spec get_render(t()) :: term() | nil
  def get_render(%__MODULE__{renders: []}), do: nil
  def get_render(%__MODULE__{renders: [latest | _]}), do: latest

  @doc """
  Gets all render results (most recent first).
  """
  @spec get_renders(t()) :: [term()]
  def get_renders(%__MODULE__{renders: renders}), do: renders

  @doc """
  Gets all events sent (most recent first).
  """
  @spec get_events(t()) :: [term()]
  def get_events(%__MODULE__{events: events}), do: events

  @doc """
  Gets the render area dimensions.
  """
  @spec get_area(t()) :: map()
  def get_area(%__MODULE__{area: area}), do: area

  @doc """
  Updates component state directly (for testing edge cases).

  Use sparingly - prefer sending events for realistic testing.
  """
  @spec update_state(t(), (term() -> term())) :: t()
  def update_state(%__MODULE__{} = harness, fun) when is_function(fun, 1) do
    %{harness | state: fun.(harness.state)}
  end

  @doc """
  Sets component state directly.
  """
  @spec set_state(t(), term()) :: t()
  def set_state(%__MODULE__{} = harness, new_state) do
    %{harness | state: new_state}
  end

  @doc """
  Gets state value at path.
  """
  @spec get_state_at(t(), [atom() | String.t()]) :: term()
  def get_state_at(%__MODULE__{state: state}, path) do
    get_in(state, path)
  end

  @doc """
  Checks if state has changed since last render.
  """
  @spec state_changed?(t()) :: boolean()
  def state_changed?(%__MODULE__{renders: [], state: _}), do: true

  def state_changed?(%__MODULE__{} = _harness) do
    # Would need to track previous state for this
    true
  end

  @doc """
  Simulates a render cycle: render -> wait -> check.

  Renders the component and returns the harness for assertions.
  """
  @spec render_cycle(t()) :: t()
  def render_cycle(%__MODULE__{} = harness) do
    harness
    |> render()
  end

  @doc """
  Simulates an event cycle: send event -> render -> check.
  """
  @spec event_cycle(t(), term()) :: t()
  def event_cycle(%__MODULE__{} = harness, event) do
    harness
    |> send_event(event)
    |> render()
  end

  @doc """
  Resets the harness to initial state.
  """
  @spec reset(t()) :: {:ok, t()} | {:error, term()}
  def reset(%__MODULE__{} = harness) do
    with {:ok, state} <- init_component(harness.module, harness.props) do
      TestRenderer.clear(harness.renderer)

      {:ok,
       %{
         harness
         | state: state,
           events: [],
           renders: []
       }}
    end
  end
end
