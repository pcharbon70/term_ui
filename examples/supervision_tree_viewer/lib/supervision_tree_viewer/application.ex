defmodule SupervisionTreeViewerExample.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Sample supervision tree for demonstration
      SupervisionTreeViewerExample.SampleTree
    ]

    opts = [strategy: :one_for_one, name: SupervisionTreeViewerExample.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
