defmodule TermUI.Widgets.SplitPane do
  @moduledoc """
  SplitPane widget for resizable multi-pane layouts.

  SplitPane divides space between two or more panes with draggable dividers,
  enabling complex layouts like IDE editors with sidebars and bottom panels.

  ## Usage

      SplitPane.new(
        orientation: :horizontal,
        panes: [
          %{id: :left, content: sidebar(), size: 0.25, min_size: 10},
          %{id: :right, content: main_content(), size: 0.75}
        ]
      )

  ## Features

  - Horizontal and vertical split orientations
  - Draggable dividers (keyboard and mouse)
  - Min/max size constraints per pane
  - Collapsible panes
  - Nested splits for complex layouts
  - Layout state persistence

  ## Keyboard Controls

  - Tab: Move focus between dividers
  - Left/Up: Move divider left/up (decrease pane before)
  - Right/Down: Move divider right/down (increase pane before)
  - Shift+Left/Up: Move divider by larger step
  - Shift+Right/Down: Move divider by larger step
  - Enter: Toggle collapse of pane after divider
  - Home: Move divider to minimum position
  - End: Move divider to maximum position
  """

  use TermUI.StatefulComponent

  alias TermUI.Event

  @type orientation :: :horizontal | :vertical

  @type pane_spec :: %{
          id: term(),
          content: term(),
          size: number(),
          min_size: non_neg_integer() | nil,
          max_size: non_neg_integer() | nil,
          collapsed: boolean()
        }

  @type pane :: %{
          id: term(),
          content: term(),
          size: number(),
          min_size: non_neg_integer() | nil,
          max_size: non_neg_integer() | nil,
          collapsed: boolean(),
          computed_size: non_neg_integer()
        }

  @default_divider_style Style.new(fg: :white)
  @focused_divider_style Style.new(fg: :cyan, attrs: [:bold])
  @resize_step 1
  @large_resize_step 5

  # Divider characters
  @vertical_divider "│"
  @vertical_divider_focused "┃"
  @horizontal_divider "─"
  @horizontal_divider_focused "━"

  # ----------------------------------------------------------------------------
  # Pane Constructors
  # ----------------------------------------------------------------------------

  @doc """
  Creates a pane specification.

  ## Options

  - `:size` - Size as float (0.0-1.0 proportion) or integer (fixed chars/lines)
  - `:min_size` - Minimum size in characters/lines
  - `:max_size` - Maximum size in characters/lines
  - `:collapsed` - Whether pane starts collapsed (default: false)
  """
  @spec pane(term(), term(), keyword()) :: pane_spec()
  def pane(id, content, opts \\ []) do
    %{
      id: id,
      content: content,
      size: Keyword.get(opts, :size, 1.0),
      min_size: Keyword.get(opts, :min_size),
      max_size: Keyword.get(opts, :max_size),
      collapsed: Keyword.get(opts, :collapsed, false)
    }
  end

  # ----------------------------------------------------------------------------
  # Props
  # ----------------------------------------------------------------------------

  @doc """
  Creates new SplitPane widget props.

  ## Options

  - `:orientation` - `:horizontal` (side by side) or `:vertical` (stacked) (default: :horizontal)
  - `:panes` - List of pane specifications (required)
  - `:divider_size` - Divider thickness in characters (default: 1)
  - `:divider_style` - Style for dividers
  - `:focused_divider_style` - Style for focused divider
  - `:resizable` - Whether dividers can be dragged (default: true)
  - `:on_resize` - Callback when panes are resized: `fn panes -> ... end`
  - `:on_collapse` - Callback when pane is collapsed/expanded: `fn {id, collapsed} -> ... end`
  - `:persist_key` - Key for layout persistence (optional)
  """
  @spec new(keyword()) :: map()
  def new(opts) do
    %{
      orientation: Keyword.get(opts, :orientation, :horizontal),
      panes: Keyword.fetch!(opts, :panes),
      divider_size: Keyword.get(opts, :divider_size, 1),
      divider_style: Keyword.get(opts, :divider_style, @default_divider_style),
      focused_divider_style: Keyword.get(opts, :focused_divider_style, @focused_divider_style),
      resizable: Keyword.get(opts, :resizable, true),
      on_resize: Keyword.get(opts, :on_resize),
      on_collapse: Keyword.get(opts, :on_collapse),
      persist_key: Keyword.get(opts, :persist_key)
    }
  end

  # ----------------------------------------------------------------------------
  # StatefulComponent Callbacks
  # ----------------------------------------------------------------------------

  @impl true
  def init(props) do
    panes =
      props.panes
      |> Enum.map(fn pane_spec ->
        Map.merge(pane_spec, %{computed_size: 0})
      end)

    state = %{
      orientation: props.orientation,
      panes: panes,
      divider_size: props.divider_size,
      divider_style: props.divider_style,
      focused_divider_style: props.focused_divider_style,
      resizable: props.resizable,
      focused_divider: nil,
      dragging: false,
      drag_start: nil,
      drag_divider: nil,
      on_resize: props.on_resize,
      on_collapse: props.on_collapse,
      persist_key: props.persist_key,
      # Will be set on first render
      total_size: 0,
      last_area: nil
    }

    {:ok, state}
  end

  @impl true
  def handle_event(%Event.Key{key: :tab, modifiers: modifiers}, state) when state.resizable do
    if :shift in modifiers do
      handle_shift_tab(state)
    else
      handle_tab(state)
    end
  end

  # Arrow keys for resizing
  def handle_event(%Event.Key{key: key, modifiers: modifiers}, state)
      when key in [:left, :up] and state.focused_divider != nil and state.resizable do
    step = if :shift in modifiers, do: @large_resize_step, else: @resize_step
    move_divider(state, state.focused_divider, -step)
  end

  def handle_event(%Event.Key{key: key, modifiers: modifiers}, state)
      when key in [:right, :down] and state.focused_divider != nil and state.resizable do
    step = if :shift in modifiers, do: @large_resize_step, else: @resize_step
    move_divider(state, state.focused_divider, step)
  end

  # Home/End for min/max positions
  def handle_event(%Event.Key{key: :home}, state)
      when state.focused_divider != nil and state.resizable do
    move_divider_to_min(state, state.focused_divider)
  end

  def handle_event(%Event.Key{key: :end}, state)
      when state.focused_divider != nil and state.resizable do
    move_divider_to_max(state, state.focused_divider)
  end

  # Enter to toggle collapse
  def handle_event(%Event.Key{key: :enter}, state) when state.focused_divider != nil do
    toggle_collapse(state, state.focused_divider + 1)
  end

  # Mouse click on divider
  def handle_event(%Event.Mouse{action: :click, x: x, y: y}, state) when state.resizable do
    case divider_at(state, x, y) do
      nil ->
        {:ok, %{state | focused_divider: nil}}

      divider_index ->
        pos = if state.orientation == :horizontal, do: x, else: y

        {:ok,
         %{
           state
           | focused_divider: divider_index,
             dragging: true,
             drag_start: pos,
             drag_divider: divider_index
         }}
    end
  end

  # Mouse drag
  def handle_event(%Event.Mouse{action: :drag, x: x, y: y}, state)
      when state.dragging and state.resizable do
    pos = if state.orientation == :horizontal, do: x, else: y
    delta = pos - state.drag_start
    state = %{state | drag_start: pos}
    move_divider(state, state.drag_divider, delta)
  end

  # Mouse release
  def handle_event(%Event.Mouse{action: :release}, state) do
    {:ok, %{state | dragging: false, drag_start: nil, drag_divider: nil}}
  end

  # Double-click to toggle collapse
  def handle_event(%Event.Mouse{action: :double_click, x: x, y: y}, state) do
    case divider_at(state, x, y) do
      nil -> {:ok, state}
      divider_index -> toggle_collapse(state, divider_index + 1)
    end
  end

  def handle_event(_event, state) do
    {:ok, state}
  end

  @impl true
  def render(state, area) do
    # Recalculate sizes based on current area
    state = compute_pane_sizes(state, area)

    case state.orientation do
      :horizontal -> render_horizontal(state, area)
      :vertical -> render_vertical(state, area)
    end
  end

  # ----------------------------------------------------------------------------
  # Public API
  # ----------------------------------------------------------------------------

  @doc """
  Gets the current layout state for persistence.

  Returns a map of pane IDs to their sizes and collapsed states.
  """
  @spec get_layout(map()) :: map()
  def get_layout(state) do
    state.panes
    |> Enum.map(fn pane ->
      {pane.id, %{size: pane.size, collapsed: pane.collapsed}}
    end)
    |> Map.new()
  end

  @doc """
  Restores layout from a saved state.
  """
  @spec set_layout(map(), map()) :: map()
  def set_layout(state, layout) do
    panes =
      Enum.map(state.panes, fn pane ->
        case Map.get(layout, pane.id) do
          nil ->
            pane

          saved ->
            %{
              pane
              | size: Map.get(saved, :size, pane.size),
                collapsed: Map.get(saved, :collapsed, pane.collapsed)
            }
        end
      end)

    %{state | panes: panes}
  end

  @doc """
  Collapses a pane by ID.
  """
  @spec collapse(map(), term()) :: map()
  def collapse(state, pane_id) do
    update_pane(state, pane_id, fn pane -> %{pane | collapsed: true} end)
  end

  @doc """
  Expands a collapsed pane by ID.
  """
  @spec expand(map(), term()) :: map()
  def expand(state, pane_id) do
    update_pane(state, pane_id, fn pane -> %{pane | collapsed: false} end)
  end

  @doc """
  Toggles collapse state of a pane by ID.
  """
  @spec toggle(map(), term()) :: map()
  def toggle(state, pane_id) do
    update_pane(state, pane_id, fn pane -> %{pane | collapsed: not pane.collapsed} end)
  end

  @doc """
  Sets the size of a pane by ID.
  """
  @spec set_pane_size(map(), term(), number()) :: map()
  def set_pane_size(state, pane_id, size) do
    update_pane(state, pane_id, fn pane -> %{pane | size: size} end)
  end

  @doc """
  Gets a list of pane IDs.
  """
  @spec get_pane_ids(map()) :: [term()]
  def get_pane_ids(state) do
    Enum.map(state.panes, & &1.id)
  end

  @doc """
  Gets the focused divider index (0-indexed), or nil if none focused.
  """
  @spec get_focused_divider(map()) :: non_neg_integer() | nil
  def get_focused_divider(state) do
    state.focused_divider
  end

  @doc """
  Updates content of a pane by ID.
  """
  @spec set_content(map(), term(), term()) :: map()
  def set_content(state, pane_id, content) do
    update_pane(state, pane_id, fn pane -> %{pane | content: content} end)
  end

  # ----------------------------------------------------------------------------
  # Private: Size Calculation
  # ----------------------------------------------------------------------------

  defp compute_pane_sizes(state, area) do
    total_size =
      if state.orientation == :horizontal do
        area.width
      else
        area.height
      end

    num_dividers = length(state.panes) - 1
    divider_space = num_dividers * state.divider_size
    available_space = max(0, total_size - divider_space)

    # Separate collapsed and visible panes
    {visible_panes, collapsed_indices} =
      state.panes
      |> Enum.with_index()
      |> Enum.reduce({[], []}, fn {pane, idx}, {visible, collapsed} ->
        if pane.collapsed do
          {visible, [idx | collapsed]}
        else
          {[{pane, idx} | visible], collapsed}
        end
      end)

    visible_panes = Enum.reverse(visible_panes)
    collapsed_indices = Enum.reverse(collapsed_indices)

    # Calculate sizes for visible panes
    computed_sizes = distribute_space(visible_panes, available_space)

    # Build final panes list with computed sizes
    panes =
      state.panes
      |> Enum.with_index()
      |> Enum.map(fn {pane, idx} ->
        if idx in collapsed_indices do
          %{pane | computed_size: 0}
        else
          visible_idx = Enum.find_index(visible_panes, fn {_, i} -> i == idx end)
          size = Enum.at(computed_sizes, visible_idx, 0)
          %{pane | computed_size: size}
        end
      end)

    %{state | panes: panes, total_size: total_size, last_area: area}
  end

  defp distribute_space([], _available), do: []

  defp distribute_space(visible_panes, available_space) do
    # First pass: calculate proportional sizes
    total_proportion =
      visible_panes
      |> Enum.map(fn {pane, _} -> normalize_size(pane.size) end)
      |> Enum.sum()

    total_proportion = max(total_proportion, 0.001)

    initial_sizes =
      Enum.map(visible_panes, fn {pane, _} ->
        proportion = normalize_size(pane.size) / total_proportion
        round(available_space * proportion)
      end)

    # Second pass: apply min/max constraints
    constrained_sizes =
      visible_panes
      |> Enum.zip(initial_sizes)
      |> Enum.map(fn {{pane, _}, size} ->
        size
        |> apply_min_constraint(pane.min_size)
        |> apply_max_constraint(pane.max_size)
      end)

    # Third pass: redistribute any remaining space
    total_assigned = Enum.sum(constrained_sizes)
    remaining = available_space - total_assigned

    if remaining != 0 and length(constrained_sizes) > 0 do
      redistribute_space(visible_panes, constrained_sizes, remaining)
    else
      constrained_sizes
    end
  end

  defp normalize_size(size) when is_float(size) and size > 0 and size <= 1, do: size
  defp normalize_size(size) when is_integer(size) and size > 0, do: size / 100.0
  defp normalize_size(_), do: 1.0

  defp apply_min_constraint(size, nil), do: size
  defp apply_min_constraint(size, min_size), do: max(size, min_size)

  defp apply_max_constraint(size, nil), do: size
  defp apply_max_constraint(size, max_size), do: min(size, max_size)

  defp redistribute_space(visible_panes, sizes, remaining) do
    # Find panes that can absorb extra space
    flexible_indices =
      visible_panes
      |> Enum.with_index()
      |> Enum.filter(fn {{pane, _}, idx} ->
        current_size = Enum.at(sizes, idx)

        cond do
          remaining > 0 -> pane.max_size == nil or current_size < pane.max_size
          remaining < 0 -> pane.min_size == nil or current_size > pane.min_size
          true -> false
        end
      end)
      |> Enum.map(fn {_, idx} -> idx end)

    if flexible_indices == [] do
      sizes
    else
      flexible_count = length(flexible_indices)
      per_pane = div(remaining, flexible_count)
      leftover = rem(remaining, flexible_count)

      sizes
      |> Enum.with_index()
      |> Enum.map(fn {size, idx} ->
        if idx in flexible_indices do
          extra = if idx == hd(flexible_indices), do: per_pane + leftover, else: per_pane
          max(0, size + extra)
        else
          size
        end
      end)
    end
  end

  # ----------------------------------------------------------------------------
  # Private: Rendering
  # ----------------------------------------------------------------------------

  defp render_horizontal(state, area) do
    children = build_horizontal_children(state, area)
    stack(:horizontal, children)
  end

  defp render_vertical(state, area) do
    children = build_vertical_children(state, area)
    stack(:vertical, children)
  end

  defp build_horizontal_children(state, area) do
    state.panes
    |> Enum.with_index()
    |> Enum.flat_map(fn {pane, idx} ->
      pane_element =
        if pane.collapsed do
          []
        else
          [render_pane_content(pane, area, state.orientation)]
        end

      # Add divider after each pane except the last
      divider_element =
        if idx < length(state.panes) - 1 do
          [render_vertical_divider(state, idx, area.height)]
        else
          []
        end

      pane_element ++ divider_element
    end)
  end

  defp build_vertical_children(state, area) do
    state.panes
    |> Enum.with_index()
    |> Enum.flat_map(fn {pane, idx} ->
      pane_element =
        if pane.collapsed do
          []
        else
          [render_pane_content(pane, area, state.orientation)]
        end

      # Add divider after each pane except the last
      divider_element =
        if idx < length(state.panes) - 1 do
          [render_horizontal_divider(state, idx, area.width)]
        else
          []
        end

      pane_element ++ divider_element
    end)
  end

  defp render_pane_content(pane, area, orientation) do
    # Create a container with the computed size
    pane_area =
      if orientation == :horizontal do
        %{area | width: pane.computed_size}
      else
        %{area | height: pane.computed_size}
      end

    # Wrap content in a box with the pane's size
    # Content can be a render node or needs to be wrapped
    content = wrap_content(pane.content)
    box(content, width: pane_area.width, height: pane_area.height)
  end

  defp wrap_content(content) when is_list(content), do: content
  defp wrap_content(%RenderNode{} = content), do: [content]
  defp wrap_content(content) when is_binary(content), do: [text(content)]
  defp wrap_content(content), do: [content]

  defp render_vertical_divider(state, divider_idx, height) do
    is_focused = state.focused_divider == divider_idx
    style = if is_focused, do: state.focused_divider_style, else: state.divider_style
    char = if is_focused, do: @vertical_divider_focused, else: @vertical_divider

    lines =
      for _ <- 1..height do
        char
      end

    text(Enum.join(lines, "\n"), style)
  end

  defp render_horizontal_divider(state, divider_idx, width) do
    is_focused = state.focused_divider == divider_idx
    style = if is_focused, do: state.focused_divider_style, else: state.divider_style
    char = if is_focused, do: @horizontal_divider_focused, else: @horizontal_divider

    text(String.duplicate(char, width), style)
  end

  # ----------------------------------------------------------------------------
  # Private: Divider Movement
  # ----------------------------------------------------------------------------

  defp move_divider(state, _divider_idx, delta) when delta == 0 do
    {:ok, state}
  end

  defp move_divider(state, divider_idx, delta) do
    # Get panes on either side of the divider
    pane_before = Enum.at(state.panes, divider_idx)
    pane_after = Enum.at(state.panes, divider_idx + 1)

    if pane_before && pane_after && not pane_before.collapsed && not pane_after.collapsed do
      # If computed_size is 0, use proportional sizes based on total_size or a default
      {size_before, size_after} =
        if pane_before.computed_size == 0 and pane_after.computed_size == 0 do
          # Use the size ratios to compute approximate sizes
          # Default to 100 units if no area has been rendered yet
          total = if state.total_size > 0, do: state.total_size, else: 100
          {round(pane_before.size * total), round(pane_after.size * total)}
        else
          {pane_before.computed_size, pane_after.computed_size}
        end

      # Calculate new sizes
      new_size_before = size_before + delta
      new_size_after = size_after - delta

      # Apply constraints
      {final_before, final_after} =
        apply_resize_constraints(pane_before, pane_after, new_size_before, new_size_after)

      # Only update if we could actually move
      if final_before != size_before do
        # Update pane sizes as ratios
        total = final_before + final_after

        panes =
          state.panes
          |> Enum.with_index()
          |> Enum.map(fn {pane, idx} ->
            cond do
              idx == divider_idx -> %{pane | size: final_before / max(total, 1)}
              idx == divider_idx + 1 -> %{pane | size: final_after / max(total, 1)}
              true -> pane
            end
          end)

        state = %{state | panes: panes}
        maybe_call_resize_callback(state)
      else
        {:ok, state}
      end
    else
      {:ok, state}
    end
  end

  defp apply_resize_constraints(pane_before, pane_after, size_before, size_after) do
    # Apply min constraints
    size_before = apply_min_constraint(size_before, pane_before.min_size)
    size_after = apply_min_constraint(size_after, pane_after.min_size)

    # Apply max constraints
    size_before = apply_max_constraint(size_before, pane_before.max_size)
    size_after = apply_max_constraint(size_after, pane_after.max_size)

    # Ensure neither goes negative
    size_before = max(0, size_before)
    size_after = max(0, size_after)

    {size_before, size_after}
  end

  defp move_divider_to_min(state, divider_idx) do
    pane_before = Enum.at(state.panes, divider_idx)

    if pane_before && not pane_before.collapsed do
      min_size = pane_before.min_size || 1
      delta = min_size - pane_before.computed_size
      move_divider(state, divider_idx, delta)
    else
      {:ok, state}
    end
  end

  defp move_divider_to_max(state, divider_idx) do
    pane_after = Enum.at(state.panes, divider_idx + 1)

    if pane_after && not pane_after.collapsed do
      min_size = pane_after.min_size || 1
      delta = pane_after.computed_size - min_size
      move_divider(state, divider_idx, delta)
    else
      {:ok, state}
    end
  end

  # ----------------------------------------------------------------------------
  # Private: Collapse
  # ----------------------------------------------------------------------------

  defp toggle_collapse(state, pane_idx) do
    pane = Enum.at(state.panes, pane_idx)

    if pane do
      panes =
        List.update_at(state.panes, pane_idx, fn p ->
          %{p | collapsed: not p.collapsed}
        end)

      state = %{state | panes: panes}

      if state.on_collapse do
        state.on_collapse.({pane.id, not pane.collapsed})
      end

      {:ok, state}
    else
      {:ok, state}
    end
  end

  # ----------------------------------------------------------------------------
  # Private: Mouse Hit Testing
  # ----------------------------------------------------------------------------

  defp divider_at(state, x, y) do
    case state.orientation do
      :horizontal -> divider_at_horizontal(state, x)
      :vertical -> divider_at_vertical(state, y)
    end
  end

  defp divider_at_horizontal(state, x) do
    # Calculate cumulative positions
    {_, result} =
      state.panes
      |> Enum.take(length(state.panes) - 1)
      |> Enum.with_index()
      |> Enum.reduce({0, nil}, fn {pane, idx}, {pos, found} ->
        pane_end = pos + pane.computed_size
        divider_start = pane_end
        divider_end = divider_start + state.divider_size

        if found == nil && x >= divider_start && x < divider_end do
          {divider_end, idx}
        else
          {divider_end, found}
        end
      end)

    result
  end

  defp divider_at_vertical(state, y) do
    {_, result} =
      state.panes
      |> Enum.take(length(state.panes) - 1)
      |> Enum.with_index()
      |> Enum.reduce({0, nil}, fn {pane, idx}, {pos, found} ->
        pane_end = pos + pane.computed_size
        divider_start = pane_end
        divider_end = divider_start + state.divider_size

        if found == nil && y >= divider_start && y < divider_end do
          {divider_end, idx}
        else
          {divider_end, found}
        end
      end)

    result
  end

  # ----------------------------------------------------------------------------
  # Private: Tab Navigation
  # ----------------------------------------------------------------------------

  defp handle_tab(state) do
    num_dividers = length(state.panes) - 1

    if num_dividers > 0 do
      next_divider =
        case state.focused_divider do
          nil -> 0
          n when n >= num_dividers - 1 -> nil
          n -> n + 1
        end

      {:ok, %{state | focused_divider: next_divider}}
    else
      {:ok, state}
    end
  end

  defp handle_shift_tab(state) do
    num_dividers = length(state.panes) - 1

    if num_dividers > 0 do
      prev_divider =
        case state.focused_divider do
          nil -> num_dividers - 1
          0 -> nil
          n -> n - 1
        end

      {:ok, %{state | focused_divider: prev_divider}}
    else
      {:ok, state}
    end
  end

  # ----------------------------------------------------------------------------
  # Private: Helpers
  # ----------------------------------------------------------------------------

  defp update_pane(state, pane_id, update_fn) do
    panes =
      Enum.map(state.panes, fn pane ->
        if pane.id == pane_id do
          update_fn.(pane)
        else
          pane
        end
      end)

    %{state | panes: panes}
  end

  defp maybe_call_resize_callback(state) do
    if state.on_resize do
      sizes = Enum.map(state.panes, fn p -> {p.id, p.size} end)
      state.on_resize.(sizes)
    end

    {:ok, state}
  end
end
