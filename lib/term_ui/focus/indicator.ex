defmodule TermUI.Focus.Indicator do
  @moduledoc """
  Focus indicator styles for visual focus feedback.

  Provides default and customizable styles for indicating
  which component has focus.

  ## Usage

      # Get default focus style
      style = Indicator.default_style()

      # Get focus style for component
      style = Indicator.get_style(:my_button, opts)

      # Apply focus styling to a cell
      cell = Indicator.apply_focus_style(cell)
  """

  alias TermUI.Renderer.Style

  @type indicator_style :: %{
          border: Style.border_style() | nil,
          fg: Style.color() | nil,
          bg: Style.color() | nil,
          bold: boolean()
        }

  @doc """
  Returns the default focus indicator style.

  Default style uses a highlighted border color.
  """
  @spec default_style() :: indicator_style()
  def default_style do
    %{
      border: :single,
      fg: :cyan,
      bg: nil,
      bold: true
    }
  end

  @doc """
  Gets the focus indicator style for a component.

  Merges default style with component-specific overrides.

  ## Parameters

  - `component_id` - Component to get style for
  - `opts` - Options:
    - `:styles` - Map of component_id => indicator_style

  ## Returns

  Focus indicator style map.
  """
  @spec get_style(term(), keyword()) :: indicator_style()
  def get_style(component_id, opts \\ []) do
    styles = Keyword.get(opts, :styles, %{})
    custom = Map.get(styles, component_id, %{})

    Map.merge(default_style(), custom)
  end

  @doc """
  Creates a Style struct from focus indicator style.

  ## Parameters

  - `indicator` - Focus indicator style map

  ## Returns

  A Style struct suitable for rendering.
  """
  @spec to_render_style(indicator_style()) :: Style.t()
  def to_render_style(indicator) do
    opts = []

    opts =
      if indicator[:fg] do
        [{:fg, indicator[:fg]} | opts]
      else
        opts
      end

    opts =
      if indicator[:bg] do
        [{:bg, indicator[:bg]} | opts]
      else
        opts
      end

    opts =
      if indicator[:bold] do
        [{:attrs, [:bold]} | opts]
      else
        opts
      end

    Style.new(opts)
  end

  @doc """
  Gets focus border color.

  Returns the color to use for focused component borders.

  ## Returns

  Color atom (e.g., :cyan, :blue).
  """
  @spec focus_border_color() :: atom()
  def focus_border_color do
    :cyan
  end

  @doc """
  Checks if focus indicators should animate.

  Some terminals support blinking or pulsing focus indicators.

  ## Returns

  Boolean indicating animation support.
  """
  @spec animate?() :: boolean()
  def animate? do
    # Animation disabled by default for simplicity
    false
  end

  @doc """
  Returns predefined focus indicator themes.

  ## Available Themes

  - `:default` - Cyan border with bold
  - `:subtle` - Dim border color change
  - `:bold` - Bright yellow with background
  - `:minimal` - No border, just cursor

  ## Returns

  Map of theme name to indicator style.
  """
  @spec themes() :: %{atom() => indicator_style()}
  def themes do
    %{
      default: %{
        border: :single,
        fg: :cyan,
        bg: nil,
        bold: true
      },
      subtle: %{
        border: :single,
        fg: :white,
        bg: nil,
        bold: false
      },
      bold: %{
        border: :double,
        fg: :yellow,
        bg: :blue,
        bold: true
      },
      minimal: %{
        border: nil,
        fg: nil,
        bg: nil,
        bold: false
      }
    }
  end

  @doc """
  Gets a predefined theme by name.

  ## Parameters

  - `theme_name` - Name of the theme

  ## Returns

  Indicator style for the theme, or default if not found.
  """
  @spec get_theme(atom()) :: indicator_style()
  def get_theme(theme_name) do
    Map.get(themes(), theme_name, default_style())
  end
end
