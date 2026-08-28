defmodule TermUI.StatefulComponent do
  @moduledoc """
  Behaviour for stateful, interactive components.

  StatefulComponent extends the base Component behaviour with state management
  and event handling. Use this for components that need to maintain internal
  state and respond to user input.

  In a normal `TermUI.Runtime` application, a stateful widget is an explicit
  state machine embedded in the root Elm state: call `init/1`, keep the returned
  state, forward relevant events to `handle_event/2`, and call `render/2` from
  the root view. `TermUI.ComponentServer` can host this behaviour in its own
  process, but that subsystem is not automatically connected to the Elm runtime.

  ## Basic Usage

      defmodule MyApp.Counter do
        use TermUI.StatefulComponent

        @impl true
        def init(props) do
          {:ok, %{count: props[:initial] || 0}}
        end

        @impl true
        def handle_event(%TermUI.Event.Key{key: :up}, state) do
          {:ok, %{state | count: state.count + 1}}
        end

        def handle_event(%TermUI.Event.Key{key: :down}, state) do
          {:ok, %{state | count: state.count - 1}}
        end

        def handle_event(_event, state) do
          {:ok, state}
        end

        @impl true
        def render(state, _area) do
          text("Count: \#{state.count}")
        end
      end

  ## Lifecycle

  1. `init/1` - Initialize state from props
  2. `handle_event/2` - Process input events
  3. `render/2` - Render current state

  ## Commands

  When hosted by `TermUI.ComponentServer`, event handlers can return its legacy
  command tuples for side effects:

      def handle_event(%TermUI.Event.Key{key: :enter}, state) do
        {:ok, state, [{:send, parent_pid, {:submitted, state.value}}]}
      end

  `ComponentServer` recognizes `{:send, pid, message}` and
  `{:timer, milliseconds, message}`. It does not delegate arbitrary process
  messages to the component's `handle_info/2` callback in 1.0, so a timer
  command needs a different/custom host and should not be used with
  `ComponentServer` alone.

  ## Optional Callbacks

  - `terminate/2` - Cleanup when component stops
  - `handle_info/2` - Handle non-event messages when the chosen integration
    invokes it
  - `handle_call/3` - Handle synchronous calls when the chosen integration
    invokes it

  The 1.0 `ComponentServer` does not delegate arbitrary GenServer calls or
  messages to these optional callbacks. An embedded root or custom host can
  invoke them explicitly.
  """

  alias TermUI.Component.RenderNode

  # Type definitions

  @typedoc "Component state - any term"
  @type state :: term()

  @typedoc "Component props"
  @type props :: map()

  @typedoc "Available rendering area"
  @type rect :: %{x: integer(), y: integer(), width: integer(), height: integer()}

  @typedoc "Render tree output"
  @type render_tree :: RenderNode.t() | [render_tree()] | String.t() | tuple() | map()

  @typedoc "Event types from user input"
  @type event :: term()

  @typedoc "Commands for side effects"
  @type command ::
          {:send, pid(), term()}
          | {:timer, non_neg_integer(), term()}
          | term()

  @typedoc "Event handler return value"
  @type event_result ::
          {:ok, state()}
          | {:ok, state(), [command()]}
          | {:stop, reason :: term(), state()}

  # Required callbacks

  @doc """
  Initializes component state from props.

  Called once when the component starts. Returns initial state.

  ## Parameters

  - `props` - Initial properties passed to the component

  ## Returns

  - `{:ok, state}` - Initial state
  - `{:ok, state, commands}` - Initial state with startup commands
  - `{:stop, reason}` - Fail to initialize

  ## Examples

      @impl true
      def init(props) do
        {:ok, %{
          text: props[:text] || "",
          cursor: 0
        }}
      end
  """
  @callback init(props()) :: {:ok, state()} | {:ok, state(), [command()]} | {:stop, term()}

  @doc """
  Handles input events and updates state.

  Called when the component receives a keyboard, mouse, or focus event.
  Returns updated state and optional commands.

  ## Parameters

  - `event` - A normalized event such as `TermUI.Event.Key`,
    `TermUI.Event.Mouse`, or `TermUI.Event.Focus`
  - `state` - Current component state

  ## Returns

  - `{:ok, new_state}` - Updated state
  - `{:ok, new_state, commands}` - Updated state with commands
  - `{:stop, reason, state}` - Stop the component

  ## Examples

      @impl true
      def handle_event(%TermUI.Event.Key{key: :enter}, state) do
        {:ok, state, [{:send, state.parent, {:submit, state.value}}]}
      end

      def handle_event(%TermUI.Event.Key{char: char}, state) when char != nil do
        {:ok, %{state | text: state.text <> char}}
      end

      def handle_event(_event, state) do
        {:ok, state}
      end
  """
  @callback handle_event(event(), state()) :: event_result()

  @doc """
  Renders the component's current state.

  Called after state changes to produce the visual output.
  Unlike stateless components, receives state instead of props.

  ## Parameters

  - `state` - Current component state
  - `area` - Available rendering area

  ## Returns

  A render tree accepted by `TermUI.Runtime.NodeRenderer` (RenderNode, list,
  string, tuple node, or supported map node).

  ## Examples

      @impl true
      def render(state, _area) do
        text(state.text)
      end
  """
  @callback render(state(), rect()) :: render_tree()

  # Optional callbacks

  @doc """
  Called when the component is mounted to the active tree.

  Mount is the appropriate place for setup requiring the component
  to be "live": registering event handlers, starting timers, fetching data.

  ## Parameters

  - `state` - Current component state after init

  ## Returns

  - `{:ok, new_state}` - Mount successful
  - `{:ok, new_state, commands}` - Mount with commands
  - `{:stop, reason}` - Mount failed
  """
  @callback mount(state()) :: {:ok, state()} | {:ok, state(), [command()]} | {:stop, term()}

  @doc """
  Called when the component's props change.

  The parent passes new props, triggering this callback.
  Update may modify state based on new props.

  ## Parameters

  - `new_props` - The new props from parent
  - `state` - Current component state

  ## Returns

  - `{:ok, new_state}` - Update successful
  - `{:ok, new_state, commands}` - Update with commands
  """
  @callback update(new_props :: props(), state()) ::
              {:ok, state()} | {:ok, state(), [command()]}

  @doc """
  Called when the component is unmounted from the tree.

  This is the appropriate place for cleanup: canceling timers,
  closing files, unregistering handlers.

  ## Parameters

  - `state` - Current component state
  """
  @callback unmount(state()) :: :ok

  @doc """
  Handles component termination.

  Called when the component is stopping. Use for cleanup.

  ## Parameters

  - `reason` - Why the component is stopping
  - `state` - Final component state
  """
  @callback terminate(reason :: term(), state()) :: term()

  @doc """
  Handles non-event messages.

  Available to integrations that explicitly invoke it for messages that are
  not input events. The 1.0 `ComponentServer` does not delegate its GenServer
  mailbox to this callback.

  ## Parameters

  - `message` - The received message
  - `state` - Current component state

  ## Returns

  Same as `handle_event/2`.
  """
  @callback handle_info(message :: term(), state()) :: event_result()

  @doc """
  Handles synchronous calls.

  Available to integrations that explicitly invoke it for request-response
  patterns. The 1.0 `ComponentServer` does not delegate `GenServer.call/3` to
  this callback.

  ## Parameters

  - `request` - The request term
  - `from` - Caller identifier for reply
  - `state` - Current component state

  ## Returns

  - `{:reply, response, new_state}` - Reply and update state
  - `{:reply, response, new_state, commands}` - Reply with commands
  - `{:noreply, new_state}` - Don't reply yet
  """
  @callback handle_call(request :: term(), from :: term(), state()) ::
              {:reply, term(), state()}
              | {:reply, term(), state(), [command()]}
              | {:noreply, state()}
              | {:noreply, state(), [command()]}

  @optional_callbacks mount: 1,
                      update: 2,
                      unmount: 1,
                      terminate: 2,
                      handle_info: 2,
                      handle_call: 3

  @doc false
  defmacro __using__(_opts) do
    quote do
      @behaviour TermUI.StatefulComponent

      alias TermUI.Component.RenderNode
      alias TermUI.Renderer.Style

      import TermUI.Component.Helpers

      # Default implementations for optional callbacks

      @doc false
      def mount(state), do: {:ok, state}

      @doc false
      def update(_new_props, state), do: {:ok, state}

      @doc false
      def unmount(_state), do: :ok

      @doc false
      def terminate(_reason, _state), do: :ok

      @doc false
      def handle_info(_message, state), do: {:ok, state}

      @doc false
      def handle_call(_request, _from, state), do: {:reply, :ok, state}

      defoverridable mount: 1, update: 2, unmount: 1, terminate: 2, handle_info: 2, handle_call: 3
    end
  end
end
