defmodule TermUI.Dev.StateInspector do
  @moduledoc """
  State Inspector panel for development mode.

  Shows detailed component state in a side panel with expandable tree view.
  Toggle with Ctrl+Shift+S when dev mode is enabled.

  ## Features

  - Tree view of component state
  - Expand/collapse nested values
  - State change highlighting
  - Type information display
  """

  import TermUI.Component.Helpers

  @default_width 40

  @doc """
  Renders the state inspector panel.

  Returns render nodes for the side panel with state tree.
  """
  @spec render(map() | nil, map()) :: term()
  def render(nil, _area) do
    render_empty_panel()
  end

  def render(component_info, area) do
    panel_width = min(@default_width, div(area.width, 3))
    panel_x = area.width - panel_width

    # Render state tree
    state_tree = render_state_tree(component_info.state, 0)

    # Create panel
    header = render_panel_header(component_info.module, panel_width)
    content = render_panel_content(state_tree, panel_width)

    panel = stack(:vertical, [header | content])

    %{
      type: :positioned,
      content: panel,
      x: panel_x,
      y: 0,
      # Below UI inspector but above content
      z: 190
    }
  end

  defp render_empty_panel do
    %{
      type: :empty
    }
  end

  defp render_panel_header(module, width) do
    module_name = get_module_name(module)
    title = " State: #{module_name} "

    # Center title
    remaining = width - String.length(title)
    left = div(remaining, 2)
    right = remaining - left

    header_text = String.duplicate("─", left) <> title <> String.duplicate("─", right)
    text(header_text)
  end

  defp render_panel_content(tree_lines, width) do
    tree_lines
    |> Enum.map(fn line ->
      # Pad or truncate to panel width
      padded = String.pad_trailing(line, width - 2)
      truncated = String.slice(padded, 0, width - 2)
      text("│" <> truncated <> "│")
    end)
  end

  @doc """
  Renders state as a tree of lines.
  """
  @spec render_state_tree(term(), integer()) :: [String.t()]
  def render_state_tree(value, depth) do
    indent = String.duplicate("  ", depth)

    cond do
      is_map(value) and map_size(value) == 0 ->
        [indent <> "%{}"]

      is_map(value) ->
        render_map_tree(value, depth)

      is_list(value) and length(value) == 0 ->
        [indent <> "[]"]

      is_list(value) ->
        render_list_tree(value, depth)

      is_tuple(value) ->
        render_tuple_tree(value, depth)

      struct_value?(value) ->
        render_struct_tree(value, depth)

      true ->
        [indent <> format_value(value)]
    end
  end

  defp render_map_tree(map, depth) do
    indent = String.duplicate("  ", depth)

    header = [indent <> "%{"]

    entries =
      map
      |> Enum.flat_map(fn {key, value} ->
        key_str = format_key(key)

        if is_simple_value(value) do
          [indent <> "  #{key_str}: #{format_value(value)}"]
        else
          [indent <> "  #{key_str}:" | render_state_tree(value, depth + 2)]
        end
      end)

    footer = [indent <> "}"]

    header ++ entries ++ footer
  end

  defp render_list_tree(list, depth) do
    indent = String.duplicate("  ", depth)

    if length(list) > 10 do
      # Truncate long lists
      first_items =
        list
        |> Enum.take(5)
        |> Enum.with_index()
        |> Enum.flat_map(fn {item, idx} ->
          if is_simple_value(item) do
            [indent <> "  [#{idx}]: #{format_value(item)}"]
          else
            [indent <> "  [#{idx}]:" | render_state_tree(item, depth + 2)]
          end
        end)

      [indent <> "["] ++
        first_items ++ [indent <> "  ... (#{length(list) - 5} more)", indent <> "]"]
    else
      entries =
        list
        |> Enum.with_index()
        |> Enum.flat_map(fn {item, idx} ->
          if is_simple_value(item) do
            [indent <> "  [#{idx}]: #{format_value(item)}"]
          else
            [indent <> "  [#{idx}]:" | render_state_tree(item, depth + 2)]
          end
        end)

      [indent <> "["] ++ entries ++ [indent <> "]"]
    end
  end

  defp render_tuple_tree(tuple, depth) do
    indent = String.duplicate("  ", depth)
    elements = Tuple.to_list(tuple)

    if tuple_size(tuple) <= 3 and Enum.all?(elements, &is_simple_value/1) do
      # Inline small tuples
      values = Enum.map_join(elements, ", ", &format_value/1)
      [indent <> "{#{values}}"]
    else
      entries =
        elements
        |> Enum.with_index()
        |> Enum.flat_map(fn {item, idx} ->
          if is_simple_value(item) do
            [indent <> "  .#{idx}: #{format_value(item)}"]
          else
            [indent <> "  .#{idx}:" | render_state_tree(item, depth + 2)]
          end
        end)

      [indent <> "{"] ++ entries ++ [indent <> "}"]
    end
  end

  defp render_struct_tree(struct, depth) do
    indent = String.duplicate("  ", depth)
    struct_name = struct.__struct__ |> get_module_name()

    map = Map.from_struct(struct)

    if map_size(map) == 0 do
      [indent <> "%#{struct_name}{}"]
    else
      entries =
        map
        |> Enum.flat_map(fn {key, value} ->
          key_str = to_string(key)

          if is_simple_value(value) do
            [indent <> "  #{key_str}: #{format_value(value)}"]
          else
            [indent <> "  #{key_str}:" | render_state_tree(value, depth + 2)]
          end
        end)

      [indent <> "%#{struct_name}{"] ++ entries ++ [indent <> "}"]
    end
  end

  defp struct_value?(%{__struct__: _}), do: true
  defp struct_value?(_), do: false

  defp is_simple_value(value) do
    is_atom(value) or is_number(value) or is_binary(value) or
      is_boolean(value) or is_nil(value) or is_pid(value) or is_reference(value)
  end

  defp format_key(key) when is_atom(key), do: to_string(key)
  defp format_key(key), do: inspect(key)

  defp format_value(nil), do: "nil"
  defp format_value(true), do: "true"
  defp format_value(false), do: "false"
  defp format_value(value) when is_atom(value), do: ":#{value}"
  defp format_value(value) when is_integer(value), do: to_string(value)
  defp format_value(value) when is_float(value), do: Float.to_string(value)

  defp format_value(value) when is_binary(value) do
    if String.printable?(value) do
      if String.length(value) > 30 do
        "\"#{String.slice(value, 0, 27)}...\""
      else
        "\"#{value}\""
      end
    else
      "<<binary #{byte_size(value)} bytes>>"
    end
  end

  defp format_value(value) when is_pid(value), do: inspect(value)
  defp format_value(value) when is_reference(value), do: "#Ref<...>"

  defp format_value(value) when is_function(value) do
    info = Function.info(value)
    "#Function<#{info[:arity]}>"
  end

  defp format_value(value), do: inspect(value, limit: 10)

  defp get_module_name(module) when is_atom(module) do
    module
    |> Atom.to_string()
    |> String.split(".")
    |> List.last()
  end

  defp get_module_name(_), do: "Unknown"

  @doc """
  Compares two states and returns paths that changed.
  """
  @spec diff_states(term(), term()) :: [list()]
  def diff_states(old_state, new_state) do
    diff_values(old_state, new_state, [])
  end

  defp diff_values(old, new, _path) when old == new, do: []

  defp diff_values(old, new, path) when is_map(old) and is_map(new) do
    all_keys = MapSet.union(MapSet.new(Map.keys(old)), MapSet.new(Map.keys(new)))

    Enum.flat_map(all_keys, fn key ->
      old_val = Map.get(old, key)
      new_val = Map.get(new, key)
      diff_values(old_val, new_val, path ++ [key])
    end)
  end

  defp diff_values(_old, _new, path), do: [path]
end
