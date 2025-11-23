defmodule TermUI.Component.Introspection do
  @moduledoc """
  Supervision introspection tools for debugging and monitoring.

  Provides visibility into the component tree structure, component states,
  and supervision metrics for debugging and monitoring purposes.

  ## Usage

      # Get tree structure
      tree = Introspection.get_component_tree()

      # Get component info
      info = Introspection.get_component_info(:my_component)

      # Print tree visualization
      Introspection.print_tree()

      # Get supervision metrics
      metrics = Introspection.get_metrics(:my_component)
  """

  alias TermUI.Component.StatePersistence
  alias TermUI.ComponentRegistry
  alias TermUI.ComponentServer

  @doc """
  Returns the component tree structure.

  ## Returns

  A map with tree structure:
  ```
  %{
    id: term(),
    pid: pid(),
    module: module(),
    children: [...]
  }
  ```
  """
  @spec get_component_tree() :: [map()]
  def get_component_tree do
    # Get all components
    components = ComponentRegistry.list_all()

    # Build parent-child relationships
    components
    |> Enum.map(fn component ->
      children = get_children_tree(component.id, components)

      %{
        id: component.id,
        pid: component.pid,
        module: component.module,
        children: children
      }
    end)
    |> Enum.filter(fn component ->
      # Only include root components (those without parents)
      case ComponentRegistry.get_parent(component.id) do
        {:ok, nil} -> true
        {:ok, _parent} -> false
        {:error, :not_found} -> true
      end
    end)
  end

  defp get_children_tree(parent_id, all_components) do
    child_ids = ComponentRegistry.get_children(parent_id)

    Enum.map(child_ids, fn child_id ->
      component = Enum.find(all_components, fn c -> c.id == child_id end)

      if component do
        %{
          id: component.id,
          pid: component.pid,
          module: component.module,
          children: get_children_tree(child_id, all_components)
        }
      else
        nil
      end
    end)
    |> Enum.reject(&is_nil/1)
  end

  @doc """
  Returns detailed information about a component.

  ## Parameters

  - `component_id` - Component identifier

  ## Returns

  - `{:ok, info}` - Component information
  - `{:error, :not_found}` - Component not found
  """
  @spec get_component_info(term()) :: {:ok, map()} | {:error, :not_found}
  def get_component_info(component_id) do
    case ComponentRegistry.get_info(component_id) do
      {:ok, info} ->
        pid = info.pid

        # Get additional info from the component server
        {state, props, lifecycle} =
          try do
            state = ComponentServer.get_state(pid)
            props = ComponentServer.get_props(pid)
            lifecycle = ComponentServer.get_lifecycle(pid)
            {state, props, lifecycle}
          catch
            :exit, _ -> {nil, nil, :unknown}
          end

        # Get metrics
        restart_count = StatePersistence.get_restart_count(component_id)
        child_count = length(ComponentRegistry.get_children(component_id))

        # Calculate uptime (use reductions as proxy since start_time not always available)
        uptime_ms =
          case Process.info(pid, :reductions) do
            # Can't reliably calculate uptime
            {:reductions, _} -> 0
            nil -> 0
          end

        enhanced_info =
          Map.merge(info, %{
            state: state,
            props: props,
            lifecycle: lifecycle,
            restart_count: restart_count,
            child_count: child_count,
            uptime_ms: uptime_ms
          })

        {:ok, enhanced_info}

      {:error, :not_found} ->
        {:error, :not_found}
    end
  end

  @doc """
  Returns supervision metrics for a component.

  ## Parameters

  - `component_id` - Component identifier

  ## Returns

  - `{:ok, metrics}` - Metrics map
  - `{:error, :not_found}` - Component not found
  """
  @spec get_metrics(term()) :: {:ok, map()} | {:error, :not_found}
  def get_metrics(component_id) do
    case ComponentRegistry.lookup(component_id) do
      {:ok, pid} ->
        restart_count = StatePersistence.get_restart_count(component_id)
        child_count = length(ComponentRegistry.get_children(component_id))

        # Get process info
        info =
          Process.info(pid, [
            :memory,
            :message_queue_len,
            :reductions,
            :status
          ]) || []

        # uptime_ms not reliably available
        uptime_ms = 0

        metrics = %{
          restart_count: restart_count,
          child_count: child_count,
          uptime_ms: uptime_ms,
          memory_bytes: Keyword.get(info, :memory, 0),
          message_queue_len: Keyword.get(info, :message_queue_len, 0),
          reductions: Keyword.get(info, :reductions, 0),
          status: Keyword.get(info, :status, :unknown)
        }

        {:ok, metrics}

      {:error, :not_found} ->
        {:error, :not_found}
    end
  end

  @doc """
  Prints a text visualization of the component tree.

  ## Options

  - `:io` - IO device to print to (default: `:stdio`)
  """
  @spec print_tree(keyword()) :: :ok
  def print_tree(opts \\ []) do
    io = Keyword.get(opts, :io, :stdio)
    tree = get_component_tree()

    if Enum.empty?(tree) do
      IO.puts(io, "(no components)")
    else
      Enum.each(tree, fn node ->
        print_node(io, node, "")
      end)
    end

    :ok
  end

  defp print_node(io, node, prefix) do
    pid_str = inspect(node.pid)
    module_str = inspect(node.module) |> String.replace("Elixir.", "")

    IO.puts(io, "#{prefix}#{node.id} (#{pid_str}) - #{module_str}")

    children = node.children
    child_count = length(children)

    Enum.with_index(children, fn child, index ->
      is_last = index == child_count - 1
      print_child_node(io, child, prefix, is_last)
    end)
  end

  defp print_child_node(io, child, prefix, is_last) do
    child_prefix = get_child_prefix(prefix, is_last)
    cont_prefix = get_continuation_prefix(prefix, is_last)

    # Print child with its prefix
    pid_str = inspect(child.pid)
    module_str = inspect(child.module) |> String.replace("Elixir.", "")
    IO.puts(io, "#{child_prefix}#{child.id} (#{pid_str}) - #{module_str}")

    # Recursively print grandchildren
    grand_children = child.children
    grand_count = length(grand_children)

    Enum.with_index(grand_children, fn grandchild, gindex ->
      is_last_grand = gindex == grand_count - 1
      grand_prefix = get_child_prefix(cont_prefix, is_last_grand)
      print_node(io, grandchild, grand_prefix)
    end)
  end

  defp get_child_prefix(prefix, true), do: "#{prefix}└── "
  defp get_child_prefix(prefix, false), do: "#{prefix}├── "

  defp get_continuation_prefix(prefix, true), do: "#{prefix}    "
  defp get_continuation_prefix(prefix, false), do: "#{prefix}│   "

  @doc """
  Returns the tree as a formatted string.
  """
  @spec format_tree() :: String.t()
  def format_tree do
    {:ok, io} = StringIO.open("")

    print_tree(io: io)

    {_input, output} = StringIO.contents(io)
    StringIO.close(io)

    output
  end

  @doc """
  Returns aggregate statistics for all components.
  """
  @spec aggregate_stats() :: map()
  def aggregate_stats do
    components = ComponentRegistry.list_all()

    total_count = length(components)

    total_restarts =
      Enum.reduce(components, 0, fn c, acc ->
        acc + StatePersistence.get_restart_count(c.id)
      end)

    total_memory =
      Enum.reduce(components, 0, fn c, acc ->
        case :erlang.process_info(c.pid, :memory) do
          {:memory, mem} -> acc + mem
          nil -> acc
        end
      end)

    %{
      component_count: total_count,
      total_restarts: total_restarts,
      total_memory_bytes: total_memory,
      persisted_state_count: StatePersistence.count()
    }
  end

  @doc """
  Finds components by module.
  """
  @spec find_by_module(module()) :: [map()]
  def find_by_module(module) do
    ComponentRegistry.list_all()
    |> Enum.filter(fn c -> c.module == module end)
  end

  @doc """
  Finds components with high restart counts.

  ## Parameters

  - `threshold` - Minimum restart count (default: 1)
  """
  @spec find_unstable(non_neg_integer()) :: [map()]
  def find_unstable(threshold \\ 1) do
    ComponentRegistry.list_all()
    |> Enum.map(fn c ->
      restart_count = StatePersistence.get_restart_count(c.id)
      Map.put(c, :restart_count, restart_count)
    end)
    |> Enum.filter(fn c -> c.restart_count >= threshold end)
    |> Enum.sort_by(fn c -> -c.restart_count end)
  end
end
