defmodule TermUI.Component do
  @moduledoc """
  Base behaviour for all TermUI components.

  Components are the building blocks of TermUI applications. This behaviour
  defines the minimal interface that all components must implement.

  ## Basic Usage

  The simplest component only needs to implement `render/2`:

      defmodule MyApp.Label do
        use TermUI.Component

        @impl true
        def render(props, _area) do
          text(props[:text] || "")
        end
      end

  ## Optional Callbacks

  Components can also implement:

  - `describe/0` - Returns metadata about the component
  - `default_props/0` - Returns default prop values

  ## Render Tree

  The `render/2` callback returns a render tree, which can be:

  - A `RenderNode` struct
  - A list of render nodes
  - A plain string (converted to text node)

  ## Props

  Props are passed as a map to the `render/2` callback. Use `default_props/0`
  to define defaults that are merged with passed props.

  ## Area

  The area parameter defines the available space for rendering:

      %{x: integer(), y: integer(), width: integer(), height: integer()}

  Components should respect these bounds when producing render output.
  """

  alias TermUI.Component.RenderNode

  # Type definitions

  @typedoc "Render tree output - can be a node, list of nodes, or string"
  @type render_tree :: RenderNode.t() | [render_tree()] | String.t()

  @typedoc "Component props passed to render"
  @type props :: map()

  @typedoc "Available rendering area"
  @type rect :: %{x: integer(), y: integer(), width: integer(), height: integer()}

  @typedoc "Component metadata"
  @type component_info :: %{
          name: String.t(),
          description: String.t() | nil,
          version: String.t() | nil
        }

  # Required callbacks

  @doc """
  Renders the component given props and available area.

  This is the only required callback. It receives the component's props
  and the available rendering area, and must return a render tree.

  ## Parameters

  - `props` - Map of properties passed to the component
  - `area` - Available rendering area with x, y, width, height

  ## Returns

  A render tree (RenderNode, list, or string).

  ## Examples

      @impl true
      def render(props, area) do
        text = props[:text] || ""
        style = props[:style]

        if style do
          styled_text(text, style)
        else
          text(text)
        end
      end
  """
  @callback render(props(), rect()) :: render_tree()

  # Optional callbacks

  @doc """
  Returns metadata about the component.

  Useful for introspection, debugging, and documentation generation.

  ## Examples

      @impl true
      def describe do
        %{
          name: "Label",
          description: "A simple text display component",
          version: "1.0.0"
        }
      end
  """
  @callback describe() :: component_info()

  @doc """
  Returns default prop values for the component.

  These defaults are merged with props passed to `render/2`,
  with passed props taking precedence.

  ## Examples

      @impl true
      def default_props do
        %{
          text: "",
          style: nil,
          align: :left
        }
      end
  """
  @callback default_props() :: props()

  @optional_callbacks describe: 0, default_props: 0

  @doc false
  defmacro __using__(_opts) do
    quote do
      @behaviour TermUI.Component

      alias TermUI.Component.RenderNode
      alias TermUI.Renderer.Style

      import TermUI.Component.Helpers

      # Default implementations for optional callbacks

      @doc false
      def describe do
        %{
          name: inspect(__MODULE__),
          description: nil,
          version: nil
        }
      end

      @doc false
      def default_props do
        %{}
      end

      defoverridable describe: 0, default_props: 0

      # Helper to merge default props with passed props
      @doc false
      def merge_props(props) do
        Map.merge(default_props(), props)
      end
    end
  end
end
