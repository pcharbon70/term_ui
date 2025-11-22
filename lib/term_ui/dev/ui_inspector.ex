defmodule TermUI.Dev.UIInspector do
  @moduledoc """
  UI Inspector overlay for development mode.

  Shows component boundaries, names, types, and render times as an overlay
  on top of the application. Toggle with Ctrl+Shift+I when dev mode is enabled.

  ## Features

  - Component boundary outlines
  - Component name and type labels
  - Render time display
  - Click to select component for state inspection
  """

  import TermUI.Component.Helpers

  @doc """
  Renders the UI inspector overlay.

  Returns render nodes for component boundaries and labels.
  """
  @spec render(map(), term() | nil, map()) :: term()
  def render(components, selected_id, _area) do
    # Render boundaries for all components
    boundaries = components
    |> Enum.map(fn {id, info} ->
      render_component_boundary(id, info, id == selected_id)
    end)

    # Create overlay container
    %{
      type: :overlay,
      content: stack(:vertical, boundaries),
      x: 0,
      y: 0,
      z: 200  # Above normal content
    }
  end

  @doc """
  Renders a single component's boundary and label.
  """
  @spec render_component_boundary(term(), map(), boolean()) :: term()
  def render_component_boundary(id, info, selected?) do
    bounds = info.bounds
    module_name = get_module_name(info.module)
    render_time = format_render_time(info.render_time)

    # Create boundary outline
    border_char = if selected?, do: "█", else: "░"
    border_style = if selected?, do: :selected, else: :normal

    # Top border with label
    label = "#{module_name} (#{render_time})"
    top_line = create_labeled_border(label, bounds.width, border_char)

    # Side borders
    side_lines = for _y <- 1..(bounds.height - 2) do
      border_char <> String.duplicate(" ", bounds.width - 2) <> border_char
    end

    # Bottom border
    bottom_line = String.duplicate(border_char, bounds.width)

    # Combine into positioned element
    content = [top_line | side_lines] ++ [bottom_line]
    lines = Enum.map(content, &text/1)

    %{
      type: :positioned,
      content: stack(:vertical, lines),
      x: bounds.x,
      y: bounds.y,
      id: {:inspector_boundary, id},
      style: border_style
    }
  end

  @doc """
  Creates a top border line with embedded label.
  """
  @spec create_labeled_border(String.t(), integer(), String.t()) :: String.t()
  def create_labeled_border(label, width, char) do
    label_with_brackets = "[ #{label} ]"
    label_len = String.length(label_with_brackets)

    if label_len >= width - 2 do
      # Label too long, truncate
      truncated = String.slice(label_with_brackets, 0, width - 2)
      char <> truncated <> char
    else
      # Center the label
      remaining = width - label_len
      left = div(remaining, 2)
      right = remaining - left
      String.duplicate(char, left) <> label_with_brackets <> String.duplicate(char, right)
    end
  end

  @doc """
  Extracts short module name from full module atom.
  """
  @spec get_module_name(module()) :: String.t()
  def get_module_name(module) when is_atom(module) do
    module
    |> Atom.to_string()
    |> String.split(".")
    |> List.last()
  end

  def get_module_name(_), do: "Unknown"

  @doc """
  Formats render time for display.
  """
  @spec format_render_time(integer()) :: String.t()
  def format_render_time(time_us) when time_us < 1000 do
    "#{time_us}μs"
  end

  def format_render_time(time_us) when time_us < 1_000_000 do
    ms = Float.round(time_us / 1000, 1)
    "#{ms}ms"
  end

  def format_render_time(time_us) do
    s = Float.round(time_us / 1_000_000, 2)
    "#{s}s"
  end

  @doc """
  Finds component at screen position for selection.
  """
  @spec find_component_at(map(), integer(), integer()) :: term() | nil
  def find_component_at(components, x, y) do
    components
    |> Enum.filter(fn {_id, info} ->
      bounds = info.bounds
      x >= bounds.x and x < bounds.x + bounds.width and
      y >= bounds.y and y < bounds.y + bounds.height
    end)
    |> Enum.sort_by(fn {_id, info} ->
      # Prefer smaller (more specific) components
      info.bounds.width * info.bounds.height
    end)
    |> case do
      [{id, _} | _] -> id
      [] -> nil
    end
  end

  @doc """
  Gets summary of component state for quick display.
  """
  @spec get_state_summary(term()) :: String.t()
  def get_state_summary(state) when is_map(state) do
    keys = Map.keys(state)
    count = length(keys)

    if count <= 3 do
      Enum.map_join(keys, ", ", &to_string/1)
    else
      first_three = keys |> Enum.take(3) |> Enum.map_join(", ", &to_string/1)
      "#{first_three}... (+#{count - 3})"
    end
  end

  def get_state_summary(state) when is_list(state) do
    "List[#{length(state)}]"
  end

  def get_state_summary(state) do
    inspect(state, limit: 50)
  end
end
