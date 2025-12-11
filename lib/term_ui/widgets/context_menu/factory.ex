defmodule TermUI.Widgets.ContextMenu.Factory do
  @moduledoc """
  Factory for creating context menus with automatic mode selection.

  This module provides a unified way to create context menus that automatically
  selects between positioned (mouse) and inline (keyboard) modes based on
  terminal capabilities and provided options.

  ## Usage

      # Auto-detect: uses positioned if position provided, inline otherwise
      {:ok, {module, props}} = Factory.create(
        items: [
          ContextMenu.action(:copy, "Copy"),
          ContextMenu.action(:paste, "Paste")
        ],
        position: {10, 5},  # Optional - triggers positioned mode
        on_select: fn id -> handle_action(id) end
      )

      # Force inline mode
      {:ok, {module, props}} = Factory.create(
        items: items,
        mode: :inline,
        on_select: on_select
      )

      # Force positioned mode (requires position)
      {:ok, {module, props}} = Factory.create(
        items: items,
        mode: :positioned,
        position: {x, y},
        on_select: on_select
      )

  ## Mode Selection

  The factory selects a menu mode based on:

  1. **Explicit mode** - If `:mode` option is provided:
     - `:inline` - Always use `ContextMenu.Inline`
     - `:positioned` - Always use `ContextMenu` (requires `:position`)
     - `:auto` - Auto-detect based on position and capabilities (default)

  2. **Auto-detection** (`:mode == :auto` or not specified):
     - If `:position` is provided → use positioned `ContextMenu`
     - If no position and mouse not supported → use `ContextMenu.Inline`
     - If no position but mouse supported → returns error (caller should provide position)

  ## Return Value

  Returns `{:ok, {module, props}}` where:
  - `module` is either `TermUI.Widgets.ContextMenu` or `TermUI.Widgets.ContextMenu.Inline`
  - `props` are the initialized props for that module

  Or `{:error, reason}` if the configuration is invalid.
  """

  alias TermUI.Capabilities
  alias TermUI.Widgets.ContextMenu
  alias TermUI.Widgets.ContextMenu.Inline

  @type mode :: :auto | :positioned | :inline

  @type option ::
          {:items, [map()]}
          | {:position, {non_neg_integer(), non_neg_integer()}}
          | {:mode, mode()}
          | {:on_select, (term() -> any())}
          | {:on_close, (() -> any())}
          | {:orientation, :horizontal | :vertical}
          | {:item_style, term()}
          | {:selected_style, term()}
          | {:disabled_style, term()}
          | {:number_style, term()}

  @doc """
  Creates a context menu with automatic mode selection.

  ## Options

  - `:items` - List of menu items (required). Use `ContextMenu.action/3` and
    `ContextMenu.separator/0` to create items.
  - `:position` - `{x, y}` tuple for positioned mode. If provided and mode is
    `:auto`, positioned mode will be used.
  - `:mode` - Explicit mode selection:
    - `:auto` - Auto-detect based on position and capabilities (default)
    - `:positioned` - Force positioned mode (requires `:position`)
    - `:inline` - Force inline mode
  - `:on_select` - Callback when item is selected: `fn id -> ... end`
  - `:on_close` - Callback when menu is closed: `fn -> ... end`
  - `:orientation` - For inline mode: `:horizontal` (default) or `:vertical`
  - `:item_style` - Style for normal items
  - `:selected_style` - Style for focused item
  - `:disabled_style` - Style for disabled items
  - `:number_style` - For inline mode: style for `[n]` prefix

  ## Returns

  - `{:ok, {module, props}}` - The module and props to use
  - `{:error, :missing_items}` - Items not provided
  - `{:error, :missing_position}` - Positioned mode requires position
  - `{:error, :position_required}` - Auto mode with mouse support but no position
  """
  @spec create(keyword()) :: {:ok, {module(), map()}} | {:error, atom()}
  def create(opts) do
    with {:ok, items} <- fetch_items(opts),
         {:ok, mode} <- determine_mode(opts),
         {:ok, {module, props}} <- build_props(mode, items, opts) do
      {:ok, {module, props}}
    end
  end

  @doc """
  Creates a context menu, raising on error.

  Same as `create/1` but raises `ArgumentError` on invalid configuration.
  """
  @spec create!(keyword()) :: {module(), map()}
  def create!(opts) do
    case create(opts) do
      {:ok, result} ->
        result

      {:error, :missing_items} ->
        raise ArgumentError, "ContextMenu.Factory.create!/1 requires :items option"

      {:error, :missing_position} ->
        raise ArgumentError, "positioned mode requires :position option"

      {:error, :position_required} ->
        raise ArgumentError,
              "mouse is supported but no position provided; " <>
                "provide :position or use mode: :inline"
    end
  end

  @doc """
  Returns whether the terminal supports mouse tracking.

  This is used for auto-detection when no position is provided.
  """
  @spec mouse_supported?() :: boolean()
  def mouse_supported? do
    Capabilities.supports_mouse?()
  end

  # Private implementation

  @spec fetch_items(keyword()) :: {:ok, [map()]} | {:error, :missing_items}
  defp fetch_items(opts) do
    case Keyword.fetch(opts, :items) do
      {:ok, items} when is_list(items) -> {:ok, items}
      _ -> {:error, :missing_items}
    end
  end

  @spec determine_mode(keyword()) :: {:ok, mode()} | {:error, atom()}
  defp determine_mode(opts) do
    mode = Keyword.get(opts, :mode, :auto)
    position = Keyword.get(opts, :position)

    case {mode, position} do
      {:inline, _} ->
        {:ok, :inline}

      {:positioned, nil} ->
        {:error, :missing_position}

      {:positioned, _pos} ->
        {:ok, :positioned}

      {:auto, {_x, _y}} ->
        {:ok, :positioned}

      {:auto, nil} ->
        if mouse_supported?() do
          # Mouse is supported but no position provided
          # This is ambiguous - caller should either provide position or force inline
          {:error, :position_required}
        else
          {:ok, :inline}
        end
    end
  end

  @spec build_props(mode(), [map()], keyword()) :: {:ok, {module(), map()}}
  defp build_props(:positioned, items, opts) do
    props =
      ContextMenu.new(
        items: items,
        position: Keyword.fetch!(opts, :position),
        on_select: Keyword.get(opts, :on_select),
        on_close: Keyword.get(opts, :on_close),
        item_style: Keyword.get(opts, :item_style),
        selected_style: Keyword.get(opts, :selected_style),
        disabled_style: Keyword.get(opts, :disabled_style)
      )

    {:ok, {ContextMenu, props}}
  end

  defp build_props(:inline, items, opts) do
    props =
      Inline.new(
        items: items,
        on_select: Keyword.get(opts, :on_select),
        on_close: Keyword.get(opts, :on_close),
        orientation: Keyword.get(opts, :orientation, :horizontal),
        item_style: Keyword.get(opts, :item_style),
        selected_style: Keyword.get(opts, :selected_style),
        disabled_style: Keyword.get(opts, :disabled_style),
        number_style: Keyword.get(opts, :number_style)
      )

    {:ok, {Inline, props}}
  end
end
