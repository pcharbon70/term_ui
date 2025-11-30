defmodule TermUI.Widgets.WidgetHelpers do
  @moduledoc """
  Shared utilities for interactive widgets (forms, palettes, menus).

  Provides common functions for:
  - Text padding and truncation
  - Focus/selection styling
  - Common render patterns

  ## Usage

      alias TermUI.Widgets.WidgetHelpers, as: Helpers

      # Pad and truncate text to fit a width
      Helpers.pad_and_truncate("Hello", 10)
      #=> "Hello     "

      # Style an element based on focus state
      Helpers.render_focused(text("Item"), true, Style.new(attrs: [:reverse]))
      #=> styled render node with reverse attribute
  """

  import TermUI.Component.RenderNode, only: [text: 1, styled: 2]

  alias TermUI.Renderer.Style

  @doc """
  Pads a string to a specified width, then truncates if it exceeds that width.

  This ensures the resulting string is exactly `width` characters long,
  first padding with spaces if too short, then slicing if too long.

  ## Examples

      iex> WidgetHelpers.pad_and_truncate("Hello", 10)
      "Hello     "

      iex> WidgetHelpers.pad_and_truncate("Hello World", 5)
      "Hello"

      iex> WidgetHelpers.pad_and_truncate("Test", 4)
      "Test"

      iex> WidgetHelpers.pad_and_truncate("", 5)
      "     "
  """
  @spec pad_and_truncate(String.t(), non_neg_integer()) :: String.t()
  def pad_and_truncate(string, width) when is_binary(string) and is_integer(width) and width >= 0 do
    string
    |> String.pad_trailing(width)
    |> String.slice(0, width)
  end

  def pad_and_truncate(_, width) when is_integer(width) and width >= 0, do: String.duplicate(" ", width)

  @doc """
  Renders an element with focused styling applied conditionally.

  When `focused` is true, wraps the render node with the provided focus style.
  When false, returns the node unchanged.

  This is commonly used for list items, form fields, and menu options.

  ## Examples

      # With focus
      Helpers.render_focused(text("Option 1"), true)
      #=> styled node with reverse attribute

      # Without focus
      Helpers.render_focused(text("Option 2"), false)
      #=> plain text node

      # Custom focus style
      Helpers.render_focused(text("Active"), true, Style.new(fg: :cyan, attrs: [:bold]))
      #=> styled node with cyan foreground and bold
  """
  @spec render_focused(any(), boolean(), Style.t() | nil) :: any()
  def render_focused(node, focused, focus_style \\ nil)

  def render_focused(node, true, nil) do
    styled(node, Style.new(attrs: [:reverse]))
  end

  def render_focused(node, true, focus_style) do
    styled(node, focus_style)
  end

  def render_focused(node, false, _focus_style) do
    node
  end

  @doc """
  Creates a text render node with conditional focus styling.

  Convenience function that combines `text/1` and `render_focused/3`.

  ## Examples

      Helpers.text_focused("Item 1", true)
      #=> styled text node with reverse attribute

      Helpers.text_focused("Item 2", false)
      #=> plain text node
  """
  @spec text_focused(String.t(), boolean(), Style.t() | nil) :: any()
  def text_focused(content, focused, focus_style \\ nil) do
    render_focused(text(content), focused, focus_style)
  end

  @doc """
  Truncates a string to the specified maximum length.

  Unlike `pad_and_truncate/2`, this does not add padding.
  Returns the original string if it's already within the limit.

  ## Examples

      iex> WidgetHelpers.truncate("Hello World", 5)
      "Hello"

      iex> WidgetHelpers.truncate("Hi", 10)
      "Hi"
  """
  @spec truncate(String.t(), non_neg_integer()) :: String.t()
  def truncate(string, max_length) when is_binary(string) and is_integer(max_length) and max_length >= 0 do
    String.slice(string, 0, max_length)
  end

  def truncate(_, _), do: ""

  @doc """
  Builds a focus indicator string based on focus state.

  Returns a prefix indicator typically used in list displays.

  ## Examples

      iex> WidgetHelpers.focus_indicator(true)
      "> "

      iex> WidgetHelpers.focus_indicator(false)
      "  "

      iex> WidgetHelpers.focus_indicator(true, "→ ", "  ")
      "→ "
  """
  @spec focus_indicator(boolean(), String.t(), String.t()) :: String.t()
  def focus_indicator(focused, indicator \\ "> ", blank \\ "  ")

  def focus_indicator(true, indicator, _blank), do: indicator
  def focus_indicator(false, _indicator, blank), do: blank
end
