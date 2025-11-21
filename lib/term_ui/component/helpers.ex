defmodule TermUI.Component.Helpers do
  @moduledoc """
  Common helper functions and macros for TermUI components.

  This module is automatically imported when you `use TermUI.Component`.
  It provides convenience functions for building render trees and
  working with props and styles.

  ## Render Tree Builders

  - `text/1`, `text/2` - Create text nodes
  - `box/1`, `box/2` - Create box containers
  - `stack/2`, `stack/3` - Create stacked layouts

  ## Props Helpers

  - `props!/2` - Validate and extract required props

  ## Style Helpers

  - `merge_styles/2` - Merge multiple styles
  - `compute_size/2` - Calculate content dimensions
  """

  alias TermUI.Component.RenderNode
  alias TermUI.Renderer.Style

  # Render tree builders - delegate to RenderNode

  @doc """
  Creates a text node.

  ## Examples

      text("Hello, World!")
      text("Styled", Style.new() |> Style.fg(:red))
  """
  @spec text(String.t(), Style.t() | nil) :: RenderNode.t()
  defdelegate text(content, style \\ nil), to: RenderNode

  @doc """
  Creates a box container.

  ## Examples

      box([text("Content")])
      box([text("Styled")], style: Style.new() |> Style.bg(:blue))
  """
  @spec box([RenderNode.t()], keyword()) :: RenderNode.t()
  defdelegate box(children, opts \\ []), to: RenderNode

  @doc """
  Creates a stack layout.

  ## Examples

      stack(:vertical, [text("Top"), text("Bottom")])
      stack(:horizontal, [text("Left"), text("Right")])
  """
  @spec stack(RenderNode.direction(), [RenderNode.t()], keyword()) :: RenderNode.t()
  defdelegate stack(direction, children, opts \\ []), to: RenderNode

  @doc """
  Creates a styled wrapper around a node.

  ## Examples

      styled(text("Hello"), Style.new() |> Style.fg(:red))
  """
  @spec styled(RenderNode.t(), Style.t()) :: RenderNode.t()
  defdelegate styled(node, style), to: RenderNode

  @doc """
  Creates an empty node.

  ## Examples

      empty()
  """
  @spec empty() :: RenderNode.t()
  defdelegate empty(), to: RenderNode

  # Props validation

  @doc """
  Validates and extracts props with type checking and defaults.

  Raises `ArgumentError` if required props are missing or types don't match.

  ## Spec Format

  Each prop spec is a tuple: `{name, type, opts}`

  Types: `:string`, `:integer`, `:boolean`, `:atom`, `:any`, `:style`

  Options:
  - `:required` - Prop must be present (default: false)
  - `:default` - Default value if not provided

  ## Examples

      props!(props, [
        {:text, :string, required: true},
        {:count, :integer, default: 0},
        {:enabled, :boolean, default: true}
      ])
      # Returns %{text: "...", count: 0, enabled: true}
  """
  @spec props!(map(), [{atom(), atom(), keyword()}]) :: map()
  def props!(props, specs) when is_map(props) and is_list(specs) do
    Enum.reduce(specs, %{}, fn {name, type, opts}, acc ->
      required = Keyword.get(opts, :required, false)
      default = Keyword.get(opts, :default)

      value =
        case Map.fetch(props, name) do
          {:ok, val} ->
            validate_prop_type!(name, val, type)
            val

          :error ->
            if required do
              raise ArgumentError, "Required prop #{inspect(name)} is missing"
            else
              default
            end
        end

      Map.put(acc, name, value)
    end)
  end

  defp validate_prop_type!(_name, nil, _type), do: :ok

  defp validate_prop_type!(name, value, :string) do
    unless is_binary(value) do
      raise ArgumentError,
            "Prop #{inspect(name)} must be a string, got: #{inspect(value)}"
    end
  end

  defp validate_prop_type!(name, value, :integer) do
    unless is_integer(value) do
      raise ArgumentError,
            "Prop #{inspect(name)} must be an integer, got: #{inspect(value)}"
    end
  end

  defp validate_prop_type!(name, value, :boolean) do
    unless is_boolean(value) do
      raise ArgumentError,
            "Prop #{inspect(name)} must be a boolean, got: #{inspect(value)}"
    end
  end

  defp validate_prop_type!(name, value, :atom) do
    unless is_atom(value) do
      raise ArgumentError,
            "Prop #{inspect(name)} must be an atom, got: #{inspect(value)}"
    end
  end

  defp validate_prop_type!(name, value, :style) do
    unless match?(%Style{}, value) do
      raise ArgumentError,
            "Prop #{inspect(name)} must be a Style, got: #{inspect(value)}"
    end
  end

  defp validate_prop_type!(_name, _value, :any), do: :ok

  # Style helpers

  @doc """
  Merges multiple styles in order, with later styles overriding earlier ones.

  Follows CSS cascade rules - later values take precedence, attributes combine.

  ## Examples

      base = Style.new() |> Style.fg(:white)
      override = Style.new() |> Style.fg(:red) |> Style.bold()
      merge_styles([base, override])
      # Result: fg: :red, attrs: [:bold]
  """
  @spec merge_styles([Style.t() | nil]) :: Style.t()
  def merge_styles(styles) when is_list(styles) do
    styles
    |> Enum.reject(&is_nil/1)
    |> Enum.reduce(Style.new(), &Style.merge(&2, &1))
  end

  @doc """
  Computes the display size of text content.

  Returns `{width, height}` where width is the maximum line length
  and height is the number of lines.

  ## Examples

      compute_size("Hello")
      # {5, 1}

      compute_size("Line 1\\nLine 2")
      # {6, 2}
  """
  @spec compute_size(String.t()) :: {non_neg_integer(), non_neg_integer()}
  def compute_size(text) when is_binary(text) do
    lines = String.split(text, "\n")
    height = length(lines)

    width =
      lines
      |> Enum.map(&String.length/1)
      |> Enum.max(fn -> 0 end)

    {width, height}
  end

  @doc """
  Computes the size of a render node.

  For text nodes, returns the text dimensions.
  For containers, returns explicit size or `:auto`.

  ## Examples

      compute_node_size(text("Hello"))
      # {5, 1}

      compute_node_size(box([], width: 20, height: 10))
      # {20, 10}
  """
  @spec compute_node_size(RenderNode.t()) :: {non_neg_integer() | :auto, non_neg_integer() | :auto}
  def compute_node_size(%RenderNode{type: :text, content: content}) do
    compute_size(content || "")
  end

  def compute_node_size(%RenderNode{type: :empty}) do
    {0, 0}
  end

  def compute_node_size(%RenderNode{width: w, height: h}) do
    {w || :auto, h || :auto}
  end

  @doc """
  Checks if a value fits within a rect.

  ## Examples

      fits_in_rect?({10, 5}, %{x: 0, y: 0, width: 20, height: 10})
      # true

      fits_in_rect?({30, 5}, %{x: 0, y: 0, width: 20, height: 10})
      # false
  """
  @spec fits_in_rect?({non_neg_integer(), non_neg_integer()}, TermUI.Component.rect()) :: boolean()
  def fits_in_rect?({width, height}, %{width: max_width, height: max_height}) do
    width <= max_width and height <= max_height
  end

  @doc """
  Truncates text to fit within a given width.

  ## Examples

      truncate_text("Hello, World!", 5)
      # "Hello"

      truncate_text("Hi", 10)
      # "Hi"
  """
  @spec truncate_text(String.t(), non_neg_integer()) :: String.t()
  def truncate_text(text, max_width) when is_binary(text) and is_integer(max_width) do
    if String.length(text) <= max_width do
      text
    else
      String.slice(text, 0, max_width)
    end
  end
end
