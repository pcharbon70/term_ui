defmodule TermUI.Container do
  @moduledoc """
  Behaviour for container components that manage children.

  Container extends StatefulComponent with child management capabilities.
  Use this for components that contain and organize other components,
  like panels, forms, tabs, or split views.

  ## Basic Usage

      defmodule MyApp.Panel do
        use TermUI.Container

        @impl true
        def init(props) do
          {:ok, %{title: props[:title] || "Panel"}}
        end

        @impl true
        def children(_state) do
          [
            {MyApp.Label, %{text: "Header"}, :header},
            {MyApp.Content, %{}, :content}
          ]
        end

        @impl true
        def layout(children, state, area) do
          # Arrange children within available area
          header_area = %{area | height: 1}
          content_area = %{area | y: area.y + 1, height: area.height - 1}

          [
            {Enum.at(children, 0), header_area},
            {Enum.at(children, 1), content_area}
          ]
        end

        @impl true
        def render(state, _area) do
          # Container render is called after children
          # Return empty if children handle all rendering
          empty()
        end

        @impl true
        def handle_event(_event, state) do
          {:ok, state}
        end
      end

  ## Child Specifications

  Children are specified as tuples:

  - `{Module, props}` - Child with auto-generated ID
  - `{Module, props, id}` - Child with explicit ID

  IDs are used for event routing and child lookup.

  ## Layout

  The `layout/3` callback positions children within the container's area.
  It receives the list of child specs and must return tuples of
  `{child_spec, area}` assigning each child its rendering bounds.

  ## Event Routing

  Containers can route events to specific children or handle them directly.
  Override `route_event/2` to customize event routing.
  """

  alias TermUI.Component.RenderNode
  alias TermUI.Renderer.Style

  # Type definitions

  @typedoc "Component state"
  @type state :: term()

  @typedoc "Available rendering area"
  @type rect :: %{x: integer(), y: integer(), width: integer(), height: integer()}

  @typedoc "Render tree output"
  @type render_tree :: RenderNode.t() | [render_tree()] | String.t()

  @typedoc "Event from user input"
  @type event :: term()

  @typedoc "Command for side effects"
  @type command :: term()

  @typedoc "Child specification"
  @type child_spec ::
          {module(), props :: map()}
          | {module(), props :: map(), id :: term()}

  @typedoc "Child with assigned area"
  @type child_layout :: {child_spec(), rect()}

  @typedoc "Event routing target"
  @type route_target ::
          :self
          | {:child, id :: term()}
          | :broadcast

  # Required callbacks (inherited from StatefulComponent)

  @doc """
  Initializes container state from props.

  Same as `StatefulComponent.init/1`.
  """
  @callback init(props :: map()) ::
              {:ok, state()}
              | {:ok, state(), [command()]}
              | {:stop, term()}

  @doc """
  Returns the list of child components.

  Called to determine which children the container should manage.
  Children are specified as tuples with module, props, and optional ID.

  ## Parameters

  - `state` - Current container state

  ## Returns

  List of child specifications.

  ## Examples

      @impl true
      def children(state) do
        [
          {Label, %{text: state.title}, :title},
          {Button, %{label: "OK"}, :ok_button},
          {Button, %{label: "Cancel"}, :cancel_button}
        ]
      end
  """
  @callback children(state()) :: [child_spec()]

  @doc """
  Lays out children within the available area.

  Determines the position and size of each child component.
  The default implementation stacks children vertically.

  ## Parameters

  - `children` - List of child specifications from `children/1`
  - `state` - Current container state
  - `area` - Available area for the container

  ## Returns

  List of `{child_spec, area}` tuples.

  ## Examples

      @impl true
      def layout(children, _state, area) do
        # Horizontal layout with equal widths
        child_width = div(area.width, length(children))

        children
        |> Enum.with_index()
        |> Enum.map(fn {child, i} ->
          child_area = %{
            x: area.x + i * child_width,
            y: area.y,
            width: child_width,
            height: area.height
          }
          {child, child_area}
        end)
      end
  """
  @callback layout([child_spec()], state(), rect()) :: [child_layout()]

  @doc """
  Handles input events.

  Same as `StatefulComponent.handle_event/2`.
  """
  @callback handle_event(event(), state()) ::
              {:ok, state()}
              | {:ok, state(), [command()]}
              | {:stop, term(), state()}

  @doc """
  Renders the container.

  Called after children are rendered. Can render container chrome
  (borders, titles) or return empty if children handle everything.

  Same signature as `StatefulComponent.render/2`.
  """
  @callback render(state(), rect()) :: render_tree()

  # Optional callbacks

  @doc """
  Routes an event to the appropriate handler.

  Override to customize how events are distributed to children.
  Default routes all events to self.

  ## Parameters

  - `event` - The input event
  - `state` - Current container state

  ## Returns

  - `:self` - Handle event in this container
  - `{:child, id}` - Route to specific child
  - `:broadcast` - Send to all children
  """
  @callback route_event(event(), state()) :: route_target()

  @doc """
  Called when a child emits a message.

  Use to handle messages bubbling up from child components.

  ## Parameters

  - `child_id` - ID of the child that sent the message
  - `message` - The message from the child
  - `state` - Current container state
  """
  @callback handle_child_message(child_id :: term(), message :: term(), state()) ::
              {:ok, state()}
              | {:ok, state(), [command()]}

  @optional_callbacks route_event: 2, handle_child_message: 3

  @doc false
  defmacro __using__(_opts) do
    quote do
      @behaviour TermUI.Container

      alias TermUI.Component.RenderNode
      alias TermUI.Renderer.Style

      import TermUI.Component.Helpers

      # Default implementations

      @doc false
      def terminate(_reason, _state), do: :ok

      @doc false
      def handle_info(_message, state), do: {:ok, state}

      @doc false
      def handle_call(_request, _from, state), do: {:reply, :ok, state}

      @doc false
      def route_event(_event, _state), do: :self

      @doc false
      def handle_child_message(_child_id, _message, state), do: {:ok, state}

      @doc """
      Default layout: stack children vertically.
      """
      def layout(children, _state, area) do
        child_count = length(children)

        if child_count == 0 do
          []
        else
          child_height = div(area.height, child_count)

          children
          |> Enum.with_index()
          |> Enum.map(fn {child, i} ->
            child_area = %{
              x: area.x,
              y: area.y + i * child_height,
              width: area.width,
              height: child_height
            }

            {child, child_area}
          end)
        end
      end

      defoverridable terminate: 2,
                     handle_info: 2,
                     handle_call: 3,
                     route_event: 2,
                     handle_child_message: 3,
                     layout: 3

      # Helper functions for child management

      @doc """
      Normalizes a child spec to always have an ID.
      """
      def normalize_child_spec({module, props}) when is_atom(module) and is_map(props) do
        {module, props, make_ref()}
      end

      def normalize_child_spec({module, props, id}) when is_atom(module) and is_map(props) do
        {module, props, id}
      end

      @doc """
      Gets the ID from a child spec.
      """
      def child_id({_module, _props, id}), do: id
      def child_id({_module, _props}), do: nil

      @doc """
      Gets the module from a child spec.
      """
      def child_module({module, _props, _id}), do: module
      def child_module({module, _props}), do: module

      @doc """
      Gets the props from a child spec.
      """
      def child_props({_module, props, _id}), do: props
      def child_props({_module, props}), do: props
    end
  end
end
