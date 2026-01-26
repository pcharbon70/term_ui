defmodule TermUI.Test.ContextMenuHelpers do
  @moduledoc """
  Shared test helpers for ContextMenu test suites.

  Provides common item builders and utilities used across multiple
  context menu test files.
  """

  alias TermUI.Widgets.ContextMenu

  @doc """
  Creates a simple list of selectable menu items.

  ## Returns

  Three action items: Copy, Paste, Delete
  """
  def simple_items do
    [
      ContextMenu.action(:copy, "Copy"),
      ContextMenu.action(:paste, "Paste"),
      ContextMenu.action(:delete, "Delete")
    ]
  end

  @doc """
  Creates a mixed list of menu items including separators and disabled items.

  ## Returns

  Four items: Copy (enabled), separator, Paste (disabled), Delete (enabled)
  """
  def mixed_items do
    [
      ContextMenu.action(:copy, "Copy"),
      ContextMenu.separator(),
      ContextMenu.action(:paste, "Paste", disabled: true),
      ContextMenu.action(:delete, "Delete")
    ]
  end

  @doc """
  Creates a test area struct for rendering tests.

  ## Parameters

  - `width` - Width of the test area (default: 80)
  - `height` - Height of the test area (default: 24)

  ## Returns

  A map representing a test rendering area
  """
  def test_area(width \\ 80, height \\ 24) do
    %{x: 0, y: 0, width: width, height: height}
  end
end
