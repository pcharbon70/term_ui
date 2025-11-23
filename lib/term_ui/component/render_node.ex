defmodule TermUI.Component.RenderNode do
  @moduledoc """
  Represents a node in the render tree.

  RenderNodes are the output of component rendering. They form a tree structure
  that the renderer converts to terminal buffer cells. Each node has content,
  styling, and optional children.

  ## Node Types

  - **Text nodes**: Simple text content with optional styling
  - **Box nodes**: Rectangular regions that can contain children
  - **Stack nodes**: Vertical or horizontal arrangements of children

  ## Examples

      # Simple text node
      RenderNode.text("Hello, World!")

      # Styled text
      style = Style.new() |> Style.fg(:red) |> Style.bold()
      RenderNode.text("Error!", style)

      # Box with children
      RenderNode.box([
        RenderNode.text("Header"),
        RenderNode.text("Content")
      ])

      # Horizontal stack
      RenderNode.stack(:horizontal, [
        RenderNode.text("Left"),
        RenderNode.text("Right")
      ])
  """

  alias TermUI.Renderer.Cell
  alias TermUI.Renderer.Style

  @type node_type :: :text | :box | :stack | :empty | :cells

  @typedoc "A cell with position information for the :cells node type"
  @type positioned_cell :: %{x: non_neg_integer(), y: non_neg_integer(), cell: Cell.t()}
  @type direction :: :vertical | :horizontal

  @type t :: %__MODULE__{
          type: node_type(),
          content: String.t() | nil,
          style: Style.t() | nil,
          children: [t()],
          direction: direction() | nil,
          width: non_neg_integer() | :auto | nil,
          height: non_neg_integer() | :auto | nil,
          cells: [positioned_cell()] | nil
        }

  defstruct type: :empty,
            content: nil,
            style: nil,
            children: [],
            direction: nil,
            width: nil,
            height: nil,
            cells: nil

  @doc """
  Creates an empty render node.

  ## Examples

      iex> RenderNode.empty()
      %RenderNode{type: :empty}
  """
  @spec empty() :: t()
  def empty do
    %__MODULE__{type: :empty}
  end

  @doc """
  Creates a text node with optional styling.

  ## Examples

      iex> RenderNode.text("Hello")
      %RenderNode{type: :text, content: "Hello"}

      iex> style = Style.new() |> Style.fg(:red)
      iex> node = RenderNode.text("Error", style)
      iex> node.style.fg
      :red
  """
  @spec text(String.t(), Style.t() | nil) :: t()
  def text(content, style \\ nil) when is_binary(content) do
    %__MODULE__{
      type: :text,
      content: content,
      style: style
    }
  end

  @doc """
  Creates a box node that can contain children.

  ## Options

  - `:style` - Style to apply to the box background
  - `:width` - Fixed width or `:auto`
  - `:height` - Fixed height or `:auto`

  ## Examples

      iex> RenderNode.box([RenderNode.text("Content")])
      %RenderNode{type: :box, children: [%RenderNode{type: :text, content: "Content"}]}

      iex> RenderNode.box([RenderNode.text("Styled")], style: Style.new() |> Style.bg(:blue))
      %RenderNode{type: :box, style: %Style{bg: :blue}}
  """
  @spec box([t()], keyword()) :: t()
  def box(children, opts \\ []) when is_list(children) do
    %__MODULE__{
      type: :box,
      children: children,
      style: Keyword.get(opts, :style),
      width: Keyword.get(opts, :width),
      height: Keyword.get(opts, :height)
    }
  end

  @doc """
  Creates a stack node that arranges children in a direction.

  ## Examples

      iex> RenderNode.stack(:vertical, [RenderNode.text("Top"), RenderNode.text("Bottom")])
      %RenderNode{type: :stack, direction: :vertical, children: [...]}

      iex> RenderNode.stack(:horizontal, [RenderNode.text("Left"), RenderNode.text("Right")])
      %RenderNode{type: :stack, direction: :horizontal, children: [...]}
  """
  @spec stack(direction(), [t()], keyword()) :: t()
  def stack(direction, children, opts \\ [])
      when direction in [:vertical, :horizontal] and is_list(children) do
    %__MODULE__{
      type: :stack,
      direction: direction,
      children: children,
      style: Keyword.get(opts, :style),
      width: Keyword.get(opts, :width),
      height: Keyword.get(opts, :height)
    }
  end

  @doc """
  Creates a cells node with pre-rendered cells.

  This is used by widgets that need fine-grained control over cell positioning.
  The cells list should contain Cell structs with absolute positions.

  ## Examples

      iex> cells = [%{x: 0, y: 0, cell: Cell.new("H")}, %{x: 1, y: 0, cell: Cell.new("i")}]
      iex> RenderNode.cells(cells)
      %RenderNode{type: :cells, cells: [...]}
  """
  @spec cells([positioned_cell()], keyword()) :: t()
  def cells(cells, opts \\ []) when is_list(cells) do
    %__MODULE__{
      type: :cells,
      cells: cells,
      children: Keyword.get(opts, :children, []),
      width: Keyword.get(opts, :width),
      height: Keyword.get(opts, :height)
    }
  end

  @doc """
  Creates a styled wrapper around a node.

  Applies additional styling to an existing node without changing its structure.

  ## Examples

      iex> node = RenderNode.text("Hello")
      iex> styled = RenderNode.styled(node, Style.new() |> Style.fg(:red))
      iex> styled.children
      [%RenderNode{type: :text, content: "Hello"}]
  """
  @spec styled(t(), Style.t()) :: t()
  def styled(%__MODULE__{} = node, %Style{} = style) do
    %__MODULE__{
      type: :box,
      style: style,
      children: [node]
    }
  end

  @doc """
  Sets the width of a node.

  ## Examples

      iex> RenderNode.box([]) |> RenderNode.width(20)
      %RenderNode{type: :box, width: 20}
  """
  @spec width(t(), non_neg_integer() | :auto) :: t()
  def width(%__MODULE__{} = node, w) when (is_integer(w) and w >= 0) or w == :auto do
    %{node | width: w}
  end

  @doc """
  Sets the height of a node.

  ## Examples

      iex> RenderNode.box([]) |> RenderNode.height(10)
      %RenderNode{type: :box, height: 10}
  """
  @spec height(t(), non_neg_integer() | :auto) :: t()
  def height(%__MODULE__{} = node, h) when (is_integer(h) and h >= 0) or h == :auto do
    %{node | height: h}
  end

  @doc """
  Checks if a node is empty.

  ## Examples

      iex> RenderNode.empty?(RenderNode.empty())
      true

      iex> RenderNode.empty?(RenderNode.text("Hello"))
      false
  """
  @spec empty?(t()) :: boolean()
  def empty?(%__MODULE__{type: :empty}), do: true
  def empty?(%__MODULE__{}), do: false

  @doc """
  Returns the number of direct children of a node.

  ## Examples

      iex> RenderNode.child_count(RenderNode.text("Hello"))
      0

      iex> RenderNode.child_count(RenderNode.box([RenderNode.text("A"), RenderNode.text("B")]))
      2
  """
  @spec child_count(t()) :: non_neg_integer()
  def child_count(%__MODULE__{children: children}) do
    length(children)
  end
end
