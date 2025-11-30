defmodule TermUI.Elm do
  @moduledoc """
  The Elm Architecture implementation for TermUI components.

  This module provides the core callbacks for implementing components
  using The Elm Architecture pattern: `update/2` for state changes and
  `view/1` for rendering.

  ## The Pattern

  1. **Events** arrive from terminal input
  2. **event_to_msg/2** converts events to component-specific messages
  3. **update/2** transforms state based on messages, returns new state + commands
  4. **view/1** renders current state to a render tree
  5. **Commands** execute asynchronously, sending result messages back

  ## Usage

      defmodule Counter do
        use TermUI.Elm

        def init(_opts), do: %{count: 0}

        def event_to_msg(%Event.Key{key: :up}, _state), do: {:msg, :increment}
        def event_to_msg(%Event.Key{key: :down}, _state), do: {:msg, :decrement}
        def event_to_msg(_, _), do: :ignore

        def update(:increment, state), do: {%{state | count: state.count + 1}, []}
        def update(:decrement, state), do: {%{state | count: state.count - 1}, []}

        def view(state) do
          text("Count: \#{state.count}")
        end
      end
  """

  alias TermUI.Event
  alias TermUI.Message

  @type state :: term()
  @type msg :: Message.t()
  @type command :: term()
  @type render_tree :: term()

  @type update_result ::
          {state(), [command()]}
          | {state()}
          | :noreply

  @type event_to_msg_result ::
          {:msg, msg()}
          | :ignore
          | :propagate

  @doc """
  Converts an event to a component-specific message.

  This callback transforms raw terminal events into domain-specific messages
  that have semantic meaning for the component.

  ## Parameters

  - `event` - The terminal event (Key, Mouse, Resize, etc.)
  - `state` - Current component state

  ## Returns

  - `{:msg, message}` - Event converted to a message for update
  - `:ignore` - Event not handled by this component
  - `:propagate` - Pass event to parent component
  """
  @callback event_to_msg(Event.t(), state()) :: event_to_msg_result()

  @doc """
  Updates component state based on a message.

  This is the core logic of the component. It receives the current state
  and a message, and returns the new state plus any commands to execute.

  Update functions must be pure—no side effects, no external calls.
  Side effects are performed through commands returned in the result.

  ## Parameters

  - `msg` - The message to handle
  - `state` - Current component state

  ## Returns

  - `{new_state, commands}` - New state and commands to execute
  - `{new_state}` - Shorthand for `{new_state, []}`
  - `:noreply` - Keep state unchanged, no commands

  ## Examples

      def update(:increment, state) do
        {%{state | count: state.count + 1}, []}
      end

      def update({:fetch_data, url}, state) do
        cmd = Command.http_get(url, {:data_loaded, :response})
        {%{state | loading: true}, [cmd]}
      end

      def update(:noop, _state), do: :noreply
  """
  @callback update(msg(), state()) :: update_result()

  @doc """
  Renders the current state to a render tree.

  View functions must be pure—given the same state, they always produce
  the same output. View functions should be fast since they run every frame.

  ## Parameters

  - `state` - Current component state

  ## Returns

  A render tree structure that will be processed into terminal output.

  ## Examples

      def view(state) do
        box(border: true) do
          text("Count: \#{state.count}")
        end
      end
  """
  @callback view(state()) :: render_tree()

  @doc """
  Initializes component state from options.

  Called once when the component is created.

  ## Parameters

  - `opts` - Options passed to the component

  ## Returns

  Initial state for the component.
  """
  @callback init(opts :: keyword()) :: state()

  @optional_callbacks [init: 1]

  defmacro __using__(_opts) do
    quote do
      @behaviour TermUI.Elm

      # Import Component.Helpers for RenderNode-based view building
      # (text/1, text/2, box/1, box/2, stack/2, stack/3, styled/2, empty/0)
      import TermUI.Component.Helpers

      # Import Elm.Helpers for macros that don't conflict
      # Exclude text, styled, box which are provided by Component.Helpers
      import TermUI.Elm.Helpers, except: [text: 1, styled: 2, box: 1, box: 2]

      # Default implementations

      @doc false
      def init(_opts), do: %{}

      @doc false
      def event_to_msg(_event, _state), do: :ignore

      defoverridable init: 1, event_to_msg: 2
    end
  end

  @doc """
  Normalizes update result to standard form.

  Converts shorthand forms to the full `{state, commands}` tuple.
  """
  @spec normalize_update_result(update_result(), state()) :: {state(), [command()]}
  def normalize_update_result({state, commands}, _old_state) when is_list(commands) do
    {state, commands}
  end

  def normalize_update_result({state}, _old_state) do
    {state, []}
  end

  def normalize_update_result(:noreply, old_state) do
    {old_state, []}
  end

  @doc """
  Validates that an update function is pure (best effort).

  Returns warnings if the update function appears to have side effects.
  This is a heuristic check, not a guarantee.
  """
  @spec validate_update_purity(module()) :: :ok | {:warnings, [String.t()]}
  def validate_update_purity(_module) do
    # This would require compile-time analysis or runtime tracing
    # For now, we document the requirement and trust the developer
    :ok
  end
end

defmodule TermUI.Elm.Helpers do
  @moduledoc """
  Helper functions for Elm Architecture components.
  """

  @doc """
  Creates a text render node.
  """
  def text(content) when is_binary(content) do
    {:text, content}
  end

  def text(content) do
    {:text, to_string(content)}
  end

  @doc """
  Creates a styled text render node.
  """
  def styled(content, style) do
    {:styled, content, style}
  end

  @doc """
  Creates a box container.
  """
  defmacro box(opts \\ [], do: block) do
    quote do
      {:box, unquote(opts), unquote(block)}
    end
  end

  @doc """
  Creates a row container (horizontal layout).
  """
  defmacro row(opts \\ [], do: block) do
    quote do
      {:row, unquote(opts), unquote(block)}
    end
  end

  @doc """
  Creates a column container (vertical layout).
  """
  defmacro column(opts \\ [], do: block) do
    quote do
      {:column, unquote(opts), unquote(block)}
    end
  end

  @doc """
  Groups multiple render nodes.
  """
  def fragment(children) when is_list(children) do
    {:fragment, children}
  end
end
