defmodule TermUI.ComponentSupervisor do
  @moduledoc """
  Dynamic supervisor for managing component processes.

  Components are spawned as child processes under this supervisor,
  providing fault isolation and automatic cleanup. Each component
  runs as a GenServer managed by `TermUI.ComponentServer`.

  ## Usage

      # Start a component under the supervisor
      {:ok, pid} = ComponentSupervisor.start_component(MyComponent, %{text: "Hello"})

      # Stop a component
      :ok = ComponentSupervisor.stop_component(pid)

  ## Supervision Strategy

  Uses `:one_for_one` strategy - each component is independent.
  Default restart is `:transient` - restart only on crash, not normal exit.
  """

  use DynamicSupervisor

  @doc """
  Starts the component supervisor.

  Called by the application supervisor during startup.
  """
  @spec start_link(keyword()) :: Supervisor.on_start()
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    DynamicSupervisor.start_link(__MODULE__, opts, name: name)
  end

  @impl true
  def init(_opts) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  @doc """
  Starts a component under the supervisor.

  ## Parameters

  - `module` - The component module implementing a behaviour
  - `props` - Initial properties for the component
  - `opts` - Options including `:id` for component identification

  ## Options

  - `:id` - Component identifier for registry lookup
  - `:name` - Process name registration
  - `:timeout` - Init timeout in milliseconds (default 5000)

  ## Returns

  - `{:ok, pid}` - Component started successfully
  - `{:error, reason}` - Failed to start

  ## Examples

      {:ok, pid} = ComponentSupervisor.start_component(Label, %{text: "Hello"})

      {:ok, pid} = ComponentSupervisor.start_component(
        Button,
        %{label: "Click"},
        id: :submit_button
      )
  """
  @spec start_component(module(), map(), keyword()) :: DynamicSupervisor.on_start_child()
  def start_component(module, props, opts \\ []) do
    child_spec = %{
      id: Keyword.get(opts, :id, make_ref()),
      start: {TermUI.ComponentServer, :start_link, [module, props, opts]},
      restart: Keyword.get(opts, :restart, :transient),
      type: :worker
    }

    DynamicSupervisor.start_child(__MODULE__, child_spec)
  end

  @doc """
  Stops a component gracefully.

  Triggers the unmount lifecycle before termination.

  ## Parameters

  - `pid` - The component process pid

  ## Returns

  - `:ok` - Component stopped successfully
  - `{:error, :not_found}` - Component not found
  """
  @spec stop_component(pid()) :: :ok | {:error, :not_found}
  def stop_component(pid) when is_pid(pid) do
    case DynamicSupervisor.terminate_child(__MODULE__, pid) do
      :ok -> :ok
      {:error, :not_found} -> {:error, :not_found}
    end
  end

  @doc """
  Returns the count of running components.
  """
  @spec count_children() :: non_neg_integer()
  def count_children do
    %{workers: count} = DynamicSupervisor.count_children(__MODULE__)
    count
  end

  @doc """
  Returns all component pids.
  """
  @spec which_children() :: [pid()]
  def which_children do
    __MODULE__
    |> DynamicSupervisor.which_children()
    |> Enum.map(fn {_, pid, _, _} -> pid end)
    |> Enum.filter(&is_pid/1)
  end
end
